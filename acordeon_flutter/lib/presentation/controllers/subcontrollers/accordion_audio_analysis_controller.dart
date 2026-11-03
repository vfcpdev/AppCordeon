import '../../../core/audio/analysis/tuning_recommender.dart';
import '../../../domain/models/audio_analysis_models.dart';
import '../../../domain/models/tuning.dart';
import '../../../domain/theory/chord_catalog.dart';

/// Controlador de dominio especializado para el análisis de audio,
/// recálculo y corrección de tonalidad, BPM, transposición de línea temporal
/// y recomendaciones de afinación según el círculo armónico.
///
/// Aplica el principio de Responsabilidad Única (SRP) y forma parte
/// del desacoplamiento modular bajo SPEC-001.
class AccordionAudioAnalysisController {
  final TuningRecommender tuningRecommender;

  const AccordionAudioAnalysisController({
    this.tuningRecommender = const TuningRecommender(),
  });

  /// Recalcula el reporte de análisis al corregir manualmente la tonalidad y BPM.
  ///
  /// {P}: `rootMod >= 0`, `bpm > 0`, `mode` es 'Major'/'Mayor' o 'Minor'/'Menor'.
  /// {Q}: Devuelve un nuevo [AudioAnalysisReport] transpuesto e invariante.
  AudioAnalysisReport recalculateReportWithKeyAndBpm({
    required AudioAnalysisReport? existingReport,
    required int rootMod,
    required String mode,
    required int bpm,
    double totalAudioDuration = 0.0,
  }) {
    final clampedBpm = bpm.clamp(30, 300);
    final report = existingReport ?? AudioAnalysisReport.placeholder(clampedBpm);
    final effectiveDuration =
        totalAudioDuration > 0 ? totalAudioDuration : report.duration;

    final normRootMod = ((rootMod % 12) + 12) % 12;
    final semitoneOffset =
        (normRootMod - (report.mainKey.rootMod % 12) + 12) % 12;

    final keyNames = buildKeyNames(rootMod: normRootMod, mode: mode);
    final (recName, recOffset, recRow) = tuningRecommender.recommend(normRootMod);
    final preferFlats = TuningRegistry.usesFlats(recOffset);

    final updatedKey = report.mainKey.copyWith(
      rootMod: normRootMod,
      mode: mode,
      keyNameLat: keyNames.$1,
      keyNameAle: keyNames.$2,
      recommendedTuning: recName,
      recommendedOffset: recOffset,
      recommendedRow: recRow,
    );

    final updatedChords = transposeTimelineChords(
      chords: report.chords,
      semitoneOffset: semitoneOffset,
      newMode: mode,
      previousMode: report.mainKey.mode,
      preferFlats: preferFlats,
    );

    return report.copyWith(
      duration: effectiveDuration,
      bpm: clampedBpm,
      mainKey: updatedKey,
      chords: updatedChords,
    );
  }

  /// Construye los nombres de la tonalidad en notación latina y anglosajona.
  (String, String) buildKeyNames({required int rootMod, required String mode}) {
    const noteNamesLat = [
      'Do',
      'Do♯',
      'Re',
      'Mi♭',
      'Mi',
      'Fa',
      'Fa♯',
      'Sol',
      'Sol♯',
      'La',
      'Si♭',
      'Si',
    ];
    const noteNamesAle = [
      'C',
      'C#',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'Bb',
      'B',
    ];

    final isMajor = mode.toLowerCase() == 'major' || mode.toLowerCase() == 'mayor';
    final mod = ((rootMod % 12) + 12) % 12;
    return (
      '${noteNamesLat[mod]} ${isMajor ? 'Mayor' : 'Menor'}',
      '${noteNamesAle[mod]} ${isMajor ? 'Major' : 'Minor'}',
    );
  }

  /// Transpone los acordes del timeline al nuevo semitono. Si no hubo cambio de
  /// semitono ni de modo, devuelve la lista original sin copiar.
  List<DetectedChordSegment> transposeTimelineChords({
    required List<DetectedChordSegment> chords,
    required int semitoneOffset,
    required String newMode,
    required String previousMode,
    required bool preferFlats,
  }) {
    if (semitoneOffset == 0 && previousMode == newMode) return chords;
    return chords.map((ch) {
      final newSymbol = ChordCatalog.transposeChordSymbol(
        ch.chordSymbol,
        semitoneOffset,
        preferFlats: preferFlats,
      );
      final newName = ChordCatalog.transposeChordName(
        ch.chordName,
        semitoneOffset,
        preferFlats: preferFlats,
      );
      final newRootMod = ((ch.rootMod + semitoneOffset) % 12 + 12) % 12;
      return ch.copyWith(
        rootMod: newRootMod,
        chordSymbol: newSymbol,
        chordName: newName,
      );
    }).toList();
  }
}
