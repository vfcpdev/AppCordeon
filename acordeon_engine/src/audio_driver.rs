use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, StreamConfig};
use std::sync::{Arc, Mutex};
use std::thread;
use crate::synth::AccordionSynth;

/// Controlador de audio nativo en tiempo real con cpal (WASAPI en Windows).
/// El stream se aísla en un hilo dedicado para garantizar thread-safety.
pub struct AudioDriver {
    synth: Arc<Mutex<AccordionSynth>>,
}

impl AudioDriver {
    pub fn new(requested_sample_rate: f32) -> Self {
        let synth = Arc::new(Mutex::new(AccordionSynth::new(requested_sample_rate)));
        let synth_clone = Arc::clone(&synth);

        // Hilo dedicado de audio WASAPI
        thread::Builder::new()
            .name("acordeon_audio_thread".to_string())
            .spawn(move || {
                let host = cpal::default_host();
                let device = match host.default_output_device() {
                    Some(d) => d,
                    None => {
                        eprintln!("[acordeon_engine] No se detectó dispositivo de salida de audio");
                        return;
                    }
                };

                let default_config = match device.default_output_config() {
                    Ok(c) => c,
                    Err(e) => {
                        eprintln!("[acordeon_engine] Error al obtener config de audio: {}", e);
                        return;
                    }
                };

                let actual_sample_rate = default_config.sample_rate().0 as f32;
                let actual_channels = default_config.channels() as usize;

                if let Ok(mut s) = synth_clone.lock() {
                    s.sample_rate = actual_sample_rate;
                }

                let config: StreamConfig = default_config.clone().into();
                let synth_audio = Arc::clone(&synth_clone);
                let channels = actual_channels;

                let err_fn = |err| eprintln!("[acordeon_engine] Error en stream de audio cpal: {}", err);

                let stream = match default_config.sample_format() {
                    SampleFormat::F32 => device.build_output_stream(
                        &config,
                        move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                            if let Ok(mut s) = synth_audio.lock() {
                                s.process_interleaved(data, channels);
                            }
                        },
                        err_fn,
                        None,
                    ),
                    SampleFormat::I16 => device.build_output_stream(
                        &config,
                        move |data: &mut [i16], _: &cpal::OutputCallbackInfo| {
                            let mut temp_f32 = vec![0.0f32; data.len()];
                            if let Ok(mut s) = synth_audio.lock() {
                                s.process_interleaved(&mut temp_f32, channels);
                                for (out_sample, in_sample) in data.iter_mut().zip(temp_f32.iter()) {
                                    *out_sample = (in_sample.clamp(-1.0, 1.0) * 32767.0) as i16;
                                }
                            }
                        },
                        err_fn,
                        None,
                    ),
                    SampleFormat::U16 => device.build_output_stream(
                        &config,
                        move |data: &mut [u16], _: &cpal::OutputCallbackInfo| {
                            let mut temp_f32 = vec![0.0f32; data.len()];
                            if let Ok(mut s) = synth_audio.lock() {
                                s.process_interleaved(&mut temp_f32, channels);
                                for (out_sample, in_sample) in data.iter_mut().zip(temp_f32.iter()) {
                                    let sample_norm = in_sample.clamp(-1.0, 1.0) * 0.5 + 0.5;
                                    *out_sample = (sample_norm * 65535.0) as u16;
                                }
                            }
                        },
                        err_fn,
                        None,
                    ),
                    _ => Err(cpal::BuildStreamError::DeviceNotAvailable),
                };

                match stream {
                    Ok(st) => {
                        if let Err(e) = st.play() {
                            eprintln!("[acordeon_engine] Error al iniciar reproducción cpal: {}", e);
                            return;
                        }
                        eprintln!(
                            "[acordeon_engine] Stream WASAPI/cpal activo a {} Hz ({} canales)",
                            actual_sample_rate, actual_channels
                        );
                        // Mantener vivo el stream dentro de este hilo
                        loop {
                            thread::park();
                        }
                    }
                    Err(e) => {
                        eprintln!("[acordeon_engine] Fallo al crear stream cpal: {}", e);
                    }
                }
            })
            .expect("No se pudo iniciar hilo de audio nativo");

        Self { synth }
    }

    pub fn synth(&self) -> Arc<Mutex<AccordionSynth>> {
        Arc::clone(&self.synth)
    }
}
