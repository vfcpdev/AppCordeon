// Diagnóstico binario: reproduce analyze_audio con zeros a 4096 vía DLL C-ABI
// dentro de Rust (para descartar ABI vs código).
use acordeon_engine::{acordeon_analyze_audio_ffi, acordeon_free_string};
use std::ffi::CStr;

fn main() {
    let n = 4096usize;
    let samples = vec![0.0f32; n];
    println!("LLAMANDO via C-ABI desde Rust (mismo runtime)...");
    let ptr = samples.as_ptr();
    unsafe {
        let result = acordeon_analyze_audio_ffi(ptr as *const f32, n, 44100.0);
        let cstr = CStr::from_ptr(result);
        println!("respuesta: {}", cstr.to_str().unwrap_or("<invalid>"));
        acordeon_free_string(result);
    }
    println!("sin crash");
}
