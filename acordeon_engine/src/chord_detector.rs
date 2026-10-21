//! Motor de Reconocimiento Armónico Inteligente de Acordes en Rust

#[derive(Debug, Clone)]
pub struct DetectedChord {
    pub name: String,
    pub root: String,
    pub bass: String,
    pub formula: String,
    pub chord_type: String,
    pub inversion: String,
}

const NOTE_NAMES: [&str; 12] = [
    "Do", "Do#", "Re", "Mib", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "Sib", "Si",
];

pub fn detect_chord_from_notes(notes: &[u8]) -> Option<DetectedChord> {
    if notes.len() < 2 {
        return None;
    }

    let mut pitch_classes: Vec<u8> = notes.iter().map(|n| n % 12).collect();
    pitch_classes.sort_unstable();
    pitch_classes.dedup();

    let bass_midi = notes.iter().min().copied().unwrap_or(0);
    let bass_name = NOTE_NAMES[(bass_midi % 12) as usize].to_string();

    // Evaluar cada tónica posible
    for &root_pc in &pitch_classes {
        let mut intervals: Vec<u8> = pitch_classes
            .iter()
            .map(|&pc| (pc + 12 - root_pc) % 12)
            .collect();
        intervals.sort_unstable();

        let root_name = NOTE_NAMES[root_pc as usize];

        // Comparar con plantillas de intervalos armónicos
        let match_info = match intervals.as_slice() {
            [0, 4, 7] => Some(("Mayor", "1 - 3 - 5", "Tríada Mayor")),
            [0, 3, 7] => Some(("Menor", "1 - b3 - 5", "Tríada Menor")),
            [0, 4, 7, 10] => Some(("7", "1 - 3 - 5 - b7", "Séptima Dominante")),
            [0, 4, 7, 11] => Some(("Maj7", "1 - 3 - 5 - 7", "Mayor Séptima")),
            [0, 3, 7, 10] => Some(("m7", "1 - b3 - 5 - b7", "Menor Séptima")),
            [0, 5, 7] => Some(("sus4", "1 - 4 - 5", "Suspendido 4")),
            [0, 2, 7] => Some(("sus2", "1 - 2 - 5", "Suspendido 2")),
            [0, 3, 6] => Some(("dim", "1 - b3 - b5", "Disminuido")),
            [0, 4, 8] => Some(("aug", "1 - 3 - #5", "Aumentado")),
            [0, 4, 7, 9] => Some(("6", "1 - 3 - 5 - 6", "Sexta Mayor")),
            [0, 3, 7, 9] => Some(("m6", "1 - b3 - 5 - 6", "Sexta Menor")),
            [0, 2, 4, 7] => Some(("add9", "1 - 2 - 3 - 5", "Novena Agregada")),
            _ => None,
        };

        if let Some((quality, formula, c_type)) = match_info {
            let chord_name = if quality == "Mayor" {
                root_name.to_string()
            } else {
                format!("{}{}", root_name, quality)
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
                formula: formula.to_string(),
                chord_type: c_type.to_string(),
                inversion,
            });
        }
    }

    // Acorde no clasificado en plantillas estándar
    Some(DetectedChord {
        name: format!("Notas: {}", pitch_classes.iter().map(|&p| NOTE_NAMES[p as usize]).collect::<Vec<_>>().join(" · ")),
        root: NOTE_NAMES[(pitch_classes[0]) as usize].to_string(),
        bass: bass_name,
        formula: "Complejo".to_string(),
        chord_type: "Clúster / Personalizado".to_string(),
        inversion: "-".to_string(),
    })
}
