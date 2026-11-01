enum BassRhythmButtonType { fundamental, chord }

/// Golpe de un patrón rítmico de bajos.
///
/// Cada golpe se ejecuta con una pareja de botones de la misma nota: el bajo
/// (dedo índice, [fingerNumber]) y su acorde (dedo medio,
/// [pairedFingerNumber]). [buttonIndex] y [pairedButtonIndex] son los índices
/// físicos de esa pareja en el panel de bajos.
class BassRhythmHit {
  final double onsetQuarterBeats;
  final double durationQuarterBeats;
  final int buttonIndex;
  final int? pairedButtonIndex;
  final BassRhythmButtonType? buttonType;
  final int? fingerNumber;
  final int? pairedFingerNumber;
  final bool isAccented;
  final bool isStaccato;

  const BassRhythmHit({
    required this.onsetQuarterBeats,
    required this.durationQuarterBeats,
    required this.buttonIndex,
    this.pairedButtonIndex,
    this.buttonType,
    this.fingerNumber,
    this.pairedFingerNumber,
    this.isAccented = false,
    this.isStaccato = false,
  });

  /// Índices de los botones que se resaltan al ejecutar el golpe.
  List<int> get buttonIndexes => [
    buttonIndex,
    if (pairedButtonIndex != null && pairedButtonIndex != buttonIndex)
      pairedButtonIndex!,
  ];

  /// Dedo que corresponde a un botón iluminado por este golpe.
  int? fingerNumberFor(int buttonIndex) {
    if (pairedButtonIndex == buttonIndex) return pairedFingerNumber;
    if (this.buttonIndex == buttonIndex) return fingerNumber;
    return null;
  }
}

class BassRhythmPattern {
  final String id;
  final String name;
  final String partName;
  final int measureNumber;
  final int beatsPerMeasure;
  final int beatType;
  final double durationQuarterBeats;
  final double? quarterNotesPerMinute;
  final List<BassRhythmHit> hits;

  BassRhythmPattern({
    required this.id,
    required this.name,
    required this.partName,
    required this.measureNumber,
    required this.beatsPerMeasure,
    required this.beatType,
    required this.durationQuarterBeats,
    required this.quarterNotesPerMinute,
    required List<BassRhythmHit> hits,
  }) : hits = List.unmodifiable(hits);

  int get beatsPerMeasureInQuarterNotes {
    final quarterNotes = (beatsPerMeasure * 4 / beatType).round();
    if (quarterNotes < 1) return 1;
    if (quarterNotes > 32) return 32;
    return quarterNotes;
  }
}

class BassRhythmImportSummary {
  final List<BassRhythmPattern> patterns;
  final int recoveredMalformedEvents;

  BassRhythmImportSummary({
    required List<BassRhythmPattern> patterns,
    required this.recoveredMalformedEvents,
  }) : patterns = List.unmodifiable(patterns);
}
