use crate::types::{DetectedChordSegment, KeyDetectionResult};
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

                for (idx, &interval) in prof.intervals.iter().enumerate() {
                    let note_idx = (root + interval) % 12;
                    let weight = if idx == 0 {
                        1.3
                    } else if idx == 1 {
                        1.1
                    } else {
                        0.95
                    };
                    harmony_score += harmony[note_idx] * weight;
                }

                let mut penalty = 0.0f32;
                for &interval in prof.non_intervals.iter() {
                    let note_idx = (root + interval) % 12;
                    penalty += harmony[note_idx] * 0.38;
                }

                let bass_match = (bass[root] * 0.70) + (bass[(root + 7) % 12] * 0.20);
                let mut score = harmony_score - penalty + bass_match;

                let is_tonic = root == main_key.rootMod;
                let is_dominant = root == (main_key.rootMod + 7) % 12;
                let is_subdominant = root == (main_key.rootMod + 5) % 12;
                let is_relative = root == (main_key.rootMod + 9) % 12;

                if is_tonic {
                    score *= 1.15;
                } else if is_dominant || is_subdominant {
                    score *= 1.10;
                } else if is_relative {
                    score *= 1.06;
                }

                if score > best_score {
                    best_score = score;
                    best_root = root;
                    best_profile_idx = p_idx;
                }
            }
        }

        let prof = &CHORD_PROFILES[best_profile_idx];
        let bass_midi = 48 + (best_root as i32);
        let mut playback_midis = vec![bass_midi];
        for &int in prof.intervals.iter() {
            playback_midis.push(60 + (best_root as i32) + (int as i32));
        }

        let note_mods = prof.intervals.iter().map(|&int| (best_root + int) % 12).collect();

        frame_detections.push(FrameDetection {
            root_mod: best_root,
            quality: prof.profile_type.to_string(),
            chord_name: format!("{} {}", NOTE_NAMES_LAT[best_root], prof.name),
            chord_symbol: format!("{}{}", NOTE_NAMES_ALE[best_root], prof.symbol),
            note_mods,
            playback_midis,
            confidence: (best_score / 2.6).clamp(0.2, 1.0),
        });
    }

    // Suavizado temporal mediante ventana mediana de 7 frames (~350ms)
    let smoothed = smooth_detections(&frame_detections);

    if smoothed.is_empty() {
        return Vec::new();
    }

    let mut segments: Vec<DetectedChordSegment> = Vec::new();
    let mut current_segment = DetectedChordSegment {
        startTime: 0.0,
        endTime: frame_duration,
        rootMod: smoothed[0].root_mod,
        quality: smoothed[0].quality.clone(),
        chordName: smoothed[0].chord_name.clone(),
        chordSymbol: smoothed[0].chord_symbol.clone(),
        noteMods: smoothed[0].note_mods.clone(),
        playbackMidis: smoothed[0].playback_midis.clone(),
        confidence: smoothed[0].confidence,
    };

    for i in 1..smoothed.len() {
        let frame = &smoothed[i];
        let is_same = frame.root_mod == current_segment.rootMod && frame.quality == current_segment.quality;

        if is_same {
            current_segment.endTime = ((i + 1) as f32) * frame_duration;
        } else {
            // Filtrar oscilaciones menores a 0.35s para estabilidad armónica
            if current_segment.endTime - current_segment.startTime >= 0.35 || segments.is_empty() {
                segments.push(current_segment);
            } else if let Some(last) = segments.last_mut() {
                last.endTime = current_segment.endTime;
            }

            current_segment = DetectedChordSegment {
                startTime: (i as f32) * frame_duration,
                endTime: ((i + 1) as f32) * frame_duration,
                rootMod: frame.root_mod,
                quality: frame.quality.clone(),
                chordName: frame.chord_name.clone(),
                chordSymbol: frame.chord_symbol.clone(),
                noteMods: frame.note_mods.clone(),
                playbackMidis: frame.playback_midis.clone(),
                confidence: frame.confidence,
            };
        }
    }

    segments.push(current_segment);
    segments
}

fn smooth_detections(frames: &[FrameDetection]) -> Vec<FrameDetection> {
    let mut result = Vec::with_capacity(frames.len());
    let window_size = 7;

    for i in 0..frames.len() {
        let start = i.saturating_sub(window_size / 2);
        let end = (i + (window_size + 1) / 2).min(frames.len());

        let mut votes: HashMap<String, usize> = HashMap::new();
        for j in start..end {
            let key = format!("{}_{}", frames[j].root_mod, frames[j].quality);
            *votes.entry(key).or_insert(0) += 1;
        }

        let mut max_votes = 0;
        let mut winner_key = format!("{}_{}", frames[i].root_mod, frames[i].quality);
        for (k, &v) in votes.iter() {
            if v > max_votes {
                max_votes = v;
                winner_key = k.clone();
            }
        }

        let winner_frame = frames[start..end]
            .iter()
            .find(|f| format!("{}_{}", f.root_mod, f.quality) == winner_key)
            .unwrap_or(&frames[i])
            .clone();

        result.push(winner_frame);
    }

    result
}
