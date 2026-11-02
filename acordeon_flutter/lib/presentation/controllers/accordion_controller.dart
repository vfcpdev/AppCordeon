import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/analysis/tuning_recommender.dart';
import '../../core/audio/audio_analyzer.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/audio/audio_file_loader_interface.dart';
import '../../core/audio/audio_file_player.dart';
import '../../core/audio/demo_track_generator.dart';
import '../../core/constants/enums.dart';
import '../../core/di/providers.dart';
import '../../domain/commands/accordion_commands.dart';
import '../../domain/memento/grid_memento.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/audio_analysis_models.dart';
import '../../domain/models/bass_matrix_layout.dart';
import '../../domain/models/bass_rhythm_pattern.dart';
import '../../domain/models/free_chord_state.dart';
import '../../domain/models/measure_json_serializer.dart';
import '../../domain/models/measure_models.dart';
import '../../domain/models/tuning.dart';
import '../../domain/services/bass_rhythm_catalog.dart';
import '../../domain/services/bass_row_pair_resolver.dart';
import '../../domain/services/grid_metrics_service.dart' as grid_metrics;
import '../../domain/services/hoare_contract.dart';
import '../../domain/services/musicxml_rhythm_importer.dart';
import '../../domain/theory/chord_catalog.dart';
import '../../domain/theory/chord_detector_engine.dart';
import 'free_chord_playback_coordinator.dart';

export '../../domain/models/measure_json_serializer.dart';
export '../../domain/models/measure_models.dart';

export '../../domain/models/free_chord_state.dart';

/// Resultado de una operación de carga de audio. La UI decide cómo mostrarlo.
sealed class AudioLoadResult {
  const AudioLoadResult();
}

class AudioLoadSuccess extends AudioLoadResult {
  final String fileName;
  const AudioLoadSuccess(this.fileName);
}

class AudioAnalysisSuccess extends AudioLoadResult {
  final AudioAnalysisReport report;
  final String fileName;
  const AudioAnalysisSuccess(this.report, this.fileName);
}

class AudioLoadCancelled extends AudioLoadResult {
  const AudioLoadCancelled();
}

class AudioLoadFailure extends AudioLoadResult {
  final String message;
  const AudioLoadFailure(this.message);
}

/// Delegaciones al servicio de métricas de cuadrícula en domain (única
/// implementación; el controller solo redirige para conservar la API interna).
String _findChordForTime(
  List<DetectedChordSegment> chords,
  double timeSeconds,
) => grid_metrics.findChordForTime(chords, timeSeconds);

/// Agrupa el estado de acople/desacople y posición de los paneles flotantes
/// (Cuadro de compás 1/2, Barra de canción y Detector de acordes).
class DockState {
  final bool isCompas1Undocked;
  final Offset compas1Position;
  final bool isCompas2Undocked;
  final Offset compas2Position;
  final bool isSongBarUndocked;
  final Offset songBarPosition;
  final bool isChordDetectorUndocked;
  final Offset chordDetectorPosition;

  const DockState({
    this.isCompas1Undocked = false,
    this.compas1Position = const Offset(220, 70),
    this.isCompas2Undocked = false,
    this.compas2Position = const Offset(440, 70),
    this.isSongBarUndocked = false,
    this.songBarPosition = const Offset(20, 50),
    this.isChordDetectorUndocked = false,
    this.chordDetectorPosition = const Offset(390, 150),
  });

  DockState copyWith({
    bool? isCompas1Undocked,
    Offset? compas1Position,
    bool? isCompas2Undocked,
    Offset? compas2Position,
    bool? isSongBarUndocked,
    Offset? songBarPosition,
    bool? isChordDetectorUndocked,
    Offset? chordDetectorPosition,
  }) {
    return DockState(
      isCompas1Undocked: isCompas1Undocked ?? this.isCompas1Undocked,
      compas1Position: compas1Position ?? this.compas1Position,
      isCompas2Undocked: isCompas2Undocked ?? this.isCompas2Undocked,
      compas2Position: compas2Position ?? this.compas2Position,
      isSongBarUndocked: isSongBarUndocked ?? this.isSongBarUndocked,
      songBarPosition: songBarPosition ?? this.songBarPosition,
      isChordDetectorUndocked:
          isChordDetectorUndocked ?? this.isChordDetectorUndocked,
      chordDetectorPosition:
          chordDetectorPosition ?? this.chordDetectorPosition,
    );
  }
}

/// Agrupa la configuración de la Sección 5: Acorde Libre y Escalas.
/// Implementación consolidada en domain/models; ver el export al inicio
/// del archivo.

/// Agrupa el transporte del reproductor y la sincronización con el Compás.
class AudioTransportState {
  final bool isPlayingAudio;
  final double currentAudioTime;
  final double? currentCompasTime;
  final double totalAudioDuration;
  final bool isAudioCoupled;
  final double compasVolume;

  const AudioTransportState({
    this.isPlayingAudio = false,
    this.currentAudioTime = 0.0,
    this.currentCompasTime,
    this.totalAudioDuration = 180.0,
    this.isAudioCoupled = true,
    this.compasVolume = 0.8,
  });

  AudioTransportState copyWith({
    bool? isPlayingAudio,
    double? currentAudioTime,
    double? currentCompasTime,
    double? totalAudioDuration,
    bool? isAudioCoupled,
    double? compasVolume,
  }) {
    return AudioTransportState(
      isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
      currentAudioTime: currentAudioTime ?? this.currentAudioTime,
      currentCompasTime: currentCompasTime ?? this.currentCompasTime,
      totalAudioDuration: totalAudioDuration ?? this.totalAudioDuration,
      isAudioCoupled: isAudioCoupled ?? this.isAudioCoupled,
      compasVolume: compasVolume ?? this.compasVolume,
    );
  }
}

/// Estado global del simulador de Acordeón
class AccordionSimulatorState {
  // Configuración General
  final NotationMode notation;
  final bool showDiapason1;
  final bool showDiapason2;

  // Acordeón 1 (Principal)
  final TuningDefinition tuning1;
  final BellowsMode bellows1;
  final bool isBass1Collapsed;
  final bool mirror1;
  final double volume1;
  final bool isMuted1;

  // Acordeón 2 (Comparativo / Equivalente)
  final TuningDefinition tuning2;
  final BellowsMode bellows2;
  final bool isBass2Collapsed;
  final bool mirror2;
  final double volume2;
  final bool isMuted2;
  final bool syncVolume;

  // Botones activos (pulsados actualmente)
  final Set<String> activeButtons;

  // Reproductor & Cuadrícula de Compases
  final AudioTransportState transport;
  double get compasTime =>
      transport.currentCompasTime ?? transport.currentAudioTime;
  final bool syncDiapason;

  /// Notas MIDI que están sonando en el compás actual (para el diapasón).
  final Set<int> playingChordNotes;
  final bool sequenceMode;
  final int visibleGridRows;
  final List<MeasureRow> measures;
  final int? selectedBarIndex;
  final int? selectedBeatIndex;
  final bool isManualBeatSelection;

  /// Tiempos marcados con el checkbox de la cuadrícula. Si hay alguno, la
  /// inserción desde el Constructor y la reproducción se limitan a ellos.
  final Set<int>? _markedBeats;
  Set<int> get markedBeats => _markedBeats ?? const {};

  final bool isMultiBeatAssignmentMode;
  final Set<int>? _multiBeatAssignmentTargets;
  Set<int> get multiBeatAssignmentTargets =>
      _multiBeatAssignmentTargets ?? const {};

  /// Tiempos resaltados en amarillo para decidir el fuelle (acordes completos abriendo o cerrando).
  final Set<int>? _yellowDecisionBeats;
  Set<int> get yellowDecisionBeats => _yellowDecisionBeats ?? const {};

  // Sección 5: Acorde Libre y Escalas
  final FreeChordState freeChord;

  // Sección 3: Detector Inteligente de Acordes
  final bool detectorMode;
  final String detectorDirection; // auto, push, pull
  final List<String> detectorSelectedButtons;
  final DetectedChordModel? detectedChord;

  // Carga y Análisis de Audio con DSP Rust
  final AudioAnalysisReport? audioReport;
  final bool isAnalyzingAudio;
  final String? loadedAudioFileName;

  // Asignación de acorde a múltiples compases (modal movible)
  final bool showMultiBeatModal;
  final String? _multiBeatPattern;
  String get multiBeatPattern => _multiBeatPattern ?? '';
  final String? multiBeatChord;

  // Paneles acoplables/desacoplables y movibles (Compás 1/2, Barra de canción,
  // Detector de acordes).
  final DockState dock;

  // Metrónomo y Marcación en Vivo con Barra Espaciadora
  final bool? _isMetronomeActive;
  bool get isMetronomeActive => _isMetronomeActive ?? false;

  final double? _metronomeVolume;
  double get metronomeVolume => _metronomeVolume ?? 0.8;

  final List<BassRhythmPattern> bassRhythmPatterns;
  final String? selectedBassRhythmPatternId;
  final AccordionRowTarget selectedBassRowTarget;
  final bool isBassMetronomeActive;
  final double bassRhythmElapsedSeconds;
  final double? _manualMetronomeBpm;
  double get manualMetronomeBpm => _manualMetronomeBpm ?? 120.0;

  /// Captura de patrón en curso (matriz 2×2 de bajos 7/8/4/5). `null` cuando
  /// no hay captura activa.
  final BassRhythmRecorder? bassRhythmRecorder;
  bool get isBassCaptureActive => bassRhythmRecorder?.isRecording ?? false;

  /// Panel inline de captura visible sobre el propio panel de bajos (no
  /// modal: los bajos deben seguir tocables durante la captura).
  final bool isBassCapturePanelOpen;

  BassRhythmPattern? get selectedBassRhythmPattern {
    final selectedId = selectedBassRhythmPatternId;
    if (selectedId == null) return null;
    for (final pattern in bassRhythmPatterns) {
      if (pattern.id == selectedId) return pattern;
    }
    return null;
  }

  double get bassRhythmPositionQuarterBeats {
    final pattern = selectedBassRhythmPattern;
    if (pattern == null || pattern.durationQuarterBeats <= 0) return 0;
    final bpm = isPlayingAudio
        ? audioReport?.bpm.toDouble() ??
              manualMetronomeBpm
        : pattern.quarterNotesPerMinute ??
              audioReport?.bpm.toDouble() ??
              manualMetronomeBpm;
    final elapsedSeconds = isPlayingAudio
        ? math.max(0.0, compasTime - effectiveAudioStartOffset)
        : bassRhythmElapsedSeconds;
    return (elapsedSeconds * bpm / 60.0) % pattern.durationQuarterBeats;
  }

  Set<int> get activeBassRhythmButtonIndexes {
    final pattern = selectedBassRhythmPattern;
    if (pattern == null) return const {};
    final position = bassRhythmPositionQuarterBeats;
    final rawIndexes = {
      for (final hit in pattern.hits)
        if (position >= hit.onsetQuarterBeats &&
            position < hit.onsetQuarterBeats + hit.durationQuarterBeats)
          ...hit.buttonIndexes,
    };
    return rawIndexes
        .map((idx) => BassRowPairResolver.remapButtonIndex(idx, selectedBassRowTarget))
        .toSet();
  }

  Map<int, BassRhythmHit> get activeBassRhythmHits {
    final pattern = selectedBassRhythmPattern;
    if (pattern == null) return const {};
    final position = bassRhythmPositionQuarterBeats;
    final result = <int, BassRhythmHit>{};
    for (final hit in pattern.hits) {
      if (position >= hit.onsetQuarterBeats &&
          position < hit.onsetQuarterBeats + hit.durationQuarterBeats) {
        for (final buttonIndex in hit.buttonIndexes) {
          final remapped =
              BassRowPairResolver.remapButtonIndex(buttonIndex, selectedBassRowTarget);
          result[remapped] = hit;
        }
      }
    }
    return result;
  }

  final bool? _isLiveChordMarkerActive;
  bool get isLiveChordMarkerActive => _isLiveChordMarkerActive ?? false;

  final String copiedChord;

  /// Marca temporal (s) del primer toque de Control para calibrar el BPM.
  /// Valor negativo = calibración inactiva.
  final double? _bpmCalibrationStart;
  double get bpmCalibrationStart => _bpmCalibrationStart ?? -1.0;
  bool get isCalibratingBpm => bpmCalibrationStart >= 0.0;

  /// Desplazamiento temporal (s) donde inicia el Compás 1 en el archivo de audio.
  /// Permite sincronizar intros, silencios o anacrusas.
  final double? _audioStartOffset;
  double get audioStartOffset => _audioStartOffset ?? 0.0;

  /// Detección automática del acorde en reproducción sólo cuando hay cambios de acorde.
  final bool? _isPlaybackAutoChordDetectEnabled;
  bool get isPlaybackAutoChordDetectEnabled =>
      _isPlaybackAutoChordDetectEnabled ?? false;

  /// Micro-ajuste o ajuste fino del desfase del pulso (s) respecto a la cuadrícula.
  final double? _beatNudgeOffset;
  double get beatNudgeOffset => _beatNudgeOffset ?? 0.0;

  /// Desplazamiento temporal total acumulado (inicio de audio + micro-ajuste de beat).
  double get effectiveAudioStartOffset => audioStartOffset + beatNudgeOffset;

  // Getters de compatibilidad: exponen los grupos como campos planos para no
  // romper widgets ni pruebas existentes.
  bool get isPlayingAudio => transport.isPlayingAudio;
  double get currentAudioTime => transport.currentAudioTime;
  double? get currentCompasTime => transport.currentCompasTime;
  double get totalAudioDuration => transport.totalAudioDuration;
  bool get isAudioCoupled => transport.isAudioCoupled;
  double get compasVolume => transport.compasVolume;

  int get freeChordRoot => freeChord.root;
  String get freeChordType => freeChord.type;
  String get freeChordFourth => freeChord.fourth;
  String get freeChordOctave => freeChord.octave;
  String get freeChordMode => freeChord.mode;
  bool get isFreeChordFixed => freeChord.isFixed;
  bool get isFreeChordBeingEdited => freeChord.isBeingEdited;
  BellowsMode get freeChordBellows => freeChord.bellows;
  String get freeChordScaleHarmonicMode => freeChord.scaleHarmonicMode;
  String get freeChordBass => freeChord.bass;

  bool get isCompas1Undocked => dock.isCompas1Undocked;
  Offset get compas1Position => dock.compas1Position;
  bool get isCompas2Undocked => dock.isCompas2Undocked;
  Offset get compas2Position => dock.compas2Position;
  bool get isSongBarUndocked => dock.isSongBarUndocked;
  Offset get songBarPosition => dock.songBarPosition;
  bool get isChordDetectorUndocked => dock.isChordDetectorUndocked;
  Offset get chordDetectorPosition => dock.chordDetectorPosition;

  /// Acorde de la casilla seleccionada, sin heredar acordes de otras casillas.
  String get activeCompasChord {
    final barIndex = selectedBarIndex;
    final beatIndex = selectedBeatIndex ?? 0;
    if (barIndex != null && barIndex >= 0 && barIndex < measures.length) {
      final beats = measures[barIndex].beats;
      if (beatIndex >= 0 && beatIndex < beats.length) {
        final chord = beats[beatIndex].chord.trim();
        if (chord.isNotEmpty || isManualBeatSelection) return chord;
      }
    }
    if (!transport.isAudioCoupled) return '';
    return _findChordForTime(
      audioReport?.chords ?? const [],
      transport.currentAudioTime,
    );
  }

  const AccordionSimulatorState({
    required this.notation,
    required this.showDiapason1,
    required this.showDiapason2,
    required this.tuning1,
    required this.bellows1,
    required this.isBass1Collapsed,
    required this.mirror1,
    required this.volume1,
    required this.isMuted1,
    required this.tuning2,
    required this.bellows2,
    required this.isBass2Collapsed,
    required this.mirror2,
    required this.volume2,
    required this.isMuted2,
    required this.syncVolume,
    required this.activeButtons,
    this.transport = const AudioTransportState(),
    required this.syncDiapason,
    required this.playingChordNotes,
    required this.sequenceMode,
    required this.visibleGridRows,
    required this.measures,
    this.selectedBarIndex,
    this.selectedBeatIndex,
    this.isManualBeatSelection = false,
    Set<int>? markedBeats,
    this.isMultiBeatAssignmentMode = false,
    Set<int>? multiBeatAssignmentTargets,
    Set<int>? yellowDecisionBeats,
    this.freeChord = const FreeChordState(),
    required this.detectorMode,
    required this.detectorDirection,
    required this.detectorSelectedButtons,
    this.detectedChord,
    this.audioReport,
    this.isAnalyzingAudio = false,
    this.loadedAudioFileName,
    this.showMultiBeatModal = false,
    String? multiBeatPattern,
    this.multiBeatChord,
    this.dock = const DockState(),
    bool? isMetronomeActive,
    double? metronomeVolume,
    this.bassRhythmPatterns = const [],
    this.selectedBassRhythmPatternId,
    this.selectedBassRowTarget = AccordionRowTarget.middleRow,
    this.isBassMetronomeActive = false,
    this.bassRhythmElapsedSeconds = 0.0,
    double? manualMetronomeBpm,
    this.bassRhythmRecorder,
    this.isBassCapturePanelOpen = false,
    bool? isLiveChordMarkerActive,
    this.copiedChord = '',
    double? bpmCalibrationStart,
    double? audioStartOffset,
    bool? isPlaybackAutoChordDetectEnabled,
    double? beatNudgeOffset,
  }) : _audioStartOffset = audioStartOffset ?? 0.0,
       _bpmCalibrationStart = bpmCalibrationStart ?? -1.0,
       _manualMetronomeBpm = manualMetronomeBpm ?? 120.0,
       _isPlaybackAutoChordDetectEnabled =
           isPlaybackAutoChordDetectEnabled ?? false,
       _beatNudgeOffset = beatNudgeOffset ?? 0.0,
       _markedBeats = markedBeats ?? const {},
       _multiBeatAssignmentTargets = multiBeatAssignmentTargets ?? const {},
       _yellowDecisionBeats = yellowDecisionBeats ?? const {},
       _multiBeatPattern = multiBeatPattern ?? '',
       _isMetronomeActive = isMetronomeActive ?? false,
       _metronomeVolume = metronomeVolume ?? 0.8,
       _isLiveChordMarkerActive = isLiveChordMarkerActive ?? false;

  AccordionSimulatorState copyWith({
    NotationMode? notation,
    bool? showDiapason1,
    bool? showDiapason2,
    TuningDefinition? tuning1,
    BellowsMode? bellows1,
    bool? isBass1Collapsed,
    bool? mirror1,
    double? volume1,
    bool? isMuted1,
    TuningDefinition? tuning2,
    BellowsMode? bellows2,
    bool? isBass2Collapsed,
    bool? mirror2,
    double? volume2,
    bool? isMuted2,
    bool? syncVolume,
    Set<String>? activeButtons,
    AudioTransportState? transport,
    bool? isPlayingAudio,
    double? currentAudioTime,
    double? currentCompasTime,
    double? totalAudioDuration,
    bool? syncDiapason,
    bool? isAudioCoupled,
    double? compasVolume,
    Set<int>? playingChordNotes,
    bool? sequenceMode,
    int? visibleGridRows,
    List<MeasureRow>? measures,
    int? selectedBarIndex,
    int? selectedBeatIndex,
    bool? isManualBeatSelection,
    Set<int>? markedBeats,
    bool? isMultiBeatAssignmentMode,
    Set<int>? multiBeatAssignmentTargets,
    Set<int>? yellowDecisionBeats,
    FreeChordState? freeChord,
    int? freeChordRoot,
    String? freeChordType,
    String? freeChordFourth,
    String? freeChordOctave,
    String? freeChordMode,
    bool? isFreeChordFixed,
    bool? isFreeChordBeingEdited,
    BellowsMode? freeChordBellows,
    String? freeChordScaleHarmonicMode,
    bool? detectorMode,
    String? detectorDirection,
    List<String>? detectorSelectedButtons,
    DetectedChordModel? detectedChord,
    AudioAnalysisReport? audioReport,
    bool? isAnalyzingAudio,
    String? loadedAudioFileName,
    bool clearAudio = false,
    bool clearAudioReport = false,
    bool clearDetectedChord = false,
    bool? showMultiBeatModal,
    String? multiBeatPattern,
    String? multiBeatChord,
    bool clearMultiBeatChord = false,
    DockState? dock,
    bool? isCompas1Undocked,
    Offset? compas1Position,
    bool? isCompas2Undocked,
    Offset? compas2Position,
    bool? isSongBarUndocked,
    Offset? songBarPosition,
    bool? isChordDetectorUndocked,
    Offset? chordDetectorPosition,
    String? freeChordBass,
    bool? isMetronomeActive,
    double? metronomeVolume,
    List<BassRhythmPattern>? bassRhythmPatterns,
    String? selectedBassRhythmPatternId,
    bool clearSelectedBassRhythmPattern = false,
    AccordionRowTarget? selectedBassRowTarget,
    bool? isBassMetronomeActive,
    double? bassRhythmElapsedSeconds,
    double? manualMetronomeBpm,
    BassRhythmRecorder? bassRhythmRecorder,
    bool clearBassRhythmRecorder = false,
    bool? isBassCapturePanelOpen,
    bool? isLiveChordMarkerActive,
    String? copiedChord,
    double? bpmCalibrationStart,
    double? audioStartOffset,
    bool? isPlaybackAutoChordDetectEnabled,
    double? beatNudgeOffset,
  }) {
    // Merge del transporte: primero el grupo, luego los campos planos.
    final mergedTransport = (transport ?? this.transport).copyWith(
      isPlayingAudio: isPlayingAudio,
      currentAudioTime: currentAudioTime,
      currentCompasTime: currentCompasTime ?? compasTime,
      totalAudioDuration: totalAudioDuration,
      isAudioCoupled: isAudioCoupled,
      compasVolume: compasVolume,
    );
    // Merge del acorde libre: primero el grupo, luego los campos planos.
    final mergedFreeChord = (freeChord ?? this.freeChord).copyWith(
      root: freeChordRoot,
      type: freeChordType,
      fourth: freeChordFourth,
      octave: freeChordOctave,
      mode: freeChordMode,
      isFixed: isFreeChordFixed,
      isBeingEdited: isFreeChordBeingEdited,
      bellows: freeChordBellows,
      scaleHarmonicMode: freeChordScaleHarmonicMode,
      bass: freeChordBass,
    );
    // Merge del estado de acople: primero el grupo, luego los campos planos.
    final mergedDock = (dock ?? this.dock).copyWith(
      isCompas1Undocked: isCompas1Undocked,
      compas1Position: compas1Position,
      isCompas2Undocked: isCompas2Undocked,
      compas2Position: compas2Position,
      isSongBarUndocked: isSongBarUndocked,
      songBarPosition: songBarPosition,
      isChordDetectorUndocked: isChordDetectorUndocked,
      chordDetectorPosition: chordDetectorPosition,
    );

    return AccordionSimulatorState(
      audioStartOffset: audioStartOffset ?? this.audioStartOffset,
      bpmCalibrationStart: bpmCalibrationStart ?? this.bpmCalibrationStart,
      isPlaybackAutoChordDetectEnabled:
          isPlaybackAutoChordDetectEnabled ??
          this.isPlaybackAutoChordDetectEnabled,
      beatNudgeOffset: beatNudgeOffset ?? this.beatNudgeOffset,
      notation: notation ?? this.notation,
      showDiapason1: showDiapason1 ?? this.showDiapason1,
      showDiapason2: showDiapason2 ?? this.showDiapason2,
      tuning1: tuning1 ?? this.tuning1,
      bellows1: bellows1 ?? this.bellows1,
      isBass1Collapsed: isBass1Collapsed ?? this.isBass1Collapsed,
      mirror1: mirror1 ?? this.mirror1,
      volume1: volume1 ?? this.volume1,
      isMuted1: isMuted1 ?? this.isMuted1,
      tuning2: tuning2 ?? this.tuning2,
      bellows2: bellows2 ?? this.bellows2,
      isBass2Collapsed: isBass2Collapsed ?? this.isBass2Collapsed,
      mirror2: mirror2 ?? this.mirror2,
      volume2: volume2 ?? this.volume2,
      isMuted2: isMuted2 ?? this.isMuted2,
      syncVolume: syncVolume ?? this.syncVolume,
      activeButtons: activeButtons ?? this.activeButtons,
      transport: mergedTransport,
      syncDiapason: syncDiapason ?? this.syncDiapason,
      playingChordNotes: playingChordNotes ?? this.playingChordNotes,
      sequenceMode: sequenceMode ?? this.sequenceMode,
      visibleGridRows: visibleGridRows ?? this.visibleGridRows,
      measures: measures ?? this.measures,
      selectedBarIndex: selectedBarIndex ?? this.selectedBarIndex,
      selectedBeatIndex: selectedBeatIndex ?? this.selectedBeatIndex,
      isManualBeatSelection:
          isManualBeatSelection ?? this.isManualBeatSelection,
      markedBeats: markedBeats ?? this.markedBeats,
      isMultiBeatAssignmentMode:
          isMultiBeatAssignmentMode ?? this.isMultiBeatAssignmentMode,
      multiBeatAssignmentTargets:
          multiBeatAssignmentTargets ?? this.multiBeatAssignmentTargets,
      yellowDecisionBeats: yellowDecisionBeats ?? this.yellowDecisionBeats,
      freeChord: mergedFreeChord,
      detectorMode: detectorMode ?? this.detectorMode,
      detectorDirection: detectorDirection ?? this.detectorDirection,
      detectorSelectedButtons:
          detectorSelectedButtons ?? this.detectorSelectedButtons,
      detectedChord: clearDetectedChord
          ? null
          : (detectedChord ?? this.detectedChord),
      audioReport: clearAudio || clearAudioReport
          ? null
          : (audioReport ?? this.audioReport),
      isAnalyzingAudio: isAnalyzingAudio ?? this.isAnalyzingAudio,
      loadedAudioFileName: clearAudio
          ? null
          : (loadedAudioFileName ?? this.loadedAudioFileName),
      showMultiBeatModal: showMultiBeatModal ?? this.showMultiBeatModal,
      multiBeatPattern: multiBeatPattern ?? this.multiBeatPattern,
      multiBeatChord: clearMultiBeatChord
          ? null
          : (multiBeatChord ?? this.multiBeatChord),
      dock: mergedDock,
      isMetronomeActive: isMetronomeActive ?? this.isMetronomeActive,
      metronomeVolume: metronomeVolume ?? this.metronomeVolume,
      bassRhythmPatterns: bassRhythmPatterns ?? this.bassRhythmPatterns,
      selectedBassRhythmPatternId: clearSelectedBassRhythmPattern
          ? null
          : (selectedBassRhythmPatternId ?? this.selectedBassRhythmPatternId),
      selectedBassRowTarget:
          selectedBassRowTarget ?? this.selectedBassRowTarget,
      isBassMetronomeActive:
          isBassMetronomeActive ?? this.isBassMetronomeActive,
      bassRhythmElapsedSeconds:
          bassRhythmElapsedSeconds ?? this.bassRhythmElapsedSeconds,
      manualMetronomeBpm: manualMetronomeBpm ?? this.manualMetronomeBpm,
      bassRhythmRecorder: clearBassRhythmRecorder
          ? null
          : (bassRhythmRecorder ?? this.bassRhythmRecorder),
      isBassCapturePanelOpen:
          isBassCapturePanelOpen ?? this.isBassCapturePanelOpen,
      isLiveChordMarkerActive:
          isLiveChordMarkerActive ?? this.isLiveChordMarkerActive,
      copiedChord: copiedChord ?? this.copiedChord,
    );
  }

  Map<String, List<TrebleButtonModel>> get trebleData1 =>
      AccordionData.getTransposedTreble(tuning1.offset);

  List<BassButtonModel> get bassData1 =>
      AccordionData.getTransposedBasses(tuning1.offset);

  Map<String, List<TrebleButtonModel>> get trebleData2 =>
      AccordionData.getTransposedTreble(tuning2.offset);

  List<BassButtonModel> get bassData2 =>
      AccordionData.getTransposedBasses(tuning2.offset);
}

class AccordionSimulatorNotifier extends Notifier<AccordionSimulatorState>
    with HoareContract {
  late AudioEngine _audioBridge;
  late AudioAnalyzer _analyzer;
  late AudioFileLoader _fileLoader;
  late AudioFilePlayer _audioPlayer;
  late DemoTrackGenerator _demoGenerator;
  late FreeChordPlaybackCoordinator _freeChordCoordinator;
  Uint8List? _loadedAudioBytes;

  /// Identificador de la carga vigente. Sirve para descartar hidrataciones de
  /// duración que llegan tarde (p. ej. al reemplazar la pista antes de que el
  /// navegador publique `loadedmetadata`).
  int _audioLoadGeneration = 0;

  /// Marca de ciclo de vida para no mutar el estado tras el `dispose` del
  /// notifier (p. ej. hidrataciones de duración que llegan tarde en tests).
  bool _disposed = false;
  final GridHistoryManager _gridHistory = GridHistoryManager();

  /// Visibilidad de prueba: reemplaza el estado completo sin pasar por copyWith.
  @visibleForTesting
  void applyRawState(AccordionSimulatorState s) => state = s;

  /// Reemplaza el estado completo. Uso interno desde coordinadores de la misma
  /// capa de presentación que comparten la misma fuente de verdad.
  void replaceState(AccordionSimulatorState s) => state = s;

  bool get canUndoGrid => _gridHistory.canUndo;
  bool get canRedoGrid => _gridHistory.canRedo;

  void undoGrid() {
    final memento = _gridHistory.undo(
      currentMeasures: state.measures,
      currentMarkedBeats: state.markedBeats,
      currentYellowDecisionBeats: state.yellowDecisionBeats,
    );
    if (memento != null) {
      state = state.copyWith(
        measures: memento.measures,
        markedBeats: memento.markedBeats,
        yellowDecisionBeats: memento.yellowDecisionBeats,
      );
    }
  }

  void redoGrid() {
    final memento = _gridHistory.redo(
      currentMeasures: state.measures,
      currentMarkedBeats: state.markedBeats,
      currentYellowDecisionBeats: state.yellowDecisionBeats,
    );
    if (memento != null) {
      state = state.copyWith(
        measures: memento.measures,
        markedBeats: memento.markedBeats,
        yellowDecisionBeats: memento.yellowDecisionBeats,
      );
    }
  }

  @override
  AccordionSimulatorState build() {
    _audioBridge = ref.read(audioEngineProvider);
    _analyzer = ref.read(audioAnalyzerProvider);
    _fileLoader = ref.read(audioFileLoaderProvider);
    _audioPlayer = ref.read(audioFilePlayerProvider);
    _demoGenerator = ref.read(demoTrackGeneratorProvider);
    _freeChordCoordinator = FreeChordPlaybackCoordinator(
      () => state,
      (s) => state = s,
      () => ref.read(audioEngineProvider),
    );
    ref.onDispose(() {
      _disposed = true;
      _playbackTimer?.cancel();
      _standaloneMetronomeTimer?.cancel();
      _bassCaptureTimer?.cancel();
    });

    // Generar compases iniciales por defecto (8 compases con 4 tiempos)
    final initialMeasures = List.generate(8, (bIdx) {
      return MeasureRow(
        barNumber: bIdx + 1,
        beats: List.generate(4, (beatIdx) {
          final timeSec = (bIdx * 4 + beatIdx) * 0.5;
          return MeasureBeat(
            barIndex: bIdx,
            beatIndex: beatIdx,
            chord: '',
            timeText: formatBeatTime(timeSec),
            isContinue: false,
          );
        }),
      );
    });

    return AccordionSimulatorState(
      notation: NotationMode.latina,
      showDiapason1: true,
      showDiapason2: true,
      tuning1: TuningRegistry.defaultTunings[0], // Cinco Letras
      bellows1: BellowsMode.both,
      isBass1Collapsed: false,
      mirror1: false,
      volume1: 0.8,
      isMuted1: false,
      tuning2: TuningRegistry.defaultTunings[1], // Rey Vallenato
      bellows2: BellowsMode.both,
      isBass2Collapsed: true,
      mirror2: false,
      volume2: 0.8,
      isMuted2: false,
      syncVolume: true,
      activeButtons: const {},
      transport: const AudioTransportState(
        isPlayingAudio: false,
        currentAudioTime: 0.0,
        currentCompasTime: 0.0,
        totalAudioDuration: 180.0,
        isAudioCoupled: true,
        compasVolume: 0.8,
      ),
      syncDiapason: true,
      playingChordNotes: const {},
      sequenceMode: true,
      visibleGridRows: 4,
      measures: initialMeasures,
      selectedBarIndex: null,
      selectedBeatIndex: null,
      freeChord: const FreeChordState(
        root: 0, // Do
        type: 'maj',
        fourth: 'none',
        octave: 'all',
        mode: 'harmonic',
        isFixed: false,
        bellows: BellowsMode.both,
        scaleHarmonicMode: 'triad',
      ),
      detectorMode: false,
      detectorDirection: 'auto',
      detectorSelectedButtons: const [],
      detectedChord: null,
      bassRhythmPatterns: BassRhythmCatalog.patterns,
    );
  }

  // Toggles de cabecera
  void toggleDiapason1() {
    state = state.copyWith(showDiapason1: !state.showDiapason1);
  }

  void toggleDiapason2() {
    state = state.copyWith(showDiapason2: !state.showDiapason2);
  }

  void toggleUndockCompas(int accordionNumber) {
    if (accordionNumber == 1) {
      state = state.copyWith(isCompas1Undocked: !state.isCompas1Undocked);
    } else {
      state = state.copyWith(isCompas2Undocked: !state.isCompas2Undocked);
    }
  }

  void setCompasPosition(int accordionNumber, Offset position) {
    if (accordionNumber == 1) {
      state = state.copyWith(compas1Position: position);
    } else {
      state = state.copyWith(compas2Position: position);
    }
  }

  void toggleUndockSongBar() {
    state = state.copyWith(isSongBarUndocked: !state.isSongBarUndocked);
  }

  void setSongBarPosition(Offset position) {
    state = state.copyWith(songBarPosition: position);
  }

  void toggleUndockChordDetector() {
    state = state.copyWith(
      isChordDetectorUndocked: !state.isChordDetectorUndocked,
    );
  }

  void setChordDetectorPosition(Offset position) {
    state = state.copyWith(chordDetectorPosition: position);
  }

  void setFreeChordBass(String bass) {
    state = state.copyWith(freeChordBass: bass, isFreeChordBeingEdited: true);
  }

  void setNotation(NotationMode notation) {
    if (state.notation == notation) return;

    final convertedMeasures = state.measures.map((row) {
      final updatedBeats = row.beats.map((beat) {
        if (beat.chord.trim().isEmpty) return beat;
        final converted = ChordCatalog.formatChordForNotation(
          beat.chord,
          notation,
        );
        return beat.copyWith(chord: converted);
      }).toList();
      return MeasureRow(barNumber: row.barNumber, beats: updatedBeats);
    }).toList();

    final convertedDetected =
        state.detectedChord != null && state.detectedChord!.notes.isNotEmpty
        ? ChordDetectorEngine.detect(
            midiNotes: state.detectedChord!.notes,
            notation: notation,
          )
        : null;

    state = state.copyWith(
      notation: notation,
      measures: convertedMeasures,
      detectedChord: convertedDetected ?? state.detectedChord,
      multiBeatChord:
          state.multiBeatChord != null && state.multiBeatChord!.isNotEmpty
          ? ChordCatalog.formatChordForNotation(state.multiBeatChord!, notation)
          : state.multiBeatChord,
    );
  }

  Timer? _playbackTimer;

  // Carga y Análisis de Audio con DSP Rust
  /// IMPORTANTE (Web): no debe haber ningún `await` antes de `pickAudioFile()`
  /// para que el navegador conserve el gesto del usuario y abra el selector.
  Future<AudioLoadResult> pickAndLoadAudio() async {
    try {
      final picked = await _fileLoader.pickAudioFile();
      if (picked == null) return const AudioLoadCancelled();
      final result = loadAudioBytes(picked.bytes, picked.name);
      if (result is AudioLoadFailure) return result;
      return await _confirmEffectiveAudioLoad(picked.name);
    } catch (e) {
      state = state.copyWith(isAnalyzingAudio: false);
      return AudioLoadFailure('Error al cargar audio: $e');
    }
  }

  /// Carga una pista demo clásica de Vallenato sin analizarla.
  Future<AudioLoadResult> loadDemoAudioTrack() async {
    try {
      final result = loadAudioBytes(
        _demoGenerator.generate(),
        DemoTrackGenerator.demoFileName,
      );
      if (result is AudioLoadFailure) return result;
      return await _confirmEffectiveAudioLoad(DemoTrackGenerator.demoFileName);
    } catch (e) {
      state = state.copyWith(isAnalyzingAudio: false);
      return AudioLoadFailure('Error al procesar demo: $e');
    }
  }

  /// Confirma que el reproductor decodificó efectivamente el archivo.
  ///
  /// {P}: hay una pista registrada y el reproductor ya recibió los bytes.
  /// {Q}: devuelve [AudioLoadSuccess] con la duración hidratada cuando el
  ///      reproductor expone una duración positiva; en plataformas sin
  ///      transport (stub nativo) también hay éxito. Si el navegador no pudo
  ///      decodificar el archivo, la pista fantasma se limpia y se devuelve
  ///      [AudioLoadFailure].
  Future<AudioLoadResult> _confirmEffectiveAudioLoad(String fileName) async {
    if (!_audioPlayer.isLoaded) {
      // Plataforma sin reproducción real (stub): la pista se acepta.
      return AudioLoadSuccess(fileName);
    }
    final duration = await _audioPlayer.waitForDuration(
      timeout: const Duration(seconds: 8),
    );
    if (duration > 0) {
      if (!_disposed && state.loadedAudioFileName == fileName) {
        state = state.copyWith(totalAudioDuration: duration);
      }
      return AudioLoadSuccess(fileName);
    }
    // El navegador no publicó metadatos: el archivo no es decodificable.
    clearAudioReport();
    return const AudioLoadFailure(
      'El navegador no pudo decodificar el archivo de audio seleccionado.',
    );
  }

  /// Carga audio para reproducción. El análisis se solicita explícitamente mediante
  /// [analyzeLoadedAudio].
  ///
  /// {P}: `bytes` no vacío y `fileName` identifica la pista.
  /// {Q}: la pista queda disponible para reproducción y no se invoca el analizador.
  ///      La duración real puede resolverse de forma asíncrona cuando el
  ///      navegador publica `loadedmetadata`; [unawaited] de [_hydrateAudioDuration]
  ///      mantiene el transporte sincronizado sin bloquear el gesto del usuario.
  ///      En plataformas nativas el reproductor es un stub sin audio: la pista
  ///      se acepta pero sin transport real (`isLoaded == false`).
  AudioLoadResult loadAudioBytes(Uint8List bytes, String fileName) {
    // {P}: bytes no vacío y fileName identificable.
    if (bytes.isEmpty || fileName.trim().isEmpty) {
      return const AudioLoadFailure(
        'El archivo de audio está vacío o no tiene nombre.',
      );
    }
    if (state.isAnalyzingAudio) {
      return const AudioLoadFailure(
        'Espera a que termine el análisis actual antes de cargar otra pista.',
      );
    }

    // Detener cualquier reproducción anterior antes de cargar la nueva pista.
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    _audioBridge.allNotesOff();
    _currentBeatNotes = [];

    try {
      _audioPlayer.load(bytes, _mimeTypeFor(fileName));
      _audioPlayer.setVolume(state.compasVolume);
    } catch (e) {
      return AudioLoadFailure('Error al preparar la pista para reproducción: $e');
    }

    // La duración puede no conocerse todavía: en web el `<audio>` publica
    // `loadedmetadata` después de `load()`. No se trata como error; se hidrata
    // en segundo plano para conservar la carga efectiva del archivo.
    final loadedDuration = _audioPlayer.durationSeconds;
    _loadedAudioBytes = Uint8List.fromList(bytes);

    // Invalida cualquier hidratación en vuelo de una pista anterior.
    final generation = ++_audioLoadGeneration;

    state = state.copyWith(
      isAnalyzingAudio: false,
      clearAudioReport: true,
      loadedAudioFileName: fileName,
      totalAudioDuration: loadedDuration > 0 ? loadedDuration : 0.0,
      currentAudioTime: 0.0,
      currentCompasTime: 0.0,
      isPlayingAudio: false,
    );
    _hydrateAudioDuration(generation, fileName);
    // {Q}: la pista queda registrada sin reproducción activa ni análisis pendiente.
    ensure(
      'loadAudioBytes',
      'la pista cargada queda registrada',
      state.loadedAudioFileName == fileName,
    );
    ensure(
      'loadAudioBytes',
      'no hay reproducción activa tras la carga',
      !state.isPlayingAudio,
    );
    return AudioLoadSuccess(fileName);
  }

  /// Completa la duración real del audio cuando el reproductor la publica.
  ///
  /// {P}: `generation` corresponde a la última carga y `fileName` sigue siendo
  ///      la pista activa.
  /// {Q}: si el reproductor expone una duración finita y positiva,
  ///      `totalAudioDuration` coincide con ella; en caso contrario el estado
  ///      no se altera.
  void _hydrateAudioDuration(int generation, String fileName) {
    unawaited(() async {
      final duration = await _audioPlayer.waitForDuration();
      if (_disposed) return;
      if (generation != _audioLoadGeneration) return;
      if (state.loadedAudioFileName != fileName) return;
      if (!duration.isFinite || duration <= 0) return;
      state = state.copyWith(totalAudioDuration: duration);
    }());
  }

  /// Analiza la pista previamente cargada y aplica sus resultados al acordeón.
  ///
  /// {P}: hay una pista cargada y el analizador no está ocupado.
  /// {Q}: el reporte, afinación y compases reflejan el análisis; ante error,
  /// `isAnalyzingAudio` vuelve a `false` y se devuelve un fallo explícito.
  Future<AudioLoadResult> analyzeLoadedAudio() async {
    final bytes = _loadedAudioBytes;
    final fileName = state.loadedAudioFileName;
    if (bytes == null || fileName == null) {
      return const AudioLoadFailure('Primero carga un archivo de audio.');
    }
    if (state.isAnalyzingAudio) {
      return const AudioLoadFailure('El análisis de audio ya está en curso.');
    }

    state = state.copyWith(isAnalyzingAudio: true);
    try {
      final report = await _analyzer.analyzeAudio(bytes, fileName);
      state = state.copyWith(
        isAnalyzingAudio: false,
        audioReport: report,
        totalAudioDuration: report.duration,
        currentAudioTime: 0.0,
        currentCompasTime: 0.0,
      );

      applyDetectedTuning(report.keyResult);
      generateMeasuresForAudio(
        durationSeconds: report.duration,
        bpm: report.bpm,
      );

      return AudioAnalysisSuccess(report, fileName);
    } catch (e) {
      state = state.copyWith(isAnalyzingAudio: false);
      return AudioLoadFailure('Error al analizar audio: $e');
    }
  }

  /// Asigna directamente el reporte de análisis de audio (útil para pruebas y sincronización).
  void setAudioReport(AudioAnalysisReport? report) {
    state = state.copyWith(audioReport: report);
  }

  /// Calibración del BPM con dos toques de la tecla Control (State: inactivo → esperando 2º toque).
  ///
  /// 1er toque: fija el inicio del Compás 1 en el segundo actual del audio (`audioStartOffset`)
  /// y regenera la cuadrícula alineada a ese punto de inicio.
  /// 2º toque: registra el inicio del compás siguiente (Compás 2), calcula el BPM con
  /// [CalibrateBpmFromTapsCommand], actualiza la tonalidad y aplica con precisión los
  /// cambios de acordes a los compases automáticamente.
  ///
  /// {P}: existe `audioReport`.
  /// {Q}: retorna el nuevo BPM tras el 2º toque válido (con `audioReport.bpm` y `audioStartOffset`
  ///      actualizados y cambios de acordes aplicados), o `null` tras el 1er toque / toque inválido.
  int? tapBpmCalibration() {
    final report = state.audioReport;
    if (report == null) return null;

    final now = state.currentAudioTime;
    if (!state.isCalibratingBpm) {
      // 1er toque: fija el inicio del Compás 1 en 'now'
      state = state.copyWith(bpmCalibrationStart: now, audioStartOffset: now);
      final dur = state.totalAudioDuration > 0
          ? state.totalAudioDuration
          : (report.duration > 0 ? report.duration : 60.0);
      generateMeasuresForAudio(
        durationSeconds: dur,
        bpm: report.bpm,
        startOffset: now,
      );
      return null;
    }

    final startTime = state.bpmCalibrationStart;
    final command = CalibrateBpmFromTapsCommand(
      startTime: startTime,
      endTime: now,
    );

    if (!command.canExecute()) {
      // Toque inválido (orden o rango): se toma como nuevo inicio de compás 1.
      state = state.copyWith(bpmCalibrationStart: now, audioStartOffset: now);
      return null;
    }

    final bpm = command.execute();
    // {P} del 2º toque: BPM calculado dentro del rango musical válido.
    require(
      'tapBpmCalibration',
      'el BPM calculado debe estar en [30,300]',
      bpm >= 30 && bpm <= 300,
    );
    state = state.copyWith(
      bpmCalibrationStart: -1.0,
      audioStartOffset: startTime,
    );
    updateAudioKeyAndBpm(
      rootMod: report.mainKey.rootMod,
      mode: report.mainKey.mode,
      bpm: bpm,
    );
    // Aplicar automáticamente la detección precisa de cambios de acorde al compás
    applyDetectedChordChangesToGrid();
    // {Q}: la calibración termina inactiva y el BPM aplicado coincide con el calculado.
    ensure(
      'tapBpmCalibration',
      'la calibración queda inactiva tras el 2º toque',
      !state.isCalibratingBpm,
    );
    ensure(
      'tapBpmCalibration',
      'el BPM aplicado coincide con el calculado',
      state.audioReport?.bpm == bpm,
    );
    return bpm;
  }

  /// Cancela una calibración de BPM en curso.
  void cancelBpmCalibration() =>
      state = state.copyWith(bpmCalibrationStart: -1.0);

  /// Tipo MIME según la extensión del archivo cargado.
  static String _mimeTypeFor(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.wav')) return 'audio/wav';
    if (name.endsWith('.mp3')) return 'audio/mpeg';
    if (name.endsWith('.ogg') || name.endsWith('.oga')) return 'audio/ogg';
    if (name.endsWith('.m4a') || name.endsWith('.mp4')) return 'audio/mp4';
    if (name.endsWith('.flac')) return 'audio/flac';
    if (name.endsWith('.aac')) return 'audio/aac';
    if (name.endsWith('.webm')) return 'audio/webm';
    return 'audio/mpeg';
  }

  void clearAudioReport() {
    stopAudio();
    _loadedAudioBytes = null;
    // Invalida hidrataciones pendientes de la pista cerrada.
    _audioLoadGeneration++;
    state = state.copyWith(clearAudio: true, isPlayingAudio: false);
  }

  void updateAudioKey(int rootMod, String mode) {
    final report = state.audioReport;
    updateAudioKeyAndBpm(
      rootMod: rootMod,
      mode: mode,
      bpm: report?.bpm ?? 120,
    );
  }

  void updateAudioBpm(int newBpm) {
    final report = state.audioReport;
    updateAudioKeyAndBpm(
      rootMod: report?.mainKey.rootMod ?? 0,
      mode: report?.mainKey.mode ?? 'major',
      bpm: newBpm,
    );
  }

  /// Actualiza la tonalidad principal y el BPM de forma conjunta y atómica,
  /// recalculando de forma efectiva los acordes en el reporte y en la cuadrícula
  /// de compases.
  ///
  /// Si aún no hay reporte (pista cargada sin analizar), se crea uno de reserva
  /// para que las opciones de tono/BPM estén siempre disponibles.
  ///
  /// {P}: `bpm` se clampea a [30, 300] y `rootMod` se interpreta módulo 12.
  /// {Q}: `audioReport` refleja el BPM clampeado y la tónica indicada, la
  ///      cuadrícula se reconstruye coherente y la afinación se aplica al
  ///      diapasón.
  void updateAudioKeyAndBpm({
    required int rootMod,
    required String mode,
    required int bpm,
  }) {
    final existingReport = state.audioReport;

    // {P}: bpm ∈ [30, 300] tras el clampeo y rootMod dentro de 0..11 módulo 12.
    require(
      'updateAudioKeyAndBpm',
      'bpm debe estar en [30,300] tras clampear',
      bpm.clamp(30, 300) >= 30 && bpm.clamp(30, 300) <= 300,
    );
    require(
      'updateAudioKeyAndBpm',
      'rootMod debe representarse módulo 12',
      rootMod >= 0,
    );

    final clampedBpm = bpm.clamp(30, 300);
    final report =
        existingReport ?? AudioAnalysisReport.placeholder(clampedBpm);
    final effectiveDuration = state.totalAudioDuration > 0
        ? state.totalAudioDuration
        : report.duration;
    final semitoneOffset =
        ((rootMod % 12) - (report.mainKey.rootMod % 12) + 12) % 12;

    final keyNames = _buildKeyNames(rootMod: rootMod, mode: mode);
    final (recName, recOffset, recRow) = const TuningRecommender().recommend(
      rootMod % 12,
    );
    final preferFlats = TuningRegistry.usesFlats(recOffset);

    final updatedKey = report.mainKey.copyWith(
      rootMod: rootMod % 12,
      mode: mode,
      keyNameLat: keyNames.$1,
      keyNameAle: keyNames.$2,
      recommendedTuning: recName,
      recommendedOffset: recOffset,
      recommendedRow: recRow,
    );

    // 1. Recalcular y transponer acordes del timeline
    final updatedChords = _transposeTimelineChords(
      chords: report.chords,
      semitoneOffset: semitoneOffset,
      newMode: mode,
      previousMode: report.mainKey.mode,
      preferFlats: preferFlats,
    );

    final updatedReport = report.copyWith(
      duration: effectiveDuration,
      bpm: clampedBpm,
      mainKey: updatedKey,
      chords: updatedChords,
    );

    final secondsPerBeat = 60.0 / clampedBpm;
    final totalBeats = (effectiveDuration / secondsPerBeat).ceil();
    final totalBars = ((totalBeats + 3) ~/ 4).clamp(8, 500);

    final newMeasures = _rebuildMeasuresForKeyChange(
      currentMeasures: state.measures,
      chords: updatedChords,
      totalBars: totalBars,
      secondsPerBeat: secondsPerBeat,
      bpmChanged: clampedBpm != report.bpm,
      semitoneOffset: semitoneOffset,
      preferFlats: preferFlats,
    );

    state = state.copyWith(audioReport: updatedReport, measures: newMeasures);

    // {Q}: el reporte actualizado refleja el BPM clampeado y la cuadrícula es coherente.
    ensure(
      'updateAudioKeyAndBpm',
      'el reporte actualizado mantiene el BPM clampeado',
      state.audioReport!.bpm == clampedBpm,
    );
    ensure(
      'updateAudioKeyAndBpm',
      'la cuadrícula reconstruida es no vacía',
      state.measures.isNotEmpty,
    );

    applyDetectedTuning(updatedKey);
  }

  /// Construye los nombres de tonalidad (latino y alemán) para `rootMod`/`mode`.
  /// Devuelve `(keyNameLat, keyNameAle)`.
  static (String, String) _buildKeyNames({
    required int rootMod,
    required String mode,
  }) {
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

    final isMajor = mode.toLowerCase() == 'major';
    return (
      '${noteNamesLat[rootMod % 12]} ${isMajor ? 'Mayor' : 'Menor'}',
      '${noteNamesAle[rootMod % 12]} ${isMajor ? 'Major' : 'Minor'}',
    );
  }

  /// Transpone los acordes del timeline al nuevo semitono. Si no hubo cambio de
  /// semitono ni de modo, devuelve la lista original sin copiar.
  static List<DetectedChordSegment> _transposeTimelineChords({
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

  /// Visibilidad de prueba: delega en [_buildKeyNames].
  @visibleForTesting
  static (String, String) buildKeyNamesForTest({
    required int rootMod,
    required String mode,
  }) => _buildKeyNames(rootMod: rootMod, mode: mode);

  /// Visibilidad de prueba: delega en [_transposeTimelineChords].
  @visibleForTesting
  static List<DetectedChordSegment> transposeTimelineChordsForTest({
    required List<DetectedChordSegment> chords,
    required int semitoneOffset,
    required String newMode,
    required String previousMode,
    required bool preferFlats,
  }) => _transposeTimelineChords(
        chords: chords,
        semitoneOffset: semitoneOffset,
        newMode: newMode,
        previousMode: previousMode,
        preferFlats: preferFlats,
      );

  /// Visibilidad de prueba: delega en [_rebuildMeasuresForKeyChange].
  @visibleForTesting
  static List<MeasureRow> rebuildMeasuresForKeyChangeForTest({
    required List<MeasureRow> currentMeasures,
    required List<DetectedChordSegment> chords,
    required int totalBars,
    required double secondsPerBeat,
    required bool bpmChanged,
    required int semitoneOffset,
    required bool preferFlats,
  }) => _rebuildMeasuresForKeyChange(
        currentMeasures: currentMeasures,
        chords: chords,
        totalBars: totalBars,
        secondsPerBeat: secondsPerBeat,
        bpmChanged: bpmChanged,
        semitoneOffset: semitoneOffset,
        preferFlats: preferFlats,
      );

  /// Delegaciones al servicio de dominio: la implementación vive en
  /// `domain/services/grid_metrics_service.dart` (único punto de verdad).
  static String formatBeatTime(double seconds) =>
      grid_metrics.formatBeatTime(seconds);

  static MeasureRow buildMeasureRow({
    required int barIndex,
    required double secondsPerBeat,
    double startOffset = 0.0,
    List<DetectedChordSegment> chords = const [],
    double chordProbeBias = 0.0,
    bool isContinue = false,
  }) =>
      grid_metrics.buildMeasureRow(
        barIndex: barIndex,
        secondsPerBeat: secondsPerBeat,
        startOffset: startOffset,
        chords: chords,
        chordProbeBias: chordProbeBias,
        isContinue: isContinue,
      );

  /// Visibilidad de prueba: delega en [grid_metrics.formatBeatTime].
  @visibleForTesting
  static String formatBeatTimeForTest(double seconds) =>
      grid_metrics.formatBeatTime(seconds);

  /// Reconstruye (o transpone) la cuadrícula de compases tras un cambio de
  /// tonalidad/BPM, respetando los acordes ya cargados cuando existan.
  static List<MeasureRow> _rebuildMeasuresForKeyChange({
    required List<MeasureRow> currentMeasures,
    required List<DetectedChordSegment> chords,
    required int totalBars,
    required double secondsPerBeat,
    required bool bpmChanged,
    required int semitoneOffset,
    required bool preferFlats,
  }) {
    final bool hasLoadedChords = currentMeasures.any(
      (m) => m.beats.any((b) => b.chord.trim().isNotEmpty),
    );

    final List<MeasureRow> newMeasures;
    if (hasLoadedChords && chords.isNotEmpty) {
      newMeasures = List.generate(
        totalBars,
        (barIdx) => buildMeasureRow(
          barIndex: barIdx,
          secondsPerBeat: secondsPerBeat,
          chords: chords,
        ),
      );
    } else if (bpmChanged) {
      newMeasures = List.generate(
        totalBars,
        (barIdx) => buildMeasureRow(
          barIndex: barIdx,
          secondsPerBeat: secondsPerBeat,
        ),
      );
    } else if (hasLoadedChords && semitoneOffset != 0) {
      newMeasures = currentMeasures.map((m) {
        return MeasureRow(
          barNumber: m.barNumber,
          beats: m.beats.map((b) {
            if (b.chord.trim().isEmpty) return b;
            final transposed = ChordCatalog.transposeChordSymbol(
              b.chord,
              semitoneOffset,
              preferFlats: preferFlats,
            );
            return b.copyWith(chord: transposed);
          }).toList(),
        );
      }).toList();
    } else {
      newMeasures = currentMeasures;
    }
    return newMeasures;
  }

  void applyDetectedTuning(KeyDetectionResult keyResult) {
    final match = TuningRegistry.defaultTunings.firstWhere(
      (t) => t.offset == keyResult.recommendedOffset,
      orElse: () => TuningRegistry.defaultTunings.first,
    );
    setTuning1(match);
  }

  /// Genera la cantidad de compases vacíos necesarios para cubrir la duración
  /// completa del audio cargado según su BPM y su desplazamiento de inicio de Compás 1.
  void generateMeasuresForAudio({
    required double durationSeconds,
    required int bpm,
    double? startOffset,
  }) {
    // {P}: BPM efectivo > 0 y duración no negativa.
    require(
      'generateMeasuresForAudio',
      'durationSeconds no negativa',
      durationSeconds >= 0.0,
    );
    final offset = startOffset ?? state.audioStartOffset;
    final effectiveBpm = bpm > 0 ? bpm : 120;
    final secondsPerBeat = 60.0 / effectiveBpm;
    final effectiveDuration = math.max(0.0, durationSeconds - offset);
    final totalBeats = (effectiveDuration / secondsPerBeat).ceil();
    // 4 tiempos por compás, con un mínimo de 8 compases
    final totalBars = ((totalBeats + 3) ~/ 4).clamp(8, 500);

    final generated = List.generate(
      totalBars,
      (barIdx) => buildMeasureRow(
        barIndex: barIdx,
        secondsPerBeat: secondsPerBeat,
        startOffset: offset,
      ),
    );

    state = state.copyWith(
      measures: generated,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
      isManualBeatSelection: false,
      audioStartOffset: offset,
    );

    // {Q}: la cuadrícula generada tiene entre 8 y 500 compases y cada compás 4 beats.
    ensure(
      'generateMeasuresForAudio',
      'la cuadrícula generada tiene entre 8 y 500 compases',
      state.measures.length >= 8 && state.measures.length <= 500,
    );
    ensure(
      'generateMeasuresForAudio',
      'cada compás tiene exactamente 4 tiempos',
      state.measures.every((m) => m.beats.length == 4),
    );
  }

  /// Aplica los cambios de acordes detectados en el archivo de audio a la cuadrícula de compases,
  /// marcando automáticamente cada beat donde ocurre un cambio armónico con precisión algorítmica.
  ApplyMeasureChordsResult? applyDetectedChordChangesToGrid() {
    final report = state.audioReport;
    if (report == null || report.chords.isEmpty || state.measures.isEmpty) {
      return null;
    }

    final command = ApplyMeasureChordsFromAudioCommand(
      measures: state.measures,
      chords: report.chords,
      bpm: report.bpm.toDouble(),
      startOffset: state.audioStartOffset,
      notation: state.notation,
    );

    if (!command.canExecute()) return null;

    _gridHistory.saveSnapshot(
      measures: state.measures,
      markedBeats: state.markedBeats,
      yellowDecisionBeats: state.yellowDecisionBeats,
    );

    final result = command.execute();

    state = state.copyWith(
      measures: result.updatedMeasures,
      markedBeats: result.updatedMarkedBeats,
    );

    return result;
  }

  /// Aplica los acordes detectados a los compases existentes posicionándolos en el tiempo exacto.
  void applyChordsToMeasures(List<DetectedChordSegment> chords) {
    if (chords.isEmpty) return;

    final report = state.audioReport;
    final effectiveBpm = (report?.bpm ?? 120).clamp(30, 300);
    final secondsPerBeat = 60.0 / effectiveBpm;
    final offset = state.audioStartOffset;

    final duration = report?.duration ?? chords.last.endTime;
    final effectiveDuration = math.max(0.0, duration - offset);
    final totalBeats = (effectiveDuration / secondsPerBeat).ceil();
    final totalBars = ((totalBeats + 3) ~/ 4).clamp(8, 500);

    final updatedMeasures = List.generate(
      totalBars,
      (barIdx) => buildMeasureRow(
        barIndex: barIdx,
        secondsPerBeat: secondsPerBeat,
        startOffset: offset,
        chords: chords,
        chordProbeBias: secondsPerBeat * 0.5,
        isContinue: false,
      ),
    );

    state = state.copyWith(measures: updatedMeasures);
  }

  // Controles Diapasón 1
  void setTuning1(TuningDefinition t) => state = state.copyWith(tuning1: t);
  void setBellows1(BellowsMode m) {
    state = state.copyWith(bellows1: m);
    if (state.detectorSelectedButtons.isNotEmpty) {
      _recalculateDetectedChord();
    }
  }

  void toggleBass1() =>
      state = state.copyWith(isBass1Collapsed: !state.isBass1Collapsed);
  void toggleMirror1() => state = state.copyWith(mirror1: !state.mirror1);
  void setVolume1(double vol) {
    state = state.copyWith(
      volume1: vol,
      volume2: state.syncVolume ? vol : state.volume2,
    );
    _audioBridge.setVolume(vol);
  }

  /// Volumen independiente de la sección Compás: controla la pista cargada y
  /// la intensidad de los acordes sintetizados que marca la cuadrícula.
  void setCompasVolume(double vol) {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(compasVolume: clamped);
    _audioPlayer.setVolume(clamped);
  }

  void toggleMute1() => state = state.copyWith(isMuted1: !state.isMuted1);

  // Controles Diapasón 2
  void setTuning2(TuningDefinition t) => state = state.copyWith(tuning2: t);
  void setBellows2(BellowsMode m) => state = state.copyWith(bellows2: m);
  void toggleBass2() =>
      state = state.copyWith(isBass2Collapsed: !state.isBass2Collapsed);
  void toggleMirror2() => state = state.copyWith(mirror2: !state.mirror2);
  void setVolume2(double vol) => state = state.copyWith(volume2: vol);
  void toggleMute2() => state = state.copyWith(isMuted2: !state.isMuted2);
  void toggleSyncVolume() =>
      state = state.copyWith(syncVolume: !state.syncVolume);

  // Interacción táctil / audio
  void pressButton(String buttonId, int midiNote) {
    if (state.detectorMode) {
      toggleDetectorButton(buttonId, midiNote);
      return;
    }
    final next = Set<String>.from(state.activeButtons)..add(buttonId);
    state = state.copyWith(activeButtons: next);
    _audioBridge.noteOn(midiNote);
  }

  void releaseButton(String buttonId, int midiNote) {
    if (state.detectorMode) return;
    final next = Set<String>.from(state.activeButtons)..remove(buttonId);
    state = state.copyWith(activeButtons: next);
    _audioBridge.noteOff(midiNote);
  }

  // Reproductor y Cuadrícula
  int? _lastPlayedBar;
  int? _lastPlayedBeat;
  String? _lastPlaybackDetectedChord;

  /// Convierte un símbolo de acorde textual en notas MIDI (octava 4, base 60=Do4)
  List<int> _chordSymbolToMidi(String chord) {
    final trimmed = chord.trim();
    if (trimmed.isEmpty) return [];

    final root = ChordCatalog.rootPitchClassForChordSymbol(trimmed);
    final pitchClasses = ChordCatalog.pitchClassesForChordSymbol(trimmed);
    if (root == null || pitchClasses.isEmpty) return [];

    final intervals =
        pitchClasses.map((pitchClass) => (pitchClass - root + 12) % 12).toList()
          ..sort();
    return intervals.map((interval) => 60 + root + interval).toList();
  }

  List<int> _currentBeatNotes = [];

  void _playBeatChord(int barIndex, int beatIndex) {
    // Apagar notas del beat anterior
    for (final n in _currentBeatNotes) {
      _audioBridge.noteOff(n);
    }
    _currentBeatNotes = [];

    if (barIndex < 0 || barIndex >= state.measures.length) {
      state = state.copyWith(playingChordNotes: const {});
      return;
    }
    final row = state.measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) {
      state = state.copyWith(playingChordNotes: const {});
      return;
    }

    // Si hay tiempos marcados, solo esos acordes se ejecutan.
    if (state.markedBeats.isNotEmpty &&
        !state.markedBeats.contains(beatKey(barIndex, beatIndex))) {
      state = state.copyWith(playingChordNotes: const {});
      return;
    }

    final beat = row.beats[beatIndex];
    final chord = beat.chord.trim().isNotEmpty
        ? beat.chord.trim()
        : state.isAudioCoupled
        ? _findChordForTime(
            state.audioReport?.chords ?? const [],
            state.currentAudioTime,
          )
        : '';
    if (chord.isEmpty) {
      state = state.copyWith(playingChordNotes: const {});
      return;
    }

    final notes = _chordSymbolToMidi(chord);
    final velocity = (0.65 * state.compasVolume).clamp(0.0, 1.0);
    for (final n in notes) {
      _audioBridge.noteOn(n, velocity: velocity);
    }
    _currentBeatNotes = notes;
    state = state.copyWith(
      playingChordNotes: notes.toSet(),
      bellows1: beat.bellows != BellowsMode.both
          ? beat.bellows
          : state.bellows1,
    );
  }

  /// Inicia o pausa el archivo aunque no exista análisis armónico.
  ///
  /// {P}: existe un archivo cargado o el Compás puede funcionar con su metrónomo.
  /// {Q}: el transporte se reproduce; `isAudioCoupled` solo decide si el reloj
  /// del Compás sigue la posición del archivo o avanza de manera independiente.
  void togglePlayAudio() {
    final nextPlaying = !state.isPlayingAudio;
    _playbackTimer?.cancel();

    if (!nextPlaying) {
      // Al pausar: pausar la pista y apagar notas activas
      state = state.copyWith(
        isPlayingAudio: false,
        playingChordNotes: const {},
      );
      _audioPlayer.pause();
      for (final n in _currentBeatNotes) {
        _audioBridge.noteOff(n);
      }
      _currentBeatNotes = [];
      _audioBridge.noteOff(84);
      _audioBridge.noteOff(76);
      _syncStandaloneMetronome();
      return;
    }

    _stopStandaloneMetronome();
    state = state.copyWith(
      isPlayingAudio: true,
      isFreeChordBeingEdited: false,
      isManualBeatSelection: false,
    );
    _lastPlayedBar = null;
    _lastPlayedBeat = null;
    _lastPlaybackRhythmPosition = 0;
    final startingPattern = state.selectedBassRhythmPattern;
    if (startingPattern != null &&
        (state.isMetronomeActive || state.isBassMetronomeActive)) {
      _playBassRhythmHitsBetween(0, 0, startingPattern, includeStart: true);
    }

    // El archivo siempre se reproduce si está cargado; el acoplamiento solo
    // decide si su posición gobierna también el compás.
    if (_audioPlayer.isLoaded) {
      _audioPlayer.seek(state.currentAudioTime);
      _audioPlayer.play();
    } else {
      _audioPlayer.pause();
    }
    if (state.isAudioCoupled) {
      state = state.copyWith(currentCompasTime: state.currentAudioTime);
    }

    final bpm =
        state.audioReport?.bpm.toDouble() ??
        state.selectedBassRhythmPattern?.quarterNotesPerMinute ??
        120.0;
    final rhythmClockStep = _rhythmClockStep(state.selectedBassRhythmPattern);
    final timerQuarterStep = math.min(0.5, rhythmClockStep);
    final intervalMs = ((60.0 / bpm * timerQuarterStep) * 1000).round().clamp(
      50,
      1000,
    );

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
      timer,
    ) {
      if (!state.isPlayingAudio) {
        timer.cancel();
        return;
      }

      final fileLoaded = _audioPlayer.isLoaded;
      final fileDrivesCompas = fileLoaded && state.isAudioCoupled;
      final audioDur = _audioPlayer.durationSeconds;
      final totalDur = fileLoaded && audioDur > 0
          ? audioDur
          : (state.totalAudioDuration > 0 ? state.totalAudioDuration : 16.0);

      // Si la pista terminó (y ya avanzó más allá del inicio > 0.5s), detener y volver al inicio.
      if (fileLoaded &&
          _audioPlayer.positionSeconds > 0.5 &&
          _audioPlayer.positionSeconds >= totalDur - 0.1) {
        timer.cancel();
        _audioPlayer.stop();
        _audioBridge.allNotesOff();
        _currentBeatNotes = [];
        state = state.copyWith(
          isPlayingAudio: false,
          currentAudioTime: 0.0,
          currentCompasTime: 0.0,
          selectedBarIndex: 0,
          selectedBeatIndex: 0,
          playingChordNotes: const {},
        );
        _syncStandaloneMetronome();
        return;
      }

      final nextAudioTime = fileLoaded
          ? _audioPlayer.positionSeconds
          : state.currentAudioTime + (intervalMs / 1000.0);
      final wrappedAudioTime = !fileLoaded && nextAudioTime >= totalDur
          ? 0.0
          : nextAudioTime;
      final nextCompasTime = fileDrivesCompas
          ? wrappedAudioTime
          : state.compasTime + (intervalMs / 1000.0);
      final compasDuration = state.measures.length * 4 * (60.0 / bpm);
      final wrappedCompasTime =
          !fileDrivesCompas && nextCompasTime >= compasDuration
          ? 0.0
          : nextCompasTime;

      final beatDuration = 60.0 / bpm;
      final effectiveOffset = state.effectiveAudioStartOffset;
      final effectiveTime = math.max(0.0, wrappedCompasTime - effectiveOffset);
      final totalBeats = (effectiveTime / beatDuration).floor();
      final currentBar = wrappedCompasTime >= effectiveOffset
          ? (totalBeats ~/ 4) %
                (state.measures.isNotEmpty ? state.measures.length : 8)
          : 0;
      final currentBeat = wrappedCompasTime >= effectiveOffset
          ? totalBeats % 4
          : 0;

      state = state.copyWith(
        currentAudioTime: wrappedAudioTime,
        currentCompasTime: wrappedCompasTime,
        totalAudioDuration: audioDur > 0 ? audioDur : null,
        selectedBarIndex: currentBar,
        selectedBeatIndex: currentBeat,
        isManualBeatSelection: false,
      );

      // Detección automática en reproducción: ÚNICAMENTE cuando ocurre una transición armónica
      if (state.isAudioCoupled && state.isPlaybackAutoChordDetectEnabled) {
        _checkPlaybackAutoChordChange(wrappedAudioTime);
      }

      // Reproducir acorde al entrar en un nuevo beat
      if (currentBar != _lastPlayedBar || currentBeat != _lastPlayedBeat) {
        _lastPlayedBar = currentBar;
        _lastPlayedBeat = currentBeat;
        _playBeatChord(currentBar, currentBeat);
        if (state.selectedBassRhythmPattern == null &&
            (state.isMetronomeActive || state.isBassMetronomeActive)) {
          final pattern = state.selectedBassRhythmPattern;
          playMetronomeTick(
            pattern == null ? currentBeat : totalBeats,
            beatsPerMeasure: pattern?.beatsPerMeasureInQuarterNotes ?? 4,
          );
        }
      }
      if (state.selectedBassRhythmPattern != null &&
          (state.isMetronomeActive || state.isBassMetronomeActive)) {
        final pattern = state.selectedBassRhythmPattern!;
        final currentRhythmPosition = effectiveTime * bpm / 60.0;
        final previousRhythmPosition =
            _lastPlaybackRhythmPosition ?? currentRhythmPosition;
        if (currentRhythmPosition < previousRhythmPosition) {
          _playBassRhythmHitsBetween(
            0,
            currentRhythmPosition,
            pattern,
            includeStart: true,
          );
        } else {
          _playBassRhythmHitsBetween(
            previousRhythmPosition,
            currentRhythmPosition,
            pattern,
          );
        }
        _lastPlaybackRhythmPosition = currentRhythmPosition;
      }
    });
  }

  void stopAudio() {
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    _currentBeatNotes = [];
    _audioBridge.noteOff(84);
    _audioBridge.noteOff(76);
    _lastPlaybackDetectedChord = null;
    state = state.copyWith(
      isPlayingAudio: false,
      currentAudioTime: 0.0,
      currentCompasTime: 0.0,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
      playingChordNotes: const {},
    );
    _audioBridge.allNotesOff();
    _syncStandaloneMetronome();
  }

  Timer? _standaloneMetronomeTimer;
  int _standaloneBeat = 0;
  double _standaloneElapsedQuarterBeats = 0;
  double? _lastPlaybackRhythmPosition;
  final MusicXmlRhythmImporter _rhythmImporter = MusicXmlRhythmImporter();

  /// {P}: el selector de archivos puede devolver un MusicXML de texto o cancelar.
  /// {Q}: al importar, las pistas disponibles reemplazan las anteriores y la
  /// primera queda seleccionada; cancelar conserva el estado actual.
  Future<BassRhythmImportSummary?> importBassRhythmPatterns() async {
    final content = await ref
        .read(fileStorageProvider)
        .pickTextFile(allowedExtensions: const ['musicxml', 'xml']);
    if (content == null) return null;

    final summary = _rhythmImporter.importPatterns(content);
    final builtInPatterns = state.bassRhythmPatterns
        .where((pattern) => pattern.id.startsWith('builtin:'));
    state = state.copyWith(
      bassRhythmPatterns: [...builtInPatterns, ...summary.patterns],
      selectedBassRhythmPatternId: summary.patterns.first.id,
      bassRhythmElapsedSeconds: 0,
    );
    _syncStandaloneMetronome();
    return summary;
  }

  /// {P}: el identificador es nulo o pertenece a un patrón importado.
  /// {Q}: el reloj del patrón inicia en cero y el metrónomo conserva el BPM correcto.
  void selectBassRhythmPattern(String? patternId) {
    if (patternId != null &&
        !state.bassRhythmPatterns.any((pattern) => pattern.id == patternId)) {
      throw ArgumentError.value(
        patternId,
        'patternId',
        'No corresponde a un patrón rítmico importado.',
      );
    }
    state = state.copyWith(
      selectedBassRhythmPatternId: patternId,
      clearSelectedBassRhythmPattern: patternId == null,
      bassRhythmElapsedSeconds: 0,
    );
    _syncStandaloneMetronome();
  }

  /// Selecciona la hilera melódica objetivo (Externa, Media, Interna) para el patrón de bajos.
  ///
  /// {P}: `target` no nulo.
  /// {Q}: `state.selectedBassRowTarget == target`.
  void selectBassRowTarget(AccordionRowTarget target) {
    if (state.selectedBassRowTarget == target) return;
    state = state.copyWith(selectedBassRowTarget: target);
  }

  /// Selecciona un ritmo del catálogo y comienza a ejecutarlo inmediatamente.
  void playBassRhythmPattern(String patternId) {
    if (!state.bassRhythmPatterns.any((pattern) => pattern.id == patternId)) {
      throw ArgumentError.value(
        patternId,
        'patternId',
        'No corresponde a un patrón rítmico disponible.',
      );
    }
    state = state.copyWith(
      selectedBassRhythmPatternId: patternId,
      isBassMetronomeActive: true,
      bassRhythmElapsedSeconds: 0,
    );
    _syncStandaloneMetronome();
  }

  /// Detiene la ejecución del ritmo de bajos sin borrar el patrón elegido.
  void stopBassRhythm() {
    if (!state.isBassMetronomeActive) return;
    state = state.copyWith(
      isBassMetronomeActive: false,
      bassRhythmElapsedSeconds: 0,
    );
    _syncStandaloneMetronome();
  }

  /// Alterna la reproducción del patrón indicado: si ya suena, lo detiene;
  /// si no, lo selecciona y arranca el metrónomo de bajos.
  ///
  /// {P}: `patternId` pertenece a `bassRhythmPatterns`.
  /// {Q}: tras la llamada `isBassMetronomeActive == false` (si sonaba ese
  ///      patrón) o `selectedBassRhythmPatternId == patternId ∧
  ///      isBassMetronomeActive == true` (si no sonaba).
  void toggleBassRhythmPatternPlayback(String patternId) {
    require(
      'toggleBassRhythmPatternPlayback',
      'el patrón existe en la biblioteca',
      state.bassRhythmPatterns.any((pattern) => pattern.id == patternId),
    );
    final isCurrent = state.selectedBassRhythmPatternId == patternId;
    if (isCurrent && state.isBassMetronomeActive) {
      stopBassRhythm();
      return;
    }
    playBassRhythmPattern(patternId);
    ensure(
      'toggleBassRhythmPatternPlayback',
      'el patrón queda seleccionado y sonando',
      state.selectedBassRhythmPatternId == patternId &&
          state.isBassMetronomeActive,
    );
  }

  /// Reproduce el patrón seleccionado, o el primero disponible si no hay
  /// selección. Si ya está sonando, lo detiene.
  ///
  /// {Q}: si hay patrones, el transporte de bajos queda en reproducción o
  ///      detenido de forma consistente con su estado previo.
  void toggleSelectedBassRhythmPlayback() {
    final selectedId = state.selectedBassRhythmPatternId;
    final targetId = selectedId ??
        (state.bassRhythmPatterns.isNotEmpty
            ? state.bassRhythmPatterns.first.id
            : null);
    if (targetId == null) return;
    toggleBassRhythmPatternPlayback(targetId);
  }

  /// Elimina un patrón capturado o importado de la biblioteca.
  ///
  /// Los patrones del catálogo (`builtin:`) son inmutables y no se eliminan.
  ///
  /// {P}: `patternId` existe y no es del catálogo integrado.
  /// {Q}: el patrón desaparece de `bassRhythmPatterns`; si era el
  ///      seleccionado, la selección pasa al primero restante o se limpia;
  ///      si estaba sonando, la reproducción se detiene.
  void deleteBassRhythmPattern(String patternId) {
    require(
      'deleteBassRhythmPattern',
      'el patrón existe en la biblioteca',
      state.bassRhythmPatterns.any((pattern) => pattern.id == patternId),
    );
    require(
      'deleteBassRhythmPattern',
      'los patrones integrados del catálogo no se eliminan',
      !patternId.startsWith('builtin:'),
    );
    final wasSelected = state.selectedBassRhythmPatternId == patternId;
    final remaining = state.bassRhythmPatterns
        .where((pattern) => pattern.id != patternId)
        .toList(growable: false);

    if (wasSelected && state.isBassMetronomeActive) {
      _stopStandaloneMetronome();
    }

    state = state.copyWith(
      bassRhythmPatterns: remaining,
      clearSelectedBassRhythmPattern: wasSelected && remaining.isEmpty,
      selectedBassRhythmPatternId:
          wasSelected && remaining.isNotEmpty ? remaining.first.id : null,
      isBassMetronomeActive: wasSelected ? false : state.isBassMetronomeActive,
      bassRhythmElapsedSeconds: wasSelected ? 0 : state.bassRhythmElapsedSeconds,
    );
    ensure(
      'deleteBassRhythmPattern',
      'el patrón eliminado ya no está en la biblioteca',
      !state.bassRhythmPatterns.any((pattern) => pattern.id == patternId),
    );
  }

  /// Actualiza un patrón existente de bajos (Update en CRUD).
  ///
  /// {P}: `patternId` existe en la biblioteca y `name` no está vacío.
  /// {Q}: el patrón conserva su id pero refleja los nuevos campos actualizados.
  void updateBassRhythmPattern({
    required String patternId,
    String? newName,
    double? newQuarterNotesPerMinute,
  }) {
    require(
      'updateBassRhythmPattern',
      'el patrón existe en la biblioteca',
      state.bassRhythmPatterns.any((p) => p.id == patternId),
    );
    if (newName != null) {
      require(
        'updateBassRhythmPattern',
        'el nombre del patrón no puede estar vacío',
        newName.trim().isNotEmpty,
      );
    }
    if (newQuarterNotesPerMinute != null) {
      require(
        'updateBassRhythmPattern',
        'el tempo debe estar en el rango [30, 300] BPM',
        newQuarterNotesPerMinute >= 30 && newQuarterNotesPerMinute <= 300,
      );
    }

    final updatedList = state.bassRhythmPatterns.map((p) {
      if (p.id == patternId) {
        return p.copyWith(
          name: newName?.trim() ?? p.name,
          quarterNotesPerMinute: newQuarterNotesPerMinute ?? p.quarterNotesPerMinute,
        );
      }
      return p;
    }).toList(growable: false);

    state = state.copyWith(bassRhythmPatterns: updatedList);
    _syncStandaloneMetronome();

    ensure(
      'updateBassRhythmPattern',
      'el patrón fue actualizado correctamente',
      state.bassRhythmPatterns.firstWhere((p) => p.id == patternId).name ==
          (newName?.trim() ?? state.bassRhythmPatterns.firstWhere((p) => p.id == patternId).name),
    );
  }

  /// Duplica un patrón existente (Create a partir de existente).
  ///
  /// {P}: `sourcePatternId` existe.
  /// {Q}: se añade un nuevo patrón con nuevo identificador al inicio de la lista.
  void duplicateBassRhythmPattern(String sourcePatternId) {
    require(
      'duplicateBassRhythmPattern',
      'el patrón origen existe en la biblioteca',
      state.bassRhythmPatterns.any((p) => p.id == sourcePatternId),
    );
    final source = state.bassRhythmPatterns.firstWhere((p) => p.id == sourcePatternId);
    final newId = 'custom:${DateTime.now().millisecondsSinceEpoch}';
    final duplicated = source.copyWith(
      id: newId,
      name: '${source.name} (Copia)',
    );

    state = state.copyWith(
      bassRhythmPatterns: [duplicated, ...state.bassRhythmPatterns],
      selectedBassRhythmPatternId: newId,
    );

    ensure(
      'duplicateBassRhythmPattern',
      'el nuevo patrón está presente en la biblioteca',
      state.bassRhythmPatterns.any((p) => p.id == newId),
    );
  }

  /// Establece o acopla el tempo del patrón seleccionado o manual del metrónomo principal.
  ///
  /// {P}: `bpm` en el rango musical [30, 300].
  /// {Q}: `state.manualMetronomeBpm == bpm`. Si hay un patrón seleccionado,
  ///      su tempo también se actualiza para sincronización perfecta.
  void setManualMetronomeBpm(double bpm) {
    require(
      'setManualMetronomeBpm',
      'el BPM debe estar dentro de [30, 300]',
      bpm >= 30.0 && bpm <= 300.0,
    );
    final selectedPattern = state.selectedBassRhythmPattern;
    if (selectedPattern != null) {
      updateBassRhythmPattern(
        patternId: selectedPattern.id,
        newQuarterNotesPerMinute: bpm,
      );
    }
    state = state.copyWith(manualMetronomeBpm: bpm);
    _syncStandaloneMetronome();
    ensure(
      'setManualMetronomeBpm',
      'el BPM manual coincide con el asignado',
      state.manualMetronomeBpm == bpm,
    );
  }

  /// Conmuta la reproducción del metrónomo principal independiente.
  ///
  /// Funciona aún sin archivo de audio cargado.
  void toggleStandaloneMetronome() {
    final nextState = !state.isMetronomeActive;
    state = state.copyWith(isMetronomeActive: nextState);
    _syncStandaloneMetronome();
  }

  void toggleBassMetronome() {
    state = state.copyWith(isBassMetronomeActive: !state.isBassMetronomeActive);
    _syncStandaloneMetronome();
  }

  /// Inicia la captura de un patrón rítmico tocado sobre la matriz 2×2
  /// (bajos 7, 8, 4 y 5).
  ///
  /// {P}: no hay captura activa y `selectedButtons` es subconjunto de
  ///      `{7, 8, 4, 5}`.
  /// {Q}: `isBassCaptureActive == true` y el reloj de captura parte de cero.
  void startBassRhythmCapture({
    required String name,
    required Set<int> selectedButtons,
  }) {
    require(
      'startBassRhythmCapture',
      'no debe haber una captura en curso',
      !state.isBassCaptureActive,
    );
    require(
      'startBassRhythmCapture',
      'selección dentro de la matriz 2×2',
      selectedButtons.every(BassMatrixLayout.buttonNumbers.contains),
    );
    final bpm = _standaloneMetronomeBpm;
    final recorder = BassRhythmRecorder()
      ..start(
        name: name,
        beatSeconds: 60.0 / bpm,
        quarterNotesPerMinute: bpm,
        beatsPerMeasure: _standaloneMetronomeBeatsPerMeasure,
        beatType: 4,
        selectedButtons: selectedButtons,
      );
    state = state.copyWith(
      bassRhythmRecorder: recorder,
      isBassMetronomeActive: false,
      bassRhythmElapsedSeconds: 0,
    );
    _startBassCaptureClock();
    ensure(
      'startBassRhythmCapture',
      'la captura queda activa',
      state.isBassCaptureActive,
    );
  }

  Timer? _bassCaptureTimer;

  /// Arranca el reloj de captura (25 Hz). Cada tick avanza el recorder y
  /// publica el tiempo transcurrido en `bassRhythmElapsedSeconds`.
  ///
  /// {P}: existe una captura activa.
  /// {Q}: hay un único `Timer` vivo mientras la captura esté activa.
  void _startBassCaptureClock() {
    _bassCaptureTimer?.cancel();
    _bassCaptureTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (timer) {
        final recorder = state.bassRhythmRecorder;
        if (recorder == null || !recorder.isRecording) {
          timer.cancel();
          _bassCaptureTimer = null;
          return;
        }
        // 40 ms ≈ 4 ticks de 10 ms del reloj del recorder.
        recorder.tick(ticks: 4);
        state = state.copyWith(
          bassRhythmRecorder: recorder,
          bassRhythmElapsedSeconds: recorder.elapsedSeconds,
        );
      },
    );
  }

  void _stopBassCaptureClock() {
    _bassCaptureTimer?.cancel();
    _bassCaptureTimer = null;
  }

  /// Registra un golpe de la matriz en el instante actual de la captura.
  ///
  /// {P}: `buttonNumber` ∈ `{7, 8, 4, 5}`.
  /// {Q}: el golpe queda en el recorder sólo si la captura está activa y el
  ///      botón pertenece a la selección.
  void captureBassMatrixHit(int buttonNumber) {
    final recorder = state.bassRhythmRecorder;
    if (recorder == null || !recorder.isRecording) return;
    require(
      'captureBassMatrixHit',
      'botón dentro de la matriz 2×2',
      BassMatrixLayout.buttonNumbers.contains(buttonNumber),
    );
    // El reloj del recorder ya está al día gracias a _startBassCaptureClock.
    recorder.recordButton(buttonNumber);
    state = state.copyWith(bassRhythmRecorder: recorder);
  }

  /// Alterna la selección de una caja de la matriz durante la captura.
  void toggleBassCaptureSelection(int buttonNumber) {
    final recorder = state.bassRhythmRecorder;
    if (recorder == null) return;
    recorder.toggleSelection(buttonNumber);
    state = state.copyWith(bassRhythmRecorder: recorder);
  }

  /// Detiene la captura y registra el patrón resultante en la lista.
  ///
  /// {P}: existe una captura en curso.
  /// {Q}: el patrón aparece primero en `bassRhythmPatterns`, queda seleccionado
  ///      en modo reproducción (o no, si está vacío) y el recorder se libera.
  BassRhythmPattern? stopBassRhythmCapture() {
    final recorder = state.bassRhythmRecorder;
    if (recorder == null || !recorder.isRecording) return null;
    _stopBassCaptureClock();
    final totalSeconds = recorder.elapsedSeconds;
    recorder.stop();
    final pattern = recorder.buildPattern(totalSeconds: totalSeconds);

    state = state.copyWith(
      bassRhythmPatterns: [pattern, ...state.bassRhythmPatterns],
      selectedBassRhythmPatternId: pattern.id,
      // La captura termina SIN auto-reproducir: el usuario decide cuándo
      // lanzar el patrón guardado desde el panel. Esto además evita dejar
      // timers del metrónomo pendientes al cerrar el diálogo.
      isBassMetronomeActive: false,
      clearBassRhythmRecorder: true,
      bassRhythmElapsedSeconds: 0,
    );
    _stopStandaloneMetronome();
    ensure(
      'stopBassRhythmCapture',
      'el recorder se libera tras guardar el patrón',
      !state.isBassCaptureActive,
    );
    return pattern;
  }

  /// Cancela la captura sin registrar el patrón.
  void cancelBassRhythmCapture() {
    _stopBassCaptureClock();
    state = state.copyWith(
      clearBassRhythmRecorder: true,
      bassRhythmElapsedSeconds: 0,
    );
  }

  /// Muestra u oculta el panel inline de captura (no modal).
  ///
  /// {Q}: al abrirse con una captura ya activa el panel refleja su estado;
  ///      al cerrarse con captura en curso, la captura se cancela.
  void toggleBassCapturePanel() {
    final opening = !state.isBassCapturePanelOpen;
    if (!opening && state.isBassCaptureActive) {
      cancelBassRhythmCapture();
    }
    state = state.copyWith(isBassCapturePanelOpen: opening);
  }

  /// Alterna el estado del metrónomo (click rítmico de compás).
  void toggleMetronome() {
    state = state.copyWith(isMetronomeActive: !state.isMetronomeActive);
    _syncStandaloneMetronome();
  }

  /// Ajusta el volumen del click del metrónomo [0.0, 1.0].
  void setMetronomeVolume(double vol) {
    state = state.copyWith(metronomeVolume: vol.clamp(0.0, 1.0));
  }

  /// Alterna el modo de marcación de acordes en vivo con barra espaciadora.
  void toggleLiveChordMarker() {
    state = state.copyWith(
      isLiveChordMarkerActive: !state.isLiveChordMarkerActive,
    );
  }

  /// Ejecuta un chasquido de metrónomo (acento en beat 0, secundario en beats 1..3).
  void playMetronomeTick(
    int beatIndex, {
    int beatsPerMeasure = 4,
    bool? accented,
  }) {
    PlayMetronomeTickCommand(
      onPercussiveClick: ({bool isDownbeat = true, double volume = 0.8}) {
        _audioBridge.playPercussiveClick(
          isDownbeat: isDownbeat,
          volume: volume,
        );
      },
      onNoteOn: (note, {velocity = 0.8}) =>
          _audioBridge.noteOn(note, velocity: velocity),
      onNoteOff: (note) => _audioBridge.noteOff(note),
      beatIndex: beatIndex,
      volume: state.metronomeVolume,
      beatsPerMeasure: beatsPerMeasure,
      accented: accented,
    ).execute();
  }

  void _playBassRhythmHitsBetween(
    double previousPosition,
    double currentPosition,
    BassRhythmPattern pattern,
    {bool includeStart = false}
  ) {
    if (pattern.durationQuarterBeats <= 0 ||
        currentPosition < previousPosition) {
      return;
    }
    final firstCycle = (previousPosition / pattern.durationQuarterBeats).floor();
    final lastCycle = (currentPosition / pattern.durationQuarterBeats).floor();
    for (var cycle = firstCycle; cycle <= lastCycle; cycle++) {
      for (final hit in pattern.hits) {
        final absoluteOnset =
            cycle * pattern.durationQuarterBeats + hit.onsetQuarterBeats;
        final isAfterPrevious = includeStart
            ? absoluteOnset >= previousPosition
            : absoluteOnset > previousPosition;
        if (isAfterPrevious && absoluteOnset <= currentPosition) {
          playMetronomeTick(
            (hit.onsetQuarterBeats * 4).round(),
            beatsPerMeasure: pattern.beatsPerMeasureInQuarterNotes * 4,
            accented: hit.isAccented,
          );
        }
      }
    }
  }

  double get _standaloneMetronomeBpm =>
      state.selectedBassRhythmPattern?.quarterNotesPerMinute ??
      state.audioReport?.bpm.toDouble() ??
      state.manualMetronomeBpm;

  int get _standaloneMetronomeBeatsPerMeasure =>
      state.selectedBassRhythmPattern?.beatsPerMeasureInQuarterNotes ?? 4;

  double _rhythmClockStep(BassRhythmPattern? pattern) {
    if (pattern == null || pattern.hits.isEmpty) return 1;
    final onsets =
        pattern.hits.map((hit) => hit.onsetQuarterBeats).toSet().toList()
          ..sort();
    final intervals = <double>[
      for (final hit in pattern.hits)
        if (hit.durationQuarterBeats > 0) hit.durationQuarterBeats,
      for (var index = 1; index < onsets.length; index++)
        onsets[index] - onsets[index - 1],
    ]..removeWhere((interval) => interval <= 0);
    if (intervals.isEmpty) return 1;
    return intervals
        .reduce((first, second) => first < second ? first : second)
        .clamp(0.125, 1.0)
        .toDouble();
  }

  void _syncStandaloneMetronome() {
    if (state.isPlayingAudio ||
        (!state.isMetronomeActive && !state.isBassMetronomeActive)) {
      _stopStandaloneMetronome();
      return;
    }
    _startStandaloneMetronome();
  }

  void _startStandaloneMetronome() {
    _standaloneMetronomeTimer?.cancel();
    final bpm = _standaloneMetronomeBpm;
    final quarterBeatStep = _rhythmClockStep(state.selectedBassRhythmPattern);
    final intervalMs = ((60.0 / bpm * quarterBeatStep) * 1000).round().clamp(
      50,
      3000,
    );
    final beatsPerMeasure = _standaloneMetronomeBeatsPerMeasure;
    _standaloneBeat = 0;
    _standaloneElapsedQuarterBeats = 0;
    state = state.copyWith(bassRhythmElapsedSeconds: 0);
    final pattern = state.selectedBassRhythmPattern;
    if (pattern == null) {
      playMetronomeTick(_standaloneBeat, beatsPerMeasure: beatsPerMeasure);
    } else {
      _playBassRhythmHitsBetween(0, 0, pattern, includeStart: true);
    }

    _standaloneMetronomeTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        if ((!state.isMetronomeActive && !state.isBassMetronomeActive) ||
            state.isPlayingAudio) {
          timer.cancel();
          return;
        }
        final currentBeatsPerMeasure = _standaloneMetronomeBeatsPerMeasure;
        final previousBeat = _standaloneElapsedQuarterBeats.floor();
        final previousPosition = _standaloneElapsedQuarterBeats;
        _standaloneElapsedQuarterBeats += quarterBeatStep;
        final currentBeat = _standaloneElapsedQuarterBeats.floor();
        state = state.copyWith(
          bassRhythmElapsedSeconds: _standaloneElapsedQuarterBeats * 60 / bpm,
        );
        final currentPattern = state.selectedBassRhythmPattern;
        if (currentPattern != null) {
          _playBassRhythmHitsBetween(
            previousPosition,
            _standaloneElapsedQuarterBeats,
            currentPattern,
          );
        } else if (currentBeat > previousBeat) {
          _standaloneBeat = currentBeat % currentBeatsPerMeasure;
          playMetronomeTick(
            _standaloneBeat,
            beatsPerMeasure: currentBeatsPerMeasure,
          );
        }
      },
    );
  }

  void _stopStandaloneMetronome() {
    _standaloneMetronomeTimer?.cancel();
    _standaloneMetronomeTimer = null;
    _audioBridge.noteOff(84);
    _audioBridge.noteOff(76);
  }

  /// Marca en vivo el cambio de acorde en el compás y tiempo exacto según el slider de audio.
  /// Aplica el acorde detectado en el archivo de audio tanto a la cuadrícula como a la selección del diapasón.
  /// Se ejecuta al presionar la Barra Espaciadora durante la reproducción (Command Pattern + Hoare Triples).
  LiveMarkerResult? markLiveChordChange() {
    final bpm = state.audioReport?.bpm.toDouble() ?? 120.0;

    // 1. Prioridad: Acorde detectado en el archivo de audio para la posición temporal actual
    String? audioDetectedChord;
    final report = state.audioReport;
    if (report != null && report.chords.isNotEmpty) {
      final t = state.currentAudioTime;
      final matchingSegment = report.chords.firstWhere(
        (seg) => t >= seg.startTime && t <= seg.endTime,
        orElse: () => report.chords.reduce((best, seg) {
          final bestMid = (best.startTime + best.endTime) / 2.0;
          final segMid = (seg.startTime + seg.endTime) / 2.0;
          return (segMid - t).abs() < (bestMid - t).abs() ? seg : best;
        }),
      );
      audioDetectedChord = state.notation == NotationMode.alemana
          ? matchingSegment.chordSymbol
          : (matchingSegment.chordName.isNotEmpty
                ? matchingSegment.chordName
                : matchingSegment.chordSymbol);
    }

    // 2. Acorde del constructor libre
    final constructorChord = ChordCatalog.symbolFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      bass: state.freeChordBass,
      latin: state.notation != NotationMode.alemana,
    );

    // Jerarquía armónica: 1. Audio detectado, 2. Constructor libre, 3. Detector diapasón
    final activeChord =
        (audioDetectedChord != null && audioDetectedChord.trim().isNotEmpty)
        ? audioDetectedChord.trim()
        : (constructorChord.isNotEmpty
              ? constructorChord
              : state.detectedChord?.formattedSymbol(state.notation));

    final command = MarkLiveChordChangeCommand(
      currentAudioTime: state.currentAudioTime,
      bpm: bpm,
      measures: state.measures,
      markedBeats: state.markedBeats,
      activeChord: activeChord,
      startOffset: state.audioStartOffset,
    );

    if (!command.canExecute()) return null;

    _gridHistory.saveSnapshot(
      measures: state.measures,
      markedBeats: state.markedBeats,
      yellowDecisionBeats: state.yellowDecisionBeats,
    );

    final result = command.execute();

    state = state.copyWith(
      measures: result.updatedMeasures,
      markedBeats: result.updatedMarkedBeats,
      selectedBarIndex: result.targetBar,
      selectedBeatIndex: result.targetBeat,
    );

    return result;
  }

  /// Retrocede al compás anterior y sincroniza la posición del audio y de la cuadrícula.
  void previousBar() {
    final bpm = state.audioReport?.bpm ?? 120.0;
    final secondsPerBar = (60.0 / bpm) * 4.0;
    final currentBar = state.selectedBarIndex ?? 0;
    final targetBar = (currentBar - 1).clamp(
      0,
      state.measures.isNotEmpty ? state.measures.length - 1 : 0,
    );
    final targetTime =
        state.effectiveAudioStartOffset + targetBar * secondsPerBar;
    if (state.isAudioCoupled) {
      seekAudio(targetTime, audition: true);
    } else {
      _seekCompas(targetTime, audition: true);
    }
  }

  /// Avanza al siguiente compás y sincroniza la posición del audio y de la cuadrícula.
  void nextBar() {
    final bpm = state.audioReport?.bpm ?? 120.0;
    final secondsPerBar = (60.0 / bpm) * 4.0;
    final currentBar = state.selectedBarIndex ?? 0;
    final maxBar = state.measures.isNotEmpty ? state.measures.length - 1 : 0;
    final targetBar = (currentBar + 1).clamp(0, maxBar);
    final targetTime =
        state.effectiveAudioStartOffset + targetBar * secondsPerBar;
    if (state.isAudioCoupled) {
      seekAudio(targetTime, audition: true);
    } else {
      _seekCompas(targetTime, audition: true);
    }
  }

  /// Posiciona la reproducción de audio en el segundo indicado y sincroniza la cuadrícula de compases.
  ///
  /// # Tripla de Hoare:
  /// - {P}: `time.isFinite`.
  /// - {Q}: `0.0 <= state.currentAudioTime <= totalDur && 0 <= state.selectedBarIndex < measures.length && 0 <= state.selectedBeatIndex < 4`.
  /// - {I}: `_lastPlaybackDetectedChord == null` (garantiza re-detección limpia del acorde tras el salto temporal).
  void seekAudio(double time, {bool audition = false}) {
    final clamped = time.clamp(
      0.0,
      state.totalAudioDuration > 0
          ? state.totalAudioDuration
          : (_audioPlayer.durationSeconds > 0
                ? _audioPlayer.durationSeconds
                : time),
    );
    _audioPlayer.seek(clamped);
    if (!state.isAudioCoupled) {
      state = state.copyWith(currentAudioTime: clamped);
      return;
    }

    final bpm = state.audioReport?.bpm ?? 120.0;
    final beatDuration = 60.0 / bpm;
    final effectiveOffset = state.effectiveAudioStartOffset;
    final effectiveTime = math.max(0.0, clamped - effectiveOffset);
    final totalBeats = (effectiveTime / beatDuration).floor();
    final currentBar = clamped >= effectiveOffset
        ? (totalBeats ~/ 4) %
              (state.measures.isNotEmpty ? state.measures.length : 8)
        : 0;
    final currentBeat = clamped >= effectiveOffset ? totalBeats % 4 : 0;
    _lastPlayedBar = currentBar;
    _lastPlayedBeat = currentBeat;
    _lastPlaybackDetectedChord = null;

    state = state.copyWith(
      currentAudioTime: clamped,
      currentCompasTime: clamped,
      selectedBarIndex: currentBar,
      selectedBeatIndex: currentBeat,
      isManualBeatSelection: false,
    );
    if (audition || state.isPlayingAudio) {
      _playBeatChord(currentBar, currentBeat);
    }
  }

  void _seekCompas(double time, {bool audition = false}) {
    final bpm = state.audioReport?.bpm ?? 120.0;
    final effectiveOffset = state.effectiveAudioStartOffset;
    final effectiveTime = math.max(0.0, time - effectiveOffset);
    final totalBeats = (effectiveTime / (60.0 / bpm)).floor();
    final currentBar = time >= effectiveOffset
        ? (totalBeats ~/ 4) %
              (state.measures.isNotEmpty ? state.measures.length : 8)
        : 0;
    final currentBeat = time >= effectiveOffset ? totalBeats % 4 : 0;
    _lastPlayedBar = currentBar;
    _lastPlayedBeat = currentBeat;
    state = state.copyWith(
      currentCompasTime: time,
      selectedBarIndex: currentBar,
      selectedBeatIndex: currentBeat,
      isManualBeatSelection: false,
    );
    if (audition || state.isPlayingAudio) {
      _playBeatChord(currentBar, currentBeat);
    }
  }

  /// Conmuta la detección automática de acordes durante la reproducción de audio.
  /// Cuando está activa, se asignan y marcan acordes en la cuadrícula ÚNICAMENTE
  /// cuando el audio presenta un cambio armónico observable (transición).
  void togglePlaybackAutoChordDetect() {
    final next = !state.isPlaybackAutoChordDetectEnabled;
    _lastPlaybackDetectedChord = null;
    state = state.copyWith(isPlaybackAutoChordDetectEnabled: next);
    if (next && state.isPlayingAudio && state.audioReport != null) {
      _checkPlaybackAutoChordChange(state.currentAudioTime);
    }
  }

  /// Realiza un micro-ajuste temporal del desfase del pulso (Beat Nudge) en segundos.
  /// Positivo = adelanta el beat; Negativo = atrasa el beat.
  /// {P}: deltaSeconds.isFinite.
  /// {Q}: state.beatNudgeOffset actualizado y códigos de tiempo recalculados.
  void adjustBeatOffset(double deltaSeconds) {
    final cmd = AdjustBeatOffsetCommand(
      currentOffset: state.beatNudgeOffset,
      deltaSeconds: deltaSeconds,
    );
    if (!cmd.canExecute()) return;
    final newOffset = cmd.execute();
    state = state.copyWith(beatNudgeOffset: newOffset);
    if (state.audioReport != null) {
      _updateMeasuresTimeCodes();
    }
  }

  /// Restablece el desfase del pulso a 0.0 segundos.
  void resetBeatOffset() {
    state = state.copyWith(beatNudgeOffset: 0.0);
    if (state.audioReport != null) {
      _updateMeasuresTimeCodes();
    }
  }

  /// Sincroniza instantáneamente el pulso más próximo al tiempo actual del reproductor (Beat Sync).
  void syncBeatToCurrentAudioTime() {
    final bpm = state.audioReport?.bpm.toDouble() ?? 120.0;
    final cmd = SyncBeatToAudioCommand(
      currentAudioTime: state.currentAudioTime,
      audioStartOffset: state.audioStartOffset,
      bpm: bpm,
    );
    if (!cmd.canExecute()) return;
    final delta = cmd.execute();
    adjustBeatOffset(delta);
  }

  /// Evalúa si hay un cambio de acorde en el tiempo de reproducción actual y lo aplica
  /// atómicamente a la cuadrícula de compases solo si difiere del último acorde registrado.
  void _checkPlaybackAutoChordChange(double audioTime) {
    if (!state.isPlaybackAutoChordDetectEnabled) return;
    final report = state.audioReport;
    if (report == null || report.chords.isEmpty || state.measures.isEmpty) {
      return;
    }

    final bpm = report.bpm.toDouble();
    final effectiveOffset = state.effectiveAudioStartOffset;

    final cmd = DetectPlaybackChordTransitionCommand(
      currentAudioTime: audioTime,
      bpm: bpm,
      startOffset: effectiveOffset,
      measures: state.measures,
      markedBeats: state.markedBeats,
      chords: report.chords,
      lastDetectedChordText: _lastPlaybackDetectedChord,
      notation: state.notation,
    );

    if (!cmd.canExecute()) return;
    final result = cmd.execute();

    if (result.hasTransition) {
      _lastPlaybackDetectedChord = result.detectedChordText;
      _gridHistory.saveSnapshot(
        measures: state.measures,
        markedBeats: state.markedBeats,
        yellowDecisionBeats: state.yellowDecisionBeats,
      );

      state = state.copyWith(
        measures: result.updatedMeasures,
        markedBeats: result.updatedMarkedBeats,
        selectedBarIndex: result.targetBar,
        selectedBeatIndex: result.targetBeat,
        isManualBeatSelection: false,
      );

      // Reproducir sonoramente el nuevo acorde en el sintetizador
      _playBeatChord(result.targetBar, result.targetBeat);
    }
  }

  /// Recalcula los textos de tiempo ($mins:$secs) de cada pulso según el offset acumulado.
  void _updateMeasuresTimeCodes() {
    final bpm = state.audioReport?.bpm.toDouble() ?? 120.0;
    final secondsPerBeat = 60.0 / bpm;
    final totalOffset = state.effectiveAudioStartOffset;

    final updated = state.measures.map((row) {
      final updatedBeats = row.beats.map((b) {
        final timeSec =
            totalOffset + (b.barIndex * 4 + b.beatIndex) * secondsPerBeat;
        final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
        final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
        return b.copyWith(timeText: '$mins:$secs');
      }).toList();
      return MeasureRow(barNumber: row.barNumber, beats: updatedBeats);
    }).toList();

    state = state.copyWith(measures: updated);
  }

  /// Acopla o desacopla la pista de audio al transporte del Compás.
  ///
  /// {P}: el estado de sincronización puede cambiarse durante la reproducción.
  /// {Q}: al desacoplar, la pista sigue sonando y el Compás conserva su reloj;
  /// al acoplar, ambos continúan desde el tiempo actual del Compás.
  void toggleAudioCoupling() {
    final coupled = !state.isAudioCoupled;
    final syncedTime = coupled ? state.compasTime : state.currentAudioTime;
    state = state.copyWith(
      isAudioCoupled: coupled,
      currentAudioTime: syncedTime,
      currentCompasTime: coupled ? syncedTime : state.compasTime,
    );

    if (coupled) {
      _audioPlayer.seek(syncedTime);
      if (state.isPlayingAudio && _audioPlayer.isLoaded) {
        _audioPlayer.play();
      }
    }
  }

  void toggleSyncDiapason() {
    state = state.copyWith(syncDiapason: !state.syncDiapason);
  }

  void toggleSequenceMode() {
    state = state.copyWith(sequenceMode: !state.sequenceMode);
  }

  void selectBeat(int barIdx, int beatIdx) {
    if (barIdx < 0 || barIdx >= state.measures.length) {
      state = state.copyWith(
        selectedBarIndex: barIdx,
        selectedBeatIndex: beatIdx,
        isManualBeatSelection: false,
        isFreeChordBeingEdited: false,
      );
      return;
    }
    final beats = state.measures[barIdx].beats;
    if (beatIdx < 0 || beatIdx >= beats.length) {
      state = state.copyWith(
        selectedBarIndex: barIdx,
        selectedBeatIndex: beatIdx,
        isManualBeatSelection: false,
        isFreeChordBeingEdited: false,
      );
      return;
    }

    final beat = beats[beatIdx];
    final chordSelection = ChordCatalog.constructorSelectionForSymbol(
      beat.chord,
    );
    BellowsMode nextBellows = state.bellows1;
    if (beat.bellows != BellowsMode.both) {
      nextBellows = beat.bellows;
    }

    _currentBeatNotes = [];
    _audioBridge.allNotesOff();
    state = state.copyWith(
      selectedBarIndex: barIdx,
      selectedBeatIndex: beatIdx,
      isManualBeatSelection: true,
      bellows1: nextBellows,
      activeButtons: const {},
      playingChordNotes: const {},
      freeChordRoot: chordSelection?.root ?? -1,
      freeChordType: chordSelection?.type ?? '',
      freeChordFourth: chordSelection?.extension ?? '',
      freeChordOctave: chordSelection == null ? '' : 'all',
      freeChordMode: chordSelection == null ? '' : 'harmonic',
      freeChordBellows: BellowsMode.both,
      freeChordBass: chordSelection?.bass ?? '',
      freeChordScaleHarmonicMode: chordSelection?.structure ?? '',
      isFreeChordFixed: false,
      isFreeChordBeingEdited: false,
      detectorMode: false,
      detectorSelectedButtons: const [],
      clearDetectedChord: true,
    );
  }

  /// Copia el acorde de una casilla válida al portapapeles interno.
  ///
  /// {P}: los índices apuntan a una casilla existente.
  /// {Q}: devuelve y conserva el acorde no vacío; para una casilla vacía,
  /// devuelve `null` y el portapapeles permanece intacto.
  String? copyChordFromBeat(int barIndex, int beatIndex) {
    if (barIndex < 0 || barIndex >= state.measures.length) return null;
    final beats = state.measures[barIndex].beats;
    if (beatIndex < 0 || beatIndex >= beats.length) return null;
    final chord = beats[beatIndex].chord.trim();
    if (chord.isEmpty) return null;
    state = state.copyWith(copiedChord: chord);
    return chord;
  }

  String? get copiedChord =>
      state.copiedChord.isEmpty ? null : state.copiedChord;

  /// Clave plana de un tiempo. La cuadrícula usa 4 tiempos por compás.
  static int beatKey(int barIndex, int beatIndex) => barIndex * 4 + beatIndex;

  bool isBeatMarked(int barIndex, int beatIndex) =>
      state.markedBeats.contains(beatKey(barIndex, beatIndex));

  /// Marca o desmarca los 4 tiempos de un compás con el checkbox a la izquierda
  /// del número del compás. Si los 4 tiempos están marcados, los desmarca;
  /// en caso contrario (parcial o desmarcado) los marca a los 4, preservando
  /// las marcas de los demás compases.
  void toggleMeasureMark(int barIndex) {
    if (barIndex < 0 || barIndex >= state.measures.length) return;
    final measureKeys = {for (var i = 0; i < 4; i++) beatKey(barIndex, i)};
    final next = Set<int>.from(state.markedBeats);
    if (measureKeys.every(next.contains)) {
      next.removeAll(measureKeys);
    } else {
      next.addAll(measureKeys);
    }
    state = state.copyWith(markedBeats: next);
  }

  /// Indica si los 4 tiempos del compás [barIndex] están marcados.
  bool isMeasureMarked(int barIndex) {
    if (barIndex < 0 || barIndex >= state.measures.length) return false;
    return measureKeysOf(barIndex).every(state.markedBeats.contains);
  }

  /// Claves planas de los 4 tiempos del compás [barIndex].
  Set<int> measureKeysOf(int barIndex) => {
    for (var i = 0; i < 4; i++) beatKey(barIndex, i),
  };

  /// Marca o desmarca un tiempo individual. Los tiempos marcados reciben el
  /// acorde del Constructor de forma simultánea y son los únicos que se
  /// ejecutan durante la reproducción.
  void toggleBeatMark(int barIndex, int beatIndex) {
    final key = beatKey(barIndex, beatIndex);
    final next = Set<int>.from(state.markedBeats);
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(markedBeats: next);
  }

  void clearBeatMarks() => state = state.copyWith(markedBeats: const {});

  /// Activa el modo de selección de destinos desde las cajas de texto.
  /// Al salir del modo, limpia los destinos sin modificar los checkbox.
  void toggleMultiBeatAssignmentMode() {
    final enabling = !state.isMultiBeatAssignmentMode;
    state = state.copyWith(
      isMultiBeatAssignmentMode: enabling,
      multiBeatAssignmentTargets: const {},
    );
  }

  /// Alterna una caja como destino de asignación masiva.
  void toggleMultiBeatAssignmentTarget(int barIndex, int beatIndex) {
    if (!state.isMultiBeatAssignmentMode ||
        barIndex < 0 ||
        barIndex >= state.measures.length ||
        beatIndex < 0 ||
        beatIndex >= state.measures[barIndex].beats.length) {
      return;
    }

    final targets = Set<int>.from(state.multiBeatAssignmentTargets);
    final key = beatKey(barIndex, beatIndex);
    if (!targets.add(key)) targets.remove(key);
    state = state.copyWith(multiBeatAssignmentTargets: targets);
  }

  /// Marca o desmarca todos los tiempos de la cuadrícula. Si todos los
  /// checkboxes están marcados, los desmarca; si no, los marca a todos.
  void toggleAllBeatMarks() {
    final total = state.measures.length * 4;
    final allMarked = total > 0 && state.markedBeats.length == total;
    if (allMarked) {
      state = state.copyWith(markedBeats: const {});
    } else {
      state = state.copyWith(markedBeats: {for (var i = 0; i < total; i++) i});
    }
  }

  /// Borra los acordes de la cuadrícula aplicando [DeleteGridChordsCommand]
  /// (Triplas de Hoare {P} C {Q}).
  ///
  /// - Casilla de selección masiva marcada (`deleteAll == true`): limpia todos
  ///   los acordes de la cuadrícula y desmarca todas las casillas
  ///   {Q: forall k in [0, N): chord(k) == '' && markedBeats == {}}.
  /// - Casilla desactivada: borra únicamente los acordes de las casillas
  ///   marcadas directamente
  ///   {Q: chord vacía solo para k in markedBeats; el resto permanece intacto}.
  /// Devuelve la cantidad de acordes borrados (0 si no hay nada que borrar).
  int deleteGridChords({required bool deleteAll}) {
    final targets = deleteAll
        ? {
            // Casilla masiva activa: targets = todas las posiciones válidas,
            // más cualquier marca residual fuera de rango (la desmarca igual).
            for (var i = 0; i < state.measures.length * 4; i++) i,
            ...state.markedBeats,
          }
        : // Casilla desactivada: targets = solo las casillas marcadas a mano.
          Set<int>.from(state.markedBeats);
    return _deleteGridChordsAt(targets);
  }

  /// Atajo para el borrado total (retrocompatible con código y pruebas existentes).
  int deleteAllGridChords() => deleteGridChords(deleteAll: true);

  /// Borra los acordes únicamente de las casillas actualmente marcadas.
  int deleteMarkedGridChords() => deleteGridChords(deleteAll: false);

  /// Núcleo atómico de borrado: crea, verifica {P}, ejecuta {C} y publica
  /// {Q} del comando sin conocer la estrategia de selección de las claves.
  int _deleteGridChordsAt(Set<int> targetKeys) {
    if (targetKeys.isEmpty) return 0;
    final command = DeleteGridChordsCommand(
      currentMeasures: state.measures,
      currentMarkedBeats: state.markedBeats,
      targetKeys: targetKeys,
    );
    if (!command.canExecute()) return 0;
    final result = command.execute();
    state = state.copyWith(
      measures: result.updatedMeasures,
      markedBeats: result.updatedMarkedBeats,
    );
    return result.deletedCount;
  }

  void setBeatChord(int barIdx, int beatIdx, String chord) {
    final newMeasures = state.measures.map((m) {
      if (m.barNumber - 1 != barIdx) return m;
      final newBeats = m.beats.map((b) {
        if (b.beatIndex != beatIdx) return b;
        return b.copyWith(chord: chord);
      }).toList();
      return MeasureRow(barNumber: m.barNumber, beats: newBeats);
    }).toList();
    state = state.copyWith(measures: newMeasures);
  }

  void addMeasure() {
    final nextBar = state.measures.length + 1;
    final newRow = MeasureRow(
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
    );
    state = state.copyWith(measures: [...state.measures, newRow]);
  }

  void clearAllGridChords() {
    final cleared = state.measures.map((m) {
      return MeasureRow(
        barNumber: m.barNumber,
        beats: m.beats.map((b) => b.copyWith(chord: '')).toList(),
      );
    }).toList();
    state = state.copyWith(measures: cleared);
  }

  void updateMeasureBeat(int barIndex, int beatIndex, String chord) {
    if (barIndex < 0 || barIndex >= state.measures.length) return;
    final row = state.measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return;

    final updatedBeats = List<MeasureBeat>.from(row.beats);
    updatedBeats[beatIndex] = updatedBeats[beatIndex].copyWith(chord: chord);

    final updatedMeasures = List<MeasureRow>.from(state.measures);
    updatedMeasures[barIndex] = MeasureRow(
      barNumber: row.barNumber,
      beats: updatedBeats,
    );

    final beatBellows = updatedBeats[beatIndex].bellows;
    final nextBellows = beatBellows != BellowsMode.both
        ? beatBellows
        : state.bellows1;

    state = state.copyWith(
      measures: updatedMeasures,
      selectedBarIndex: barIndex,
      selectedBeatIndex: beatIndex,
      bellows1: nextBellows,
    );
  }

  /// Edita y sincroniza formalmente los tiempos de inicio y fin de un compás/cuadro (Hoare Triples + SRP).
  ///
  /// {P}: `barIndex` y `beatIndex` válidos dentro de `measures`, y si se proveen ambos, `startTime <= endTime`.
  /// {Q}: el cuadro de compás actualiza su etiqueta `timeText`, `startTime` y `endTime`.
  void updateMeasureBeatTiming({
    required int barIndex,
    required int beatIndex,
    required double startTime,
    required double endTime,
  }) {
    require(
      'updateMeasureBeatTiming',
      'índice de compás y tiempo dentro de rango',
      barIndex >= 0 && barIndex < state.measures.length &&
          beatIndex >= 0 && beatIndex < state.measures[barIndex].beats.length,
    );
    require(
      'updateMeasureBeatTiming',
      'startTime no negativo y menor o igual que endTime',
      startTime >= 0.0 && startTime <= endTime,
    );

    final row = state.measures[barIndex];
    final updatedBeats = List<MeasureBeat>.from(row.beats);
    final minSecStr = _formatTimeSeconds(startTime);

    updatedBeats[beatIndex] = updatedBeats[beatIndex].copyWith(
      timeText: minSecStr,
      startTime: startTime,
      endTime: endTime,
    );

    final updatedMeasures = List<MeasureRow>.from(state.measures);
    updatedMeasures[barIndex] = MeasureRow(
      barNumber: row.barNumber,
      beats: updatedBeats,
    );

    state = state.copyWith(measures: updatedMeasures);

    ensure(
      'updateMeasureBeatTiming',
      'el cuadro del compás refleja el tiempo actualizado',
      state.measures[barIndex].beats[beatIndex].startTime == startTime &&
          state.measures[barIndex].beats[beatIndex].endTime == endTime,
    );
  }

  static String _formatTimeSeconds(double seconds) {
    final totalSec = seconds.toInt();
    final mins = (totalSec ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// Define el fuelle (Abre o Cierra) para un tiempo del compás.
  /// Solo es válido para cuadros que tengan un acorde registrado.
  /// No modifica el acorde ni aplica acordes a cuadros anteriores o actuales.
  void setBeatBellows(int barIndex, int beatIndex, BellowsMode bellows) {
    if (barIndex < 0 || barIndex >= state.measures.length) return;
    final row = state.measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return;

    final targetBeat = row.beats[beatIndex];
    // Solo es válido para cuadros que ya tengan un acorde registrado
    if (targetBeat.chord.trim().isEmpty) return;

    final newBellows = targetBeat.bellows == bellows
        ? BellowsMode.both
        : bellows;
    final updatedMeasures = List<MeasureRow>.from(state.measures);
    final key = beatKey(barIndex, beatIndex);

    if (state.markedBeats.contains(key)) {
      for (final markedKey in state.markedBeats) {
        final bIdx = markedKey ~/ 4;
        final tIdx = markedKey % 4;
        if (bIdx >= 0 && bIdx < updatedMeasures.length) {
          final r = updatedMeasures[bIdx];
          if (tIdx >= 0 && tIdx < r.beats.length) {
            final bts = List<MeasureBeat>.from(r.beats);
            // Solo para cuadros con acorde registrado, sin modificar el acorde
            if (bts[tIdx].chord.trim().isNotEmpty) {
              bts[tIdx] = bts[tIdx].copyWith(bellows: newBellows);
              updatedMeasures[bIdx] = MeasureRow(
                barNumber: r.barNumber,
                beats: bts,
              );
            }
          }
        }
      }
    } else {
      final beats = List<MeasureBeat>.from(row.beats);
      beats[beatIndex] = targetBeat.copyWith(bellows: newBellows);
      updatedMeasures[barIndex] = MeasureRow(
        barNumber: row.barNumber,
        beats: beats,
      );
    }

    final remainingYellow = Set<int>.from(state.yellowDecisionBeats);
    if (state.markedBeats.contains(key)) {
      remainingYellow.removeAll(state.markedBeats);
    } else {
      remainingYellow.remove(key);
    }

    state = state.copyWith(
      measures: updatedMeasures,
      selectedBarIndex: barIndex,
      selectedBeatIndex: beatIndex,
      bellows1: newBellows != BellowsMode.both ? newBellows : state.bellows1,
      yellowDecisionBeats: remainingYellow,
    );
  }

  /// Analiza los acordes en la cuadrícula de compases según el diapasón del acordeón especificado.
  /// - Asigna automáticamente push a los que solo están completos cerrando.
  /// - Asigna automáticamente pull a los que solo están completos abriendo.
  /// - Marca en amarillo (yellowDecisionBeats) los acordes completos abriendo o cerrando para decidir y aplicar.
  Map<String, int> assignCompleteChordsBellows(int accordionNumber) {
    final isPrimary = accordionNumber == 1;
    final treble = isPrimary ? state.trebleData1 : state.trebleData2;

    final pullPcs = <int>{};
    final pushPcs = <int>{};
    for (final row in treble.values) {
      for (final btn in row) {
        pullPcs.add(btn.pull % 12);
        pushPcs.add(btn.push % 12);
      }
    }

    final newYellow = <int>{};
    int assignedCount = 0;
    int yellowCount = 0;
    int incompleteCount = 0;

    final updatedMeasures = state.measures.map((measure) {
      final updatedBeats = measure.beats.map((beat) {
        final chord = beat.chord.trim();
        if (chord.isEmpty) return beat;

        final chordPcs = ChordCatalog.pitchClassesForChordSymbol(chord);
        if (chordPcs.isEmpty) return beat;

        final isCompletePush = chordPcs.difference(pushPcs).isEmpty;
        final isCompletePull = chordPcs.difference(pullPcs).isEmpty;
        final key = beat.barIndex * 4 + beat.beatIndex;

        if (isCompletePush && !isCompletePull) {
          assignedCount++;
          return beat.copyWith(bellows: BellowsMode.push);
        } else if (!isCompletePush && isCompletePull) {
          assignedCount++;
          return beat.copyWith(bellows: BellowsMode.pull);
        } else if (isCompletePush && isCompletePull) {
          yellowCount++;
          newYellow.add(key);
          return beat;
        } else {
          incompleteCount++;
          return beat;
        }
      }).toList();

      return MeasureRow(barNumber: measure.barNumber, beats: updatedBeats);
    }).toList();

    state = state.copyWith(
      measures: updatedMeasures,
      yellowDecisionBeats: newYellow,
    );

    return {
      'assigned': assignedCount,
      'yellow': yellowCount,
      'incomplete': incompleteCount,
    };
  }

  /// Selecciona (marca con checkbox) todos los tiempos cuyos acordes tienen notas completas.
  int selectCompleteChordsBeats(int accordionNumber) {
    final isPrimary = accordionNumber == 1;
    final treble = isPrimary ? state.trebleData1 : state.trebleData2;

    final pullPcs = <int>{};
    final pushPcs = <int>{};
    for (final row in treble.values) {
      for (final btn in row) {
        pullPcs.add(btn.pull % 12);
        pushPcs.add(btn.push % 12);
      }
    }

    final completeKeys = <int>{};
    for (final measure in state.measures) {
      for (final beat in measure.beats) {
        final chord = beat.chord.trim();
        if (chord.isEmpty) continue;
        final chordPcs = ChordCatalog.pitchClassesForChordSymbol(chord);
        if (chordPcs.isEmpty) continue;
        final isCompletePush = chordPcs.difference(pushPcs).isEmpty;
        final isCompletePull = chordPcs.difference(pullPcs).isEmpty;
        if (isCompletePush || isCompletePull) {
          completeKeys.add(beat.barIndex * 4 + beat.beatIndex);
        }
      }
    }

    state = state.copyWith(markedBeats: completeKeys);
    return completeKeys.length;
  }

  /// Marca en amarillo todos los tiempos cuyos acordes están completos tanto abriendo como cerrando
  /// (abriendo o cerrando) para que el usuario pueda decidir.
  int markYellowDecisionBeats(int accordionNumber) {
    final isPrimary = accordionNumber == 1;
    final treble = isPrimary ? state.trebleData1 : state.trebleData2;

    final pullPcs = <int>{};
    final pushPcs = <int>{};
    for (final row in treble.values) {
      for (final btn in row) {
        pullPcs.add(btn.pull % 12);
        pushPcs.add(btn.push % 12);
      }
    }

    final yellowKeys = <int>{};
    for (final measure in state.measures) {
      for (final beat in measure.beats) {
        final chord = beat.chord.trim();
        if (chord.isEmpty) continue;
        final chordPcs = ChordCatalog.pitchClassesForChordSymbol(chord);
        if (chordPcs.isEmpty) continue;
        final isCompletePush = chordPcs.difference(pushPcs).isEmpty;
        final isCompletePull = chordPcs.difference(pullPcs).isEmpty;
        if (isCompletePush && isCompletePull) {
          yellowKeys.add(beat.barIndex * 4 + beat.beatIndex);
        }
      }
    }

    state = state.copyWith(yellowDecisionBeats: yellowKeys);
    return yellowKeys.length;
  }

  /// Aplica la decisión de fuelle (Abre o Cierra) a todos los acordes resaltados en amarillo
  /// y limpia el resaltado de decisión (Command Pattern + Memento).
  int applyYellowDecision(BellowsMode mode, [Set<int>? specificKeys]) {
    final targets = specificKeys ?? state.yellowDecisionBeats;
    if (targets.isEmpty) return 0;

    _gridHistory.saveSnapshot(
      measures: state.measures,
      markedBeats: state.markedBeats,
      yellowDecisionBeats: state.yellowDecisionBeats,
    );

    final result = ApplyYellowDecisionCommand(
      measures: state.measures,
      yellowDecisionBeats: state.yellowDecisionBeats,
      mode: mode,
      specificTargets: specificKeys,
    ).execute();

    state = state.copyWith(
      measures: result.updatedMeasures,
      yellowDecisionBeats: result.remainingYellowBeats,
    );
    return result.appliedCount;
  }

  /// Limpia las marcas amarillas de decisión de fuelle.
  void clearYellowDecisionBeats() =>
      state = state.copyWith(yellowDecisionBeats: const {});

  /// Asigna el acorde del constructor a todas las casillas marcadas.
  /// Devuelve el símbolo asignado, o `null` si no hay acorde o destinos válidos.
  String? assignFreeChordToMarkedBeats() {
    return _assignFreeChordToBeatKeys(state.markedBeats);
  }

  /// Asigna el acorde del constructor a las cajas seleccionadas en modo múltiple.
  /// {P}: el modo está activo y existen destinos válidos.
  /// {Q}: los destinos reciben el acorde y la selección queda limpia.
  String? assignFreeChordToMultiBeatTargets() {
    if (!state.isMultiBeatAssignmentMode) return null;
    final symbol = _assignFreeChordToBeatKeys(state.multiBeatAssignmentTargets);
    if (symbol == null) return null;
    state = state.copyWith(
      isMultiBeatAssignmentMode: false,
      multiBeatAssignmentTargets: const {},
    );
    return symbol;
  }

  String? _assignFreeChordToBeatKeys(Set<int> targetKeys) {
    final symbol = _freeChordSymbol();
    if (symbol == null || targetKeys.isEmpty) return null;

    final updatedMeasures = List<MeasureRow>.from(state.measures);
    var applied = false;
    for (final key in targetKeys) {
      final barIndex = key ~/ 4;
      final beatIndex = key % 4;
      if (barIndex < 0 || barIndex >= updatedMeasures.length) continue;

      final row = updatedMeasures[barIndex];
      if (beatIndex < 0 || beatIndex >= row.beats.length) continue;

      final beats = List<MeasureBeat>.from(row.beats);
      beats[beatIndex] = beats[beatIndex].copyWith(chord: symbol);
      updatedMeasures[barIndex] = MeasureRow(
        barNumber: row.barNumber,
        beats: beats,
      );
      applied = true;
    }

    if (!applied) return null;
    state = state.copyWith(measures: updatedMeasures);
    return symbol;
  }

  /// Inserta el acorde generado en el constructor en la casilla enfocada.
  /// Devuelve el símbolo insertado, o `null` si no hay acorde o destino válido.
  String? insertFreeChordIntoSelectedCell() {
    final symbol = _freeChordSymbol();
    if (symbol == null) return null;

    final barIndex = state.selectedBarIndex;
    final beatIndex = state.selectedBeatIndex;
    if (barIndex == null || beatIndex == null) return null;
    if (barIndex < 0 || barIndex >= state.measures.length) return null;
    final row = state.measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return null;

    final key = beatKey(barIndex, beatIndex);
    updateMeasureBeat(barIndex, beatIndex, symbol);
    state = state.copyWith(
      markedBeats: Set<int>.from(state.markedBeats)..add(key),
    );
    return symbol;
  }

  /// Inserta el acorde del constructor en los tiempos marcados o, si no hay
  /// marcas, en la casilla enfocada. Conserva el comportamiento anterior para
  /// consumidores existentes; la interfaz ofrece acciones separadas.
  String? insertFreeChordIntoSelectedBeat() {
    if (state.markedBeats.isNotEmpty) {
      return assignFreeChordToMarkedBeats();
    }
    return insertFreeChordIntoSelectedCell();
  }

  String? _freeChordSymbol() {
    final symbol = ChordCatalog.symbolFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      bass: state.freeChordBass,
      latin: state.notation != NotationMode.alemana,
    );
    return symbol.isEmpty ? null : symbol;
  }

  /// Activa o desactiva la visibilidad del modal movible de asignación múltiple de acorde.
  void setShowMultiBeatModal(bool show) {
    if (show) {
      final symbol = (state.multiBeatChord?.trim().isNotEmpty == true)
          ? state.multiBeatChord!.trim()
          : ChordCatalog.symbolFor(
              root: state.freeChordRoot,
              type: state.freeChordType,
              extension: state.freeChordFourth,
              latin: state.notation != NotationMode.alemana,
            );
      // Recolectar todas las posiciones actuales de este acorde en todos los compases y cuadros
      final positions = <String>[];
      final chordMarkedBeats = <int>{};
      for (var m = 0; m < state.measures.length; m++) {
        for (var b = 0; b < state.measures[m].beats.length; b++) {
          if (state.measures[m].beats[b].chord.trim() == symbol) {
            positions.add('${m + 1}.${b + 1}');
            chordMarkedBeats.add(beatKey(m, b));
          }
        }
      }
      final pattern = positions.isNotEmpty
          ? positions.join(', ')
          : (state.multiBeatChord == symbol ? state.multiBeatPattern : '');

      state = state.copyWith(
        showMultiBeatModal: true,
        multiBeatChord: symbol,
        multiBeatPattern: pattern,
        markedBeats: chordMarkedBeats.isNotEmpty
            ? chordMarkedBeats
            : state.markedBeats,
      );
    } else {
      state = state.copyWith(showMultiBeatModal: false);
    }
  }

  /// Alterna el estado del modal movible para el acorde actual del constructor armónico.
  void toggleMultiBeatModal() {
    setShowMultiBeatModal(!state.showMultiBeatModal);
  }

  /// Abre el modal movible enfocado en un acorde específico y precarga sus posiciones.
  /// Además, deja seleccionados (marcados) todos los cuadros donde se encuentra este acorde.
  void openMultiBeatModalForChord(String chord, {String? pattern}) {
    final effectiveChord = chord.trim();
    String effectivePattern = pattern ?? '';
    final positions = <String>[];
    final chordMarkedBeats = <int>{};

    for (var m = 0; m < state.measures.length; m++) {
      for (var b = 0; b < state.measures[m].beats.length; b++) {
        if (state.measures[m].beats[b].chord.trim() == effectiveChord) {
          positions.add('${m + 1}.${b + 1}');
          chordMarkedBeats.add(beatKey(m, b));
        }
      }
    }

    if (pattern == null && effectiveChord.isNotEmpty) {
      effectivePattern = positions.join(', ');
    }

    state = state.copyWith(
      showMultiBeatModal: true,
      multiBeatChord: effectiveChord,
      multiBeatPattern: effectivePattern,
      markedBeats: chordMarkedBeats.isNotEmpty
          ? chordMarkedBeats
          : state.markedBeats,
      selectedBarIndex: positions.isNotEmpty
          ? int.parse(positions.first.split('.').first) - 1
          : state.selectedBarIndex,
      selectedBeatIndex: positions.isNotEmpty
          ? int.parse(positions.first.split('.').last) - 1
          : state.selectedBeatIndex,
    );
  }

  /// Aplica el acorde en múltiples compases según el patrón "Compás.Cuadro" (ej: "1.1, 2.3, 5.2").
  /// Expande automáticamente los compases de la cuadrícula si el patrón requiere compases adicionales.
  /// Si [replaceExisting] es true, limpia las asignaciones previas de este acorde para reflejar exactamente la edición.
  /// Todos los cuadros registrados quedan seleccionados en [markedBeats].
  int applyMultiBeatChord({
    required String chord,
    required String pattern,
    bool replaceExisting = true,
    double? startTime,
    double? endTime,
  }) {
    if (chord.trim().isEmpty) return 0;
    final positions = parseMultiBeatPositions(pattern);
    if (positions.isEmpty) return 0;

    _gridHistory.saveSnapshot(
      measures: state.measures,
      markedBeats: state.markedBeats,
      yellowDecisionBeats: state.yellowDecisionBeats,
    );

    final command = ApplyMultiBeatChordCommand(
      chord: chord,
      pattern: pattern,
      currentMeasures: state.measures,
      replaceExisting: replaceExisting,
      startTime: startTime,
      endTime: endTime,
    );
    final result = command.execute();
    if (result.appliedCount == 0) return 0;

    state = state.copyWith(
      measures: result.updatedMeasures,
      multiBeatChord: chord.trim(),
      multiBeatPattern: pattern,
      markedBeats: result.markedBeats,
      selectedBarIndex: positions.first.barNumber - 1,
      selectedBeatIndex: positions.first.beatNumber - 1,
    );

    return result.appliedCount;
  }

  /// Parsea tokens en formato "Compás.Cuadro" (1-indexed, ej: "1.1, 2.3, 5.2").
  static List<({int barNumber, int beatNumber})> parseMultiBeatPositions(
    String pattern,
  ) {
    final result = <({int barNumber, int beatNumber})>[];
    if (pattern.trim().isEmpty) return result;

    final tokens = pattern.split(',');
    for (final rawToken in tokens) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      final parts = token.split(RegExp(r'[.:\-]'));
      if (parts.length >= 2) {
        final bar = int.tryParse(parts[0].trim());
        final beat = int.tryParse(parts[1].trim());
        if (bar != null && bar >= 1 && beat != null && beat >= 1 && beat <= 4) {
          result.add((barNumber: bar, beatNumber: beat));
        }
      }
    }
    return result;
  }

  /// Exporta los compases actuales a formato JSON (incluye 4 secciones por compás con sus acordes, fuelle, afinación y tiempos marcados).
  String exportMeasuresToJson({String? name}) {
    return MeasureJsonSerializer.exportToJson(
      state.measures,
      bpm: state.audioReport?.bpm,
      name: name,
      tuning: state.tuning1.name,
      markedBeats: state.markedBeats,
    );
  }

  /// Restaura los compases a partir de una cadena JSON y actualiza el estado.
  bool loadMeasuresFromJson(String jsonContent) {
    try {
      final parsed = MeasureJsonSerializer.parseJsonData(jsonContent);
      if (parsed.measures.isEmpty) return false;
      state = state.copyWith(
        measures: parsed.measures,
        markedBeats: parsed.markedBeats,
        selectedBarIndex: 0,
        selectedBeatIndex: 0,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // Sección 5: Acorde Libre
  // Cada opción funciona como interruptor: al pulsar la opción activa se
  // desactiva (valor neutro) y al pulsarla de nuevo se vuelve a activar.
  void setFreeChordRoot(int root) => state = state.copyWith(
    freeChordRoot: state.freeChordRoot == root ? -1 : root,
    isFreeChordBeingEdited: true,
  );
  void setFreeChordType(String type) => state = state.copyWith(
    freeChordType: state.freeChordType == type ? '' : type,
    isFreeChordBeingEdited: true,
  );
  void setFreeChordFourth(String fourth) => state = state.copyWith(
    freeChordFourth: state.freeChordFourth == fourth ? '' : fourth,
    isFreeChordBeingEdited: true,
  );
  void setFreeChordOctave(String oct) => state = state.copyWith(
    freeChordOctave: state.freeChordOctave == oct ? '' : oct,
    isFreeChordBeingEdited: true,
  );
  void setFreeChordMode(String mode) =>
      state = state.copyWith(freeChordMode: mode);
  void toggleFreeChordFixed() =>
      state = state.copyWith(isFreeChordFixed: !state.isFreeChordFixed);
  void setFreeChordBellows(BellowsMode m) =>
      state = state.copyWith(freeChordBellows: m);
  void setFreeChordScaleHarmonicMode(String mode) {
    if (state.freeChordScaleHarmonicMode == mode) {
      if (mode == 'five') return;
      state = state.copyWith(
        freeChordScaleHarmonicMode: '',
        isFreeChordBeingEdited: true,
      );
      return;
    }
    // Si selecciona 'triad', se limpia la 7ma/extensión.
    // Si selecciona 'seventh', se activa la 7ma según la cualidad si no hay extensión.
    String updatedFourth = state.freeChordFourth;
    if (mode == 'triad') {
      if (['dom7', 'maj7', 'min7', 'dim7', 'five'].contains(updatedFourth)) {
        updatedFourth = '';
      }
    } else if (mode == 'seventh') {
      if (updatedFourth.isEmpty ||
          updatedFourth == 'none' ||
          updatedFourth == 'octave' ||
          updatedFourth == 'five') {
        updatedFourth = switch (state.freeChordType) {
          'min' => 'min7',
          'dim' => 'dim7',
          _ => 'dom7',
        };
      }
    } else if (mode == 'five') {
      updatedFourth = 'five';
    }
    state = state.copyWith(
      freeChordScaleHarmonicMode: mode,
      freeChordFourth: updatedFourth,
      isFreeChordBeingEdited: true,
    );
  }

  void selectFreeChordDegree(int semitones, String quality) {
    final baseRoot = state.freeChordRoot < 0 ? 0 : state.freeChordRoot;
    final newRoot = (baseRoot + semitones) % 12;
    String newType = 'maj';
    if (quality.toLowerCase().contains('menor')) newType = 'min';
    if (quality.toLowerCase().contains('disminuido')) newType = 'dim';
    state = state.copyWith(
      freeChordRoot: newRoot,
      freeChordType: newType,
      freeChordBellows: BellowsMode.push,
      isFreeChordBeingEdited: true,
    );
    playFreeChord();
  }

  void playFreeChord() {
    final useArpeggio = state.freeChord.mode == 'melodic';
    _freeChordCoordinator.playFreeChord(
      arpeggio: useArpeggio,
      highlight: const Duration(milliseconds: 900),
    );
  }

  Future<void> arpeggioFreeChord() async {
    _freeChordCoordinator.playFreeChord(
      arpeggio: true,
      highlight: const Duration(milliseconds: 900),
    );
  }

  // Sección 3: Detector de Acordes
  void toggleDetectorMode() {
    state = state.copyWith(
      detectorMode: !state.detectorMode,
      activeButtons: const {},
    );
  }

  void setDetectorDirection(String dir) {
    state = state.copyWith(detectorDirection: dir);
  }

  void toggleDetectorButton(String buttonId, int midiNote) {
    final list = List<String>.from(state.detectorSelectedButtons);
    if (list.contains(buttonId)) {
      list.remove(buttonId);
    } else {
      list.add(buttonId);
    }
    state = state.copyWith(detectorSelectedButtons: list);
    _recalculateDetectedChord();
  }

  void clearDetector() {
    state = state.copyWith(
      detectorSelectedButtons: const [],
      detectedChord: null,
      activeButtons: const {},
    );
  }

  /// Limpia completamente el diapasón dejando 0 botones presionados o resaltados (Command Pattern).
  void clearDiapason() {
    ClearDiapasonCommand(
      ({
        required freeChordRoot,
        required isFreeChordFixed,
        required activeButtons,
        required detectorSelectedButtons,
        required detectedChord,
        required playingChordNotes,
      }) {
        state = state.copyWith(
          freeChordRoot: freeChordRoot,
          isFreeChordFixed: isFreeChordFixed,
          activeButtons: activeButtons,
          detectorSelectedButtons: detectorSelectedButtons,
          detectedChord: detectedChord,
          playingChordNotes: playingChordNotes,
        );
      },
      onCancelAudioPlayback: () {
        _currentBeatNotes = [];
        _audioBridge.allNotesOff();
      },
    ).execute();
  }

  void playDetectorChord() {
    if (state.detectorSelectedButtons.isEmpty && state.detectedChord == null) {
      return;
    }
    final notes = <int>[];
    if (state.detectedChord != null && state.detectedChord!.notes.isNotEmpty) {
      notes.addAll(state.detectedChord!.notes);
    } else {
      for (final btnId in state.detectorSelectedButtons) {
        for (final row in state.trebleData1.values) {
          for (final btn in row) {
            if (btn.id == btnId) {
              final midi = state.bellows1 == BellowsMode.pull
                  ? btn.pull
                  : btn.push;
              notes.add(midi);
            }
          }
        }
      }
    }
    for (final note in notes) {
      _audioBridge.noteOn(note);
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      for (final note in notes) {
        _audioBridge.noteOff(note);
      }
    });
  }

  void arpeggioDetectorChord() async {
    if (state.detectorSelectedButtons.isEmpty && state.detectedChord == null) {
      return;
    }
    final notes = <int>[];
    if (state.detectedChord != null && state.detectedChord!.notes.isNotEmpty) {
      notes.addAll(state.detectedChord!.notes);
    } else {
      for (final btnId in state.detectorSelectedButtons) {
        for (final row in state.trebleData1.values) {
          for (final btn in row) {
            if (btn.id == btnId) {
              final midi = state.bellows1 == BellowsMode.pull
                  ? btn.pull
                  : btn.push;
              notes.add(midi);
            }
          }
        }
      }
    }
    for (final note in notes) {
      _audioBridge.noteOn(note);
      await Future.delayed(const Duration(milliseconds: 220));
      _audioBridge.noteOff(note);
    }
  }

  /// Asigna el acorde detectado al compás y tiempo seleccionado actualmente (Command Pattern).
  void assignDetectedChordToCompas([int accordionNumber = 1]) {
    final barIdx = state.selectedBarIndex ?? 0;
    final beatIdx = state.selectedBeatIndex ?? 0;
    final treble = accordionNumber == 1 ? state.trebleData1 : state.trebleData2;

    AssignDetectedChordCommand(
      chord: state.detectedChord,
      barIndex: barIdx,
      beatIndex: beatIdx,
      notation: state.notation,
      trebleData: treble,
      onUpdateBeat: updateMeasureBeat,
      onSetBellows: (bar, beat, bellows) => setBeatBellows(bar, beat, bellows),
    ).execute();
  }

  /// Transfiere de forma persistente y armónicamente completa el acorde detectado al Constructor Libre.
  void transferDetectedChordToConstructor() {
    final params = TransferDetectedChordCommand(state.detectedChord).execute();
    if (params == null) return;

    state = state.copyWith(
      freeChordRoot: params.root,
      freeChordType: params.type,
      freeChordFourth: params.fourth,
      freeChordBass: params.bass,
      isFreeChordFixed: params.isFixed,
      isFreeChordBeingEdited: true,
    );
  }

  /// Muestra el acorde detectado en el diapasón principal fijando sus notas y sincronizando el constructor.
  void showDetectedChordOnDiapason() {
    transferDetectedChordToConstructor();
  }

  void _recalculateDetectedChord() {
    if (state.detectorSelectedButtons.length < 2) {
      state = state.copyWith(detectedChord: null);
      return;
    }

    final selectedIds = state.detectorSelectedButtons.toSet();
    final pullNotes = <int>[];
    final pushNotes = <int>[];

    for (final row in state.trebleData1.values) {
      for (final btn in row) {
        if (selectedIds.contains(btn.id)) {
          if (!pullNotes.contains(btn.pull)) pullNotes.add(btn.pull);
          if (!pushNotes.contains(btn.push)) pushNotes.add(btn.push);
        }
      }
    }

    final List<int> effectiveNotes;
    if (state.bellows1 == BellowsMode.pull) {
      effectiveNotes = pullNotes;
    } else if (state.bellows1 == BellowsMode.push) {
      effectiveNotes = pushNotes;
    } else {
      // BellowsMode.both: analizar ambos sentidos y enriquecer información
      final pushDet = pushNotes.length >= 2
          ? ChordDetectorEngine.detect(
              midiNotes: pushNotes,
              notation: state.notation,
            )
          : null;
      final pullDet = pullNotes.length >= 2
          ? ChordDetectorEngine.detect(
              midiNotes: pullNotes,
              notation: state.notation,
            )
          : null;

      if (pushDet != null && pullDet == null) {
        state = state.copyWith(detectedChord: pushDet);
        return;
      } else if (pullDet != null && pushDet == null) {
        state = state.copyWith(detectedChord: pullDet);
        return;
      } else if (pushDet != null && pullDet != null) {
        final combinedAlts = List<String>.from(pushDet.alternatives);
        final pullSym = pullDet.formattedSymbol(state.notation);
        if (!combinedAlts.contains(pullSym) &&
            pullSym != pushDet.formattedSymbol(state.notation)) {
          combinedAlts.insert(0, 'Abre: $pullSym');
        }
        state = state.copyWith(
          detectedChord: DetectedChordModel(
            name: pushDet.name,
            root: pushDet.root,
            bass: pushDet.bass,
            formula: pushDet.formula,
            type: pushDet.type,
            inversion: pushDet.inversion,
            alternatives: combinedAlts,
            chordSymbol: pushDet.chordSymbol,
            pitchClasses: pushDet.pitchClasses,
            rootPitchClass: pushDet.rootPitchClass,
            bassPitchClass: pushDet.bassPitchClass,
            notes: pushDet.notes,
          ),
        );
        return;
      }
      effectiveNotes = pushNotes;
    }

    if (effectiveNotes.length < 2) {
      state = state.copyWith(detectedChord: null);
      return;
    }

    final detected = ChordDetectorEngine.detect(
      midiNotes: effectiveNotes,
      notation: state.notation,
    );
    state = state.copyWith(detectedChord: detected);
  }
}

final accordionSimulatorProvider =
    NotifierProvider<AccordionSimulatorNotifier, AccordionSimulatorState>(() {
      return AccordionSimulatorNotifier();
    });

/// Selector memoizado para las clases de altura activas de un diapasón (1 o 2).
/// Evita recalculaciones en cada frame de reproducción.
final activeChordPitchClassesProvider = Provider.family<Set<int>, int>((
  ref,
  accordionNumber,
) {
  final isPrimary = accordionNumber == 1;
  final trebleData = ref.watch(
    accordionSimulatorProvider.select(
      (s) => isPrimary ? s.trebleData1 : s.trebleData2,
    ),
  );
  final freeChordRoot = ref.watch(
    accordionSimulatorProvider.select((s) => s.freeChordRoot),
  );
  final freeChordType = ref.watch(
    accordionSimulatorProvider.select((s) => s.freeChordType),
  );
  final freeChordFourth = ref.watch(
    accordionSimulatorProvider.select((s) => s.freeChordFourth),
  );
  final detectorMode = ref.watch(
    accordionSimulatorProvider.select((s) => s.detectorMode),
  );
  final detectorSelected = ref.watch(
    accordionSimulatorProvider.select((s) => s.detectorSelectedButtons),
  );
  final detectedChord = ref.watch(
    accordionSimulatorProvider.select((s) => s.detectedChord),
  );
  final syncDiapason = ref.watch(
    accordionSimulatorProvider.select((s) => s.syncDiapason),
  );
  final isPlaying = ref.watch(
    accordionSimulatorProvider.select((s) => s.isPlayingAudio),
  );
  final playingChordNotes = ref.watch(
    accordionSimulatorProvider.select((s) => s.playingChordNotes),
  );

  final isFreeChordFixed = ref.watch(
    accordionSimulatorProvider.select((s) => s.isFreeChordFixed),
  );
  final isFreeChordBeingEdited = ref.watch(
    accordionSimulatorProvider.select((s) => s.isFreeChordBeingEdited),
  );

  final generated = freeChordRoot >= 0
      ? ChordCatalog.notesFor(
          root: freeChordRoot,
          type: freeChordType,
          extension: freeChordFourth,
        )
      : const <int>[];

  // Acorde activo en el Compás (seleccionado o reproduciéndose)
  final compasChord = ref.watch(
    accordionSimulatorProvider.select((s) => s.activeCompasChord),
  );

  // Clases de altura del acorde del Compás
  final compasPcs = compasChord.isNotEmpty
      ? ChordCatalog.pitchClassesForChordSymbol(compasChord)
      : const <int>{};

  final selectedChordNotes = <int>[];
  if (detectorSelected.isNotEmpty) {
    final selectedIds = detectorSelected.toSet();
    for (final row in trebleData.values) {
      for (final btn in row) {
        if (selectedIds.contains(btn.id)) {
          selectedChordNotes
            ..add(btn.pull)
            ..add(btn.push);
        }
      }
    }
  }

  // Si estamos en modo detector, el diapasón no debe arrastrar el acorde
  // del constructor libre (ej. Do Mayor). Debe mantenerse limpio o mostrar
  // únicamente los botones del detector.
  final Set<int> baseChordPcs;
  if (detectorMode) {
    baseChordPcs = const <int>{};
  } else if (!isFreeChordFixed &&
      !isFreeChordBeingEdited &&
      compasPcs.isNotEmpty) {
    baseChordPcs = compasPcs;
  } else {
    baseChordPcs =
        (freeChordRoot >= 0 &&
            (isFreeChordFixed || !isPlaying || !syncDiapason))
        ? generated.map((n) => n % 12).toSet()
        : const <int>{};
  }

  final playingPcs = (syncDiapason && isPlaying)
      ? playingChordNotes.map((n) => n % 12).toSet()
      : const <int>{};

  return <int>{
    ...baseChordPcs,
    ...playingPcs,
    ...selectedChordNotes.map((n) => n % 12),
    if (detectedChord != null) ...detectedChord.pitchClasses,
  };
});

/// Selector atómico memoizado que indica si el diapasón está en reposo limpio (sin notas activas).
final isDiapasonCleanProvider = Provider<bool>((ref) {
  final activeButtons = ref.watch(
    accordionSimulatorProvider.select((s) => s.activeButtons),
  );
  final detectorMode = ref.watch(
    accordionSimulatorProvider.select((s) => s.detectorMode),
  );
  final detectorButtons = ref.watch(
    accordionSimulatorProvider.select((s) => s.detectorSelectedButtons),
  );
  final freeRoot = ref.watch(
    accordionSimulatorProvider.select((s) => s.freeChordRoot),
  );
  final compasChord = ref.watch(
    accordionSimulatorProvider.select((s) => s.activeCompasChord),
  );
  final isPlaying = ref.watch(
    accordionSimulatorProvider.select((s) => s.isPlayingAudio),
  );

  if (activeButtons.isNotEmpty || isPlaying) return false;
  if (detectorMode) return detectorButtons.isEmpty;
  return freeRoot < 0 && compasChord.isEmpty;
});

/// Selector atómico memoizado de la dirección del fuelle de un acordeón específico (ISP).
final bellowsModeProvider = Provider.family<BellowsMode, int>((ref, accNumber) {
  return ref.watch(
    accordionSimulatorProvider.select(
      (s) => accNumber == 1 ? s.bellows1 : s.bellows2,
    ),
  );
});

/// Selector atómico del estado del detector de acordes para widgets especializados (ISP).
final detectorStatusSliceProvider =
    Provider<({bool active, int count, bool hasChord})>((ref) {
      final mode = ref.watch(
        accordionSimulatorProvider.select((s) => s.detectorMode),
      );
      final count = ref.watch(
        accordionSimulatorProvider.select(
          (s) => s.detectorSelectedButtons.length,
        ),
      );
      final hasChord = ref.watch(
        accordionSimulatorProvider.select((s) => s.detectedChord != null),
      );
      return (active: mode, count: count, hasChord: hasChord);
    });

/// ─── Selectores finos (ISP + menor reconstrucción de widgets) ───────────────
///
/// Selectores atómicos por campo que aíslan a cada widget de los cambios del
/// resto del estado global. Un widget que solo necesita `isPlayingAudio` no
/// debe reconstruirse cuando cambia `measures`.

/// Transporte: está reproduciendo el archivo cargado.
final isPlayingAudioProvider = Provider<bool>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.isPlayingAudio),
  );
});

/// Transporte: posición actual del archivo (se actualiza cada tick).
final currentAudioTimeProvider = Provider<double>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.currentAudioTime),
  );
});

/// Transporte: duración total conocida del archivo cargado.
final totalAudioDurationProvider = Provider<double>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.totalAudioDuration),
  );
});

/// Transporte: acoplamiento del Compás con el archivo.
final isAudioCoupledProvider = Provider<bool>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.isAudioCoupled),
  );
});

/// Cuadrícula: número de compases (para scrollbars/contadores).
final measuresCountProvider = Provider<int>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.measures.length),
  );
});

/// Cuadrícula: acordes visibles por compás, memoizados por identidad de lista.
/// Útil para widgets que sólo necesitan re-dibujar los textos de acorde.
final measuresProvider = Provider<List<MeasureRow>>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.measures),
  );
});

/// Análisis: reporte completo de la pista cargada (o null si no hay).
final audioReportProvider = Provider<AudioAnalysisReport?>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.audioReport),
  );
});

/// Análisis: BPM detectado/calibrado, con valor por defecto 120.
final audioBpmProvider = Provider<int>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.audioReport?.bpm ?? 120),
  );
});

/// Análisis: pista cargada actualmente (nombre) o null.
final loadedAudioFileNameProvider = Provider<String?>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.loadedAudioFileName),
  );
});

/// Análisis: hay un análisis en curso (spinner/botón deshabilitado).
final isAnalyzingAudioProvider = Provider<bool>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.isAnalyzingAudio),
  );
});

/// Metrónomo: activación y volumen, empaquetados para widgets del panel.
final metronomeStateProvider = Provider<({bool active, double volume})>((ref) {
  final active = ref.watch(
    accordionSimulatorProvider.select((s) => s.isMetronomeActive),
  );
  final volume = ref.watch(
    accordionSimulatorProvider.select((s) => s.metronomeVolume),
  );
  return (active: active, volume: volume);
});

/// Barra de canción: estado de acople y posición (widgets flotantes).
final songBarDockProvider = Provider<({bool undocked, Offset position})>((ref) {
  final undocked = ref.watch(
    accordionSimulatorProvider.select((s) => s.isSongBarUndocked),
  );
  final position = ref.watch(
    accordionSimulatorProvider.select((s) => s.songBarPosition),
  );
  return (undocked: undocked, position: position);
});

/// Calibración de BPM: en curso con marca temporal inicial (-1 = inactiva).
final bpmCalibrationProvider = Provider<({bool calibrating, double start})>((ref) {
  final start = ref.watch(
    accordionSimulatorProvider.select((s) => s.bpmCalibrationStart),
  );
  return (calibrating: start >= 0.0, start: start);
});

/// Notación activa (latina/alemana) para widgets de texto de acordes.
final notationModeProvider = Provider<NotationMode>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.notation),
  );
});

/// Volúmenes de ambos acordeones, empaquetados para el mezclador.
final mixerVolumesProvider = Provider<({double v1, double v2, bool sync})>((ref) {
  final v1 = ref.watch(
    accordionSimulatorProvider.select((s) => s.volume1),
  );
  final v2 = ref.watch(
    accordionSimulatorProvider.select((s) => s.volume2),
  );
  final sync = ref.watch(
    accordionSimulatorProvider.select((s) => s.syncVolume),
  );
  return (v1: v1, v2: v2, sync: sync);
});
