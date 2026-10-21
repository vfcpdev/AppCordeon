use std::f32::consts::PI;

/// Genera una ventana de Hann de tamaño `size`.
pub fn generate_hann_window(size: usize) -> Vec<f32> {
    let mut window = Vec::with_capacity(size);
    let n = (size - 1) as f32;
    for i in 0..size {
        let val = 0.5 * (1.0 - (2.0 * PI * (i as f32) / n).cos());
        window.push(val);
    }
    window
}

/// FFT in-place Cooley-Tukey Radix-2.
/// `real` e `imag` deben tener longitudes iguales y ser potencias de 2.
pub fn fft_radix2(real: &mut [f32], imag: &mut [f32]) {
    let n = real.len();
    assert_eq!(n, imag.len());
    assert!(n.is_power_of_two());

    // Inversión de bits (Bit-reversal permutation)
    let mut j = 0;
    for i in 0..n - 1 {
        if i < j {
            real.swap(i, j);
            imag.swap(i, j);
        }
        let mut k = n >> 1;
        while k <= j {
            j -= k;
            k >>= 1;
        }
        j += k;
    }

    // Etapas del mariposa FFT
    let mut len = 2;
    while len <= n {
        let half = len >> 1;
        let angle = -2.0 * PI / (len as f32);
        let w_step_r = angle.cos();
        let w_step_i = angle.sin();

        let mut i = 0;
        while i < n {
            let mut wr = 1.0f32;
            let mut wi = 0.0f32;

            for k in 0..half {
                let idx_a = i + k;
                let idx_b = i + k + half;

                let tr = wr * real[idx_b] - wi * imag[idx_b];
                let ti = wr * imag[idx_b] + wi * real[idx_b];

                real[idx_b] = real[idx_a] - tr;
                imag[idx_b] = imag[idx_a] - ti;
                real[idx_a] += tr;
                imag[idx_a] += ti;

                let next_wr = wr * w_step_r - wi * w_step_i;
                wi = wr * w_step_i + wi * w_step_r;
                wr = next_wr;
            }
            i += len;
        }
        len <<= 1;
    }
}
