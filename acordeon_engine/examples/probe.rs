// Sonda de heap: analiza muchas veces dentro del proceso Rust para descartar
// corrupción interna de la DLL (el crash sólo ocurre desde Dart/FFI).
use acordeon_engine::audio_analysis::analyze_audio;

fn main() {
    let n = 8192usize;
    for iter in 0..50 {
        let mut samples = vec![0.0f32; n];
        for i in 0..n {
            samples[i] = (i % 441) as f32 / 441.0;
        }
        match analyze_audio(&samples, 44100.0) {
            Ok(json) => println!("iter {} OK ({} chars)", iter, json.len()),
            Err(e) => println!("iter {} ERR {}", iter, e),
        }
    }
    println!("50 iteraciones dentro de Rust: sin corrupción");
}
