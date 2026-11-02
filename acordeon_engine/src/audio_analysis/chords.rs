use super::types::{BeatChordAnalysis, DetectedChordSegment, KeyDetectionResult};

pub const NOTE_NAMES_LAT: [&str; 12] = ["Do", "Do♯", "Re", "Mi♭", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "Si♭", "Si"];
pub const NOTE_NAMES_ALE: [&str; 12] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"];

/// Perfil armónico de evaluación de acordes (Strategy Pattern / Open-Closed Principle).
#[derive(Debug, Clone, Copy)]
pub struct ChordProfile {
    pub profile_type: &'static str,
    pub symbol: &'static str,
    pub name: &'static str,
    pub intervals: &'static [usize],
    pub non_intervals: &'static [usize],
}

pub const CHORD_PROFILES: [ChordProfile; 7] = [
    ChordProfile {
        profile_type: "maj",
        symbol: "",
        name: "Mayor",
        intervals: &[0, 4, 7],
        non_intervals: &[1, 2, 3, 5, 6, 8, 9, 10, 11],
    },
    ChordProfile {
        profile_type: "min",
        symbol: "m",
        name: "Menor",
        intervals: &[0, 3, 7],
        non_intervals: &[1, 2, 4, 5, 6, 8, 9, 10, 11],
    },
    ChordProfile {
        profile_type: "dom7",
        symbol: "7",
        name: "7ma",
        intervals: &[0, 4, 7, 10],
        non_intervals: &[1, 2, 3, 5, 6, 8, 9, 11],
    },
    ChordProfile {
        profile_type: "min7",
        symbol: "m7",
        name: "Menor 7ma",
        intervals: &[0, 3, 7, 10],
        non_intervals: &[1, 2, 4, 5, 6, 8, 9, 11],
    },
    ChordProfile {
        profile_type: "maj7",
        symbol: "Maj7",
        name: "Mayor 7ma",
        intervals: &[0, 4, 7, 11],
        non_intervals: &[1, 2, 3, 5, 6, 8, 9, 10],
    },
    ChordProfile {
        profile_type: "sus4",
        symbol: "sus4",
        name: "Sus4",
        intervals: &[0, 5, 7],
        non_intervals: &[1, 2, 3, 4, 6, 8, 9, 10, 11],
    },
    ChordProfile {
        profile_type: "dim",
        symbol: "dim",
        name: "Dism.",
        intervals: &[0, 3, 6],
        non_intervals: &[1, 2, 4, 5, 7, 8, 9, 10, 11],
    },
];

/// Estrategia para cálculo de distancia/flujo armónico (Strategy Pattern).
pub trait HarmonicDistanceMetric {
    fn distance(&self, a: &[f32; 12], b: &[f32; 12]) -> f32;
}

pub struct CosineHarmonicDistance;

impl HarmonicDistanceMetric for CosineHarmonicDistance {
    /// Calcula el flujo cromático (1.0 - Similitud Coseno).
    /// {P}: Vectores de 12 elementos.
    /// {Q}: Distancia normalizada en [0.0, 1.0].
    fn distance(&self, a: &[f32; 12], b: &[f32; 12]) -> f32 {
        let mut dot = 0.0f32;
        let mut norm_a = 0.0f32;
        let mut norm_b = 0.0f32;

        for p in 0..12 {
            dot += a[p] * b[p];
            norm_a += a[p] * a[p];
            norm_b += b[p] * b[p];
        }

        let denom = (norm_a.sqrt() * norm_b.sqrt()).max(1e-6);
        (1.0 - (dot / denom)).clamp(0.0, 1.0)
    }
}

#[derive(Clone)]
struct FrameDetection {
    root_mod: usize,
    quality: String,
    chord_name: String,
    chord_symbol: String,
    note_mods: Vec<usize>,
    playback_midis: Vec<i32>,
    confidence: f32,
}

/// Evalúa el mejor acorde para un vector cromático dado.
fn evaluate_chroma(
    harmony: &[f32; 12],
    bass: &[f32; 12],
    main_key: &KeyDetectionResult,
) -> (usize, usize, f32) {
    let mut best_score = -f32::INFINITY;
    let mut best_root = 0usize;
    let mut best_profile_idx = 0usize;

    for root in 0..12 {
        for (p_idx, prof) in CHORD_PROFILES.iter().enumerate() {
            let mut harmony_score = 0.0f32;
            for &interval in prof.intervals {
                let pc = (root + interval) % 12;
                harmony_score += harmony[pc];
            }
            harmony_score /= prof.intervals.len() as f32;

            let mut penalty = 0.0f32;
            for &interval in prof.non_intervals {
                let pc = (root + interval) % 12;
                penalty += harmony[pc];
            }
            penalty /= prof.non_intervals.len() as f32;

            let bass_boost = bass[root] * 0.40;
            let fifth_pc = (root + 7) % 12;
            let fifth_bass_boost = bass[fifth_pc] * 0.15;

            // Prioridad modal para la tonalidad detectada (I - IV - V - vi)
            let mut tonality_bonus = 0.0f32;
            let tonic = main_key.root_mod;
            if root == tonic {
                tonality_bonus += 0.20;
            } else if root == (tonic + 7) % 12 {
                tonality_bonus += 0.15;
            } else if root == (tonic + 5) % 12 {
                tonality_bonus += 0.12;
            } else if root == (tonic + 9) % 12 {
                tonality_bonus += 0.08;
            }

            let final_score = harmony_score - (0.35 * penalty) + bass_boost + fifth_bass_boost + tonality_bonus;

            if final_score > best_score {
                best_score = final_score;
                best_root = root;
                best_profile_idx = p_idx;
            }
        }
    }

    (best_root, best_profile_idx, (best_score.clamp(0.0, 1.0) * 100.0).round() / 100.0)
}

/// Segmenta el flujo de audio en bloques continuos de acordes.
///
/// # Tripla de Hoare:
/// - {P}: `chromagram.len() > 0`, `hop_size > 0`, `sample_rate > 0.0`.
/// - {Q}: Retorna una lista continua de `DetectedChordSegment` que cubre la totalidad del audio
///        sin saltos ni vacíos temporales.
pub fn segment_chords(
    chromagram: &[[f32; 12]],
    bass_chromagram: &[[f32; 12]],
    harmony_chromagram: &[[f32; 12]],
    hop_size: usize,
    sample_rate: f32,
    main_key: &KeyDetectionResult,
) -> Vec<DetectedChordSegment> {
    let frame_duration = (hop_size as f32) / sample_rate;
    let mut frame_detections = Vec::with_capacity(chromagram.len());

    for i in 0..chromagram.len() {
        let bass = &bass_chromagram[i];
        let harmony = &harmony_chromagram[i];

        let (best_root, best_profile_idx, confidence) = evaluate_chroma(harmony, bass, main_key);

        let prof = &CHORD_PROFILES[best_profile_idx];
        let root_lat = NOTE_NAMES_LAT[best_root];
        let root_ale = NOTE_NAMES_ALE[best_root];

        let chord_name = format!("{} {}", root_lat, prof.name);
        let chord_symbol = format!("{}{}", root_ale, prof.symbol);

        let note_mods: Vec<usize> = prof.intervals.iter().map(|&inv| (best_root + inv) % 12).collect();
        let playback_midis: Vec<i32> = prof.intervals.iter().map(|&inv| 48 + (best_root as i32) + (inv as i32)).collect();

        frame_detections.push(FrameDetection {
            root_mod: best_root,
            quality: prof.profile_type.to_string(),
            chord_name,
            chord_symbol,
            note_mods,
            playback_midis,
            confidence,
        });
    }

    let mut segments: Vec<DetectedChordSegment> = Vec::new();
    if frame_detections.is_empty() {
        return segments;
    }

    let mut current_start = 0usize;
    let mut current_det = frame_detections[0].clone();

    for (i, det) in frame_detections.iter().enumerate().skip(1) {
        // Cambio de acorde tras hysteresis de al menos 3 frames
        if (det.root_mod != current_det.root_mod || det.quality != current_det.quality) && (i - current_start >= 3) {
            segments.push(DetectedChordSegment {
                start_time: ((current_start as f32) * frame_duration * 10.0).round() / 10.0,
                end_time: ((i as f32) * frame_duration * 10.0).round() / 10.0,
                root_mod: current_det.root_mod,
                quality: current_det.quality.clone(),
                chord_name: current_det.chord_name.clone(),
                chord_symbol: current_det.chord_symbol.clone(),
                note_mods: current_det.note_mods.clone(),
                playback_midis: current_det.playback_midis.clone(),
                confidence: current_det.confidence,
            });
            current_start = i;
            current_det = det.clone();
        }
    }

    // Último segmento cubriendo hasta el final del flujo
    segments.push(DetectedChordSegment {
        start_time: ((current_start as f32) * frame_duration * 10.0).round() / 10.0,
        end_time: ((frame_detections.len() as f32) * frame_duration * 10.0).round() / 10.0,
        root_mod: current_det.root_mod,
        quality: current_det.quality,
        chord_name: current_det.chord_name,
        chord_symbol: current_det.chord_symbol,
        note_mods: current_det.note_mods,
        playback_midis: current_det.playback_midis,
        confidence: current_det.confidence,
    });

    segments
}

/// Detección optimizada de acordes sincronizada a compases y tiempos (Beat-Aligned Chord Detection).
///
/// Promedia la energía cromática sobre cada tiempo musical [t_beat, t_beat + delta_t],
/// eliminando ruido transitorio y detectando con precisión cuándo cambia el acorde.
///
/// # Tripla de Hoare:
/// - {P}: `chromagram.len() > 0`, `bpm > 0.0`, `sample_rate > 0.0`, `start_offset >= 0.0`.
/// - {Q}: Retorna `Vec<BeatChordAnalysis>` con exactamente un registro por tiempo musical,
///        con `is_chord_change == true` en cada punto de inflexión armónica.
pub fn detect_beat_aligned_chords(
    chromagram: &[[f32; 12]],
    bass_chromagram: &[[f32; 12]],
    harmony_chromagram: &[[f32; 12]],
    hop_size: usize,
    sample_rate: f32,
    bpm: f32,
    start_offset: f32,
    main_key: &KeyDetectionResult,
) -> Vec<BeatChordAnalysis> {
    let frame_duration = (hop_size as f32) / sample_rate;
    let total_duration = (chromagram.len() as f32) * frame_duration;
    let seconds_per_beat = 60.0 / bpm.max(30.0);

    let effective_duration = (total_duration - start_offset).max(0.0);
    let total_beats = (effective_duration / seconds_per_beat).floor() as usize;

    let mut beat_results = Vec::with_capacity(total_beats);
    let mut last_chord_symbol = String::new();

    for k in 0..total_beats {
        let bar_index = k / 4;
        let beat_index = k % 4;

        let t_start = start_offset + (k as f32) * seconds_per_beat;
        let t_end = t_start + seconds_per_beat;

        let frame_start = ((t_start / frame_duration).floor() as usize).min(chromagram.len().saturating_sub(1));
        let frame_end = ((t_end / frame_duration).ceil() as usize).clamp(frame_start + 1, chromagram.len());

        // Pooling de cromagrama (promedio ponderado en la ventana del tiempo)
        let count = (frame_end - frame_start).max(1) as f32;
        let mut pooled_harm = [0.0f32; 12];
        let mut pooled_bass = [0.0f32; 12];

        for f in frame_start..frame_end {
            for p in 0..12 {
                pooled_harm[p] += harmony_chromagram[f][p];
                pooled_bass[p] += bass_chromagram[f][p];
            }
        }
        for p in 0..12 {
            pooled_harm[p] /= count;
            pooled_bass[p] /= count;
        }

        let (root, prof_idx, confidence) = evaluate_chroma(&pooled_harm, &pooled_bass, main_key);
        let prof = &CHORD_PROFILES[prof_idx];

        let chord_name = format!("{} {}", NOTE_NAMES_LAT[root], prof.name);
        let chord_symbol = format!("{}{}", NOTE_NAMES_ALE[root], prof.symbol);

        let is_change = beat_results.is_empty() || chord_symbol != last_chord_symbol;
        if is_change {
            last_chord_symbol = chord_symbol.clone();
        }

        beat_results.push(BeatChordAnalysis {
            bar_index,
            beat_index,
            start_time: (t_start * 100.0).round() / 100.0,
            end_time: (t_end * 100.0).round() / 100.0,
            root_mod: root,
            quality: prof.profile_type.to_string(),
            chord_name,
            chord_symbol,
            is_chord_change: is_change,
            confidence,
        });
    }

    beat_results
}
