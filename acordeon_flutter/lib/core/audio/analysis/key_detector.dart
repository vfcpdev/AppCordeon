import 'dart:math' as math;
import '../../../domain/models/audio_analysis_models.dart';
import 'tuning_recommender.dart';

abstract class KeyDetector {
  KeyDetectionResult detectKey(List<double> globalChroma);
}

/// Detector de tonalidad mediante correlación dual con perfiles Krumhansl-Kessler y Temperley.
class KrumhanslTemperleyKeyDetector implements KeyDetector {
  static const List<double> krumhanslMajor = [
    6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
  ];
  static const List<double> krumhanslMinor = [
    6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
  ];

  static const List<double> temperleyMajor = [
    5.0, 2.0, 3.5, 2.0, 4.5, 4.0, 2.0, 4.5, 2.0, 3.5, 1.5, 4.0
  ];
  static const List<double> temperleyMinor = [
    5.0, 2.0, 3.5, 4.5, 2.0, 4.0, 2.0, 4.5, 3.5, 2.0, 1.5, 4.0
  ];

  static const List<String> noteNamesLat = [
    'Do', 'Do♯', 'Re', 'Mi♭', 'Mi', 'Fa', 'Fa♯', 'Sol', 'Sol♯', 'La', 'Si♭', 'Si'
  ];
  static const List<String> noteNamesAle = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'
  ];

  final TuningRecommender tuningRecommender;

  const KrumhanslTemperleyKeyDetector({
    this.tuningRecommender = const TuningRecommender(),
  });

  @override
  KeyDetectionResult detectKey(List<double> globalChroma) {
    double bestScore = -double.infinity;
    int bestRoot = 0;
    String bestMode = 'major';

    for (int r = 0; r < 12; r++) {
      final rotated = List<double>.filled(12, 0.0);
      for (int i = 0; i < 12; i++) {
        rotated[i] = globalChroma[(i + r) % 12];
      }

      final scoreKrumMaj = _pearsonCorrelation(rotated, krumhanslMajor);
      final scoreKrumMin = _pearsonCorrelation(rotated, krumhanslMinor);
      final scoreTempMaj = _pearsonCorrelation(rotated, temperleyMajor);
      final scoreTempMin = _pearsonCorrelation(rotated, temperleyMinor);

      final combinedMaj = 0.55 * scoreKrumMaj + 0.45 * scoreTempMaj;
      final combinedMin = 0.55 * scoreKrumMin + 0.45 * scoreTempMin;

      final totalSum = rotated.fold(0.0, (a, b) => a + b);
      final sumSafe = math.max(totalSum, 1e-6);
      final tonicBonus = (rotated[0] + rotated[4] + rotated[7]) / sumSafe;
      final minorBonus = (rotated[0] + rotated[3] + rotated[7]) / sumSafe;

      final totalMaj = combinedMaj + (tonicBonus * 0.15);
      final totalMin = combinedMin + (minorBonus * 0.15);

      if (totalMaj > bestScore) {
        bestScore = totalMaj;
        bestRoot = r;
        bestMode = 'major';
      }
      if (totalMin > bestScore) {
        bestScore = totalMin;
        bestRoot = r;
        bestMode = 'minor';
      }
    }

    final rootLat = noteNamesLat[bestRoot];
    final rootAle = noteNamesAle[bestRoot];
    final modeLat = bestMode == 'major' ? 'Mayor' : 'Menor';
    final modeAle = bestMode == 'major' ? 'Major' : 'Minor';

    final rec = tuningRecommender.recommend(bestRoot);

    return KeyDetectionResult(
      rootMod: bestRoot,
      mode: bestMode,
      keyNameLat: '$rootLat $modeLat',
      keyNameAle: '$rootAle $modeAle',
      recommendedTuning: rec.$1,
      recommendedOffset: rec.$2,
      recommendedRow: rec.$3,
      correlation: double.parse(math.max(0.65, bestScore).toStringAsFixed(2)),
    );
  }

  double _pearsonCorrelation(List<double> x, List<double> y) {
    final meanX = x.fold(0.0, (a, b) => a + b) / 12.0;
    final meanY = y.fold(0.0, (a, b) => a + b) / 12.0;

    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;

    for (int i = 0; i < 12; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }

    final den = math.sqrt(denX * denY);
    if (den < 1e-9) return 0.0;
    return num / den;
  }
}
