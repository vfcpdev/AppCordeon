pub fn detect_bpm(channel_data: &[f32], sample_rate: f32) -> i32 {
    if channel_data.is_empty() {
        return 120;
    }

    let frame_size = 1024usize;
    let num_frames = channel_data.len() / frame_size;
    if num_frames < 60 {
        return 120;
    }

    let mut energy = Vec::with_capacity(num_frames);
    for i in 0..num_frames {
        let offset = i * frame_size;
        let mut sum = 0.0f32;
        let mut j = 0;
        while j < frame_size {
            let val = channel_data[offset + j];
            sum += val * val;
            j += 4;
        }
        energy.push(sum.sqrt());
    }

    // Onset envelope (diferencia positiva de energía)
    let mut onsets = vec![0.0f32; num_frames];
    for i in 1..num_frames {
        let diff = energy[i] - energy[i - 1];
        if diff > 0.0 {
            onsets[i] = diff;
        }
    }

    // Normalizar onsets
    let max_onset = onsets.iter().cloned().fold(0.0f32, f32::max);
    if max_onset > 0.0 {
        for val in onsets.iter_mut() {
            *val /= max_onset;
        }
    }

    let frames_per_sec = sample_rate / (frame_size as f32);
    let min_bpm = 65.0f32;
    let max_bpm = 185.0f32;
    let min_lag = ((60.0 / max_bpm) * frames_per_sec).floor() as usize;
    let max_lag = ((60.0 / min_bpm) * frames_per_sec).ceil() as usize;

    let max_analysis_frames = (num_frames.saturating_sub(max_lag)).min((frames_per_sec * 90.0) as usize);
    if max_analysis_frames == 0 {
        return 120;
    }

    let mut best_lag = min_lag;
    let mut best_corr = -f32::INFINITY;

    for lag in min_lag..=max_lag {
        let mut corr = 0.0f32;
        for i in 0..max_analysis_frames {
            corr += onsets[i] * onsets[i + lag];
        }
        if corr > best_corr {
            best_corr = corr;
            best_lag = lag;
        }
    }

    if best_lag == 0 {
        return 120;
    }

    let mut bpm = ((60.0 * frames_per_sec) / (best_lag as f32)).round() as i32;

    // Ajuste armónico de octava rítmica al rango popular/vallenato (70 - 180 BPM)
    if bpm < 70 {
        bpm *= 2;
    }
    if bpm > 180 {
        bpm = (bpm as f32 / 2.0).round() as i32;
    }

    if bpm > 0 {
        bpm
    } else {
        120
    }
}
