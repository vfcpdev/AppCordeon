use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MelodyNote {
    pub id: usize,
    pub bar: u32,
    pub beat: f32,
    pub step: String,
    pub alter: i32,
    pub octave: i32,
    pub pitch_name: String,
    pub scientific: String,
    pub midi: u8,
    pub duration_beats: f32,
    pub note_type: String,
    pub is_rest: bool,
    pub is_chord_note: bool,
    pub lyric: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MelodyReport {
    pub title: String,
    pub bpm: f32,
    pub meter: String,
    pub total_bars: usize,
    pub total_notes: usize,
    pub notes: Vec<MelodyNote>,
    pub engine: String,
}
