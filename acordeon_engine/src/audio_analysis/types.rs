use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedChordSegment {
    pub startTime: f32,
    pub endTime: f32,
    pub rootMod: usize,
    pub quality: String,
    pub chordName: String,
    pub chordSymbol: String,
    pub noteMods: Vec<usize>,
    pub playbackMidis: Vec<i32>,
    pub confidence: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyDetectionResult {
    pub rootMod: usize,
    pub mode: String,
    pub keyNameLat: String,
    pub keyNameAle: String,
    pub recommendedTuning: String,
    pub recommendedOffset: i32,
    pub recommendedRow: String,
    pub correlation: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioAnalysisReport {
    pub duration: f32,
    pub bpm: i32,
    pub mainKey: KeyDetectionResult,
    pub chords: Vec<DetectedChordSegment>,
    pub chromagram: Vec<[f32; 12]>,
}

/// Representa el acorde detectado en un tiempo/compás específico sincronizado al compás de audio.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BeatChordAnalysis {
    pub bar_index: usize,
    pub beat_index: usize,
    pub start_time: f32,
    pub end_time: f32,
    pub root_mod: usize,
    pub quality: String,
    pub chord_name: String,
    pub chord_symbol: String,
    pub is_chord_change: bool,
    pub confidence: f32,
}

/// Reporte completo de acordes alineados a compases y transiciones armónicas.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeatAlignedChordsReport {
    pub bpm: f32,
    pub start_offset: f32,
    pub total_changes: usize,
    pub beat_chords: Vec<BeatChordAnalysis>,
}
