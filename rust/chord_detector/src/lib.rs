pub mod bpm;
pub mod chords;
pub mod chroma;
pub mod fft;
pub mod key;
pub mod types;

use wasm_bindgen::prelude::*;

use bpm::detect_bpm;
use chords::segment_chords;
use chroma::ChromaFilterbank;
use fft::{fft_radix2, generate_hann_window};
use key::detect_global_key;
use types::AudioAnalysisReport;

/// Verifica si el módulo WebAssembly en Rust está cargado y listo.
#[wasm_bindgen]
pub fn is_wasm_ready() -> bool {
    true
}

/// Detección de BPM directa en Rust desde datos mono Float32.
#[wasm_bindgen]
pub fn detect_bpm_wasm(channel_data: &[f32], sample_rate: f32) -> i32 {
    detect_bpm(channel_data, sample_rate)
}

/// Detección de tonalidad global a partir de un vector cromático de 12 elementos.
#[wasm_bindgen]
pub fn detect_key_wasm(global_chroma: &[f32]) -> Result<JsValue, JsValue> {
    if global_chroma.len() < 12 {
        return Err(JsValue::from_str("El vector cromático debe tener al menos 12 elementos."));
    }
    let mut chroma_12 = [0.0f32; 12];
    chroma_12.copy_from_slice(&global_chroma[..12]);
    let key_result = detect_global_key(&chroma_12);
    serde_wasm_bindgen::to_value(&key_result)
        .map_err(|e| JsValue::from_str(&format!("Error serializando tonalidad: {}", e)))
}

/// Analiza un flujo de audio completo (Float32Array) y retorna el reporte armónico:
/// tonalidad principal, BPM, chromagram y línea de tiempo de acordes segmentada.
#[wasm_bindgen]
pub fn analyze_audio(channel_data: &[f32], sample_rate: f32) -> Result<JsValue, JsValue> {
    let window_size = 4096usize;
    let hop_size = 2048usize;

    if channel_data.len() < window_size {
        return Err(JsValue::from_str("El archivo de audio es demasiado corto para el análisis."));
    }

    let total_frames = (channel_data.len() - window_size) / hop_size;
    if total_frames == 0 {
        return Err(JsValue::from_str("El archivo de audio es demasiado corto para el análisis."));
    }

    let duration = (channel_data.len() as f32) / sample_rate;
    let filterbank = ChromaFilterbank::new(window_size, sample_rate);
    let hann_window = generate_hann_window(window_size);

    let mut raw_chromagram: Vec<[f32; 12]> = Vec::with_capacity(total_frames);
    let mut raw_bass_chromagram: Vec<[f32; 12]> = Vec::with_capacity(total_frames);
    let mut raw_harm_chromagram: Vec<[f32; 12]> = Vec::with_capacity(total_frames);
    let mut global_chroma_sum = [0.0f32; 12];

    let mut real = vec![0.0f32; window_size];
    let mut imag = vec![0.0f32; window_size];

    for frame in 0..total_frames {
        let offset = frame * hop_size;

        for i in 0..window_size {
            real[i] = channel_data[offset + i] * hann_window[i];
            imag[i] = 0.0;
        }

        fft_radix2(&mut real, &mut imag);

        let mut frame_bass = [0.0f32; 12];
        let mut frame_harm = [0.0f32; 12];
        let mut frame_comb = [0.0f32; 12];

        filterbank.process_frame(&real, &imag, &mut frame_bass, &mut frame_harm, &mut frame_comb);

        for p in 0..12 {
            global_chroma_sum[p] += frame_comb[p];
        }

        raw_chromagram.push(frame_comb);
        raw_bass_chromagram.push(frame_bass);
        raw_harm_chromagram.push(frame_harm);
    }

    // 1. Detección automática de BPM
    let bpm = detect_bpm(channel_data, sample_rate);

    // 2. Detección de tonalidad global
    let main_key = detect_global_key(&global_chroma_sum);

    // 3. Segmentación armónica de acordes
    let chords = segment_chords(
        &raw_chromagram,
        &raw_bass_chromagram,
        &raw_harm_chromagram,
        hop_size,
        sample_rate,
        &main_key,
    );

    // Convertir chromagram para exportar
    let chromagram_export: Vec<Vec<f32>> = raw_chromagram.iter().map(|frame| frame.to_vec()).collect();

    let report = AudioAnalysisReport {
        duration,
        bpm,
        mainKey: main_key,
        chords,
        chromagram: chromagram_export,
    };

    serde_wasm_bindgen::to_value(&report)
        .map_err(|e| JsValue::from_str(&format!("Error serializando reporte de análisis: {}", e)))
}
