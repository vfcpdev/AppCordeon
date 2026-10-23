import 'dart:math' as math;
import 'dart:typed_data';

/// Algoritmo Radix-2 FFT in-place y generador de ventana Hann.
class FftProcessor {
  const FftProcessor();

  List<double> generateHannWindow(int size) {
    final w = List<double>.filled(size, 0.0);
    final n = (size - 1).toDouble();
    for (int i = 0; i < size; i++) {
      w[i] = 0.5 * (1.0 - math.cos((2 * math.pi * i) / n));
    }
    return w;
  }

  void fftRadix2(Float32List real, Float32List imag) {
    final n = real.length;
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
      int k = n >> 1;
      while (k <= j) {
        j -= k;
        k >>= 1;
      }
      j += k;
    }

    int len = 2;
    while (len <= n) {
      final half = len >> 1;
      final angle = -2.0 * math.pi / len;
      final wStepR = math.cos(angle);
      final wStepI = math.sin(angle);

      int i = 0;
      while (i < n) {
        double wr = 1.0;
        double wi = 0.0;

        for (int k = 0; k < half; k++) {
          final idxA = i + k;
          final idxB = i + k + half;

          final tr = wr * real[idxB] - wi * imag[idxB];
          final ti = wr * imag[idxB] + wi * real[idxB];

          real[idxB] = real[idxA] - tr;
          imag[idxB] = imag[idxA] - ti;
          real[idxA] += tr;
          imag[idxA] += ti;

          final nextWr = wr * wStepR - wi * wStepI;
          wi = wr * wStepI + wi * wStepR;
          wr = nextWr;
        }
        i += len;
      }
      len <<= 1;
    }
  }
}
