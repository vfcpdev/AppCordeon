//! # Accordion DSP Core & WASM Bridge
//! Motor de síntesis física por modelado de lengüetas de acordeón diatónico (Hohner Corona III).
//! Diseñado para ejecución en tiempo real lock-free y compilación a WebAssembly.

use wasm_bindgen::prelude::*;

pub const SAMPLE_RATE: f32 = 44100.0;
pub const MAX_VOICES: usize = 32;

/// Tipo de botón del acordeón diatónico vallenato
#[wasm_bindgen]
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum TipoBoton {
    Pito = 0,
    BajoFundamental = 1,
    BajoAcorde = 2,
}

/// Implementación de oscilador PolyBLEP para formas de onda Sawtooth y Pulse/Square.
/// Elimina los saltos abruptos de fase en el dominio digital (anti-aliasing)
/// con costo computacional extremadamente bajo O(1).
#[derive(Clone, Copy, Debug)]
pub struct PolyBlepOsc {
    pub phase: f32,
    pub phase_inc: f32,
}

impl PolyBlepOsc {
    #[inline(always)]
    pub fn new() -> Self {
        Self {
            phase: 0.0,
            phase_inc: 0.0,
        }
    }

    #[inline(always)]
    pub fn set_frequency(&mut self, freq: f32, sample_rate: f32) {
        self.phase_inc = (freq / sample_rate).clamp(0.0, 0.499);
    }

    /// Corrección de discontinuidad polinómica PolyBLEP (2do orden)
    #[inline(always)]
    fn poly_blep(t: f32, dt: f32) -> f32 {
        if t < dt {
            let t = t / dt;
            t + t - t * t - 1.0
        } else if t > 1.0 - dt {
            let t = (t - 1.0) / dt;
            t * t + t + t + 1.0
        } else {
            0.0
        }
    }

    /// Diente de sierra PolyBLEP (rango [-1.0, 1.0])
    #[inline(always)]
    pub fn sample_saw(&mut self) -> f32 {
        let naive = 2.0 * self.phase - 1.0;
        let blep = Self::poly_blep(self.phase, self.phase_inc);
        let out = naive - blep;

        self.phase += self.phase_inc;
        if self.phase >= 1.0 {
            self.phase -= 1.0;
        }
        out
    }

    /// Onda cuadrada/pulso PolyBLEP (50% duty cycle)
    #[inline(always)]
    pub fn sample_square(&mut self) -> f32 {
        let naive = if self.phase < 0.5 { 1.0 } else { -1.0 };
        let blep1 = Self::poly_blep(self.phase, self.phase_inc);
        let blep2 = Self::poly_blep((self.phase + 0.5).fract(), self.phase_inc);
        let out = naive + blep1 - blep2;

        self.phase += self.phase_inc;
        if self.phase >= 1.0 {
            self.phase -= 1.0;
        }
        out
    }
}

/// Generador de Ruido Blanco ultra rápido (Xorshift32)
#[derive(Clone, Copy, Debug)]
pub struct FastNoise {
    state: u32,
}

impl FastNoise {
    pub fn new(seed: u32) -> Self {
        Self { state: if seed == 0 { 0x6D2B79F5 } else { seed } }
    }

    #[inline(always)]
    pub fn next_f32(&mut self) -> f32 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 17;
        self.state ^= self.state << 5;
        // Normalizado [-1.0, 1.0]
        (self.state as f32 / 2147483648.0) - 1.0
    }
}

/// Filtro Biquad Direct Form I transpuesto
#[derive(Clone, Copy, Debug)]
pub struct BiquadFilter {
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,
    z1: f32,
    z2: f32,
}

impl BiquadFilter {
    pub fn new() -> Self {
        Self {
            b0: 1.0, b1: 0.0, b2: 0.0,
            a1: 0.0, a2: 0.0,
            z1: 0.0, z2: 0.0,
        }
    }

    pub fn reset(&mut self) {
        self.z1 = 0.0;
        self.z2 = 0.0;
    }

    /// Filtro Peaking EQ
    pub fn set_peaking(&mut self, sample_rate: f32, freq: f32, q: f32, gain_db: f32) {
        let a = 10.0f32.powf(gain_db / 40.0);
        let w0 = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let alpha = w0.sin() / (2.0 * q);
        let cos_w0 = w0.cos();

        let b0 = 1.0 + alpha * a;
        let b1 = -2.0 * cos_w0;
        let b2 = 1.0 - alpha * a;
        let a0 = 1.0 + alpha / a;
        let a1 = -2.0 * cos_w0;
        let a2 = 1.0 - alpha / a;

        self.b0 = b0 / a0;
        self.b1 = b1 / a0;
        self.b2 = b2 / a0;
        self.a1 = a1 / a0;
        self.a2 = a2 / a0;
    }

    /// Filtro Pasa-Bajos de 2do orden (Butterworth / Resonante)
    pub fn set_lowpass(&mut self, sample_rate: f32, freq: f32, q: f32) {
        let w0 = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let cos_w0 = w0.cos();
        let alpha = w0.sin() / (2.0 * q);

        let b0 = (1.0 - cos_w0) * 0.5;
        let b1 = 1.0 - cos_w0;
        let b2 = (1.0 - cos_w0) * 0.5;
        let a0 = 1.0 + alpha;
        let a1 = -2.0 * cos_w0;
        let a2 = 1.0 - alpha;

        self.b0 = b0 / a0;
        self.b1 = b1 / a0;
        self.b2 = b2 / a0;
        self.a1 = a1 / a0;
        self.a2 = a2 / a0;
    }

    /// Filtro Pasa-Banda con ganancia constante en frecuencia central
    pub fn set_bandpass(&mut self, sample_rate: f32, freq: f32, q: f32) {
        let w0 = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let cos_w0 = w0.cos();
        let alpha = w0.sin() / (2.0 * q);

        let b0 = alpha;
        let b1 = 0.0;
        let b2 = -alpha;
        let a0 = 1.0 + alpha;
        let a1 = -2.0 * cos_w0;
        let a2 = 1.0 - alpha;

        self.b0 = b0 / a0;
        self.b1 = b1 / a0;
        self.b2 = b2 / a0;
        self.a1 = a1 / a0;
        self.a2 = a2 / a0;
    }

    #[inline(always)]
    pub fn process(&mut self, input: f32) -> f32 {
        let out = self.b0 * input + self.z1;
        self.z1 = self.b1 * input - self.a1 * out + self.z2;
        self.z2 = self.b2 * input - self.a2 * out;
        out
    }
}

/// Estado de la envolvente de fuelle
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum EnvState {
    Idle,
    Attack,
    Decay,
    Sustain,
    Release,
}

/// Modelo físico de voz de acordeón con banco Musette de 3 lengüetas + sub-octava
#[derive(Clone, Copy, Debug)]
pub struct AccordionVoice {
    pub active: bool,
    pub midi_note: u8,
    pub base_frequency: f32,
    pub button_type: TipoBoton,
    pub velocity: f32,

    // Osciladores de las 3 lengüetas
    pub osc_center: PolyBlepOsc, // Lengüeta central (0 cents)
    pub osc_high: PolyBlepOsc,   // Lengüeta aguda (+15 cents)
    pub osc_low: PolyBlepOsc,    // Lengüeta grave (-14 cents)
    pub osc_sub: PolyBlepOsc,    // Sub-octava para bajos (mano izquierda)

    // Envolvente de presión del fuelle
    pub env_state: EnvState,
    pub env_value: f32,
    pub time_in_attack_sec: f32,

    // Ruido de aire del fuelle acoplado
    pub noise_gen: FastNoise,
    pub noise_filter: BiquadFilter,

    // Filtros de cuerpo acústico por voz
    pub filter_peaking: BiquadFilter,
    pub filter_lowpass: BiquadFilter,
}

impl AccordionVoice {
    pub fn new() -> Self {
        let mut noise_filter = BiquadFilter::new();
        noise_filter.set_bandpass(SAMPLE_RATE, 1200.0, 2.0);

        let mut filter_peaking = BiquadFilter::new();
        filter_peaking.set_peaking(SAMPLE_RATE, 1050.0, 1.4, 4.5);

        let mut filter_lowpass = BiquadFilter::new();
        filter_lowpass.set_lowpass(SAMPLE_RATE, 3200.0, 0.707);

        Self {
            active: false,
            midi_note: 0,
            base_frequency: 440.0,
            button_type: TipoBoton::Pito,
            velocity: 0.8,

            osc_center: PolyBlepOsc::new(),
            osc_high: PolyBlepOsc::new(),
            osc_low: PolyBlepOsc::new(),
            osc_sub: PolyBlepOsc::new(),

            env_state: EnvState::Idle,
            env_value: 0.0,
            time_in_attack_sec: 0.0,

            noise_gen: FastNoise::new(12345),
            noise_filter,

            filter_peaking,
            filter_lowpass,
        }
    }

    /// Dispara la nota (Key On) con afinación y desvío musette
    pub fn trigger(&mut self, midi_note: u8, velocity: f32, button_type: TipoBoton, sample_rate: f32) {
        self.active = true;
        self.midi_note = midi_note;
        self.velocity = velocity.clamp(0.0, 1.0);
        self.button_type = button_type;

        // Frecuencia base por estándar A4 = 440 Hz
        let freq = 440.0 * 2.0f32.powf((midi_note as f32 - 69.0) / 12.0);
        self.base_frequency = freq;

        // Reset envolvente
        self.env_state = EnvState::Attack;
        self.time_in_attack_sec = 0.0;

        // Reconfigurar corte de filtro según botón (Pito vs Bajos)
        match button_type {
            TipoBoton::Pito => {
                self.filter_peaking.set_peaking(sample_rate, 1050.0, 1.4, 4.5);
                self.filter_lowpass.set_lowpass(sample_rate, 3200.0, 0.707);
            }
            TipoBoton::BajoFundamental | TipoBoton::BajoAcorde => {
                // Caja de resonancia más profunda y corte más oscuro para bajos
                self.filter_peaking.set_peaking(sample_rate, 220.0, 1.2, 5.0);
                self.filter_lowpass.set_lowpass(sample_rate, 1800.0, 0.707);
            }
        }

        self.noise_filter.reset();
        self.filter_peaking.reset();
        self.filter_lowpass.reset();

        self.update_frequencies(sample_rate, 0.0);
    }

    /// Actualiza frecuencias de las 3 lengüetas aplicando el Pitch Sag transitorio
    #[inline(always)]
    fn update_frequencies(&mut self, sample_rate: f32, pitch_sag_cents: f32) {
        let f_base = self.base_frequency;

        // Osc 1 (Centro): 0 cents + sag
        let f_center = f_base * 2.0f32.powf(pitch_sag_cents / 1200.0);
        self.osc_center.set_frequency(f_center, sample_rate);

        // Osc 2 (Agudo): +15 cents + sag
        let f_high = f_base * 2.0f32.powf((15.0 + pitch_sag_cents) / 1200.0);
        self.osc_high.set_frequency(f_high, sample_rate);

        // Osc 3 (Grave): -14 cents + sag
        let f_low = f_base * 2.0f32.powf((-14.0 + pitch_sag_cents) / 1200.0);
        self.osc_low.set_frequency(f_low, sample_rate);

        // Sub-octava para bajos
        if self.button_type != TipoBoton::Pito {
            self.osc_sub.set_frequency(f_center * 0.5, sample_rate);
        }
    }

    /// Cierre de botón (Key Off / Release)
    pub fn release(&mut self) {
        if self.env_state != EnvState::Idle {
            self.env_state = EnvState::Release;
        }
    }

    /// Procesa 1 muestra de audio generada por la voz (lock-free)
    #[inline(always)]
    pub fn process_sample(&mut self, sample_rate: f32) -> f32 {
        if !self.active || self.env_state == EnvState::Idle {
            return 0.0;
        }

        let dt = 1.0 / sample_rate;

        // 1. Envolvente ADSR con curvas acústicas de inercia de lengüeta
        // Attack: 40ms, Decay: 100ms, Sustain: 0.85, Release: 80ms
        let mut pitch_sag_cents = 0.0;

        match self.env_state {
            EnvState::Attack => {
                self.time_in_attack_sec += dt;
                // Exponencial suave para simular la presión del aire sobre la lámina de acero
                let progress = (self.time_in_attack_sec / 0.040).clamp(0.0, 1.0);
                self.env_value = progress * progress * (3.0 - 2.0 * progress); // smoothstep

                // Pitch Sag: en los primeros 35ms desvía de -8 cents a 0 cents
                if self.time_in_attack_sec <= 0.035 {
                    let sag_progress = self.time_in_attack_sec / 0.035;
                    pitch_sag_cents = -8.0 * (1.0 - sag_progress);
                }

                if progress >= 1.0 {
                    self.env_state = EnvState::Decay;
                }
            }
            EnvState::Decay => {
                let decay_rate = dt / 0.100;
                self.env_value -= (1.0 - 0.85) * decay_rate;
                if self.env_value <= 0.85 {
                    self.env_value = 0.85;
                    self.env_state = EnvState::Sustain;
                }
            }
            EnvState::Sustain => {
                self.env_value = 0.85;
            }
            EnvState::Release => {
                let release_rate = dt / 0.080;
                self.env_value -= 0.85 * release_rate;
                if self.env_value <= 0.0001 {
                    self.env_value = 0.0;
                    self.env_state = EnvState::Idle;
                    self.active = false;
                    return 0.0;
                }
            }
            EnvState::Idle => {
                self.env_value = 0.0;
                self.active = false;
                return 0.0;
            }
        }

        // Actualizar desvío por presión si está en transitorio de ataque
        if self.env_state == EnvState::Attack {
            self.update_frequencies(sample_rate, pitch_sag_cents);
        }

        // 2. Banco de 3 Osciladores Musette
        let s_center = self.osc_center.sample_saw() * 0.50;
        let s_high   = self.osc_high.sample_saw() * 0.35;
        let s_low    = self.osc_low.sample_square() * 0.25;

        let mut raw_reed_mix = s_center + s_high + s_low;

        // Añadir sub-grave si es botón de bajo
        if self.button_type != TipoBoton::Pito {
            let s_sub = self.osc_sub.sample_saw() * 0.45;
            raw_reed_mix = (raw_reed_mix * 0.7) + s_sub;
        }

        // 3. Ruido de Aire de fuelle acoplado (2% mezclado en pasa-banda 1200Hz)
        let white_sample = self.noise_gen.next_f32();
        let air_noise = self.noise_filter.process(white_sample) * 0.02;

        let combined = (raw_reed_mix + air_noise) * (self.env_value * self.velocity);

        // 4. Filtrado en Cascada (Caja de Resonancia Peaking + Suavizado Low-Pass)
        let peak_out = self.filter_peaking.process(combined);
        let final_out = self.filter_lowpass.process(peak_out);

        final_out
    }
}

/// Motor Polifónico de Acordeón en tiempo real (Lock-Free)
#[wasm_bindgen]
pub struct AccordionEngine {
    voices: [AccordionVoice; MAX_VOICES],
    sample_rate: f32,
    master_gain: f32,
}

#[wasm_bindgen]
impl AccordionEngine {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            voices: [AccordionVoice::new(); MAX_VOICES],
            sample_rate: SAMPLE_RATE,
            master_gain: 0.70,
        }
    }

    /// Dispara una nota por número MIDI (ej: 69 = A4)
    pub fn note_on(&mut self, midi_note: u8, velocity: f32, button_type: TipoBoton) {
        // 1. Si la nota ya está sonando, reiniciarla
        for voice in self.voices.iter_mut() {
            if voice.active && voice.midi_note == midi_note {
                voice.trigger(midi_note, velocity, button_type, self.sample_rate);
                return;
            }
        }

        // 2. Buscar voz inactiva
        for voice in self.voices.iter_mut() {
            if !voice.active {
                voice.trigger(midi_note, velocity, button_type, self.sample_rate);
                return;
            }
        }

        // 3. Voice Stealing: tomar la que tenga menor ganancia o esté en release
        let mut min_idx = 0;
        let mut min_val = f32::MAX;
        for (i, voice) in self.voices.iter().enumerate() {
            if voice.env_value < min_val {
                min_val = voice.env_value;
                min_idx = i;
            }
        }
        self.voices[min_idx].trigger(midi_note, velocity, button_type, self.sample_rate);
    }

    /// Suelta la nota
    pub fn note_off(&mut self, midi_note: u8) {
        for voice in self.voices.iter_mut() {
            if voice.active && voice.midi_note == midi_note {
                voice.release();
            }
        }
    }

    /// Detiene todas las notas
    pub fn all_notes_off(&mut self) {
        for voice in self.voices.iter_mut() {
            voice.release();
        }
    }

    /// Ajusta volumen maestro
    pub fn set_master_gain(&mut self, gain: f32) {
        self.master_gain = gain.clamp(0.0, 1.0);
    }

    /// Procesa un bloque de audio directamente en el buffer de salida (WASM / AudioWorklet)
    pub fn process_block(&mut self, output: &mut [f32]) {
        for sample in output.iter_mut() {
            let mut mix = 0.0;
            for voice in self.voices.iter_mut() {
                if voice.active {
                    mix += voice.process_sample(self.sample_rate);
                }
            }
            // Limitador suave tipo soft-clip tanh para evitar distorsión dura
            let driven = mix * self.master_gain;
            *sample = driven.tanh();
        }
    }
}
