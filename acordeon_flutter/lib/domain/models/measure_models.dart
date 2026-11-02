import '../../core/constants/enums.dart';

/// Modelos de dominio de la cuadrícula de compases y del detector de acordes.
class MeasureBeat {
  final int barIndex;
  final int beatIndex;
  final String? _chord;
  String get chord => _chord ?? '';
  final String? _timeText;
  String get timeText => _timeText ?? '';
  final double? startTime;
  final double? endTime;
  final bool isContinue;
  final BellowsMode bellows;

  const MeasureBeat({
    required this.barIndex,
    required this.beatIndex,
    String? chord,
    String? timeText,
    this.startTime,
    this.endTime,
    this.isContinue = false,
    this.bellows = BellowsMode.both,
  })  : _chord = chord ?? '',
        _timeText = timeText ?? '';

  MeasureBeat copyWith({
    String? chord,
    String? timeText,
    double? startTime,
    double? endTime,
    bool? isContinue,
    BellowsMode? bellows,
  }) {
    return MeasureBeat(
      barIndex: barIndex,
      beatIndex: beatIndex,
      chord: chord ?? this.chord,
      timeText: timeText ?? this.timeText,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isContinue: isContinue ?? this.isContinue,
      bellows: bellows ?? this.bellows,
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
  final String? _name;
  String get name => _name ?? '';

  final String? _root;
  String get root => _root ?? '';

  final String? _bass;
  String get bass => _bass ?? '';

  final String? _formula;
  String get formula => _formula ?? '';

  final String? _type;
  String get type => _type ?? '';

  final String? _inversion;
  String get inversion => _inversion ?? '';

  final List<String>? _alternatives;
  List<String> get alternatives => _alternatives ?? const [];

  final String? _chordSymbol;
  String get chordSymbol => _chordSymbol ?? '';

  final Set<int>? _pitchClasses;
  Set<int> get pitchClasses => _pitchClasses ?? const {};

  final int? _rootPitchClass;
  int get rootPitchClass => _rootPitchClass ?? 0;

  final int? _bassPitchClass;
  int get bassPitchClass => _bassPitchClass ?? 0;

  final List<int>? _notes;
  List<int> get notes => _notes ?? const [];

  const DetectedChordModel({
    String? name,
    String? root,
    String? bass,
    String? formula,
    String? type,
    String? inversion,
    List<String>? alternatives,
    String? chordSymbol,
    Set<int>? pitchClasses,
    int? rootPitchClass,
    int? bassPitchClass,
    List<int>? notes,
  })  : _name = name ?? '',
        _root = root ?? '',
        _bass = bass ?? '',
        _formula = formula ?? '',
        _type = type ?? '',
        _inversion = inversion ?? '',
        _alternatives = alternatives ?? const [],
        _chordSymbol = chordSymbol ?? '',
        _pitchClasses = pitchClasses ?? const {},
        _rootPitchClass = rootPitchClass ?? 0,
        _bassPitchClass = bassPitchClass ?? 0,
        _notes = notes ?? const [];

  /// Devuelve el nombre del acorde adaptado a la notación (Latina o Americana/Alemana).
  String formattedName(NotationMode notation) {
    if (notation == NotationMode.alemana) {
      if (chordSymbol.isNotEmpty) return chordSymbol;
      return name;
    }
    return name;
  }

  /// Devuelve el símbolo del acorde adaptado a la notación.
  String formattedSymbol(NotationMode notation) {
    if (chordSymbol.isEmpty) return root;
    return chordSymbol;
  }
}
