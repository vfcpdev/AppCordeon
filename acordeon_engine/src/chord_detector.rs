//! Motor de Reconocimiento Armónico Inteligente de Acordes en Rust.
//!
//! # Enfoque Formal con Triplas de Hoare:
//! - Precondición {P}: `notes.len() >= 2` y cada nota está en el rango MIDI estándar `[0, 127]`.
//! - Postcondición {Q}: Retorna `Some(DetectedChord)` determinístico con tónica, bajo, fórmula,
//!   inversión y nombre canónico. Si `notes.len() < 2`, retorna `None`.
//! - Invariante {I}: La detección es puramente funcional, sin estado mutable residual,
//!   con garantía de no-pánico y serialización segura JSON.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DetectedChord {
    pub name: String,
    pub root: String,
    pub bass: String,
    pub formula: String,
    pub chord_type: String,
    pub inversion: String,
}

pub const NOTE_NAMES: [&str; 12] = [
    "Do", "Do#", "Re", "Mib", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "Sib", "Si",
];

/// Regla armónica de coincidencia de intervalos (Strategy Pattern / Open-Closed Principle).
#[derive(Debug, Clone, Copy)]
pub struct ChordRule {
    pub intervals: &'static [u8],
    pub quality: &'static str,
    pub formula: &'static str,
    pub chord_type: &'static str,
}

pub const CHORD_RULES: &[ChordRule] = &[
    ChordRule { intervals: &[0, 4, 7], quality: "Mayor", formula: "1 - 3 - 5", chord_type: "Tríada Mayor" },
    ChordRule { intervals: &[0, 3, 7], quality: "Menor", formula: "1 - b3 - 5", chord_type: "Tríada Menor" },
    ChordRule { intervals: &[0, 4, 7, 10], quality: "7", formula: "1 - 3 - 5 - b7", chord_type: "Séptima Dominante" },
    ChordRule { intervals: &[0, 4, 7, 11], quality: "Maj7", formula: "1 - 3 - 5 - 7", chord_type: "Mayor Séptima" },
    ChordRule { intervals: &[0, 3, 7, 10], quality: "m7", formula: "1 - b3 - 5 - b7", chord_type: "Menor Séptima" },
    ChordRule { intervals: &[0, 5, 7], quality: "sus4", formula: "1 - 4 - 5", chord_type: "Suspendido 4" },
    ChordRule { intervals: &[0, 2, 7], quality: "sus2", formula: "1 - 2 - 5", chord_type: "Suspendido 2" },
    ChordRule { intervals: &[0, 3, 6], quality: "dim", formula: "1 - b3 - b5", chord_type: "Disminuido" },
    ChordRule { intervals: &[0, 4, 8], quality: "aug", formula: "1 - 3 - #5", chord_type: "Aumentado" },
    ChordRule { intervals: &[0, 4, 7, 9], quality: "6", formula: "1 - 3 - 5 - 6", chord_type: "Sexta Mayor" },
    ChordRule { intervals: &[0, 3, 7, 9], quality: "m6", formula: "1 - b3 - 5 - 6", chord_type: "Sexta Menor" },
    ChordRule { intervals: &[0, 2, 4, 7], quality: "add9", formula: "1 - 2 - 3 - 5", chord_type: "Novena Agregada" },
];

/// Extrae las clases de altura (pitch classes 0..11) únicas y ordenadas a partir de notas MIDI.
///
/// # Tripla de Hoare:
/// - {P}: `notes` es un slice válido de enteros `u8`.
/// - {Q}: El vector resultante tiene elementos únicos en `[0, 11]` ordenados ascendentemente.
pub fn extract_pitch_classes(notes: &[u8]) -> Vec<u8> {
    let mut pitch_classes: Vec<u8> = notes.iter().map(|&n| n % 12).collect();
    pitch_classes.sort_unstable();
    pitch_classes.dedup();
    pitch_classes
}

/// Obtiene el nombre canónico en notación latina para una clase de altura [0, 11].
pub fn note_name(pitch_class: u8) -> &'static str {
    NOTE_NAMES[(pitch_class % 12) as usize]
}

/// Detecta el acorde a partir de una lista de notas MIDI.
///
/// # Tripla de Hoare:
/// - {P}: `notes.len() >= 2`
/// - {Q}: Retorna `Some(DetectedChord)` donde `name` y `root` corresponden a la estructura
///        armónica identificada, o un clúster personalizado si no coincide con una plantilla estándar.
/// - {P_alt}: `notes.len() < 2`
/// - {Q_alt}: Retorna `None`.
pub fn detect_chord_from_notes(notes: &[u8]) -> Option<DetectedChord> {
    if notes.len() < 2 {
        return None;
    }

    let pitch_classes = extract_pitch_classes(notes);
    if pitch_classes.is_empty() {
        return None;
    }

    let bass_midi = notes.iter().min().copied().unwrap_or(0);
    let bass_name = note_name(bass_midi % 12).to_string();

    // Evaluar cada tónica candidata
    for &root_pc in &pitch_classes {
        let mut intervals: Vec<u8> = pitch_classes
            .iter()
            .map(|&pc| (pc + 12 - root_pc) % 12)
            .collect();
        intervals.sort_unstable();

        let root_name = note_name(root_pc);

        // Búsqueda en reglas declarativas (OCP / Strategy Pattern)
        if let Some(rule) = CHORD_RULES.iter().find(|r| r.intervals == intervals.as_slice()) {
            let chord_name = if rule.quality == "Mayor" {
                root_name.to_string()
            } else {
                format!("{}{}", root_name, rule.quality)
            };

            let inversion = if bass_name == root_name {
                "Estado Fundamental".to_string()
            } else {
                format!("Inversión con bajo en {}", bass_name)
            };

            return Some(DetectedChord {
                name: chord_name,
                root: root_name.to_string(),
                bass: bass_name,
                formula: rule.formula.to_string(),
                chord_type: rule.chord_type.to_string(),
                inversion,
            });
        }
    }

    // Acorde no clasificado en plantillas estándar (Clúster armónico)
    let notes_summary = pitch_classes
        .iter()
        .map(|&p| note_name(p))
        .collect::<Vec<_>>()
        .join(" · ");

    Some(DetectedChord {
        name: format!("Notas: {}", notes_summary),
        root: note_name(pitch_classes[0]).to_string(),
        bass: bass_name,
        formula: "Complejo".to_string(),
        chord_type: "Clúster / Personalizado".to_string(),
        inversion: "-".to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_major_triad() {
        // C Mayor: C (60), E (64), G (67)
        let chord = detect_chord_from_notes(&[60, 64, 67]).expect("Debe detectar C Mayor");
        assert_eq!(chord.name, "Do");
        assert_eq!(chord.root, "Do");
        assert_eq!(chord.bass, "Do");
        assert_eq!(chord.chord_type, "Tríada Mayor");
        assert_eq!(chord.inversion, "Estado Fundamental");
    }

    #[test]
    fn test_detect_minor_triad_inversion() {
        // A Menor primera inversión: C (60), E (64), A (69) -> Bajo en C
        let chord = detect_chord_from_notes(&[60, 64, 69]).expect("Debe detectar La Menor");
        assert_eq!(chord.name, "LaMenor");
        assert_eq!(chord.root, "La");
        assert_eq!(chord.bass, "Do");
        assert_eq!(chord.inversion, "Inversión con bajo en Do");
    }

    #[test]
    fn test_hoare_precondition_less_than_two_notes() {
        assert_eq!(detect_chord_from_notes(&[]), None);
        assert_eq!(detect_chord_from_notes(&[60]), None);
    }
}
