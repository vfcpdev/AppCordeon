//! Modelado acústico de lengüetas de acordeón diatónico (Reed Model) de alto rendimiento.
//!
//! # Enfoque Formal con Triplas de Hoare:
//! - Precondición {P}: `sample_rate > 0.0` y notas MIDI en `[0, 127]`.
//! - Postcondición {Q}: Cada muestra generada satisface `|sample| <= 1.0` sin NaN ni Infinitos.
//! - Invariante {I}:
//!     * `0.0 <= phase_norm_a < 1.0`
//!     * `0.0 <= phase_norm_b < 1.0`
//!     * `0.0 <= envelope <= 1.0`
//!     * Cero asignaciones en el hilo de audio en tiempo real (`no-alloc`).

use std::f32::consts::PI;
use std::sync::OnceLock;

pub const WAVETABLE_SIZE: usize = 2048;

static REED_A_TABLE: OnceLock<[f32; WAVETABLE_SIZE]> = OnceLock::new();
static REED_B_TABLE: OnceLock<[f32; WAVETABLE_SIZE]> = OnceLock::new();

fn get_reed_a_table() -> &'static [f32; WAVETABLE_SIZE] {
    REED_A_TABLE.get_or_init(|| {
        let mut table = [0.0; WAVETABLE_SIZE];
        let factor = 2.0 * PI / (WAVETABLE_SIZE as f32);
        for (i, sample) in table.iter_mut().enumerate() {
            let phase = (i as f32) * factor;
            // Armónicos 1, 2, 3, 4 característicos de la lengüeta metálica de acordeón
            *sample = (phase.sin() * 0.55)
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
        let factor = 2.0 * PI / (WAVETABLE_SIZE as f32);
        for (i, sample) in table.iter_mut().enumerate() {
            let phase = (i as f32) * factor;
            // Armónicos 1, 2, 3 para la segunda lengüeta con batimento musette
            *sample = (phase.sin() * 0.55)
                + ((phase * 2.0).sin() * 0.25)
                + ((phase * 3.0).sin() * 0.12);
        }
        table
    })
}

/// Búsqueda con interpolación lineal en la tabla de ondas.
///
/// # Tripla de Hoare:
/// - {P}: `table` contiene muestras válidas de amplitud y `0.0 <= phase_norm < 1.0`.
/// - {Q}: Retorna una interpolación continua acotada `[-1.0, 1.0]`.
#[inline(always)]
fn lookup_wavetable(table: &[f32; WAVETABLE_SIZE], phase_norm: f32) -> f32 {
    let clamped_phase = phase_norm.clamp(0.0, 1.0 - f32::EPSILON);
    let index_f = clamped_phase * (WAVETABLE_SIZE as f32);
    let i0 = (index_f as usize) % WAVETABLE_SIZE;
    let i1 = (i0 + 1) % WAVETABLE_SIZE;
    let frac = index_f - (index_f as usize as f32);
    table[i0] + frac * (table[i1] - table[i0])
}

/// Estado de la envolvente de la lengüeta acústica (State Pattern).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnvelopeState {
    Idle,
    Attack,
    Release,
}

pub struct AccordionVoice {
    pub midi_note: u8,
    pub frequency: f32,
    pub is_active: bool,
    pub envelope: f32,
    pub state: EnvelopeState,
    phase_norm_a: f32, // Fase normalizada [0.0, 1.0) para lengüeta principal
    phase_norm_b: f32, // Fase normalizada [0.0, 1.0) para lengüeta musette
    sample_rate: f32,
    attack_speed: f32,
    release_speed: f32,
}

impl AccordionVoice {
    pub fn new(sample_rate: f32) -> Self {
        let safe_sr = if sample_rate <= 0.0 { 44100.0 } else { sample_rate };
        // Inicializar tablas en el arranque
        let _ = get_reed_a_table();
        let _ = get_reed_b_table();

        Self {
            midi_note: 0,
            frequency: 440.0,
            is_active: false,
            envelope: 0.0,
            state: EnvelopeState::Idle,
            phase_norm_a: 0.0,
            phase_norm_b: 0.0,
            sample_rate: safe_sr,
            attack_speed: 1.0 / (0.015 * safe_sr),  // 15ms ataque rápido de lengüeta
            release_speed: 1.0 / (0.035 * safe_sr), // 35ms caída natural de fuelle
        }
    }

    /// Actualiza la tasa de muestreo preservando la estabilidad.
    pub fn set_sample_rate(&mut self, sample_rate: f32) {
        let safe_sr = if sample_rate <= 0.0 { 44100.0 } else { sample_rate };
        self.sample_rate = safe_sr;
        self.attack_speed = 1.0 / (0.015 * safe_sr);
        self.release_speed = 1.0 / (0.035 * safe_sr);
    }

    pub fn note_on(&mut self, midi_note: u8) {
        self.midi_note = midi_note;
        self.frequency = 440.0 * 2.0_f32.powf((midi_note as f32 - 69.0) / 12.0);
        self.is_active = true;
        self.state = EnvelopeState::Attack;
    }

    pub fn note_off(&mut self) {
        if self.is_active {
            self.state = EnvelopeState::Release;
        }
    }

    /// Renderiza una muestra mediante lookup tables interpoladas y batimento musette.
    ///
    /// # Tripla de Hoare:
    /// - {P}: Invariante {I} se cumple en la llamada.
    /// - {Q}: Salida `s` cumple `-1.0 <= s <= 1.0`, e Invariante {I} se preserva para el siguiente ciclo.
    #[inline]
    pub fn next_sample(&mut self) -> f32 {
        if !self.is_active || self.state == EnvelopeState::Idle {
            return 0.0;
        }

        // Transición de la máquina de estados del envolvente
        match self.state {
            EnvelopeState::Attack => {
                self.envelope += self.attack_speed;
                if self.envelope >= 1.0 {
                    self.envelope = 1.0;
                }
            }
            EnvelopeState::Release => {
                self.envelope -= self.release_speed;
                if self.envelope <= 0.0001 {
                    self.envelope = 0.0;
                    self.is_active = false;
                    self.state = EnvelopeState::Idle;
                    return 0.0;
                }
            }
            EnvelopeState::Idle => {
                self.envelope = 0.0;
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
        if self.phase_norm_a < 0.0 {
            self.phase_norm_a += 1.0;
        }

        self.phase_norm_b = (self.phase_norm_b + delta_b).fract();
        if self.phase_norm_b < 0.0 {
            self.phase_norm_b += 1.0;
        }

        (s_a * 0.6 + s_b * 0.4) * self.envelope
    }
}
