pub mod audio_analysis;
pub mod audio_driver;
pub mod chord_detector;
pub mod synth;
pub mod voice;

use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};
use audio_driver::AudioDriver;

static DRIVER: OnceLock<Mutex<AudioDriver>> = OnceLock::new();

#[no_mangle]
pub extern "C" fn acordeon_engine_init(sample_rate: f32) {
    let rate = if sample_rate <= 0.0 { 44100.0 } else { sample_rate };
    DRIVER.get_or_init(|| Mutex::new(AudioDriver::new(rate)));
}

#[no_mangle]
pub extern "C" fn acordeon_engine_note_on(midi_note: u8) {
    if let Some(driver_lock) = DRIVER.get() {
        if let Ok(driver) = driver_lock.lock() {
            if let Ok(mut synth) = driver.synth().lock() {
                synth.note_on(midi_note);
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_note_off(midi_note: u8) {
    if let Some(driver_lock) = DRIVER.get() {
        if let Ok(driver) = driver_lock.lock() {
            if let Ok(mut synth) = driver.synth().lock() {
                synth.note_off(midi_note);
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_all_notes_off() {
    if let Some(driver_lock) = DRIVER.get() {
        if let Ok(driver) = driver_lock.lock() {
            if let Ok(mut synth) = driver.synth().lock() {
                synth.all_notes_off();
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_set_volume(vol: f32) {
    if let Some(driver_lock) = DRIVER.get() {
        if let Ok(driver) = driver_lock.lock() {
            if let Ok(mut synth) = driver.synth().lock() {
                synth.set_volume(vol);
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_process(buffer: *mut f32, length: usize) {
    if buffer.is_null() || length == 0 {
        return;
    }
    if let Some(driver_lock) = DRIVER.get() {
        if let Ok(driver) = driver_lock.lock() {
            if let Ok(mut synth) = driver.synth().lock() {
                let slice = unsafe { std::slice::from_raw_parts_mut(buffer, length) };
                synth.process_buffer(slice);
            }
        }
    }
}

/// Detecta el acorde a partir de una lista de notas MIDI y devuelve una cadena JSON
#[no_mangle]
pub extern "C" fn acordeon_detect_chord_ffi(notes_ptr: *const u8, count: usize) -> *mut c_char {
    if notes_ptr.is_null() || count == 0 {
        return CString::new("").unwrap().into_raw();
    }
    let notes = unsafe { std::slice::from_raw_parts(notes_ptr, count) };
    if let Some(detected) = chord_detector::detect_chord_from_notes(notes) {
        let res = format!(
            "{{\"name\":\"{}\",\"root\":\"{}\",\"bass\":\"{}\",\"formula\":\"{}\",\"type\":\"{}\",\"inversion\":\"{}\"}}",
            detected.name, detected.root, detected.bass, detected.formula, detected.chord_type, detected.inversion
        );
        CString::new(res).unwrap().into_raw()
    } else {
        CString::new("{}").unwrap().into_raw()
    }
}

/// Analiza un archivo o buffer de audio Float32 y devuelve el reporte completo en JSON
#[no_mangle]
pub extern "C" fn acordeon_analyze_audio_ffi(
    channel_data_ptr: *const f32,
    length: usize,
    sample_rate: f32,
) -> *mut c_char {
    if channel_data_ptr.is_null() || length < 4096 {
        return CString::new("{}").unwrap().into_raw();
    }
    let slice = unsafe { std::slice::from_raw_parts(channel_data_ptr, length) };
    match audio_analysis::analyze_audio(slice, sample_rate) {
        Ok(json_str) => CString::new(json_str).unwrap().into_raw(),
        Err(err) => {
            let err_json = format!("{{\"error\":\"{}\"}}", err);
            CString::new(err_json).unwrap().into_raw()
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
