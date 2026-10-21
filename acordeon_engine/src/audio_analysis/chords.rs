use super::types::{DetectedChordSegment, KeyDetectionResult};
use std::collections::HashMap;

const NOTE_NAMES_LAT: [&str; 12] = ["Do", "Do♯", "Re", "Mi♭", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "Si♭", "Si"];
const NOTE_NAMES_ALE: [&str; 12] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"];

struct ChordProfile {
    profile_type: &'static str,
    symbol: &'static str,
    name: &'static str,
    intervals: &'static [usize],
    non_intervals: &'static [usize],
}

const CHORD_PROFILES: [ChordProfile; 7] = [
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

                // Prioridad tonal para la tonalidad principal detectada
                let mut tonality_bonus = 0.0f32;
                let tonic = main_key.rootMod;
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
            confidence: (best_score.clamp(0.0, 1.0) * 100.0).round() / 100.0,
        });
    }

    // Suavizado temporal y fusión de segmentos continuos
    let mut segments: Vec<DetectedChordSegment> = Vec::new();
    let min_segment_frames = 3;

    if frame_detections.is_empty() {
        return segments;
    }

    let mut current_start = 0usize;
    let mut current_det = frame_detections[0].clone();
    let mut current_count = 1usize;

    for i in 1..frame_detections.len() {
        let det = &frame_detections[i];
        if det.root_mod == current_det.root_mod && det.quality == current_det.quality {
            current_count += 1;
        } else {
            if current_count >= min_segment_frames {
                segments.push(DetectedChordSegment {
                    startTime: ((current_start as f32) * frame_duration * 10.0).round() / 10.0,
                    endTime: ((i as f32) * frame_duration * 10.0).round() / 10.0,
                    rootMod: current_det.root_mod,
                    quality: current_det.quality.clone(),
                    chordName: current_det.chord_name.clone(),
                    chordSymbol: current_det.chord_symbol.clone(),
                    noteMods: current_det.note_mods.clone(),
                    playbackMidis: current_det.playback_midis.clone(),
                    confidence: current_det.confidence,
                });
            }
            current_start = i;
            current_det = det.clone();
            current_count = 1;
        }
    }

    // Último segmento
    if current_count >= min_segment_frames {
        segments.push(DetectedChordSegment {
            startTime: ((current_start as f32) * frame_duration * 10.0).round() / 10.0,
            endTime: ((frame_detections.len() as f32) * frame_duration * 10.0).round() / 10.0,
            rootMod: current_det.root_mod,
            quality: current_det.quality,
            chordName: current_det.chord_name,
            chordSymbol: current_det.chord_symbol,
            noteMods: current_det.note_mods,
            playbackMidis: current_det.playback_midis,
            confidence: current_det.confidence,
        });
    }

    segments
}
