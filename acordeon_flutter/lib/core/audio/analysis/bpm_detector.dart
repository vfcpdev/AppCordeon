import 'dart:math' as math;
import 'dart:typed_data';

abstract class BpmDetector {
  int detectBpm(Float32List samples, double sampleRate);
}

/// Estimador de BPM por energía de ataque (onset detection) y autocorrelación.
class AutocorrelationBpmDetector implements BpmDetector {
  const AutocorrelationBpmDetector();

  @override
  int detectBpm(Float32List samples, double sampleRate) {
    const subRate = 200;
    final hop = (sampleRate / subRate).round();
    final numSub = samples.length ~/ hop;
    if (numSub < 50) return 120;

    final energy = Float32List(numSub);
    for (int i = 0; i < numSub; i++) {
      double sumSq = 0.0;
      final start = i * hop;
      for (int j = 0; j < hop && (start + j) < samples.length; j++) {
        final s = samples[start + j];
        sumSq += s * s;
      }
      energy[i] = math.sqrt(sumSq);
    }

    final onset = Float32List(numSub);
    for (int i = 1; i < numSub; i++) {
      final diff = energy[i] - energy[i - 1];
      onset[i] = diff > 0 ? diff : 0.0;
    }

    const minBpm = 60;
    const maxBpm = 200;
    final minLag = (subRate * 60) ~/ maxBpm;
    final maxLag = (subRate * 60) ~/ minBpm;

    double bestCorr = 0.0;
    int bestLag = minLag;
    final searchLen = numSub - maxLag;

    if (searchLen > 0) {
      for (int lag = minLag; lag <= maxLag; lag++) {
        double corr = 0.0;
        for (int i = 0; i < searchLen; i++) {
          corr += onset[i] * onset[i + lag];
        }
        if (corr > bestCorr) {
          bestCorr = corr;
          bestLag = lag;
        }
      }
    }

    final rawBpm = (subRate * 60) / bestLag;
    var bpm = rawBpm.round();
    if (bpm < 70) bpm *= 2;
    if (bpm > 180) bpm ~/= 2;
    return bpm.clamp(60, 200);
  }
}
