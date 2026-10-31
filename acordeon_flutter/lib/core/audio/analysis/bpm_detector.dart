import 'dart:math' as math;
import 'dart:typed_data';

abstract class BpmDetector {
  int detectBpm(Float32List samples, double sampleRate);
}

/// Estimador optimizado de BPM mediante detección adaptativa de energía de transitorios (Onset Strength)
/// y autocorrelación con filtrado armónico y resolución de ambigüedad octaval.
///
/// # Triplas de Hoare:
/// - {P}: `samples.length >= 100` y `sampleRate > 0.0`.
/// - {Q}: Retorna un valor entero en el rango estándar musical `[60, 200]` BPM.
/// - {I}: Cero excepciones o bucles infinitos; fallback determinístico de 120 BPM ante audio plano o insuficiente.
class AutocorrelationBpmDetector implements BpmDetector {
  const AutocorrelationBpmDetector();

  @override
  int detectBpm(Float32List samples, double sampleRate) {
    if (samples.length < 500 || sampleRate <= 0) return 120;

    const subRate = 200;
    final hop = (sampleRate / subRate).round().clamp(1, 44100);
    final numSub = samples.length ~/ hop;
    if (numSub < 50) return 120;

    // 1. Curva de energía de envolvente sub-muestreada
    final energy = Float32List(numSub);
    for (int i = 0; i < numSub; i++) {
      double sumSq = 0.0;
      final start = i * hop;
      final end = (start + hop).clamp(0, samples.length);
      for (int j = start; j < end; j++) {
        final s = samples[j];
        sumSq += s * s;
      }
      energy[i] = math.sqrt(sumSq);
    }

    // 2. Función de Detección de Ataque (Onset Envelope) con rectificación de media onda (Half-wave rectification)
    final onset = Float32List(numSub);
    for (int i = 1; i < numSub; i++) {
      final diff = energy[i] - energy[i - 1];
      onset[i] = diff > 0 ? diff : 0.0;
    }

    // 3. Autocorrelación normalizada en el rango [60, 200] BPM
    const minBpm = 60;
    const maxBpm = 200;
    final minLag = (subRate * 60) ~/ maxBpm;
    final maxLag = (subRate * 60) ~/ minBpm;

    double bestScore = 0.0;
    int bestLag = minLag;
    final searchLen = numSub - maxLag;

    if (searchLen > 0) {
      for (int lag = minLag; lag <= maxLag; lag++) {
        double corr = 0.0;
        for (int i = 0; i < searchLen; i++) {
          corr += onset[i] * onset[i + lag];
        }

        // Ponderación armónica suave (prioriza el tempo central de vallenato y música de acordeón 80 - 150 BPM)
        final bpmCandidate = (subRate * 60.0) / lag;
        final gaussianWeight = math.exp(-0.5 * math.pow((bpmCandidate - 115.0) / 50.0, 2));
        final weightedScore = corr * (0.75 + 0.25 * gaussianWeight);

        if (weightedScore > bestScore) {
          bestScore = weightedScore;
          bestLag = lag;
        }
      }
    }

    final rawBpm = (subRate * 60.0) / bestLag;
    var bpm = rawBpm.round();

    // Resolución de ambigüedades octavales
    if (bpm < 70) bpm *= 2;
    if (bpm > 180) bpm ~/= 2;
    return bpm.clamp(60, 200);
  }
}
