import 'dart:math' as math;
import '../../core/constants/enums.dart';
import '../models/accordion_data.dart';
import '../models/audio_analysis_models.dart';
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
/// de reproducción según el slider / transporte de audio (Barra Espaciadora),
/// alineado al punto de inicio (startOffset) del Compás 1.
/// {P}: bpm in [30, 300], currentAudioTime >= 0, startOffset >= 0, measures no vacío.
/// {Q}: targetBar y targetBeat corresponden a floor(max(0, currentAudioTime - startOffset) / beatDuration),
///      (targetBar * 4 + targetBeat) in updatedMarkedBeats.
class MarkLiveChordChangeCommand implements AccordionCommand<LiveMarkerResult> {
  @override
  String get commandName => 'MarkLiveChordChangeCommand';

  final double currentAudioTime;
  final double bpm;
  final List<MeasureRow> measures;
  final Set<int> markedBeats;
  final String? activeChord;
  final double startOffset;

  const MarkLiveChordChangeCommand({
    required this.currentAudioTime,
    required this.bpm,
    required this.measures,
    required this.markedBeats,
    this.activeChord,
    this.startOffset = 0.0,
  });

  @override
  bool canExecute() => bpm > 0 && currentAudioTime >= 0 && startOffset >= 0 && measures.isNotEmpty;

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
    if (startOffset < 0) {
      throw const PreconditionViolationException(
        'MarkLiveChordChangeCommand',
        'El desplazamiento de inicio de compás no puede ser negativo.',
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
    final elapsed = math.max(0.0, currentAudioTime - startOffset);
    final totalBeats = (elapsed / beatDuration).floor();
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

/// Comando para reproducir el chasquido acústico del metrónomo sincronizado al compás.
/// {P}: beatIndex >= 0, volume in [0.0, 1.0].
/// {Q}: Chasquido percusivo emitido con acento en beat 0 y pulsos secundarios en beats 1..3.
class PlayMetronomeTickCommand implements AccordionCommand<int> {
  @override
  String get commandName => 'PlayMetronomeTickCommand';

  final void Function(int midiNote, {double velocity})? onNoteOn;
  final void Function(int midiNote)? onNoteOff;
  final void Function({bool isDownbeat, double volume})? onPercussiveClick;
  final int beatIndex;
  final double volume;

  const PlayMetronomeTickCommand({
    this.onNoteOn,
    this.onNoteOff,
    this.onPercussiveClick,
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
    final midiNote = isDownbeat ? 84 : 76;
    final safeVolume = volume.clamp(0.0, 1.0);

    if (onPercussiveClick != null) {
      onPercussiveClick!(isDownbeat: isDownbeat, volume: safeVolume);
    } else if (onNoteOn != null && onNoteOff != null) {
      final velocity = (isDownbeat ? 0.95 : 0.65) * safeVolume;
      onNoteOn!(midiNote, velocity: velocity);
      Future.delayed(const Duration(milliseconds: 30), () {
        onNoteOff!(midiNote);
      });
    }

    return midiNote;
  }
}


/// Comando para calibrar el BPM a partir de dos toques (tecla Control) que marcan
/// el inicio del Compás 1 y el inicio del compás siguiente durante la reproducción.
///
/// {P}: 0 <= startTime < endTime, beatsPerBar > 0,
///      y el BPM resultante está en [minBpm, maxBpm].
/// {Q}: bpm = round(beatsPerBar * 60 / (endTime - startTime)).
/// {I}: Comando puro (sin efectos secundarios); no depende de Flutter ni del reproductor.
class CalibrateBpmFromTapsCommand implements AccordionCommand<int> {
  @override
  String get commandName => 'CalibrateBpmFromTapsCommand';

  final double startTime;
  final double endTime;
  final int beatsPerBar;
  final int minBpm;
  final int maxBpm;

  const CalibrateBpmFromTapsCommand({
    required this.startTime,
    required this.endTime,
    this.beatsPerBar = 4,
    this.minBpm = 30,
    this.maxBpm = 300,
  });

  double get _interval => endTime - startTime;

  double get rawBpm => _interval > 0 ? beatsPerBar * 60.0 / _interval : 0.0;

  @override
  bool canExecute() =>
      startTime >= 0 &&
      _interval > 0 &&
      beatsPerBar > 0 &&
      rawBpm >= minBpm &&
      rawBpm <= maxBpm;

  @override
  void assertPreconditions() {
    if (startTime < 0 || _interval <= 0) {
      throw const PreconditionViolationException(
        'CalibrateBpmFromTapsCommand',
        'El segundo toque debe ocurrir después del primero.',
      );
    }
    if (rawBpm < minBpm || rawBpm > maxBpm) {
      throw const PreconditionViolationException(
        'CalibrateBpmFromTapsCommand',
        'El intervalo entre compases produce un BPM fuera de rango.',
      );
    }
  }

  @override
  int execute() {
    assertPreconditions();
    return rawBpm.round();
  }
}

/// Resultado de la ejecución de [ApplyMeasureChordsFromAudioCommand].
class ApplyMeasureChordsResult {
  final List<MeasureRow> updatedMeasures;
  final Set<int> updatedMarkedBeats;
  final int totalChordChanges;

  const ApplyMeasureChordsResult({
    required this.updatedMeasures,
    required this.updatedMarkedBeats,
    required this.totalChordChanges,
  });
}

/// Comando para aplicar automáticamente los cambios de acordes detectados en el audio
/// a la cuadrícula de compases, sincronizados al BPM y al punto de inicio (Compás 1) del audio.
///
/// Sustituye la pulsación manual repetitiva de la barra espaciadora con un mapeo armónico
/// continuo, algorítmico y matemáticamente preciso.
///
/// # Triplas de Hoare:
/// - {P}: `measures.isNotEmpty`, `chords.isNotEmpty`, `bpm > 0`, `startOffset >= 0.0`.
/// - {Q}: Todas las celdas de compás reciben el acorde correspondiente a su intervalo temporal
///        [t_beat, t_beat + beatDuration]. Cada beat donde ocurre una transición/cambio de acorde
///        queda registrado en `updatedMarkedBeats` con precisión milimétrica.
/// - {I}: Conserva la cantidad de compases de la cuadrícula; no produce tiempos nulos ni negativos.
class ApplyMeasureChordsFromAudioCommand implements AccordionCommand<ApplyMeasureChordsResult> {
  @override
  String get commandName => 'ApplyMeasureChordsFromAudioCommand';

  final List<MeasureRow> measures;
  final List<DetectedChordSegment> chords;
  final double bpm;
  final double startOffset;
  final NotationMode notation;

  const ApplyMeasureChordsFromAudioCommand({
    required this.measures,
    required this.chords,
    required this.bpm,
    this.startOffset = 0.0,
    this.notation = NotationMode.latina,
  });

  @override
  bool canExecute() => measures.isNotEmpty && chords.isNotEmpty && bpm > 0 && startOffset >= 0.0;

  @override
  void assertPreconditions() {
    if (measures.isEmpty) {
      throw const PreconditionViolationException(
        'ApplyMeasureChordsFromAudioCommand',
        'La lista de compases no puede estar vacía.',
      );
    }
    if (chords.isEmpty) {
      throw const PreconditionViolationException(
        'ApplyMeasureChordsFromAudioCommand',
        'La lista de acordes detectados no puede estar vacía.',
      );
    }
    if (bpm <= 0) {
      throw const PreconditionViolationException(
        'ApplyMeasureChordsFromAudioCommand',
        'El BPM debe ser estrictamente positivo.',
      );
    }
    if (startOffset < 0) {
      throw const PreconditionViolationException(
        'ApplyMeasureChordsFromAudioCommand',
        'El desplazamiento inicial de audio no puede ser negativo.',
      );
    }
  }

  @override
  ApplyMeasureChordsResult execute() {
    assertPreconditions();

    final secondsPerBeat = 60.0 / bpm;
    final updatedMeasures = <MeasureRow>[];
    final updatedMarkedBeats = <int>{};
    String previousChord = '';
    int totalChanges = 0;

    for (int barIdx = 0; barIdx < measures.length; barIdx++) {
      final oldRow = measures[barIdx];
      final newBeats = <MeasureBeat>[];

      for (int beatIdx = 0; beatIdx < 4; beatIdx++) {
        final beatTime = startOffset + (barIdx * 4 + beatIdx) * secondsPerBeat;
        final midBeatTime = beatTime + (secondsPerBeat * 0.5);

        final mins = (beatTime ~/ 60).toString().padLeft(2, '0');
        final secs = ((beatTime % 60).toInt()).toString().padLeft(2, '0');

        final chordSegment = _findSegmentForTime(chords, midBeatTime);
        final chordText = chordSegment != null
            ? (notation == NotationMode.alemana
                ? chordSegment.chordSymbol
                : (chordSegment.chordName.isNotEmpty ? chordSegment.chordName : chordSegment.chordSymbol))
            : '';

        final isChange = chordText.isNotEmpty && (chordText != previousChord || updatedMarkedBeats.isEmpty);
        if (isChange) {
          updatedMarkedBeats.add(barIdx * 4 + beatIdx);
          previousChord = chordText;
          totalChanges++;
        }

        newBeats.add(MeasureBeat(
          barIndex: barIdx,
          beatIndex: beatIdx,
          chord: chordText,
          timeText: '$mins:$secs',
          isContinue: !isChange && chordText.isNotEmpty,
        ));
      }

      updatedMeasures.add(MeasureRow(
        barNumber: oldRow.barNumber,
        beats: newBeats,
      ));
    }

    return ApplyMeasureChordsResult(
      updatedMeasures: updatedMeasures,
      updatedMarkedBeats: updatedMarkedBeats,
      totalChordChanges: totalChanges,
    );
  }

  DetectedChordSegment? _findSegmentForTime(List<DetectedChordSegment> segments, double time) {
    if (segments.isEmpty) return null;
    for (final seg in segments) {
      if (time >= seg.startTime && time < seg.endTime) {
        return seg;
      }
    }
    return segments.reduce((best, seg) {
      final bestMid = (best.startTime + best.endTime) / 2.0;
      final segMid = (seg.startTime + seg.endTime) / 2.0;
      return (segMid - time).abs() < (bestMid - time).abs() ? seg : best;
    });
  }
}

/// Resultado de la evaluación de transición armónica en tiempo de reproducción.
class PlaybackChordTransitionResult {
  final bool hasTransition;
  final int targetBar;
  final int targetBeat;
  final String detectedChordText;
  final DetectedChordSegment? segment;
  final List<MeasureRow> updatedMeasures;
  final Set<int> updatedMarkedBeats;

  const PlaybackChordTransitionResult({
    required this.hasTransition,
    required this.targetBar,
    required this.targetBeat,
    required this.detectedChordText,
    this.segment,
    required this.updatedMeasures,
    required this.updatedMarkedBeats,
  });
}

/// Comando para la detección automática de acordes durante la reproducción de audio,
/// activándose ÚNICAMENTE cuando ocurre una transición armónica (cambio de acorde).
///
/// # Triplas de Hoare:
/// - {P}: `currentAudioTime >= 0.0 && bpm >= 30.0 && measures.isNotEmpty && chords.isNotEmpty && startOffset >= 0.0`.
/// - {Q}: Si `hasTransition == true`:
///          - `detectedChordText != lastDetectedChordText`
///          - `updatedMeasures[targetBar].beats[targetBeat].chord == detectedChordText`
///          - `updatedMarkedBeats.contains(targetBar * 4 + targetBeat) == true`
///        Si `hasTransition == false`:
///          - `updatedMeasures == measures && updatedMarkedBeats == markedBeats` (Inmutabilidad garantizada).
/// - {I}: `updatedMeasures.length == measures.length`.
class DetectPlaybackChordTransitionCommand implements AccordionCommand<PlaybackChordTransitionResult> {
  @override
  String get commandName => 'DetectPlaybackChordTransitionCommand';

  final double currentAudioTime;
  final double bpm;
  final double startOffset;
  final List<MeasureRow> measures;
  final Set<int> markedBeats;
  final List<DetectedChordSegment> chords;
  final String? lastDetectedChordText;
  final NotationMode notation;

  const DetectPlaybackChordTransitionCommand({
    required this.currentAudioTime,
    required this.bpm,
    required this.startOffset,
    required this.measures,
    required this.markedBeats,
    required this.chords,
    this.lastDetectedChordText,
    this.notation = NotationMode.latina,
  });

  @override
  bool canExecute() =>
      currentAudioTime >= 0.0 && bpm >= 30.0 && measures.isNotEmpty && chords.isNotEmpty && startOffset >= 0.0;

  @override
  void assertPreconditions() {
    if (currentAudioTime < 0.0) {
      throw const PreconditionViolationException(
        'DetectPlaybackChordTransitionCommand',
        'El tiempo actual de reproducción no puede ser negativo.',
      );
    }
    if (bpm < 30.0) {
      throw const PreconditionViolationException(
        'DetectPlaybackChordTransitionCommand',
        'El BPM debe ser de al menos 30.',
      );
    }
    if (measures.isEmpty) {
      throw const PreconditionViolationException(
        'DetectPlaybackChordTransitionCommand',
        'La cuadrícula de compases no puede estar vacía.',
      );
    }
    if (chords.isEmpty) {
      throw const PreconditionViolationException(
        'DetectPlaybackChordTransitionCommand',
        'La lista de acordes analizados no puede estar vacía.',
      );
    }
    if (startOffset < 0.0) {
      throw const PreconditionViolationException(
        'DetectPlaybackChordTransitionCommand',
        'El desplazamiento de inicio no puede ser negativo.',
      );
    }
  }

  @override
  PlaybackChordTransitionResult execute() {
    assertPreconditions();

    final seg = _findSegmentForTime(chords, currentAudioTime);
    if (seg == null) {
      return PlaybackChordTransitionResult(
        hasTransition: false,
        targetBar: 0,
        targetBeat: 0,
        detectedChordText: '',
        segment: null,
        updatedMeasures: measures,
        updatedMarkedBeats: markedBeats,
      );
    }

    final chordText = notation == NotationMode.alemana
        ? seg.chordSymbol
        : (seg.chordName.isNotEmpty ? seg.chordName : seg.chordSymbol);

    // Condición estricta: ÚNICAMENTE cuando hay un cambio de acorde detectable
    final isChordChange = chordText.isNotEmpty && (chordText != lastDetectedChordText);

    final beatDuration = 60.0 / bpm;
    final elapsed = math.max(0.0, currentAudioTime - startOffset);
    final totalBeats = (elapsed / beatDuration).floor();
    final targetBar = (totalBeats ~/ 4).clamp(0, measures.length - 1);
    final targetBeat = (totalBeats % 4).clamp(0, 3);
    final linearKey = targetBar * 4 + targetBeat;

    if (!isChordChange) {
      return PlaybackChordTransitionResult(
        hasTransition: false,
        targetBar: targetBar,
        targetBeat: targetBeat,
        detectedChordText: chordText,
        segment: seg,
        updatedMeasures: measures,
        updatedMarkedBeats: markedBeats,
      );
    }

    // Aplicar la transición en la cuadrícula de compases
    final updatedMeasures = List<MeasureRow>.from(measures);
    final row = updatedMeasures[targetBar];
    final beats = List<MeasureBeat>.from(row.beats);

    beats[targetBeat] = beats[targetBeat].copyWith(
      chord: chordText,
      isContinue: false,
    );
    updatedMeasures[targetBar] = MeasureRow(barNumber: row.barNumber, beats: beats);

    final updatedMarked = Set<int>.from(markedBeats)..add(linearKey);

    return PlaybackChordTransitionResult(
      hasTransition: true,
      targetBar: targetBar,
      targetBeat: targetBeat,
      detectedChordText: chordText,
      segment: seg,
      updatedMeasures: updatedMeasures,
      updatedMarkedBeats: updatedMarked,
    );
  }

  DetectedChordSegment? _findSegmentForTime(List<DetectedChordSegment> segments, double time) {
    if (segments.isEmpty) return null;
    for (final s in segments) {
      if (time >= s.startTime && time < s.endTime) {
        return s;
      }
    }
    return segments.reduce((best, s) {
      final bestMid = (best.startTime + best.endTime) / 2.0;
      final sMid = (s.startTime + s.endTime) / 2.0;
      return (sMid - time).abs() < (bestMid - time).abs() ? s : best;
    });
  }
}

/// Comando para micro-ajuste de la fase o desfase del pulso (Beat Nudge).
///
/// # Triplas de Hoare:
/// - {P}: `currentOffset.isFinite && deltaSeconds.isFinite && minLimit <= maxLimit`.
/// - {Q}: `result >= minLimit && result <= maxLimit` con precisión a milisegundos.
/// - {I}: Monotonía estricta según el signo de `deltaSeconds`.
class AdjustBeatOffsetCommand implements AccordionCommand<double> {
  @override
  String get commandName => 'AdjustBeatOffsetCommand';

  final double currentOffset;
  final double deltaSeconds;
  final double minLimit;
  final double maxLimit;

  const AdjustBeatOffsetCommand({
    required this.currentOffset,
    required this.deltaSeconds,
    this.minLimit = -5.0,
    this.maxLimit = 5.0,
  });

  @override
  bool canExecute() => currentOffset.isFinite && deltaSeconds.isFinite && minLimit <= maxLimit;

  @override
  void assertPreconditions() {
    if (!currentOffset.isFinite || !deltaSeconds.isFinite) {
      throw const PreconditionViolationException(
        'AdjustBeatOffsetCommand',
        'Los parámetros de ajuste temporal deben ser valores numéricos finitos.',
      );
    }
    if (minLimit > maxLimit) {
      throw const PreconditionViolationException(
        'AdjustBeatOffsetCommand',
        'El límite inferior no puede superar al límite superior.',
      );
    }
  }

  @override
  double execute() {
    assertPreconditions();
    final candidate = (currentOffset + deltaSeconds).clamp(minLimit, maxLimit);
    // Redondeo a 3 decimales para evitar artefactos de coma flotante (milisegundos)
    return (candidate * 1000.0).roundToDouble() / 1000.0;
  }
}

/// Comando para sincronizar instantáneamente el pulso más cercano al tiempo actual del reproductor (Beat Sync).
///
/// # Triplas de Hoare:
/// - {P}: `currentAudioTime >= 0.0 && bpm >= 30.0`.
/// - {Q}: El ajuste retornado $\delta$ ubica el pulso dentro de $[-\Delta t / 2, \Delta t / 2]$.
class SyncBeatToAudioCommand implements AccordionCommand<double> {
  @override
  String get commandName => 'SyncBeatToAudioCommand';

  final double currentAudioTime;
  final double audioStartOffset;
  final double bpm;

  const SyncBeatToAudioCommand({
    required this.currentAudioTime,
    required this.audioStartOffset,
    required this.bpm,
  });

  @override
  bool canExecute() => currentAudioTime >= 0.0 && bpm >= 30.0;

  @override
  void assertPreconditions() {
    if (currentAudioTime < 0.0) {
      throw const PreconditionViolationException(
        'SyncBeatToAudioCommand',
        'El tiempo actual no puede ser negativo.',
      );
    }
    if (bpm < 30.0) {
      throw const PreconditionViolationException(
        'SyncBeatToAudioCommand',
        'El BPM debe ser de al menos 30.',
      );
    }
  }

  @override
  double execute() {
    assertPreconditions();
    final secondsPerBeat = 60.0 / bpm;
    final relativeTime = currentAudioTime - audioStartOffset;
    final nearestBeatIndex = (relativeTime / secondsPerBeat).round();
    final idealBeatTime = audioStartOffset + (nearestBeatIndex * secondsPerBeat);
    final delta = currentAudioTime - idealBeatTime;
    return (delta * 1000.0).roundToDouble() / 1000.0;
  }
}

/// Comando para conmutar la selección de tiempos mediante Checkbox en cascada.
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Encapsula exclusivamente la lógica de marcación
///   en cascada hacia adelante preservando las selecciones previas ("mantener la selección").
/// - Enfoque formal con Triplas de Hoare:
///   - Precondición {P}:
///     - `barIndex >= 0 && barIndex < totalMeasures`
///     - `beatIndex >= 0 && beatIndex < 4`
///     - `totalMeasures > 0`
///   - Ejecución {C}:
///     Sea $k = \text{barIndex} \times 4 + \text{beatIndex}$ y $N = \text{totalMeasures} \times 4$.
///     Si $k \notin \text{currentMarkedBeats}$ (se está seleccionando):
///       $\text{result} = \text{currentMarkedBeats} \cup \{ i \in \mathbb{N} \mid k \le i < N \}$
///     Si $k \in \text{currentMarkedBeats}$ (se está desmarcando):
///       $\text{result} = \text{currentMarkedBeats} \setminus \{ i \in \mathbb{N} \mid k \le i < N \}$
///   - Poscondición {Q}:
///     Si $k \notin \text{currentMarkedBeats}$:
///       - $\forall m \in \text{currentMarkedBeats}: m \in \text{result}$ (preserva todas las selecciones previas)
///       - $\forall i \in [k, N - 1]: i \in \text{result}$ (marca todos los tiempos siguientes)
///       - $\forall j < k: (j \in \text{result} \iff j \in \text{currentMarkedBeats})$
///     Si $k \in \text{currentMarkedBeats}$:
///       - $\forall i \in [k, N - 1]: i \notin \text{result}$
///       - $\forall j < k: (j \in \text{result} \iff j \in \text{currentMarkedBeats})$
///   - Invariante {I}:
///     $\forall j < k: (j \in \text{result} \iff j \in \text{currentMarkedBeats})$.
class CascadeMarkBeatsCommand implements AccordionCommand<Set<int>> {
  @override
  String get commandName => 'CascadeMarkBeatsCommand';

  final Set<int> currentMarkedBeats;
  final int barIndex;
  final int beatIndex;
  final int totalMeasures;

  const CascadeMarkBeatsCommand({
    required this.currentMarkedBeats,
    required this.barIndex,
    required this.beatIndex,
    required this.totalMeasures,
  });

  int get targetKey => barIndex * 4 + beatIndex;
  int get totalBeats => totalMeasures * 4;

  @override
  bool canExecute() {
    return totalMeasures > 0 &&
        barIndex >= 0 &&
        barIndex < totalMeasures &&
        beatIndex >= 0 &&
        beatIndex < 4;
  }

  @override
  void assertPreconditions() {
    if (totalMeasures <= 0) {
      throw const PreconditionViolationException(
        'CascadeMarkBeatsCommand',
        'La cuadrícula debe tener al menos un compás.',
      );
    }
    if (barIndex < 0 || barIndex >= totalMeasures) {
      throw PreconditionViolationException(
        'CascadeMarkBeatsCommand',
        'barIndex ($barIndex) fuera de rango [0, ${totalMeasures - 1}].',
      );
    }
    if (beatIndex < 0 || beatIndex >= 4) {
      throw PreconditionViolationException(
        'CascadeMarkBeatsCommand',
        'beatIndex ($beatIndex) fuera de rango [0, 3].',
      );
    }
  }

  @override
  Set<int> execute() {
    assertPreconditions();
    final k = targetKey;
    final N = totalBeats;
    final isCurrentlyMarked = currentMarkedBeats.contains(k);
    final result = Set<int>.from(currentMarkedBeats);

    if (!isCurrentlyMarked) {
      // Se selecciona el checkbox: mantener selección previa y marcar todos los siguientes
      for (var i = k; i < N; i++) {
        result.add(i);
      }
    } else {
      // Se desmarca el checkbox: desmarcar este tiempo y los siguientes, preservando los anteriores
      for (var i = k; i < N; i++) {
        result.remove(i);
      }
    }

    assertPostconditions(result, isCurrentlyMarked);
    return result;
  }

  void assertPostconditions(Set<int> result, bool wasMarked) {
    final k = targetKey;
    final N = totalBeats;
    if (!wasMarked) {
      // Poscondición {Q}: todas las marcas previas se conservan
      assert(currentMarkedBeats.every((m) => result.contains(m)),
          'Violación {Q}: No se mantuvieron las selecciones previas.');
      // Poscondición {Q}: todos los siguientes desde k hasta N - 1 están marcados
      for (var i = k; i < N; i++) {
        assert(result.contains(i),
            'Violación {Q}: El pulso $i posterior a $k no fue marcado.');
      }
    } else {
      // Poscondición {Q}: ninguno de k a N - 1 permanece marcado
      for (var i = k; i < N; i++) {
        assert(!result.contains(i),
            'Violación {Q}: El pulso $i posterior a $k no fue desmarcado.');
      }
    }
    // Invariante {I}: pulsos anteriores a k no cambiaron su estado
    for (var j = 0; j < k; j++) {
      assert(result.contains(j) == currentMarkedBeats.contains(j),
          'Violación {I}: El pulso anterior $j fue alterado indebidamente.');
    }
  }
}

