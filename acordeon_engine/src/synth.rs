use crate::voice::AccordionVoice;

pub const MAX_POLYPHONY: usize = 32;

/// Segregación de Interfaz para recepción de eventos MIDI (ISP).
pub trait MidiReceiver {
    fn note_on(&mut self, midi_note: u8);
    fn note_off(&mut self, midi_note: u8);
    fn all_notes_off(&mut self);
}

/// Segregación de Interfaz para renderizado de señal de audio DSP (ISP & DIP).
pub trait DspRenderer {
    fn process_interleaved(&mut self, out_buffer: &mut [f32], channels: usize);
    fn process_buffer(&mut self, out_buffer: &mut [f32]) {
        self.process_interleaved(out_buffer, 1);
    }
}

pub struct AccordionSynth {
    pub sample_rate: f32,
    pub master_volume: f32,
    voices: Vec<AccordionVoice>,
}

impl AccordionSynth {
    pub fn new(sample_rate: f32) -> Self {
        let safe_sr = if sample_rate <= 0.0 { 44100.0 } else { sample_rate };
        let mut voices = Vec::with_capacity(MAX_POLYPHONY);
        for _ in 0..MAX_POLYPHONY {
            voices.push(AccordionVoice::new(safe_sr));
        }
        Self {
            sample_rate: safe_sr,
            master_volume: 0.85,
            voices,
        }
    }

    pub fn set_sample_rate(&mut self, sample_rate: f32) {
        let safe_sr = if sample_rate <= 0.0 { 44100.0 } else { sample_rate };
        self.sample_rate = safe_sr;
        for v in &mut self.voices {
            v.set_sample_rate(safe_sr);
        }
    }

    pub fn set_volume(&mut self, vol: f32) {
        self.master_volume = vol.clamp(0.0, 1.0);
    }
}

impl MidiReceiver for AccordionSynth {
    /// Activa una nota MIDI implementando asignación de voz y robo inteligente (Voice Stealing).
    ///
    /// # Tripla de Hoare:
    /// - {P}: `midi_note <= 127`.
    /// - {Q}: Al menos una voz en `self.voices` está activa con `midi_note`.
    fn note_on(&mut self, midi_note: u8) {
        // 1. Si ya está sonando, refrescarla
        for v in &mut self.voices {
            if v.is_active && v.midi_note == midi_note {
                v.note_on(midi_note);
                return;
            }
        }

        // 2. Asignar a la primera voz inactiva disponible
        for v in &mut self.voices {
            if !v.is_active {
                v.note_on(midi_note);
                return;
            }
        }

        // 3. Robo inteligente de voz (Least Audible Stealing):
        // Robar la voz que tenga el nivel de envolvente más bajo en lugar de siempre la primera.
        if let Some(quietest) = self
            .voices
            .iter_mut()
            .min_by(|a, b| a.envelope.partial_cmp(&b.envelope).unwrap_or(std::cmp::Ordering::Equal))
        {
            quietest.note_on(midi_note);
        }
    }

    fn note_off(&mut self, midi_note: u8) {
        for v in &mut self.voices {
            if v.is_active && v.midi_note == midi_note {
                v.note_off();
            }
        }
    }

    fn all_notes_off(&mut self) {
        for v in &mut self.voices {
            v.note_off();
        }
    }
}

impl DspRenderer for AccordionSynth {
    /// Rellena el buffer estéreo o multicanal PCM intercalado.
    ///
    /// # Tripla de Hoare:
    /// - {P}: `out_buffer` es mutable y `channels > 0`.
    /// - {Q}: Todos los valores en `out_buffer` están estrictamente acotados `[-1.0, 1.0]`
    ///        sin desbordamiento ni `NaN`.
    /// - {I}: Cero asignaciones de memoria dinámica (`no-alloc`) en tiempo real.
    fn process_interleaved(&mut self, out_buffer: &mut [f32], channels: usize) {
        if channels == 0 || out_buffer.is_empty() {
            return;
        }

        let num_frames = out_buffer.len() / channels;
        for frame in 0..num_frames {
            let mut sum = 0.0f32;
            for v in &mut self.voices {
                if v.is_active {
                    sum += v.next_sample();
                }
            }

            // Saturación armónica suave (soft-clipping) simulando la resonancia de la caja acústica:
            // Invariante matemático: tanh(x) \in (-1.0, 1.0) para todo x real.
            let out = (sum * self.master_volume * 0.45).tanh();

            for ch in 0..channels {
                out_buffer[frame * channels + ch] = out;
            }
        }
    }
}
