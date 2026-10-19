use crate::types::{MelodyNote, MelodyReport};

fn get_tag_content(xml: &str, tag: &str) -> Option<String> {
    let open_tag = format!("<{}>", tag);
    let close_tag = format!("</{}>", tag);
    if let Some(start_pos) = xml.find(&open_tag) {
        let content_start = start_pos + open_tag.len();
        if let Some(end_pos) = xml[content_start..].find(&close_tag) {
            return Some(xml[content_start..content_start + end_pos].trim().to_string());
        }
    }
    None
}

fn extract_attribute(xml: &str, attr: &str) -> Option<String> {
    let pattern = format!("{}=\"", attr);
    if let Some(pos) = xml.find(&pattern) {
        let val_start = pos + pattern.len();
        if let Some(end) = xml[val_start..].find('\"') {
            return Some(xml[val_start..val_start + end].trim().to_string());
        }
    }
    None
}

pub fn parse_musicxml_melody(xml: &str) -> MelodyReport {
    // 1. Título
    let title = get_tag_content(xml, "work-title")
        .or_else(|| get_tag_content(xml, "movement-title"))
        .unwrap_or_else(|| "Melodía MusicXML".to_string());

    // 2. Tempo BPM
    let bpm = if let Some(tempo_str) = extract_attribute(xml, "tempo") {
        tempo_str.parse::<f32>().unwrap_or(70.0)
    } else if let Some(pm_str) = get_tag_content(xml, "per-minute") {
        pm_str.parse::<f32>().unwrap_or(70.0)
    } else {
        70.0
    };

    // 3. Métrica
    let beats = get_tag_content(xml, "beats").unwrap_or_else(|| "4".to_string());
    let beat_type = get_tag_content(xml, "beat-type").unwrap_or_else(|| "4".to_string());
    let meter = format!("{}/{}", beats, beat_type);

    // 4. Compases y Notas
    let mut notes: Vec<MelodyNote> = Vec::new();
    let mut note_id = 1;
    let mut total_bars = 0;

    // Buscar cada <measure ...> ... </measure>
    let mut cursor = 0;
    while let Some(m_start) = xml[cursor..].find("<measure") {
        let abs_m_start = cursor + m_start;
        let m_end = match xml[abs_m_start..].find("</measure>") {
            Some(end) => abs_m_start + end + "</measure>".len(),
            None => break,
        };

        let measure_slice = &xml[abs_m_start..m_end];
        total_bars += 1;
        let bar_num = extract_attribute(measure_slice, "number")
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(total_bars as u32);

        // Parsear notas dentro del compás
        let mut note_cursor = 0;
        let mut current_beat = 1.0;

        while let Some(n_start) = measure_slice[note_cursor..].find("<note") {
            let abs_n_start = note_cursor + n_start;
            let n_end = match measure_slice[abs_n_start..].find("</note>") {
                Some(end) => abs_n_start + end + "</note>".len(),
                None => break,
            };

            let note_slice = &measure_slice[abs_n_start..n_end];
            let is_rest = note_slice.contains("<rest");
            let is_chord_note = note_slice.contains("<chord/>") || note_slice.contains("<chord />");

            let note_type = get_tag_content(note_slice, "type").unwrap_or_else(|| "quarter".to_string());
            let duration_beats = match note_type.as_str() {
                "whole" => 4.0,
                "half" => 2.0,
                "quarter" => 1.0,
                "eighth" => 0.5,
                "16th" => 0.25,
                "32nd" => 0.125,
                _ => 1.0,
            };

            let lyric = get_tag_content(note_slice, "text").unwrap_or_default();

            if is_rest {
                notes.push(MelodyNote {
                    id: note_id,
                    bar: bar_num,
                    beat: current_beat,
                    step: "R".to_string(),
                    alter: 0,
                    octave: 0,
                    pitch_name: "Silencio".to_string(),
                    scientific: "Rest".to_string(),
                    midi: 0,
                    duration_beats,
                    note_type,
                    is_rest: true,
                    is_chord_note,
                    lyric,
                });
            } else if let Some(step) = get_tag_content(note_slice, "step") {
                let alter = get_tag_content(note_slice, "alter")
                    .and_then(|a| a.parse::<i32>().ok())
                    .unwrap_or(0);
                let octave = get_tag_content(note_slice, "octave")
                    .and_then(|o| o.parse::<i32>().ok())
                    .unwrap_or(4);

                let base_semitone = match step.as_str() {
                    "C" => 0,
                    "D" => 2,
                    "E" => 4,
                    "F" => 5,
                    "G" => 7,
                    "A" => 9,
                    "B" => 11,
                    _ => 0,
                };

                let midi_val = ((octave + 1) * 12 + base_semitone + alter).clamp(0, 127) as u8;

                let spanish_step = match step.as_str() {
                    "C" => "Do",
                    "D" => "Re",
                    "E" => "Mi",
                    "F" => "Fa",
                    "G" => "Sol",
                    "A" => "La",
                    "B" => "Si",
                    _ => "Do",
                };

                let alter_symbol_es = match alter {
                    1 => "♯",
                    -1 => "♭",
                    _ => "",
                };

                let alter_symbol_sci = match alter {
                    1 => "#",
                    -1 => "b",
                    _ => "",
                };

                let pitch_name = format!("{}{}{}", spanish_step, alter_symbol_es, octave);
                let scientific = format!("{}{}{}", step, alter_symbol_sci, octave);

                notes.push(MelodyNote {
                    id: note_id,
                    bar: bar_num,
                    beat: current_beat,
                    step,
                    alter,
                    octave,
                    pitch_name,
                    scientific,
                    midi: midi_val,
                    duration_beats,
                    note_type,
                    is_rest: false,
                    is_chord_note,
                    lyric,
                });
            }

            if !is_chord_note {
                current_beat += duration_beats;
            }
            note_id += 1;
            note_cursor = n_end;
        }

        cursor = m_end;
    }

    let total_notes = notes.len();

    MelodyReport {
        title,
        bpm,
        meter,
        total_bars,
        total_notes,
        notes,
        engine: "Rust (WebAssembly)".to_string(),
    }
}
