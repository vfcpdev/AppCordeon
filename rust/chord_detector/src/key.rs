use crate::types::KeyDetectionResult;

const KRUMHANSL_MAJOR: [f32; 12] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
const KRUMHANSL_MINOR: [f32; 12] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];

const TEMPERLEY_MAJOR: [f32; 12] = [5.0, 2.0, 3.5, 2.0, 4.5, 4.0, 2.0, 4.5, 2.0, 3.5, 1.5, 4.0];
const TEMPERLEY_MINOR: [f32; 12] = [5.0, 2.0, 3.5, 4.5, 2.0, 4.0, 2.0, 4.5, 3.5, 2.0, 1.5, 4.0];

const NOTE_NAMES_LAT: [&str; 12] = ["Do", "Do♯", "Re", "Mi♭", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "Si♭", "Si"];
const NOTE_NAMES_ALE: [&str; 12] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B"];

// Afinaciones estándar de acordeón diatónico vallenato
const ROW_BASE_TONICS: [usize; 3] = [3, 8, 1]; // Row 1 (Eb), Row 2 (Ab), Row 3 (Db) con base Cinco Letras

pub fn detect_global_key(global_chroma: &[f32; 12]) -> KeyDetectionResult {
    let mut best_score = -f32::INFINITY;
    let mut best_root = 0usize;
    let mut best_mode = "major";

    for r in 0..12 {
        let mut rotated = [0.0f32; 12];
        for i in 0..12 {
            rotated[i] = global_chroma[(i + r) % 12];
        }

        let score_krum_maj = pearson_correlation(&rotated, &KRUMHANSL_MAJOR);
        let score_krum_min = pearson_correlation(&rotated, &KRUMHANSL_MINOR);
        let score_temp_maj = pearson_correlation(&rotated, &TEMPERLEY_MAJOR);
        let score_temp_min = pearson_correlation(&rotated, &TEMPERLEY_MINOR);

        let combined_maj = 0.55 * score_krum_maj + 0.45 * score_temp_maj;
        let combined_min = 0.55 * score_krum_min + 0.45 * score_temp_min;

        let total_chroma_sum: f32 = rotated.iter().sum::<f32>().max(1e-6);
        let tonic_bonus = (rotated[0] + rotated[4] + rotated[7]) / total_chroma_sum;
        let minor_tonic_bonus = (rotated[0] + rotated[3] + rotated[7]) / total_chroma_sum;

        let total_score_maj = combined_maj + (tonic_bonus * 0.15);
        let total_score_min = combined_min + (minor_tonic_bonus * 0.15);

        if total_score_maj > best_score {
            best_score = total_score_maj;
            best_root = r;
            best_mode = "major";
        }
        if total_score_min > best_score {
            best_score = total_score_min;
            best_root = r;
            best_mode = "minor";
        }
    }

    let root_lat = NOTE_NAMES_LAT[best_root];
    let root_ale = NOTE_NAMES_ALE[best_root];
    let mode_label_lat = if best_mode == "major" { "Mayor" } else { "Menor" };
    let mode_label_ale = if best_mode == "major" { "Major" } else { "Minor" };

    let (tuning_name, offset, row_key) = recommend_accordion_tuning(best_root);

    KeyDetectionResult {
        rootMod: best_root,
        mode: best_mode.to_string(),
        keyNameLat: format!("{} {}", root_lat, mode_label_lat),
        keyNameAle: format!("{} {}", root_ale, mode_label_ale),
        recommendedTuning: tuning_name,
        recommendedOffset: offset,
        recommendedRow: row_key,
        correlation: (best_score * 100.0).round() / 100.0,
    }
}

fn recommend_accordion_tuning(root_mod: usize) -> (String, i32, String) {
    // Lista de afinaciones comunes en el vallenato
    let tunings: [(&str, i32); 4] = [
        ("Cinco Letras (Bb-Eb-Ab)", 10),
        ("Tres Coronas (G-C-F)", 7),
        ("ADG (La-Re-Sol)", 9),
        ("Do-Fa-Si♭ (C-F-Bb)", 0),
    ];

    for (name, offset) in tunings {
        let r1 = ((ROW_BASE_TONICS[0] as i32 + offset).rem_euclid(12)) as usize;
        let r2 = ((ROW_BASE_TONICS[1] as i32 + offset).rem_euclid(12)) as usize;
        let r3 = ((ROW_BASE_TONICS[2] as i32 + offset).rem_euclid(12)) as usize;

        if root_mod == r2 {
            return (name.to_string(), offset, "row2".to_string());
        }
        if root_mod == r1 {
            return (name.to_string(), offset, "row1".to_string());
        }
        if root_mod == r3 {
            return (name.to_string(), offset, "row3".to_string());
        }
    }

    ("Cinco Letras (Bb-Eb-Ab)".to_string(), 10, "row2".to_string())
}

fn pearson_correlation(x: &[f32; 12], y: &[f32; 12]) -> f32 {
    let mut sum_x = 0.0f32;
    let mut sum_y = 0.0f32;
    let mut sum_xy = 0.0f32;
    let mut sum_x2 = 0.0f32;
    let mut sum_y2 = 0.0f32;

    for i in 0..12 {
        sum_x += x[i];
        sum_y += y[i];
        sum_xy += x[i] * y[i];
        sum_x2 += x[i] * x[i];
        sum_y2 += y[i] * y[i];
    }

    let numerator = 12.0 * sum_xy - sum_x * sum_y;
    let denominator = ((12.0 * sum_x2 - sum_x * sum_x) * (12.0 * sum_y2 - sum_y * sum_y)).sqrt();
    if denominator == 0.0 {
        0.0
    } else {
        numerator / denominator
    }
}
