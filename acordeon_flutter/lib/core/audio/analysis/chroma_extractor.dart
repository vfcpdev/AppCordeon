import 'dart:math' as math;
import 'dart:typed_data';

class ChromaBinInfo {
  final int pitchClass;
  final double weight;
  final bool isBass;

  const ChromaBinInfo({
    required this.pitchClass,
    required this.weight,
    required this.isBass,
  });
}

/// Extractor de cromagrama de doble banda (Bajos 45-260Hz y Armonía 260-2400Hz).
class ChromaExtractor {
  const ChromaExtractor();

  List<ChromaBinInfo?> buildFilterbank(int fftSize, double sampleRate) {
    final halfSize = fftSize ~/ 2;
    final binHz = sampleRate / fftSize;
    const minFreq = 45.0;
    const maxFreq = 2400.0;
    const bassCutoff = 260.0;

    final bins = List<ChromaBinInfo?>.filled(halfSize, null);
    for (int k = 1; k < halfSize; k++) {
      final freq = k * binHz;
      if (freq >= minFreq && freq <= maxFreq) {
        final midi = 12.0 * (math.log(freq / 440.0) / math.ln2) + 69.0;
        final roundedMidi = midi.round();
        final pitchClass = ((roundedMidi % 12) + 12) % 12;
        final deviation = (midi - roundedMidi).abs();
        final weight = math.exp(-0.5 * math.pow(deviation / 0.32, 2));

        bins[k] = ChromaBinInfo(
          pitchClass: pitchClass,
          weight: weight,
          isBass: freq < bassCutoff,
        );
      }
    }
    return bins;
  }

  void processChromaFrame(
    Float32List real,
    Float32List imag,
    List<ChromaBinInfo?> filterbank,
    List<double> outBass,
    List<double> outHarm,
    List<double> outCombined,
  ) {
    for (int k = 1; k < filterbank.length; k++) {
      final info = filterbank[k];
      if (info != null) {
        final mag = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
        final weighted = mag * info.weight;
        if (info.isBass) {
          outBass[info.pitchClass] += weighted;
        } else {
          outHarm[info.pitchClass] += weighted;
        }
      }
    }

    double normB = 0.0;
    double normH = 0.0;
    for (int p = 0; p < 12; p++) {
      normB += outBass[p] * outBass[p];
      normH += outHarm[p] * outHarm[p];
    }
    normB = math.max(math.sqrt(normB), 1e-6);
    normH = math.max(math.sqrt(normH), 1e-6);

    for (int p = 0; p < 12; p++) {
      outBass[p] /= normB;
      outHarm[p] /= normH;
      outCombined[p] = (0.35 * outBass[p]) + (0.65 * outHarm[p]);
    }
  }
}
