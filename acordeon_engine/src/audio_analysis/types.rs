use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DetectedChordSegment {
    pub start_time: f32,
    pub end_time: f32,
    pub root_mod: usize,
    pub quality: String,
    pub chord_name: String,
    pub chord_symbol: String,
    pub note_mods: Vec<usize>,
    pub playback_midis: Vec<i32>,
    pub confidence: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyDetectionResult {
    pub root_mod: usize,
    pub mode: String,
    pub key_name_lat: String,
    pub key_name_ale: String,
    pub recommended_tuning: String,
    pub recommended_offset: i32,
    pub recommended_row: String,
    pub correlation: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioAnalysisReport {
    pub duration: f32,
    pub bpm: i32,
    pub main_key: KeyDetectionResult,
    pub chords: Vec<DetectedChordSegment>,
    pub chromagram: Vec<[f32; 12]>,
}

/// Representa el acorde detectado en un tiempo/compás específico sincronizado al compás de audio.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
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
#[serde(rename_all = "camelCase")]
pub struct BeatAlignedChordsReport {
    pub bpm: f32,
    pub start_offset: f32,
    pub total_changes: usize,
    pub beat_chords: Vec<BeatChordAnalysis>,
}
