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
