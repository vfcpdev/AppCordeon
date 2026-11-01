enum BassRhythmButtonType { fundamental, chord }

class BassRhythmHit {
  final double onsetQuarterBeats;
  final double durationQuarterBeats;
  final int buttonIndex;
  final BassRhythmButtonType? buttonType;
  final int? fingerNumber;
  final bool isAccented;
  final bool isStaccato;

  const BassRhythmHit({
    required this.onsetQuarterBeats,
    required this.durationQuarterBeats,
    required this.buttonIndex,
    this.buttonType,
    this.fingerNumber,
    this.isAccented = false,
    this.isStaccato = false,
  });
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
