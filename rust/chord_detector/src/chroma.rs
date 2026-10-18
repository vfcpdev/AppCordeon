pub struct BinInfo {
    pub pitch_class: usize,
    pub weight: f32,
    pub is_bass: bool,
}

pub struct ChromaFilterbank {
    pub bins: Vec<Option<BinInfo>>,
}

impl ChromaFilterbank {
    pub fn new(fft_size: usize, sample_rate: f32) -> Self {
        let half_size = fft_size / 2;
        let bin_hz = sample_rate / (fft_size as f32);

        let min_freq = 45.0f32;  // ~F#1
        let max_freq = 2400.0f32; // ~D7
        let bass_cutoff = 260.0f32; // Separación de bajo (C4)

        let mut bins = Vec::with_capacity(half_size);
        bins.push(None); // Bin 0 (DC)

        for k in 1..half_size {
            let freq = (k as f32) * bin_hz;
            if freq >= min_freq && freq <= max_freq {
                let midi = 12.0 * (freq / 440.0).log2() + 69.0;
                let rounded_midi = midi.round() as i32;
                let pitch_class = (((rounded_midi % 12) + 12) % 12) as usize;

                let deviation = (midi - (rounded_midi as f32)).abs();
                // Campana gaussiana alrededor del semitono exacto
                let weight = (-0.5 * (deviation / 0.32).powi(2)).exp();

                bins.push(Some(BinInfo {
                    pitch_class,
                    weight,
                    is_bass: freq < bass_cutoff,
                }));
            } else {
                bins.push(None);
            }
        }

        Self { bins }
    }

    /// Procesa el espectro de magnitud de un frame y retorna el vector cromático normalizado (12 bins).
    pub fn process_frame(
        &self,
        real: &[f32],
        imag: &[f32],
        out_bass: &mut [f32; 12],
        out_harm: &mut [f32; 12],
        out_combined: &mut [f32; 12],
    ) {
        let half_size = self.bins.len();
        let mut frame_bass = [0.0f32; 12];
        let mut frame_harm = [0.0f32; 12];

        for k in 1..half_size {
            let r = real[k];
            let im = imag[k];
            let mag = (r * r + im * im).sqrt();

            // Compresión logarítmica de magnitud (spectral whitening)
            let log_mag = (1.0 + 75.0 * mag).ln();

            if let Some(ref bin) = self.bins[k] {
                let energy = log_mag * bin.weight;
                if bin.is_bass {
                    frame_bass[bin.pitch_class] += energy;
                } else {
                    frame_harm[bin.pitch_class] += energy;
                }
            }
        }

        // Normalización L2
        let norm_bass = (frame_bass.iter().map(|&v| v * v).sum::<f32>()).sqrt().max(1e-6);
        let norm_harm = (frame_harm.iter().map(|&v| v * v).sum::<f32>()).sqrt().max(1e-6);

        for p in 0..12 {
            out_bass[p] = frame_bass[p] / norm_bass;
            out_harm[p] = frame_harm[p] / norm_harm;
            // 35% peso de bajo + 65% armonía
            out_combined[p] = 0.35 * out_bass[p] + 0.65 * out_harm[p];
        }
    }
}
