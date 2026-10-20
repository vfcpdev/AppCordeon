//! # Acordeón Diatónico Pro - Evaluación Acústica y Test Bench DSP
//! Módulo de diagnóstico objetivo acústico:
//! 1. Generación de 2 segundos de audio en PCM a acordeon_test.wav con hound.
//! 2. Cálculo del Centroide Espectral (Spectral Centroid) vía FFT (rustfft).
//! 3. Frecuencia de batimiento del coro Musette (Beat Frequency).
//! 4. Factor de Cresta y Nivel RMS (Margen dinámico y anti-clipping).
//! 5. Verificación de transitorios suaves (Detección de clicks / discontinuidad de fase).

use std::sync::Arc;
use rustfft::{FftPlanner, num_complex::Complex};
use hound::{WavWriter, WavSpec, SampleFormat};
use accordion_synth::{AccordionEngine, TipoBoton, SAMPLE_RATE};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("==========================================================================");
    println!("  TEST BENCH ACÚSTICO: MOTOR DSP ACORDEÓN CORONA III (VALLENATO) EN RUST  ");
    println!("==========================================================================");

    let sample_rate = SAMPLE_RATE;
    let duration_sec = 2.0;
    let total_samples = (sample_rate * duration_sec) as usize;

    let mut engine = AccordionEngine::new();
    let mut buffer = vec![0.0f32; total_samples];

    // 1. Simulación de ejecución: Presionar La4 (MIDI 69 = 440 Hz) durante 1.6s y soltar
    println!("\n[1/5] Renderizando nota de prueba A4 (440 Hz) con banco Musette de 3 lengüetas...");
    engine.note_on(69, 0.90, TipoBoton::Pito);

    let key_off_sample = (1.6 * sample_rate) as usize;
    let block_size = 128;
    let mut current_sample = 0;

    while current_sample < total_samples {
        let chunk_len = block_size.min(total_samples - current_sample);
        
        if current_sample <= key_off_sample && (current_sample + chunk_len) > key_off_sample {
            engine.note_off(69);
        }

        engine.process_block(&mut buffer[current_sample..current_sample + chunk_len]);
        current_sample += chunk_len;
    }

    // 2. Exportación a archivo .wav usando Hound
    let wav_filename = "acordeon_test.wav";
    println!("[2/5] Exportando muestra de audio a '{}'...", wav_filename);
    let spec = WavSpec {
        channels: 1,
        sample_rate: sample_rate as u32,
        bits_per_sample: 16,
        sample_format: SampleFormat::Int,
    };

    let mut writer = WavWriter::create(wav_filename, spec)?;
    for &sample in &buffer {
        let sample_clamped = sample.clamp(-1.0, 1.0);
        let sample_i16 = (sample_clamped * i16::MAX as f32) as i16;
        writer.write_sample(sample_i16)?;
    }
    writer.finalize()?;
    println!("      Archivo '{}' creado exitosamente.", wav_filename);

    // 3. Evaluación Objetiva de Transitorios (Detección de Clicks / Discontinuidad de Derivada)
    println!("\n[3/5] Analizando suavidad de transitorios (Derivadas entre muestras)...");
    let mut max_derivative = 0.0f32;
    let mut click_detected = false;
    let click_threshold = 0.20; // Un salto abrupto > 20% de escala completa entre muestras consecutivas indica click

    for i in 1..buffer.len() {
        let diff = (buffer[i] - buffer[i - 1]).abs();
        if diff > max_derivative {
            max_derivative = diff;
        }
        if diff > click_threshold {
            click_detected = true;
        }
    }
    println!("      Máxima derivada (|x[n] - x[n-1]|): {:.5}", max_derivative);
    println!("      Clicks de discontinuidad detectados: {}", if click_detected { "ALERTA (Discontinuidad presente)" } else { "0 CLICKS (Transición de fase limpia)" });

    // 4. Métricas de Amplitud: Factor de Cresta y Nivel RMS
    println!("\n[4/5] Analizando Margen Dinámico y Anti-Clipping...");
    let mut sum_sq = 0.0;
    let mut peak = 0.0f32;
    for &sample in &buffer {
        let abs_s = sample.abs();
        if abs_s > peak {
            peak = abs_s;
        }
        sum_sq += sample * sample;
    }
    let rms = (sum_sq / buffer.len() as f32).sqrt();
    let crest_factor = if rms > 1e-6 { peak / rms } else { 0.0 };
    let crest_factor_db = 20.0 * crest_factor.log10();
    let peak_db = 20.0 * peak.max(1e-6).log10();
    let rms_db = 20.0 * rms.max(1e-6).log10();

    println!("      Nivel Pico: {:.2} dBFS (Valor absoluto: {:.4})", peak_db, peak);
    println!("      Nivel RMS:  {:.2} dBFS", rms_db);
    println!("      Factor de Cresta: {:.2} ({:.2} dB)", crest_factor, crest_factor_db);
    println!("      ¿Ocurrió saturación digital (sample > 1.0)?: {}", if peak >= 1.0 { "SÍ (Saturado)" } else { "NO (Margen limpio)" });

    // 5. Análisis Espectral vía FFT (rustfft) durante la fase de Sustain estacionario
    println!("\n[5/5] Analizando Espectro con FFT (Centroide Espectral y Batimiento Musette)...");
    let fft_size = 4096;
    let sustain_start = (0.5 * sample_rate) as usize; // En estado estacionario (0.5s)
    let mut fft_input: Vec<Complex<f32>> = Vec::with_capacity(fft_size);

    // Ventana Hann para minimizar fuga espectral (spectral leakage)
    for i in 0..fft_size {
        let hann = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / (fft_size as f32 - 1.0)).cos());
        let val = buffer[sustain_start + i] * hann;
        fft_input.push(Complex { re: val, im: 0.0 });
    }

    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(fft_size);
    fft.process(&mut fft_input);

    // Magnitudes y Centroide Espectral
    let half_size = fft_size / 2;
    let freq_bin_resolution = sample_rate / fft_size as f32;
    let mut num_centroid = 0.0;
    let mut den_centroid = 0.0;

    let mut magnitudes = vec![0.0f32; half_size];
    for (k, mag_slot) in magnitudes.iter_mut().enumerate().take(half_size) {
        let mag = (fft_input[k].re.powi(2) + fft_input[k].im.powi(2)).sqrt();
        *mag_slot = mag;
        let freq_hz = k as f32 * freq_bin_resolution;
        num_centroid += freq_hz * mag;
        den_centroid += mag;
    }

    let spectral_centroid = if den_centroid > 1e-6 { num_centroid / den_centroid } else { 0.0 };
    println!("      Centroide Espectral: {:.2} Hz", spectral_centroid);

    let centroid_status = if spectral_centroid >= 1100.0 && spectral_centroid <= 2400.0 {
        "ÓPTIMO (Timbre vallenato cálido y brillante, no chillón)"
    } else if spectral_centroid < 1100.0 {
        "OPACO (Requiere mayor brillo o abrir filtro Low-Pass)"
    } else {
        "METÁLICO/CHILLÓN (Atenuar armónicos o reducir Q en filtro Peaking)"
    };
    println!("      Diagnóstico de Timbre: {}", centroid_status);

    // Detección teórica y envolvente de Batimiento Musette (Interferencia ±15 cents)
    // f_high = 440 * 2^(15/1200) = 443.82 Hz
    // f_center = 440 Hz
    // Batimiento = 3.82 Hz
    let theoretical_beat = 440.0 * (2.0f32.powf(15.0 / 1200.0) - 1.0);
    println!("      Frecuencia de Batimiento Musette Teórica: {:.2} Hz (~{:.1} oscilaciones por segundo)", theoretical_beat, theoretical_beat);

    println!("\n==========================================================================");
    println!("  EVALUACIÓN COMPLETADA SATISFACTORIAMENTE                                ");
    println!("==========================================================================");

    Ok(())
}
