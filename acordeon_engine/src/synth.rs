use crate::voice::AccordionVoice;

pub const MAX_POLYPHONY: usize = 32;

pub struct AccordionSynth {
    pub sample_rate: f32,
    pub master_volume: f32,
    voices: Vec<AccordionVoice>,
}

impl AccordionSynth {
    pub fn new(sample_rate: f32) -> Self {
        let mut voices = Vec::with_capacity(MAX_POLYPHONY);
        for _ in 0..MAX_POLYPHONY {
            voices.push(AccordionVoice::new(sample_rate));
        }
        Self {
            sample_rate,
            master_volume: 0.85,
            voices,
        }
    }

    pub fn note_on(&mut self, midi_note: u8) {
        // Si ya está sonando, refrescar
        for v in &mut self.voices {
            if v.is_active && v.midi_note == midi_note {
                v.note_on(midi_note);
                return;
            }
        }
        // Asignar a una voz libre
        for v in &mut self.voices {
            if !v.is_active {
                v.note_on(midi_note);
                return;
            }
        }
        // Voice stealing
        if let Some(v) = self.voices.first_mut() {
            v.note_on(midi_note);
        }
    }

    pub fn note_off(&mut self, midi_note: u8) {
        for v in &mut self.voices {
            if v.is_active && v.midi_note == midi_note {
                v.note_off();
            }
        }
    }

    pub fn all_notes_off(&mut self) {
        for v in &mut self.voices {
            v.note_off();
        }
    }

    pub fn set_volume(&mut self, vol: f32) {
        self.master_volume = vol.clamp(0.0, 1.0);
    }

    /// Rellena el buffer estéreo o mono PCM intercalado
    pub fn process_interleaved(&mut self, out_buffer: &mut [f32], channels: usize) {
        if channels == 0 || out_buffer.is_empty() {
            return;
        }

        let num_frames = out_buffer.len() / channels;
        for frame in 0..num_frames {
            let mut sum = 0.0;
            for v in &mut self.voices {
                if v.is_active {
                    sum += v.next_sample();
                }
            }
            // Soft clipping suave para emular la saturación de caja armónica de madera
            let out = (sum * self.master_volume * 0.45).tanh();

            for ch in 0..channels {
                out_buffer[frame * channels + ch] = out;
            }
        }
    }

    /// Rellena el buffer mono PCM directo
    pub fn process_buffer(&mut self, out_buffer: &mut [f32]) {
        self.process_interleaved(out_buffer, 1);
    }
}
