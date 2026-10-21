//! Modelado acústico de lengüetas de acordeón diatónico (Reed Model).
use std::f32::consts::PI;

pub struct AccordionVoice {
    pub midi_note: u8,
    pub frequency: f32,
    pub is_active: bool,
    phase_reed_a: f32, // Lengüeta principal (Directa)
    phase_reed_b: f32, // Lengüeta vibrato/musette (ligero batimento)
    sample_rate: f32,
    envelope: f32,
    target_envelope: f32,
    release_speed: f32,
    attack_speed: f32,
}

impl AccordionVoice {
    pub fn new(sample_rate: f32) -> Self {
        Self {
            midi_note: 0,
            frequency: 440.0,
            is_active: false,
            phase_reed_a: 0.0,
            phase_reed_b: 0.0,
            sample_rate,
            envelope: 0.0,
            target_envelope: 0.0,
            attack_speed: 1.0 / (0.015 * sample_rate),  // 15ms ataque rápido típico de lengüeta
            release_speed: 1.0 / (0.035 * sample_rate), // 35ms apagado natural
        }
    }

    pub fn note_on(&mut self, midi_note: u8) {
        self.midi_note = midi_note;
        self.frequency = 440.0 * 2.0_f32.powf((midi_note as f32 - 69.0) / 12.0);
        self.is_active = true;
        self.target_envelope = 1.0;
    }

    pub fn note_off(&mut self) {
        self.target_envelope = 0.0;
    }

    /// Renderiza una muestra sumando armónicos pares e impares de lengüeta libre con batimento musette
    pub fn next_sample(&mut self) -> f32 {
        if !self.is_active {
            return 0.0;
        }

        // Envelope follow
        if self.envelope < self.target_envelope {
            self.envelope = (self.envelope + self.attack_speed).min(self.target_envelope);
        } else if self.envelope > self.target_envelope {
            self.envelope = (self.envelope - self.release_speed).max(0.0);
            if self.envelope <= 0.0001 {
                self.is_active = false;
                return 0.0;
            }
        }

        let detune_hz = 1.25; // Ligero desfase batimento vallenato/norteño (Musette leve)
        let delta_a = 2.0 * PI * self.frequency / self.sample_rate;
        let delta_b = 2.0 * PI * (self.frequency + detune_hz) / self.sample_rate;

        // Síntesis armónica de lengüeta de fuelle (armónicos 1, 2, 3, 4, 5)
        let s_a = (self.phase_reed_a.sin() * 0.55)
            + ((self.phase_reed_a * 2.0).sin() * 0.25)
            + ((self.phase_reed_a * 3.0).sin() * 0.12)
            + ((self.phase_reed_a * 4.0).sin() * 0.05);

        let s_b = (self.phase_reed_b.sin() * 0.55)
            + ((self.phase_reed_b * 2.0).sin() * 0.25)
            + ((self.phase_reed_b * 3.0).sin() * 0.12);

        self.phase_reed_a = (self.phase_reed_a + delta_a) % (2.0 * PI);
        self.phase_reed_b = (self.phase_reed_b + delta_b) % (2.0 * PI);

        (s_a * 0.6 + s_b * 0.4) * self.envelope
    }
}
