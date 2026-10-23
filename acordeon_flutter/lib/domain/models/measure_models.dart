/// Modelos de dominio de la cuadrícula de compases y del detector de acordes.
class MeasureBeat {
  final int barIndex;
  final int beatIndex;
  final String chord;
  final String timeText;
  final bool isContinue;

  const MeasureBeat({
    required this.barIndex,
    required this.beatIndex,
    required this.chord,
    required this.timeText,
    this.isContinue = false,
  });

  MeasureBeat copyWith({
    String? chord,
    String? timeText,
    bool? isContinue,
  }) {
    return MeasureBeat(
      barIndex: barIndex,
      beatIndex: beatIndex,
      chord: chord ?? this.chord,
      timeText: timeText ?? this.timeText,
      isContinue: isContinue ?? this.isContinue,
    );
  }
}

class MeasureRow {
  final int barNumber;
  final List<MeasureBeat> beats;

  const MeasureRow({
    required this.barNumber,
    required this.beats,
  });
}

class DetectedChordModel {
  final String name;
  final String root;
  final String bass;
  final String formula;
  final String type;
  final String inversion;
  final List<String> alternatives;

  const DetectedChordModel({
    required this.name,
    required this.root,
    required this.bass,
    required this.formula,
    required this.type,
    required this.inversion,
    this.alternatives = const [],
  });
}
