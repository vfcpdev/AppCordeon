class BassRhythmHit {
  final double onsetQuarterBeats;
  final double durationQuarterBeats;
  final int buttonIndex;

  const BassRhythmHit({
    required this.onsetQuarterBeats,
    required this.durationQuarterBeats,
    required this.buttonIndex,
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

  int get beatsPerMeasureInQuarterNotes =>
      (beatsPerMeasure * 4 / beatType).round().clamp(1, 32);
}

class BassRhythmImportSummary {
  final List<BassRhythmPattern> patterns;
  final int recoveredMalformedEvents;

  BassRhythmImportSummary({
    required List<BassRhythmPattern> patterns,
    required this.recoveredMalformedEvents,
  }) : patterns = List.unmodifiable(patterns);
}
