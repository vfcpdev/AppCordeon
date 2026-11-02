pub fn detect_bpm(channel_data: &[f32], sample_rate: f32) -> i32 {
    let sub_rate = 200usize;
    let hop = (sample_rate as usize) / sub_rate;
    if hop == 0 {
        return 120;
    }

    let num_sub_samples = channel_data.len() / hop;
    if num_sub_samples < 50 {
        return 120;
    }

    let mut energy = Vec::with_capacity(num_sub_samples);
    for i in 0..num_sub_samples {
        let start = i * hop;
        let mut sum_sq = 0.0f32;
        for j in 0..hop {
            let s = channel_data[start + j];
            sum_sq += s * s;
        }
        energy.push(sum_sq.sqrt());
    }

    let mut onset = Vec::with_capacity(num_sub_samples);
    onset.push(0.0);
    for i in 1..num_sub_samples {
        let diff = energy[i] - energy[i - 1];
        onset.push(if diff > 0.0 { diff } else { 0.0 });
    }

    let min_bpm = 60usize;
    let max_bpm = 200usize;
    let min_lag = (sub_rate * 60) / max_bpm;
    let max_lag = (sub_rate * 60) / min_bpm;

    let mut best_corr = 0.0f32;
    let mut best_lag = min_lag;

    // {I}: onset.len() == num_sub_samples; todo acceso onset[i + lag] debe
    // cumplir i + lag < num_sub_samples. Se acota el rango de búsqueda para
    // que sea imposible el out-of-bounds (fuente de un Access Violation
    // nativo que mata el proceso host — crash 0xC0000005 detectado vía FFI).
    let search_len = num_sub_samples.saturating_sub(max_lag);
    if search_len == 0 {
        return 120;
    }
    let max_search_lag = max_lag.min(num_sub_samples.saturating_sub(1));

    for lag in min_lag..=max_search_lag {
        let mut corr = 0.0f32;
        let reach = search_len.min(num_sub_samples - lag);
        for i in 0..reach {
            corr += onset[i] * onset[i + lag];
        }
        if corr > best_corr {
            best_corr = corr;
            best_lag = lag;
        }
    }

    let raw_bpm = ((sub_rate * 60) as f32) / (best_lag as f32);
    let mut final_bpm = raw_bpm.round() as i32;
    if final_bpm < 70 {
        final_bpm *= 2;
    } else if final_bpm > 180 {
        final_bpm /= 2;
    }
    final_bpm.clamp(60, 200)
}
