pub mod bpm;
pub mod chords;
pub mod chroma;
pub mod fft;
pub mod key;
pub mod types;

use bpm::detect_bpm;
use chords::segment_chords;
use chroma::ChromaFilterbank;
use fft::{fft_radix2, generate_hann_window};
use key::detect_global_key;
use types::AudioAnalysisReport;

/// Analiza un flujo de audio PCM mono Float32 y devuelve el reporte armónico en JSON.
pub fn analyze_audio(channel_data: &[f32], sample_rate: f32) -> Result<String, String> {
    let window_size = 4096usize;
    let hop_size = 2048usize;

    if channel_data.len() < window_size {
        return Err("El audio es demasiado corto para análisis espectral (mínimo 4096 muestras).".to_string());
    }

    let total_frames = (channel_data.len() - window_size) / hop_size;
    if total_frames == 0 {
        return Err("El audio no contiene suficientes frames para análisis.".to_string());
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

    // 3. Segmentación y reconocimiento de acordes
    let chords = segment_chords(
        &raw_chromagram,
        &raw_bass_chromagram,
        &raw_harm_chromagram,
        hop_size,
        sample_rate,
        &main_key,
    );

    let report = AudioAnalysisReport {
        duration: (duration * 10.0).round() / 10.0,
        bpm,
        mainKey: main_key,
        chords,
        chromagram: raw_chromagram,
    };

    serde_json::to_string(&report).map_err(|e| format!("Error serializando reporte: {}", e))
}
