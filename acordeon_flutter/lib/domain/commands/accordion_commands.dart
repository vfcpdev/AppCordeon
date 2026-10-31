import '../../core/constants/enums.dart';
import '../models/accordion_data.dart';
import '../models/measure_models.dart';
import '../theory/chord_detector_engine.dart';

/// Excepción lanzada cuando una precondición formal {P} no se satisface.
class PreconditionViolationException implements Exception {
  final String actionName;
  final String reason;

  const PreconditionViolationException(this.actionName, this.reason);

  @override
  String toString() => 'Violación de Precondición {P} en [$actionName]: $reason';
}

/// Contrato base para comandos ejecutables en el simulador (Command Pattern + SRP + Hoare Triples).
/// Soporta verificación formal de Precondición {P}, Ejecución {C} y Poscondición {Q}.
abstract class AccordionCommand<T> {
  String get commandName => runtimeType.toString();

  /// Comprueba si se satisfacen las precondiciones {P}. Devuelve true si es seguro ejecutar.
  bool canExecute() => true;

  /// Valida formalmente la precondición {P}. Lanza [PreconditionViolationException] si es inválida.
  void assertPreconditions() {}

  /// Ejecuta el comando {C}.
  T execute();
}

/// Comando para limpiar completamente el diapasón dejando 0 botones presionados o resaltados.
/// {P}: True.
/// {Q}: freeChordRoot == -1, activeButtons == {}, detectorSelectedButtons == [],
///      detectedChord == null, playingChordNotes == {}.
class ClearDiapasonCommand implements AccordionCommand<void> {
  @override
  String get commandName => 'ClearDiapasonCommand';

  final void Function({
    required int freeChordRoot,
    required bool isFreeChordFixed,
    required Set<String> activeButtons,
    required List<String> detectorSelectedButtons,
    required DetectedChordModel? detectedChord,
    required Set<int> playingChordNotes,
  }) stateUpdater;

  /// Callback opcional para cancelar notas de audio residuales y asegurar {Q}.
  final void Function()? onCancelAudioPlayback;

  const ClearDiapasonCommand(this.stateUpdater, {this.onCancelAudioPlayback});

  @override
  bool canExecute() => true;

  @override
  void assertPreconditions() {
    // P1: Siempre ejecutable
  }

  @override
  void execute() {
    assertPreconditions();
    onCancelAudioPlayback?.call();
    stateUpdater(
      freeChordRoot: -1,
      isFreeChordFixed: false,
      activeButtons: const {},
      detectorSelectedButtons: const [],
      detectedChord: null,
      playingChordNotes: const {},
    );
  }
}

/// Comando para asignar un acorde detectado a una celda de compás con fuelle óptimo.
/// {P}: chord != null, 0 <= barIndex, 0 <= beatIndex, trebleData no vacío.
/// {Q}: beat.chord == formattedSymbol, bellows in {push, pull}.
class AssignDetectedChordCommand implements AccordionCommand<bool> {
  @override
  String get commandName => 'AssignDetectedChordCommand';

  final DetectedChordModel? chord;
  final int barIndex;
  final int beatIndex;
  final NotationMode notation;
  final Map<String, List<TrebleButtonModel>> trebleData;
  final void Function(int bar, int beat, String chordSymbol) onUpdateBeat;
  final void Function(int bar, int beat, BellowsMode bellows) onSetBellows;

  const AssignDetectedChordCommand({
    required this.chord,
    required this.barIndex,
    required this.beatIndex,
    required this.notation,
    required this.trebleData,
    required this.onUpdateBeat,
    required this.onSetBellows,
  });

  @override
  bool canExecute() {
    return chord != null && barIndex >= 0 && beatIndex >= 0 && trebleData.isNotEmpty;
  }

  @override
  void assertPreconditions() {
    if (barIndex < 0 || beatIndex < 0) {
      throw PreconditionViolationException(
        commandName,
        'Índices de compás ($barIndex) o tiempo ($beatIndex) no pueden ser negativos.',
      );
    }
  }

  @override
  bool execute() {
    assertPreconditions();
    if (chord == null) return false;

    final symbol = chord!.formattedSymbol(notation);
    onUpdateBeat(barIndex, beatIndex, symbol);

    final availability = ChordDetectorEngine.evaluateDiapasonBellows(
      chordPitchClasses: chord!.pitchClasses,
      trebleData: trebleData,
    );

    if (availability.isCompletePush && !availability.isCompletePull) {
      onSetBellows(barIndex, beatIndex, BellowsMode.push);
    } else if (!availability.isCompletePush && availability.isCompletePull) {
      onSetBellows(barIndex, beatIndex, BellowsMode.pull);
    } else if (availability.isCompleteBoth) {
      onSetBellows(barIndex, beatIndex, BellowsMode.push);
    }

    return true;
  }
}

/// Resultado atómico de la ejecución de [ApplyMultiBeatChordCommand].
class MultiBeatCommandResult {
  final List<MeasureRow> updatedMeasures;
  final Set<int> markedBeats;
  final int appliedCount;

  const MultiBeatCommandResult({
    required this.updatedMeasures,
    required this.markedBeats,
    required this.appliedCount,
  });

  static const empty = MultiBeatCommandResult(
    updatedMeasures: [],
    markedBeats: {},
    appliedCount: 0,
  );
}

/// Comando para asignar un acorde en múltiples tiempos/compases mediante un patrón.
/// {P}: chord.isNotEmpty, pattern parseable a posiciones válidas, barNumber <= maxAllowedMeasures.
/// {Q}: cada posición en pattern contiene chord, markedBeats incluye todas las posiciones.
class ApplyMultiBeatChordCommand implements AccordionCommand<MultiBeatCommandResult> {
  @override
  String get commandName => 'ApplyMultiBeatChordCommand';

  static const int defaultMaxAllowedMeasures = 128;

  final String chord;
  final String pattern;
  final bool replaceExisting;
  final List<MeasureRow> currentMeasures;
  final int maxAllowedMeasures;

  const ApplyMultiBeatChordCommand({
    required this.chord,
    required this.pattern,
    required this.currentMeasures,
    this.replaceExisting = true,
    this.maxAllowedMeasures = defaultMaxAllowedMeasures,
  });

  @override
  bool canExecute() {
    if (chord.trim().isEmpty || pattern.trim().isEmpty) return false;
    final positions = parsePositions(pattern);
    return positions.isNotEmpty && positions.every((p) => p.bar <= maxAllowedMeasures);
  }

  @override
  void assertPreconditions() {
    final positions = parsePositions(pattern);
    for (final pos in positions) {
      if (pos.bar > maxAllowedMeasures) {
        throw PreconditionViolationException(
          commandName,
          'El compás ${pos.bar} excede la cota máxima permitida ($maxAllowedMeasures).',
        );
      }
      if (pos.bar < 1 || pos.beat < 1 || pos.beat > 4) {
        throw PreconditionViolationException(
          commandName,
          'Posición inválida (${pos.bar}.${pos.beat}). Rango válido: 1..$maxAllowedMeasures compás, 1..4 tiempo.',
        );
      }
    }
  }

  @override
  MultiBeatCommandResult execute() {
    final trimmedChord = chord.trim();
    if (trimmedChord.isEmpty) return MultiBeatCommandResult.empty;

    final positions = parsePositions(pattern);
    if (positions.isEmpty) return MultiBeatCommandResult.empty;

    assertPreconditions();

    var maxBar = currentMeasures.length;
    for (final pos in positions) {
      if (pos.bar > maxBar) {
        maxBar = pos.bar;
      }
    }

    // Expansión segura y acotada de compases
    final updatedMeasures = List<MeasureRow>.from(currentMeasures);
    while (updatedMeasures.length < maxBar) {
      final nextBar = updatedMeasures.length + 1;
      updatedMeasures.add(
        MeasureRow(
          barNumber: nextBar,
          beats: List.generate(4, (beatIdx) {
            final timeSec = ((nextBar - 1) * 4 + beatIdx) * 0.5;
            final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
            final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
            return MeasureBeat(
              barIndex: nextBar - 1,
              beatIndex: beatIdx,
              chord: '',
              timeText: '$mins:$secs',
            );
          }),
        ),
      );
    }

    // Limpieza de ocurrencias previas si replaceExisting está activo
    if (replaceExisting) {
      for (var m = 0; m < updatedMeasures.length; m++) {
        final row = updatedMeasures[m];
        var modified = false;
        final newBeats = List<MeasureBeat>.from(row.beats);
        for (var b = 0; b < newBeats.length; b++) {
          if (newBeats[b].chord.trim() == trimmedChord) {
            newBeats[b] = newBeats[b].copyWith(chord: '');
            modified = true;
          }
        }
        if (modified) {
          updatedMeasures[m] = MeasureRow(barNumber: row.barNumber, beats: newBeats);
        }
      }
    }

    // Asignación de acordes en las posiciones especificadas
    var appliedCount = 0;
    final newMarkedBeats = <int>{};
    for (final pos in positions) {
      final bIdx = pos.bar - 1;
      final tIdx = pos.beat - 1;
      if (bIdx >= 0 && bIdx < updatedMeasures.length) {
        final row = updatedMeasures[bIdx];
        if (tIdx >= 0 && tIdx < row.beats.length) {
          final beats = List<MeasureBeat>.from(row.beats);
          beats[tIdx] = beats[tIdx].copyWith(chord: trimmedChord);
          updatedMeasures[bIdx] = MeasureRow(barNumber: row.barNumber, beats: beats);
          newMarkedBeats.add(bIdx * 4 + tIdx);
          appliedCount++;
        }
      }
    }

    return MultiBeatCommandResult(
      updatedMeasures: updatedMeasures,
      markedBeats: newMarkedBeats,
      appliedCount: appliedCount,
    );
  }

  /// Parsea la cadena de texto de posiciones "Compas.Tiempo, ..." a tuplas numéricas.
  static List<({int bar, int beat})> parsePositions(String pattern) {
    final result = <({int bar, int beat})>[];
    if (pattern.trim().isEmpty) return result;

    final tokens = pattern.split(',');
    for (final rawToken in tokens) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      final parts = token.split(RegExp(r'[.:\-]'));
      if (parts.length >= 2) {
        final bar = int.tryParse(parts[0].trim());
        final beat = int.tryParse(parts[1].trim());
        if (bar != null && beat != null) {
          result.add((bar: bar, beat: beat));
        }
      }
    }
    return result;
  }
}

/// Resultado atómico de [ApplyYellowDecisionCommand].
class YellowDecisionResult {
  final List<MeasureRow> updatedMeasures;
  final Set<int> remainingYellowBeats;
  final int appliedCount;

  const YellowDecisionResult({
    required this.updatedMeasures,
    required this.remainingYellowBeats,
    required this.appliedCount,
  });
}

/// Comando para resolver y aplicar una decisión de fuelle sobre acordes ambiguos marcados en amarillo.
/// {P}: targetKeys no vacío, mode in {push, pull}.
/// {Q}: cada beat en targetKeys tiene fuelle == mode, remainingYellowBeats == yellowDecisionBeats \ targetKeys.
class ApplyYellowDecisionCommand implements AccordionCommand<YellowDecisionResult> {
  @override
  String get commandName => 'ApplyYellowDecisionCommand';

  final List<MeasureRow> measures;
  final Set<int> yellowDecisionBeats;
  final Set<int>? specificTargets;
  final BellowsMode mode;

  const ApplyYellowDecisionCommand({
    required this.measures,
    required this.yellowDecisionBeats,
    required this.mode,
    this.specificTargets,
  });

  @override
  bool canExecute() {
    final targets = specificTargets ?? yellowDecisionBeats;
    return targets.isNotEmpty;
  }

  @override
  void assertPreconditions() {
    final targets = specificTargets ?? yellowDecisionBeats;
    if (targets.isEmpty) {
      throw PreconditionViolationException(
        commandName,
        'No hay tiempos seleccionados para aplicar la decisión de fuelle.',
      );
    }
  }

  @override
  YellowDecisionResult execute() {
    assertPreconditions();
    final targets = specificTargets ?? yellowDecisionBeats;

    var applied = 0;
    final updatedMeasures = measures.map((measure) {
      final updatedBeats = measure.beats.map((beat) {
        final key = beat.barIndex * 4 + beat.beatIndex;
        if (targets.contains(key)) {
          applied++;
          return beat.copyWith(bellows: mode);
        }
        return beat;
      }).toList();
      return MeasureRow(barNumber: measure.barNumber, beats: updatedBeats);
    }).toList();

    final remainingYellow = Set<int>.from(yellowDecisionBeats)..removeAll(targets);

    return YellowDecisionResult(
      updatedMeasures: updatedMeasures,
      remainingYellowBeats: remainingYellow,
      appliedCount: applied,
    );
  }
}

/// Parámetros armónicos transferidos desde un acorde detectado.
class TransferredChordParams {
  final int root;
  final String type;
  final String fourth;
  final String bass;
  final bool isFixed;

  const TransferredChordParams({
    required this.root,
    required this.type,
    required this.fourth,
    required this.bass,
    this.isFixed = true,
  });
}

/// Comando para transferir de manera fuertemente tipada y completa las propiedades armónicas
/// de un acorde detectado al constructor libre.
/// {P}: chord != null.
/// {Q}: TransferredChordParams con root, type, fourth y bass coherentes con la estructura del acorde.
class TransferDetectedChordCommand implements AccordionCommand<TransferredChordParams?> {
  @override
  String get commandName => 'TransferDetectedChordCommand';

  final DetectedChordModel? chord;

  const TransferDetectedChordCommand(this.chord);

  @override
  bool canExecute() => chord != null;

  @override
  void assertPreconditions() {
    if (chord == null) {
      throw const PreconditionViolationException(
        'TransferDetectedChordCommand',
        'El acorde detectado es nulo.',
      );
    }
  }

  @override
  TransferredChordParams? execute() {
    if (chord == null) return null;
    assertPreconditions();

    final root = chord!.rootPitchClass;
    var type = 'maj';
    var fourth = 'none';

    final sym = chord!.chordSymbol.toLowerCase();
    final f = chord!.formula;

    if (f.contains('♭3') && f.contains('♭5')) {
      type = 'dim';
    } else if (f.contains('♯5')) {
      type = 'aug';
    } else if (f.contains('4') && f.contains('5') && !f.contains('3')) {
      type = 'sus4';
    } else if (f.contains('♭3') || (sym.contains('m') && !sym.contains('maj'))) {
      type = 'min';
    }

    if (sym.contains('maj7')) {
      fourth = 'maj7';
    } else if (sym.contains('7') || sym.contains('dom7')) {
      fourth = 'dom7';
    } else if (sym.contains('add9')) {
      fourth = 'add9';
    } else if (sym.contains('6')) {
      fourth = 'maj6';
    }

    var bass = '';
    if (chord!.bassPitchClass != chord!.rootPitchClass) {
      final interval = (chord!.bassPitchClass - chord!.rootPitchClass + 12) % 12;
      if (interval == 3 || interval == 4) {
        bass = '3';
      } else if (interval == 6 || interval == 7 || interval == 8) {
        bass = '5';
      } else if (interval == 10 || interval == 11) {
        bass = '7';
      } else {
        bass = chord!.bass;
      }
    }

    return TransferredChordParams(
      root: root,
      type: type,
      fourth: fourth,
      bass: bass,
      isFixed: true,
    );
  }
}

/// Resultado de la ejecución de [MarkLiveChordChangeCommand].
class LiveMarkerResult {
  final int targetBar;
  final int targetBeat;
  final List<MeasureRow> updatedMeasures;
  final Set<int> updatedMarkedBeats;
  final String? assignedChord;

  const LiveMarkerResult({
    required this.targetBar,
    required this.targetBeat,
    required this.updatedMeasures,
    required this.updatedMarkedBeats,
    this.assignedChord,
  });
}

/// Comando para marcar en vivo el cambio de acorde en el compás y tiempo exacto
/// de reproducción según el slider / transporte de audio (Barra Espaciadora).
/// {P}: bpm in [30, 300], currentAudioTime >= 0, measures no vacío.
/// {Q}: targetBar y targetBeat corresponden a floor(currentAudioTime / beatDuration),
///      (targetBar * 4 + targetBeat) in updatedMarkedBeats.
class MarkLiveChordChangeCommand implements AccordionCommand<LiveMarkerResult> {
  @override
  String get commandName => 'MarkLiveChordChangeCommand';

  final double currentAudioTime;
  final double bpm;
  final List<MeasureRow> measures;
  final Set<int> markedBeats;
  final String? activeChord;

  const MarkLiveChordChangeCommand({
    required this.currentAudioTime,
    required this.bpm,
    required this.measures,
    required this.markedBeats,
    this.activeChord,
  });

  @override
  bool canExecute() => bpm > 0 && currentAudioTime >= 0 && measures.isNotEmpty;

  @override
  void assertPreconditions() {
    if (bpm <= 0) {
      throw const PreconditionViolationException(
        'MarkLiveChordChangeCommand',
        'El BPM debe ser estrictamente positivo.',
      );
    }
    if (currentAudioTime < 0) {
      throw const PreconditionViolationException(
        'MarkLiveChordChangeCommand',
        'El tiempo actual de audio no puede ser negativo.',
      );
    }
    if (measures.isEmpty) {
      throw const PreconditionViolationException(
        'MarkLiveChordChangeCommand',
        'La lista de compases no puede estar vacía.',
      );
    }
  }

  @override
  LiveMarkerResult execute() {
    assertPreconditions();

    final beatDuration = 60.0 / bpm;
    final totalBeats = (currentAudioTime / beatDuration).floor();
    final targetBar = (totalBeats ~/ 4).clamp(0, measures.length - 1);
    final targetBeat = (totalBeats % 4).clamp(0, 3);
    final targetKey = targetBar * 4 + targetBeat;

    final updatedMeasures = List<MeasureRow>.from(measures);
    final row = updatedMeasures[targetBar];
    final beats = List<MeasureBeat>.from(row.beats);

    final chordToAssign = (activeChord != null && activeChord!.trim().isNotEmpty)
        ? activeChord!.trim()
        : beats[targetBeat].chord;

    beats[targetBeat] = beats[targetBeat].copyWith(chord: chordToAssign);
    updatedMeasures[targetBar] = MeasureRow(barNumber: row.barNumber, beats: beats);

    final updatedMarked = Set<int>.from(markedBeats)..add(targetKey);

    return LiveMarkerResult(
      targetBar: targetBar,
      targetBeat: targetBeat,
      updatedMeasures: updatedMeasures,
      updatedMarkedBeats: updatedMarked,
      assignedChord: chordToAssign,
    );
  }
}

/// Comando para reproducir el click acústico del metrónomo sincronizado al compás.
/// {P}: beatIndex >= 0, volume in [0.0, 1.0].
/// {Q}: Pulso acústico emitido con acento en beat 0 (MIDI 84, C6) y pulsos secundarios en beats 1..3 (MIDI 76, E5).
class PlayMetronomeTickCommand implements AccordionCommand<int> {
  @override
  String get commandName => 'PlayMetronomeTickCommand';

  final void Function(int midiNote, {double velocity}) onNoteOn;
  final void Function(int midiNote) onNoteOff;
  final int beatIndex;
  final double volume;

  const PlayMetronomeTickCommand({
    required this.onNoteOn,
    required this.onNoteOff,
    required this.beatIndex,
    this.volume = 0.8,
  });

  @override
  bool canExecute() => beatIndex >= 0 && volume >= 0.0;

  @override
  void assertPreconditions() {
    if (beatIndex < 0) {
      throw const PreconditionViolationException(
        'PlayMetronomeTickCommand',
        'El índice de tiempo no puede ser negativo.',
      );
    }
  }

  @override
  int execute() {
    assertPreconditions();

    final isDownbeat = (beatIndex % 4) == 0;
    // Beat 0: C6 (84) más brillante y acentuado; Beats 1, 2, 3: E5 (76)
    final midiNote = isDownbeat ? 84 : 76;
    final velocity = (isDownbeat ? 0.95 : 0.65) * volume.clamp(0.0, 1.0);

    onNoteOn(midiNote, velocity: velocity);

    // Click percusivo ultra-breve (35 ms)
    Future.delayed(const Duration(milliseconds: 35), () {
      onNoteOff(midiNote);
    });

    return midiNote;
  }
}

