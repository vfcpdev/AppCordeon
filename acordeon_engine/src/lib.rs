pub mod audio_analysis;
pub mod audio_driver;
pub mod chord_detector;
pub mod synth;
pub mod voice;

use std::ffi::CString;
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{Mutex, OnceLock};

use audio_driver::AudioDriver;
use synth::{DspRenderer, MidiReceiver};

static DRIVER: OnceLock<Mutex<AudioDriver>> = OnceLock::new();

/// Inicializa el motor DSP nativo.
///
/// # Tripla de Hoare:
/// - {P}: `sample_rate > 0.0` (o usa fallback 44100.0).
/// - {Q}: `DRIVER` está inicializado de forma atómica y segura contra carreras (`OnceLock`).
/// - {I}: No lanza pánicos cruzando el C ABI (`catch_unwind`).
#[no_mangle]
pub extern "C" fn acordeon_engine_init(sample_rate: f32) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        let rate = if sample_rate <= 0.0 { 44100.0 } else { sample_rate };
        DRIVER.get_or_init(|| Mutex::new(AudioDriver::new(rate)));
    }));
}

#[no_mangle]
pub extern "C" fn acordeon_engine_note_on(midi_note: u8) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if let Some(driver_lock) = DRIVER.get() {
            if let Ok(driver) = driver_lock.lock() {
                if let Ok(mut synth) = driver.synth().lock() {
                    synth.note_on(midi_note);
                }
            }
        }
    }));
}

#[no_mangle]
pub extern "C" fn acordeon_engine_note_off(midi_note: u8) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if let Some(driver_lock) = DRIVER.get() {
            if let Ok(driver) = driver_lock.lock() {
                if let Ok(mut synth) = driver.synth().lock() {
                    synth.note_off(midi_note);
                }
            }
        }
    }));
}

#[no_mangle]
pub extern "C" fn acordeon_engine_all_notes_off() {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if let Some(driver_lock) = DRIVER.get() {
            if let Ok(driver) = driver_lock.lock() {
                if let Ok(mut synth) = driver.synth().lock() {
                    synth.all_notes_off();
                }
            }
        }
    }));
}

#[no_mangle]
pub extern "C" fn acordeon_engine_set_volume(vol: f32) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if let Some(driver_lock) = DRIVER.get() {
            if let Ok(driver) = driver_lock.lock() {
                if let Ok(mut synth) = driver.synth().lock() {
                    synth.set_volume(vol);
                }
            }
        }
    }));
}

/// Rellena un buffer PCM monoaural en memoria compartida.
///
/// # Tripla de Hoare:
/// - {P}: `!buffer.is_null() && length > 0 && buffer alineado para f32`.
/// - {Q}: El buffer se completa con valores en `[-1.0, 1.0]`.
/// - {I}: Ningún pánico se propaga hacia el llamador C ABI.
#[no_mangle]
pub extern "C" fn acordeon_engine_process(buffer: *mut f32, length: usize) {
    if buffer.is_null() || length == 0 || (buffer as usize % std::mem::align_of::<f32>() != 0) {
        return;
    }

    let _ = catch_unwind(AssertUnwindSafe(|| {
        if let Some(driver_lock) = DRIVER.get() {
            if let Ok(driver) = driver_lock.lock() {
                if let Ok(mut synth) = driver.synth().lock() {
                    let slice = unsafe { std::slice::from_raw_parts_mut(buffer, length) };
                    synth.process_buffer(slice);
                }
            }
        }
    }));
}

/// Detecta el acorde a partir de notas MIDI y devuelve un puntero CString con JSON serializado.
///
/// # Tripla de Hoare:
/// - {P}: `!notes_ptr.is_null() && count > 0`.
/// - {Q}: Retorna un puntero de cadena C válido (formato JSON seguro) o `{}`.
///        La memoria retornada debe ser liberada con `acordeon_free_string`.
#[no_mangle]
pub extern "C" fn acordeon_detect_chord_ffi(notes_ptr: *const u8, count: usize) -> *mut c_char {
    let fallback = || CString::new("{}").unwrap().into_raw();

    if notes_ptr.is_null() || count == 0 {
        return fallback();
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let notes = unsafe { std::slice::from_raw_parts(notes_ptr, count) };
        if let Some(detected) = chord_detector::detect_chord_from_notes(notes) {
            match serde_json::to_string(&detected) {
                Ok(json_str) => CString::new(json_str).unwrap().into_raw(),
                Err(_) => fallback(),
            }
        } else {
            fallback()
        }
    }));

    result.unwrap_or_else(|_| fallback())
}

/// Analiza un archivo o buffer de audio Float32 y devuelve el reporte completo en JSON.
///
/// # Tripla de Hoare:
/// - {P}: `!channel_data_ptr.is_null() && length >= 4096 && sample_rate > 0.0`.
/// - {Q}: Retorna un JSON válido con la estructura `AudioAnalysisReport` o `{"error":"..."}`.
#[no_mangle]
pub extern "C" fn acordeon_analyze_audio_ffi(
    channel_data_ptr: *const f32,
    length: usize,
    sample_rate: f32,
) -> *mut c_char {
    let fallback_err = |msg: &str| {
        let err_json = format!("{{\"error\":\"{}\"}}", msg);
        CString::new(err_json).unwrap().into_raw()
    };

    if channel_data_ptr.is_null() || length < 4096 || (channel_data_ptr as usize % std::mem::align_of::<f32>() != 0) {
        return fallback_err("Puntero nulo, desalineado o datos insuficientes (<4096 muestras)");
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let slice = unsafe { std::slice::from_raw_parts(channel_data_ptr, length) };
        match audio_analysis::analyze_audio(slice, sample_rate) {
            Ok(json_str) => CString::new(json_str).unwrap().into_raw(),
            Err(err) => fallback_err(&err),
        }
    }));

    result.unwrap_or_else(|_| fallback_err("Excepción interna capturada durante el análisis de audio"))
}

/// Analiza los acordes sincronizados con compases y pulsos a partir de Float32 PCM.
///
/// # Tripla de Hoare:
/// - {P}: `!channel_data_ptr.is_null() && length >= 4096 && sample_rate > 0.0 && bpm >= 30.0`.
/// - {Q}: Retorna un JSON válido con la estructura `BeatAlignedChordsReport` o `{"error":"..."}`.
///        La memoria retornada debe liberarse con `acordeon_free_string`.
/// - {I}: No lanza pánicos a través del límite FFI C ABI (`catch_unwind`).
#[no_mangle]
pub extern "C" fn acordeon_detect_beat_chords_ffi(
    channel_data_ptr: *const f32,
    length: usize,
    sample_rate: f32,
    bpm: f32,
    start_offset: f32,
) -> *mut c_char {
    let fallback_err = |msg: &str| {
        let err_json = format!("{{\"error\":\"{}\"}}", msg);
        CString::new(err_json).unwrap().into_raw()
    };

    if channel_data_ptr.is_null() || length < 4096 || (channel_data_ptr as usize % std::mem::align_of::<f32>() != 0) {
        return fallback_err("Puntero nulo, desalineado o datos insuficientes (<4096 muestras)");
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let slice = unsafe { std::slice::from_raw_parts(channel_data_ptr, length) };
        match audio_analysis::analyze_beat_chords(slice, sample_rate, bpm, start_offset) {
            Ok(json_str) => CString::new(json_str).unwrap().into_raw(),
            Err(err) => fallback_err(&err),
        }
    }));

    result.unwrap_or_else(|_| fallback_err("Excepción interna capturada durante la detección de acordes por compás"))
}

/// Libera la memoria de una cadena asignada por Rust para C ABI.
///
/// # Tripla de Hoare:
/// - {P}: `ptr` es nulo o apunta a un CString previamente retornado por una función FFI de esta biblioteca.
/// - {Q}: La memoria heap de Rust correspondiente se libera sin fugas ni doble liberación.
#[no_mangle]
pub extern "C" fn acordeon_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        drop(CString::from_raw(ptr));
    }));
}

/// Reserva un buffer de floats gestionado por RUST (allocator del sistema,
/// sin el bug del heap-allocator de Dart SDK 3.12 que crashea con
/// allocations > 16 KB — ver sonda 4096 OK / 4097 crash).
///
/// # Tripla de Hoare:
/// - {P}: `len > 0`.
/// - {Q}: retorna puntero válido alineado para `f32` con capacidad `len`, o
///        null si `len == 0`. La memoria debe liberarse con
///        [`acordeon_free_buffer`] — NUNCA con `free` de Dart.
#[no_mangle]
pub extern "C" fn acordeon_alloc_buffer(len: usize) -> *mut f32 {
    if len == 0 {
        return std::ptr::null_mut();
    }
    let layout = match std::alloc::Layout::array::<f32>(len) {
        Ok(l) => l,
        Err(_) => return std::ptr::null_mut(),
    };
    unsafe { std::alloc::alloc(layout) as *mut f32 }
}

/// Libera un buffer reservado por [`acordeon_alloc_buffer`].
///
/// # Tripla de Hoare:
/// - {P}: `ptr` es nulo o fue retornado por `acordeon_alloc_buffer` con el
///        mismo `len` usado en la reserva.
/// - {Q}: memoria liberada sin fugas ni doble liberación; llamada con null
///        es no-op segura.
#[no_mangle]
pub extern "C" fn acordeon_free_buffer(ptr: *mut f32, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    let layout = match std::alloc::Layout::array::<f32>(len) {
        Ok(l) => l,
        Err(_) => return,
    };
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        std::alloc::dealloc(ptr as *mut u8, layout);
    }));
}
