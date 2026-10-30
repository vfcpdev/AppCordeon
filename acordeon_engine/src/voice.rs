//! Modelado acústico de lengüetas de acordeón diatónico (Reed Model) de alto rendimiento.
use std::f32::consts::PI;
use std::sync::OnceLock;

pub const WAVETABLE_SIZE: usize = 2048;

static REED_A_TABLE: OnceLock<[f32; WAVETABLE_SIZE]> = OnceLock::new();
static REED_B_TABLE: OnceLock<[f32; WAVETABLE_SIZE]> = OnceLock::new();

fn get_reed_a_table() -> &'static [f32; WAVETABLE_SIZE] {
    REED_A_TABLE.get_or_init(|| {
        let mut table = [0.0; WAVETABLE_SIZE];
        for i in 0..WAVETABLE_SIZE {
            let phase = 2.0 * PI * (i as f32) / (WAVETABLE_SIZE as f32);
            // Armónicos 1, 2, 3, 4 característicos de la lengüeta metálica de acordeón
            table[i] = (phase.sin() * 0.55)
                + ((phase * 2.0).sin() * 0.25)
                + ((phase * 3.0).sin() * 0.12)
                + ((phase * 4.0).sin() * 0.05);
        }
        table
    })
}

fn get_reed_b_table() -> &'static [f32; WAVETABLE_SIZE] {
    REED_B_TABLE.get_or_init(|| {
        let mut table = [0.0; WAVETABLE_SIZE];
        for i in 0..WAVETABLE_SIZE {
            let phase = 2.0 * PI * (i as f32) / (WAVETABLE_SIZE as f32);
            // Armónicos 1, 2, 3 para la segunda lengüeta con batimento musette
            table[i] = (phase.sin() * 0.55)
                + ((phase * 2.0).sin() * 0.25)
                + ((phase * 3.0).sin() * 0.12);
        }
        table
    })
}

#[inline(always)]
fn lookup_wavetable(table: &[f32; WAVETABLE_SIZE], phase_norm: f32) -> f32 {
    let index_f = phase_norm * (WAVETABLE_SIZE as f32);
    let i0 = (index_f as usize) % WAVETABLE_SIZE;
    let i1 = (i0 + 1) % WAVETABLE_SIZE;
    let frac = index_f - (index_f as usize as f32);
    table[i0] + frac * (table[i1] - table[i0])
}

pub struct AccordionVoice {
    pub midi_note: u8,
    pub frequency: f32,
    pub is_active: bool,
    phase_norm_a: f32, // Fase normalizada [0.0, 1.0) para lengüeta principal
    phase_norm_b: f32, // Fase normalizada [0.0, 1.0) para lengüeta musette
    sample_rate: f32,
    envelope: f32,
    target_envelope: f32,
    release_speed: f32,
    attack_speed: f32,
}

impl AccordionVoice {
    pub fn new(sample_rate: f32) -> Self {
        // Inicializar tablas en el arranque
        let _ = get_reed_a_table();
        let _ = get_reed_b_table();

        Self {
            midi_note: 0,
            frequency: 440.0,
            is_active: false,
            phase_norm_a: 0.0,
            phase_norm_b: 0.0,
            sample_rate,
            envelope: 0.0,
            target_envelope: 0.0,
            attack_speed: 1.0 / (0.015 * sample_rate),  // 15ms ataque rápido de lengüeta
            release_speed: 1.0 / (0.035 * sample_rate), // 35ms caída natural de fuelle
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

    /// Renderiza una muestra mediante lookup tables interpoladas y batimento musette
    #[inline]
    pub fn next_sample(&mut self) -> f32 {
        if !self.is_active {
            return 0.0;
        }

        // Seguimiento del envolvente ADSR
        if self.envelope < self.target_envelope {
            self.envelope = (self.envelope + self.attack_speed).min(self.target_envelope);
        } else if self.envelope > self.target_envelope {
            self.envelope = (self.envelope - self.release_speed).max(0.0);
            if self.envelope <= 0.0001 {
                self.is_active = false;
                return 0.0;
            }
        }

        let detune_hz = 1.25; // Ligero desfase batimento vallenato/norteño (Musette)
        let delta_a = self.frequency / self.sample_rate;
        let delta_b = (self.frequency + detune_hz) / self.sample_rate;

        let table_a = get_reed_a_table();
        let table_b = get_reed_b_table();

        let s_a = lookup_wavetable(table_a, self.phase_norm_a);
        let s_b = lookup_wavetable(table_b, self.phase_norm_b);

        self.phase_norm_a = (self.phase_norm_a + delta_a).fract();
        self.phase_norm_b = (self.phase_norm_b + delta_b).fract();

        (s_a * 0.6 + s_b * 0.4) * self.envelope
    }
}
