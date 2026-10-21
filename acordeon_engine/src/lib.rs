pub mod chord_detector;
pub mod synth;
pub mod voice;

use std::ffi::CString;
use std::os::raw::c_char;
use synth::AccordionSynth;

static mut GLOBAL_SYNTH: Option<AccordionSynth> = None;

#[no_mangle]
pub extern "C" fn acordeon_engine_init(sample_rate: f32) {
    unsafe {
        GLOBAL_SYNTH = Some(AccordionSynth::new(sample_rate));
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_note_on(midi_note: u8) {
    unsafe {
        if let Some(ref mut synth) = GLOBAL_SYNTH {
            synth.note_on(midi_note);
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_note_off(midi_note: u8) {
    unsafe {
        if let Some(ref mut synth) = GLOBAL_SYNTH {
            synth.note_off(midi_note);
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_all_notes_off() {
    unsafe {
        if let Some(ref mut synth) = GLOBAL_SYNTH {
            synth.all_notes_off();
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_set_volume(vol: f32) {
    unsafe {
        if let Some(ref mut synth) = GLOBAL_SYNTH {
            synth.set_volume(vol);
        }
    }
}

#[no_mangle]
pub extern "C" fn acordeon_engine_process(buffer: *mut f32, length: usize) {
    unsafe {
        if let Some(ref mut synth) = GLOBAL_SYNTH {
            let slice = std::slice::from_raw_parts_mut(buffer, length);
            synth.process_buffer(slice);
        }
    }
}

/// Detecta el acorde a partir de una lista de notas MIDI y devuelve una cadena JSON o formateada
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

#[no_mangle]
pub extern "C" fn acordeon_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
