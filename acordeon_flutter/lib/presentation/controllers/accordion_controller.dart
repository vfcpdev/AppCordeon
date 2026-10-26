import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/analysis/tuning_recommender.dart';
import '../../core/audio/audio_analyzer.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/audio/audio_file_loader_interface.dart';
import '../../core/audio/audio_file_player.dart';
import '../../core/audio/demo_track_generator.dart';
import '../../core/constants/enums.dart';
import '../../core/di/providers.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/audio_analysis_models.dart';
import '../../domain/models/measure_json_serializer.dart';
import '../../domain/models/measure_models.dart';
import '../../domain/models/tuning.dart';
import '../../domain/theory/chord_catalog.dart';

export '../../domain/models/measure_json_serializer.dart';
export '../../domain/models/measure_models.dart';

/// Resultado de una operación de carga de audio. La UI decide cómo mostrarlo.
sealed class AudioLoadResult {
  const AudioLoadResult();
}

class AudioLoadSuccess extends AudioLoadResult {
  final AudioAnalysisReport report;
  final String fileName;
  const AudioLoadSuccess(this.report, this.fileName);
}

class AudioLoadCancelled extends AudioLoadResult {
  const AudioLoadCancelled();
}

class AudioLoadFailure extends AudioLoadResult {
  final String message;
  const AudioLoadFailure(this.message);
}

/// Estado global del simulador de Acordeón
class AccordionSimulatorState {
  // Configuración General
  final Color backgroundColor;
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
  final bool isPlayingAudio;
  final double currentAudioTime;
  final double totalAudioDuration;
  final bool syncDiapason;

  /// `true` = el transporte del Compás controla el archivo de audio cargado.
  /// `false` = el Compás avanza por su propio reloj/BPM y la pista queda en pausa.
  final bool isAudioCoupled;

  /// Volumen propio de la sección Compás (pista y acordes sintetizados).
  final double compasVolume;

  /// Notas MIDI que están sonando en el compás actual (para el diapasón).
  final Set<int> playingChordNotes;
  final bool sequenceMode;
  final int visibleGridRows;
  final List<MeasureRow> measures;
  final int? selectedBarIndex;
  final int? selectedBeatIndex;

  /// Tiempos marcados con el checkbox de la cuadrícula. Si hay alguno, la
  /// inserción desde el Constructor y la reproducción se limitan a ellos.
  final Set<int> markedBeats;

  // Sección 5: Acorde Libre y Escalas
  final int freeChordRoot; // 0=Do, 1=Do#, etc.
  final String freeChordType; // maj, min, dim, aug, sus4
  final String freeChordFourth; // none, octave, dom7, maj7, maj6, add9
  final String freeChordOctave; // all, 3, 4, 5
  final String freeChordMode; // harmonic, melodic
  final bool isFreeChordFixed;
  final BellowsMode freeChordBellows;
  final String freeChordScaleHarmonicMode; // triad, seventh

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
  final String multiBeatPattern;
  final String? multiBeatChord;

  // Cuadro de compás acoplable/desacoplable y movible
  final bool isCompas1Undocked;
  final Offset compas1Position;
  final bool isCompas2Undocked;
  final Offset compas2Position;

  const AccordionSimulatorState({
    required this.backgroundColor,
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
    required this.isPlayingAudio,
    required this.currentAudioTime,
    required this.totalAudioDuration,
    required this.syncDiapason,
    required this.isAudioCoupled,
    required this.compasVolume,
    required this.playingChordNotes,
    required this.sequenceMode,
    required this.visibleGridRows,
    required this.measures,
    this.selectedBarIndex,
    this.selectedBeatIndex,
    this.markedBeats = const {},
    required this.freeChordRoot,
    required this.freeChordType,
    required this.freeChordFourth,
    required this.freeChordOctave,
    required this.freeChordMode,
    required this.isFreeChordFixed,
    required this.freeChordBellows,
    required this.freeChordScaleHarmonicMode,
    required this.detectorMode,
    required this.detectorDirection,
    required this.detectorSelectedButtons,
    this.detectedChord,
    this.audioReport,
    this.isAnalyzingAudio = false,
    this.loadedAudioFileName,
    this.showMultiBeatModal = false,
    this.multiBeatPattern = '',
    this.multiBeatChord,
    this.isCompas1Undocked = false,
    this.compas1Position = const Offset(220, 70),
    this.isCompas2Undocked = false,
    this.compas2Position = const Offset(440, 70),
  });

  AccordionSimulatorState copyWith({
    Color? backgroundColor,
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
    bool? isPlayingAudio,
    double? currentAudioTime,
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
    Set<int>? markedBeats,
    int? freeChordRoot,
    String? freeChordType,
    String? freeChordFourth,
    String? freeChordOctave,
    String? freeChordMode,
    bool? isFreeChordFixed,
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
    bool? showMultiBeatModal,
    String? multiBeatPattern,
    String? multiBeatChord,
    bool clearMultiBeatChord = false,
    bool? isCompas1Undocked,
    Offset? compas1Position,
    bool? isCompas2Undocked,
    Offset? compas2Position,
  }) {
    return AccordionSimulatorState(
      backgroundColor: backgroundColor ?? this.backgroundColor,
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
      isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
      currentAudioTime: currentAudioTime ?? this.currentAudioTime,
      totalAudioDuration: totalAudioDuration ?? this.totalAudioDuration,
      syncDiapason: syncDiapason ?? this.syncDiapason,
      isAudioCoupled: isAudioCoupled ?? this.isAudioCoupled,
      compasVolume: compasVolume ?? this.compasVolume,
      playingChordNotes: playingChordNotes ?? this.playingChordNotes,
      sequenceMode: sequenceMode ?? this.sequenceMode,
      visibleGridRows: visibleGridRows ?? this.visibleGridRows,
      measures: measures ?? this.measures,
      selectedBarIndex: selectedBarIndex ?? this.selectedBarIndex,
      selectedBeatIndex: selectedBeatIndex ?? this.selectedBeatIndex,
      markedBeats: markedBeats ?? this.markedBeats,
      freeChordRoot: freeChordRoot ?? this.freeChordRoot,
      freeChordType: freeChordType ?? this.freeChordType,
      freeChordFourth: freeChordFourth ?? this.freeChordFourth,
      freeChordOctave: freeChordOctave ?? this.freeChordOctave,
      freeChordMode: freeChordMode ?? this.freeChordMode,
      isFreeChordFixed: isFreeChordFixed ?? this.isFreeChordFixed,
      freeChordBellows: freeChordBellows ?? this.freeChordBellows,
      freeChordScaleHarmonicMode:
          freeChordScaleHarmonicMode ?? this.freeChordScaleHarmonicMode,
      detectorMode: detectorMode ?? this.detectorMode,
      detectorDirection: detectorDirection ?? this.detectorDirection,
      detectorSelectedButtons:
          detectorSelectedButtons ?? this.detectorSelectedButtons,
      detectedChord: detectedChord ?? this.detectedChord,
      audioReport: clearAudio ? null : (audioReport ?? this.audioReport),
      isAnalyzingAudio: isAnalyzingAudio ?? this.isAnalyzingAudio,
      loadedAudioFileName: clearAudio ? null : (loadedAudioFileName ?? this.loadedAudioFileName),
      showMultiBeatModal: showMultiBeatModal ?? this.showMultiBeatModal,
      multiBeatPattern: multiBeatPattern ?? this.multiBeatPattern,
      multiBeatChord: clearMultiBeatChord ? null : (multiBeatChord ?? this.multiBeatChord),
      isCompas1Undocked: isCompas1Undocked ?? this.isCompas1Undocked,
      compas1Position: compas1Position ?? this.compas1Position,
      isCompas2Undocked: isCompas2Undocked ?? this.isCompas2Undocked,
      compas2Position: compas2Position ?? this.compas2Position,
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

class AccordionSimulatorNotifier extends Notifier<AccordionSimulatorState> {
  late AudioEngine _audioBridge;
  late AudioAnalyzer _analyzer;
  late AudioFileLoader _fileLoader;
  late AudioFilePlayer _audioPlayer;
  late DemoTrackGenerator _demoGenerator;

  @override
  AccordionSimulatorState build() {
    _audioBridge = ref.read(audioEngineProvider);
    _analyzer = ref.read(audioAnalyzerProvider);
    _fileLoader = ref.read(audioFileLoaderProvider);
    _audioPlayer = ref.read(audioFilePlayerProvider);
    _demoGenerator = ref.read(demoTrackGeneratorProvider);
    ref.onDispose(() => _playbackTimer?.cancel());

    // Generar compases iniciales por defecto (8 compases con 4 tiempos)
    final initialMeasures = List.generate(8, (bIdx) {
      return MeasureRow(
        barNumber: bIdx + 1,
        beats: List.generate(4, (beatIdx) {
          final timeSec = (bIdx * 4 + beatIdx) * 0.5;
          final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
          final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
          return MeasureBeat(
            barIndex: bIdx,
            beatIndex: beatIdx,
            chord: (bIdx == 0 && beatIdx == 0) ? 'Bb' : '',
            timeText: '$mins:$secs',
            isContinue: (bIdx == 0 && beatIdx > 0),
          );
        }),
      );
    });

    return AccordionSimulatorState(
      backgroundColor: const Color(0xFFF1F5F9),
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
      isPlayingAudio: false,
      currentAudioTime: 0.0,
      totalAudioDuration: 180.0,
      syncDiapason: true,
      isAudioCoupled: true,
      compasVolume: 0.8,
      playingChordNotes: const {},
      sequenceMode: true,
      visibleGridRows: 4,
      measures: initialMeasures,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
      freeChordRoot: 0, // Do
      freeChordType: 'maj',
      freeChordFourth: 'none',
      freeChordOctave: 'all',
      freeChordMode: 'harmonic',
      isFreeChordFixed: false,
      freeChordBellows: BellowsMode.both,
      freeChordScaleHarmonicMode: 'triad',
      detectorMode: false,
      detectorDirection: 'auto',
      detectorSelectedButtons: const [],
      detectedChord: null,
    );
  }

  // Toggles de cabecera
  void toggleDiapason1() {
    state = state.copyWith(showDiapason1: !state.showDiapason1);
  }

  void toggleDiapason2() {
    state = state.copyWith(showDiapason2: !state.showDiapason2);
  }

  void setNotation(NotationMode notation) {
    if (state.notation == notation) return;

    final convertedMeasures = state.measures.map((row) {
      final updatedBeats = row.beats.map((beat) {
        if (beat.chord.trim().isEmpty) return beat;
        final converted = ChordCatalog.formatChordForNotation(beat.chord, notation);
        return beat.copyWith(chord: converted);
      }).toList();
      return MeasureRow(barNumber: row.barNumber, beats: updatedBeats);
    }).toList();

    state = state.copyWith(
      notation: notation,
      measures: convertedMeasures,
      multiBeatChord: state.multiBeatChord != null && state.multiBeatChord!.isNotEmpty
          ? ChordCatalog.formatChordForNotation(state.multiBeatChord!, notation)
          : state.multiBeatChord,
    );
  }

  void setBackgroundColor(Color color) {
    state = state.copyWith(backgroundColor: color);
  }

  Timer? _playbackTimer;

  // Carga y Análisis de Audio con DSP Rust
  /// IMPORTANTE (Web): no debe haber ningún `await` antes de `pickAudioFile()`
  /// para que el navegador conserve el gesto del usuario y abra el selector.
  Future<AudioLoadResult> pickAndAnalyzeAudio() async {
    try {
      final picked = await _fileLoader.pickAudioFile();
      if (picked == null) return const AudioLoadCancelled();
      return await processAudioBytes(picked.bytes, picked.name);
    } catch (e) {
      state = state.copyWith(isAnalyzingAudio: false);
      return AudioLoadFailure('Error al cargar audio: $e');
    }
  }

  /// Carga y analiza una pista demo clásica de Vallenato ("La Gota Fría" en Do Mayor / Cinco Letras)
  Future<AudioLoadResult> loadDemoAudioTrack() async {
    try {
      return await processAudioBytes(
        _demoGenerator.generate(),
        DemoTrackGenerator.demoFileName,
      );
    } catch (e) {
      state = state.copyWith(isAnalyzingAudio: false);
      return AudioLoadFailure('Error al procesar demo: $e');
    }
  }

  /// Procesa bytes de audio con el analizador inyectado y actualiza estado + acordeón
  Future<AudioLoadResult> processAudioBytes(Uint8List bytes, String fileName) async {
    // Detener cualquier reproducción anterior antes de cargar la nueva pista.
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    _audioBridge.allNotesOff();
    _currentBeatNotes = [];

    state = state.copyWith(
      isAnalyzingAudio: true,
      loadedAudioFileName: fileName,
      isPlayingAudio: false,
      currentAudioTime: 0.0,
    );

    // Dejar el archivo listo para sonar antes del análisis: el reproductor
    // conserva sus propios bytes y el DSP trabaja sobre una copia, así una
    // pista siempre se puede escuchar aunque el análisis falle.
    _audioPlayer.load(bytes, _mimeTypeFor(fileName));
    _audioPlayer.setVolume(state.compasVolume);

    final report = await _analyzer.analyzeAudio(bytes, fileName);

    state = state.copyWith(
      isAnalyzingAudio: false,
      audioReport: report,
      totalAudioDuration: report.duration,
      currentAudioTime: 0.0,
    );

    // Auto-aplicar afinación sugerida al Acordeón 1
    applyDetectedTuning(report.keyResult);

    // Ajustar la cantidad de compases para que coincida exactamente con la
    // duración y el BPM del audio, dejando los acordes vacíos para que su
    // carga sea una decisión posterior del usuario.
    generateMeasuresForAudio(
      durationSeconds: report.duration,
      bpm: report.bpm,
    );

    return AudioLoadSuccess(report, fileName);
  }

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
    state = state.copyWith(
      clearAudio: true,
      isPlayingAudio: false,
    );
  }

  void updateAudioKey(int rootMod, String mode) {
    final report = state.audioReport;
    if (report == null) return;

    const noteNamesLat = [
      'Do', 'Do♯', 'Re', 'Mi♭', 'Mi', 'Fa', 'Fa♯', 'Sol', 'Sol♯', 'La', 'Si♭', 'Si'
    ];
    const noteNamesAle = [
      'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'
    ];

    final isMajor = mode.toLowerCase() == 'major';
    final keyNameLat = '${noteNamesLat[rootMod % 12]} ${isMajor ? 'Mayor' : 'Menor'}';
    final keyNameAle = '${noteNamesAle[rootMod % 12]} ${isMajor ? 'Major' : 'Minor'}';

    final (recName, recOffset, recRow) = const TuningRecommender().recommend(rootMod % 12);

    final updatedKey = report.mainKey.copyWith(
      rootMod: rootMod % 12,
      mode: mode,
      keyNameLat: keyNameLat,
      keyNameAle: keyNameAle,
      recommendedTuning: recName,
      recommendedOffset: recOffset,
      recommendedRow: recRow,
    );

    final updatedReport = report.copyWith(mainKey: updatedKey);
    state = state.copyWith(audioReport: updatedReport);
    applyDetectedTuning(updatedKey);
  }

  void updateAudioBpm(int newBpm) {
    final clampedBpm = newBpm.clamp(30, 300);
    final report = state.audioReport;
    if (report == null) {
      const defaultKey = KeyDetectionResult(
        rootMod: 0,
        mode: 'major',
        keyNameLat: 'Do Mayor',
        keyNameAle: 'C Major',
        recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
        recommendedOffset: 10,
        recommendedRow: 'row2',
        correlation: 1.0,
      );
      state = state.copyWith(
        audioReport: AudioAnalysisReport(
          duration: 16.0,
          bpm: clampedBpm,
          mainKey: defaultKey,
          chords: const [],
        ),
      );
    } else {
      final updatedReport = report.copyWith(bpm: clampedBpm);
      state = state.copyWith(audioReport: updatedReport);
    }
  }

  void applyDetectedTuning(KeyDetectionResult keyResult) {
    final match = TuningRegistry.defaultTunings.firstWhere(
      (t) => t.offset == keyResult.recommendedOffset,
      orElse: () => TuningRegistry.defaultTunings.first,
    );
    setTuning1(match);
  }

  /// Genera la cantidad de compases vacíos necesarios para cubrir la duración
  /// completa del audio cargado según su BPM.
  void generateMeasuresForAudio({required double durationSeconds, required int bpm}) {
    final effectiveBpm = bpm > 0 ? bpm : 120;
    final secondsPerBeat = 60.0 / effectiveBpm;
    final totalBeats = (durationSeconds / secondsPerBeat).ceil();
    // 4 tiempos por compás, con un mínimo de 8 compases
    final totalBars = ((totalBeats + 3) ~/ 4).clamp(8, 500);

    final generated = List.generate(totalBars, (barIdx) {
      final barNumber = barIdx + 1;
      return MeasureRow(
        barNumber: barNumber,
        beats: List.generate(4, (bIdx) {
          final timeSec = (barIdx * 4 + bIdx) * secondsPerBeat;
          final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
          final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
          return MeasureBeat(
            barIndex: barIdx,
            beatIndex: bIdx,
            chord: '',
            timeText: '$mins:$secs',
          );
        }),
      );
    });

    state = state.copyWith(
      measures: generated,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
    );
  }

  /// Aplica los acordes detectados a los compases existentes (por decisión posterior del usuario).
  void applyChordsToMeasures(List<DetectedChordSegment> chords) {
    if (chords.isEmpty || state.measures.isEmpty) return;

    final updatedMeasures = <MeasureRow>[];
    int chordIdx = 0;

    for (final measure in state.measures) {
      final beats = <MeasureBeat>[];
      for (final beat in measure.beats) {
        final ch = chords[chordIdx % chords.length].chordSymbol;
        beats.add(beat.copyWith(chord: ch));
        if (beat.beatIndex % 2 == 1) {
          chordIdx++;
        }
      }
      updatedMeasures.add(MeasureRow(barNumber: measure.barNumber, beats: beats));
    }

    state = state.copyWith(measures: updatedMeasures);
  }

  // Controles Diapasón 1
  void setTuning1(TuningDefinition t) => state = state.copyWith(tuning1: t);
  void setBellows1(BellowsMode m) => state = state.copyWith(bellows1: m);
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

  /// Mapa raíz → semitono (MIDI pitch class, base Do = 60 - 12 = 48 + pitchClass)
  static const Map<String, int> _rootPitchClass = {
    // Latina
    'Do#': 1, 'Do♯': 1, 'Dob': 11, 'Do♭': 11, 'Do': 0,
    'Re#': 3, 'Re♯': 3, 'Reb': 1, 'Re♭': 1, 'Re': 2,
    'Mi#': 5, 'Mi♯': 5, 'Mib': 3, 'Mi♭': 3, 'Mi': 4,
    'Fa#': 6, 'Fa♯': 6, 'Fab': 4, 'Fa♭': 4, 'Fa': 5,
    'Sol#': 8, 'Sol♯': 8, 'Solb': 6, 'Sol♭': 6, 'Sol': 7,
    'La#': 10, 'La♯': 10, 'Lab': 8, 'La♭': 8, 'La': 9,
    'Si#': 0, 'Si♯': 0, 'Sib': 10, 'Si♭': 10, 'Si': 11,
    // Alemana
    'C#': 1, 'Db': 1, 'C': 0,
    'D#': 3, 'Eb': 3, 'D': 2,
    'E#': 5, 'Fb': 4, 'E': 4,
    'F#': 6, 'Gb': 6, 'F': 5,
    'G#': 8, 'Ab': 8, 'G': 7,
    'A#': 10, 'Bb': 10, 'A': 9,
    'B#': 0, 'Cb': 11, 'B': 11,
  };

  /// Convierte un símbolo de acorde textual en notas MIDI (octava 4, base 60=Do4)
  List<int> _chordSymbolToMidi(String chord) {
    final trimmed = chord.trim();
    if (trimmed.isEmpty) return [];

    // Encontrar la raíz más larga que coincida
    int? pitchClass;
    String rest = '';
    for (final entry in _rootPitchClass.entries) {
      if (trimmed.startsWith(entry.key)) {
        if (rest.isEmpty || entry.key.length > (trimmed.length - rest.length)) {
          pitchClass = entry.value;
          rest = trimmed.substring(entry.key.length);
        }
      }
    }
    if (pitchClass == null) return [];

    // Nota raíz en octava 4
    final rootMidi = 48 + pitchClass; // C4 = 60 → C3 = 48, usar octava 3 para que suene natural

    final has7 = rest.contains('7');
    final isMaj7 = rest.contains('maj7');
    final isMinor = rest.contains('m') && !rest.contains('maj') && !rest.contains('dim');
    final isDim = rest.contains('dim');
    final isAug = rest.contains('aug');
    final isSus4 = rest.contains('sus4') || rest.contains('4');
    final isSus = rest.contains('sus') && !isSus4;

    final notes = <int>[rootMidi + 12]; // tónica en octava 4
    if (isDim) {
      notes.add(rootMidi + 12 + 3); // tercera menor
      notes.add(rootMidi + 12 + 6); // quinta disminuida
    } else if (isAug) {
      notes.add(rootMidi + 12 + 4); // tercera mayor
      notes.add(rootMidi + 12 + 8); // quinta aumentada
    } else if (isSus4) {
      notes.add(rootMidi + 12 + 5); // cuarta justa
      notes.add(rootMidi + 12 + 7); // quinta justa
    } else if (isSus) {
      notes.add(rootMidi + 12 + 5); // cuarta suspendida
      notes.add(rootMidi + 12 + 7);
    } else if (isMinor) {
      notes.add(rootMidi + 12 + 3); // tercera menor
      notes.add(rootMidi + 12 + 7); // quinta justa
    } else {
      // Mayor
      notes.add(rootMidi + 12 + 4); // tercera mayor
      notes.add(rootMidi + 12 + 7); // quinta justa
    }

    // Extensiones: séptima según la cualidad, sexta, novena añadida y octava.
    if (has7) {
      notes.add(rootMidi + 12 + (isDim ? 9 : (isMaj7 ? 11 : 10)));
    }
    if (rest.contains('6') && !rest.contains('add9')) {
      notes.add(rootMidi + 12 + 9);
    }
    if (rest.contains('add9')) {
      notes.add(rootMidi + 12 + 14);
    }
    if (rest.contains('8')) {
      notes.add(rootMidi + 12 + 12);
    }
    return notes;
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
    final chord = beat.chord.trim();
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
      bellows1: beat.bellows != BellowsMode.both ? beat.bellows : state.bellows1,
    );
  }

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
      return;
    }

    state = state.copyWith(isPlayingAudio: true);
    _lastPlayedBar = null;
    _lastPlayedBeat = null;

    // Acoplado: la pista manda. Desacoplado: solo avanza el Compás.
    final useFileTransport = _audioPlayer.isLoaded && state.isAudioCoupled;
    if (useFileTransport) {
      _audioPlayer.play();
    } else {
      _audioPlayer.pause();
    }

    final bpm = state.audioReport?.bpm ?? 120.0;
    final intervalMs = ((60.0 / bpm / 2.0) * 1000).toInt().clamp(50, 1000);

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!state.isPlayingAudio) {
        timer.cancel();
        return;
      }

      final fileDrives = _audioPlayer.isLoaded && state.isAudioCoupled;
      final totalDur = fileDrives && _audioPlayer.durationSeconds > 0
          ? _audioPlayer.durationSeconds
          : (state.totalAudioDuration > 0 ? state.totalAudioDuration : 16.0);

      // Si la pista terminó, detener y volver al inicio.
      if (fileDrives && _audioPlayer.positionSeconds >= totalDur - 0.05) {
        timer.cancel();
        _audioPlayer.stop();
        _audioBridge.allNotesOff();
        _currentBeatNotes = [];
        state = state.copyWith(
          isPlayingAudio: false,
          currentAudioTime: 0.0,
          selectedBarIndex: 0,
          selectedBeatIndex: 0,
          playingChordNotes: const {},
        );
        return;
      }

      // Acoplado, la posición real manda; desacoplado, avanza el reloj.
      final nextTime = fileDrives
          ? _audioPlayer.positionSeconds
          : state.currentAudioTime + (intervalMs / 1000.0);
      final wrappedTime = !fileDrives && nextTime >= totalDur ? 0.0 : nextTime;

      final beatDuration = 60.0 / bpm;
      final totalBeats = (wrappedTime / beatDuration).floor();
      final currentBar = (totalBeats ~/ 4) % (state.measures.isNotEmpty ? state.measures.length : 8);
      final currentBeat = totalBeats % 4;

      state = state.copyWith(
        currentAudioTime: wrappedTime,
        selectedBarIndex: currentBar,
        selectedBeatIndex: currentBeat,
      );

      // Reproducir acorde al entrar en un nuevo beat
      if (currentBar != _lastPlayedBar || currentBeat != _lastPlayedBeat) {
        _lastPlayedBar = currentBar;
        _lastPlayedBeat = currentBeat;
        _playBeatChord(currentBar, currentBeat);
      }
    });
  }

  void stopAudio() {
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    _currentBeatNotes = [];
    state = state.copyWith(
      isPlayingAudio: false,
      currentAudioTime: 0.0,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
      playingChordNotes: const {},
    );
    _audioBridge.allNotesOff();
  }

  void seekAudio(double time) {
    final clamped = time.clamp(
      0.0,
      state.totalAudioDuration > 0 ? state.totalAudioDuration : time,
    );
    _audioPlayer.seek(clamped);

    final bpm = state.audioReport?.bpm ?? 120.0;
    final beatDuration = 60.0 / bpm;
    final totalBeats = (clamped / beatDuration).floor();
    final currentBar = (totalBeats ~/ 4) %
        (state.measures.isNotEmpty ? state.measures.length : 8);
    final currentBeat = totalBeats % 4;
    _lastPlayedBar = currentBar;
    _lastPlayedBeat = currentBeat;

    state = state.copyWith(
      currentAudioTime: clamped,
      selectedBarIndex: currentBar,
      selectedBeatIndex: currentBeat,
    );
  }

  /// Acopla o desacopla la pista de audio al transporte del Compás.
  ///
  /// - Acoplado: el archivo suena y su posición real manda sobre la cuadrícula.
  /// - Desacoplado: la pista se pausa y el Compás sigue con su propio reloj/BPM.
  /// Al reacoplar, la pista retoma exactamente en el tiempo actual del Compás.
  void toggleAudioCoupling() {
    final coupled = !state.isAudioCoupled;
    state = state.copyWith(isAudioCoupled: coupled);

    if (!_audioPlayer.isLoaded) return;

    if (!coupled) {
      _audioPlayer.pause();
      return;
    }

    _audioPlayer.seek(state.currentAudioTime);
    if (state.isPlayingAudio) {
      _audioPlayer.play();
    }
  }

  void toggleSyncDiapason() {
    state = state.copyWith(syncDiapason: !state.syncDiapason);
  }

  void toggleSequenceMode() {
    state = state.copyWith(sequenceMode: !state.sequenceMode);
  }

  void selectBeat(int barIdx, int beatIdx) {
    state = state.copyWith(
      selectedBarIndex: barIdx,
      selectedBeatIndex: beatIdx,
    );
  }

  /// Clave plana de un tiempo. La cuadrícula usa 4 tiempos por compás.
  static int beatKey(int barIndex, int beatIndex) => barIndex * 4 + beatIndex;

  bool isBeatMarked(int barIndex, int beatIndex) =>
      state.markedBeats.contains(beatKey(barIndex, beatIndex));

  /// Marca o desmarca un tiempo con el checkbox del Compás. Los tiempos
  /// marcados reciben el acorde del Constructor de forma simultánea y son los
  /// únicos que se ejecutan durante la reproducción.
  void toggleBeatMark(int barIndex, int beatIndex) {
    final key = beatKey(barIndex, beatIndex);
    final next = Set<int>.from(state.markedBeats);
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(markedBeats: next);
  }

  void clearBeatMarks() => state = state.copyWith(markedBeats: const {});

  /// Marca o desmarca todos los tiempos de la cuadrícula. Si todos los
  /// checkboxes están marcados, los desmarca; si no, los marca a todos.
  void toggleAllBeatMarks() {
    final total = state.measures.length * 4;
    final allMarked = total > 0 && state.markedBeats.length == total;
    if (allMarked) {
      state = state.copyWith(markedBeats: const {});
    } else {
      state = state.copyWith(
        markedBeats: {for (var i = 0; i < total; i++) i},
      );
    }
  }

  /// Borra todos los acordes registrados en la cuadrícula y desmarca
  /// todos los checkboxes.
  void deleteAllGridChords() {
    clearAllGridChords();
    clearBeatMarks();
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
    updatedMeasures[barIndex] = MeasureRow(barNumber: row.barNumber, beats: updatedBeats);

    state = state.copyWith(measures: updatedMeasures);
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

    final newBellows = targetBeat.bellows == bellows ? BellowsMode.both : bellows;
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
              updatedMeasures[bIdx] = MeasureRow(barNumber: r.barNumber, beats: bts);
            }
          }
        }
      }
    } else {
      final beats = List<MeasureBeat>.from(row.beats);
      beats[beatIndex] = targetBeat.copyWith(bellows: newBellows);
      updatedMeasures[barIndex] = MeasureRow(barNumber: row.barNumber, beats: beats);
    }

    state = state.copyWith(
      measures: updatedMeasures,
      selectedBarIndex: barIndex,
      selectedBeatIndex: beatIndex,
      bellows1: newBellows != BellowsMode.both ? newBellows : state.bellows1,
    );
  }

  /// Inserta el acorde generado en el constructor. Si hay tiempos marcados con
  /// el checkbox, se asigna a todos ellos a la vez; si no, a la celda
  /// actualmente seleccionada. Devuelve el símbolo insertado, o `null` si no
  /// hay tónica o destino válido.
  String? insertFreeChordIntoSelectedBeat() {
    final symbol = ChordCatalog.symbolFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      latin: state.notation != NotationMode.alemana,
    );
    if (symbol.isEmpty) return null;

    // Inserción simultánea en todos los tiempos marcados.
    if (state.markedBeats.isNotEmpty) {
      final updatedMeasures = List<MeasureRow>.from(state.measures);
      var applied = false;

      for (final key in state.markedBeats) {
        final barIndex = key ~/ 4;
        final beatIndex = key % 4;
        if (barIndex < 0 || barIndex >= updatedMeasures.length) continue;
        final row = updatedMeasures[barIndex];
        if (beatIndex < 0 || beatIndex >= row.beats.length) continue;

        final beats = List<MeasureBeat>.from(row.beats);
        beats[beatIndex] = beats[beatIndex].copyWith(chord: symbol);
        updatedMeasures[barIndex] =
            MeasureRow(barNumber: row.barNumber, beats: beats);
        applied = true;
      }

      if (!applied) return null;
      state = state.copyWith(measures: updatedMeasures);
      return symbol;
    }

    final barIndex = state.selectedBarIndex;
    final beatIndex = state.selectedBeatIndex;
    if (barIndex == null || beatIndex == null) return null;
    if (barIndex < 0 || barIndex >= state.measures.length) return null;
    final row = state.measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return null;

    final key = beatKey(barIndex, beatIndex);
    updateMeasureBeat(barIndex, beatIndex, symbol);
    state = state.copyWith(markedBeats: Set<int>.from(state.markedBeats)..add(key));
    return symbol;
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
        markedBeats: chordMarkedBeats.isNotEmpty ? chordMarkedBeats : state.markedBeats,
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
      markedBeats: chordMarkedBeats.isNotEmpty ? chordMarkedBeats : state.markedBeats,
      selectedBarIndex: positions.isNotEmpty ? int.parse(positions.first.split('.').first) - 1 : state.selectedBarIndex,
      selectedBeatIndex: positions.isNotEmpty ? int.parse(positions.first.split('.').last) - 1 : state.selectedBeatIndex,
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
  }) {
    if (chord.trim().isEmpty) return 0;
    final positions = parseMultiBeatPositions(pattern);
    if (positions.isEmpty) return 0;

    var maxBar = state.measures.length;
    for (final pos in positions) {
      if (pos.barNumber > maxBar) {
        maxBar = pos.barNumber;
      }
    }

    final updatedMeasures = List<MeasureRow>.from(state.measures);
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

    final trimmedChord = chord.trim();

    // En modo edición (replaceExisting), remover asignaciones previas de este acorde
    // para que la nueva cadena de texto sea la definición exacta
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

    var appliedCount = 0;
    final newMarkedBeats = <int>{};
    for (final pos in positions) {
      final bIdx = pos.barNumber - 1;
      final tIdx = pos.beatNumber - 1;
      if (bIdx >= 0 && bIdx < updatedMeasures.length) {
        final row = updatedMeasures[bIdx];
        if (tIdx >= 0 && tIdx < row.beats.length) {
          final beats = List<MeasureBeat>.from(row.beats);
          beats[tIdx] = beats[tIdx].copyWith(chord: trimmedChord);
          updatedMeasures[bIdx] = MeasureRow(barNumber: row.barNumber, beats: beats);
          newMarkedBeats.add(beatKey(bIdx, tIdx));
          appliedCount++;
        }
      }
    }

    state = state.copyWith(
      measures: updatedMeasures,
      multiBeatChord: trimmedChord,
      multiBeatPattern: pattern,
      markedBeats: newMarkedBeats,
      selectedBarIndex: positions.first.barNumber - 1,
      selectedBeatIndex: positions.first.beatNumber - 1,
    );

    return appliedCount;
  }

  /// Parsea tokens en formato "Compás.Cuadro" (1-indexed, ej: "1.1, 2.3, 5.2").
  static List<({int barNumber, int beatNumber})> parseMultiBeatPositions(String pattern) {
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
      );
  void setFreeChordType(String type) => state = state.copyWith(
        freeChordType: state.freeChordType == type ? '' : type,
      );
  void setFreeChordFourth(String fourth) => state = state.copyWith(
        freeChordFourth: state.freeChordFourth == fourth ? '' : fourth,
      );
  void setFreeChordOctave(String oct) => state = state.copyWith(
        freeChordOctave: state.freeChordOctave == oct ? '' : oct,
      );
  void setFreeChordMode(String mode) =>
      state = state.copyWith(freeChordMode: mode);
  void toggleFreeChordFixed() =>
      state = state.copyWith(isFreeChordFixed: !state.isFreeChordFixed);
  void setFreeChordBellows(BellowsMode m) =>
      state = state.copyWith(freeChordBellows: m);
  void setFreeChordScaleHarmonicMode(String mode) {
    if (state.freeChordScaleHarmonicMode == mode) {
      state = state.copyWith(freeChordScaleHarmonicMode: '');
      return;
    }
    // Si selecciona 'triad', se limpia la 7ma/extensión.
    // Si selecciona 'seventh', se activa la 7ma según la cualidad si no hay extensión.
    String updatedFourth = state.freeChordFourth;
    if (mode == 'triad') {
      if (['dom7', 'maj7', 'min7', 'dim7'].contains(updatedFourth)) {
        updatedFourth = '';
      }
    } else if (mode == 'seventh') {
      if (updatedFourth.isEmpty || updatedFourth == 'none' || updatedFourth == 'octave') {
        updatedFourth = switch (state.freeChordType) {
          'min' => 'min7',
          'dim' => 'dim7',
          _ => 'dom7',
        };
      }
    }
    state = state.copyWith(
      freeChordScaleHarmonicMode: mode,
      freeChordFourth: updatedFourth,
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
    );
    playFreeChord();
  }

  void playFreeChord() {
    final notes = _calculateFreeChordNotes();
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
    }
    // Activa visualmente el efecto glow en los botones del diapasón
    _highlightDiapasonButtonsForNotes(notes, const Duration(milliseconds: 900));

    Future.delayed(const Duration(milliseconds: 900), () {
      for (final midi in notes) {
        _audioBridge.noteOff(midi);
      }
    });
  }

  void arpeggioFreeChord() async {
    final notes = _calculateFreeChordNotes();
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
      _highlightDiapasonButtonsForNotes([midi], const Duration(milliseconds: 210));
      await Future.delayed(const Duration(milliseconds: 220));
      _audioBridge.noteOff(midi);
    }
  }

  void _highlightDiapasonButtonsForNotes(List<int> notes, Duration duration) {
    final matchingButtonIds = <String>{};
    final targetMidis = notes.toSet();
    final targetPitchClasses = notes.map((n) => n % 12).toSet();
    final octFilter = state.freeChordOctave;

    // Busca en ambos acordeones los botones correspondientes
    for (final trebleData in [state.trebleData1, state.trebleData2]) {
      for (final row in trebleData.values) {
        for (final btn in row) {
          final matchesPull = octFilter == 'all'
              ? targetPitchClasses.contains(btn.pull % 12)
              : targetMidis.contains(btn.pull);
          final matchesPush = octFilter == 'all'
              ? targetPitchClasses.contains(btn.push % 12)
              : targetMidis.contains(btn.push);

          if (matchesPull || matchesPush) {
            matchingButtonIds.add(btn.id);
          }
        }
      }
    }

    if (matchingButtonIds.isEmpty) return;
    final next = Set<String>.from(state.activeButtons)..addAll(matchingButtonIds);
    state = state.copyWith(activeButtons: next);

    Future.delayed(duration, () {
      final remaining = Set<String>.from(state.activeButtons)..removeAll(matchingButtonIds);
      state = state.copyWith(activeButtons: remaining);
    });
  }

  List<int> _calculateFreeChordNotes() {
    final oct = state.freeChordOctave;
    final baseMidi = switch (oct) {
      '3' => 48,
      '4' => 60,
      '5' => 72,
      _ => 60,
    };
    return ChordCatalog.notesFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      baseMidi: baseMidi,
    );
  }

  // Sección 3: Detector de Acordes
  void toggleDetectorMode() {
    state = state.copyWith(
      detectorMode: !state.detectorMode,
      detectorSelectedButtons: const [],
      detectedChord: null,
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
    );
  }

  void playDetectorChord() {
    if (state.detectorSelectedButtons.isEmpty) return;
    final notes = <int>[];
    for (final btnId in state.detectorSelectedButtons) {
      for (final row in state.trebleData1.values) {
        for (final btn in row) {
          if (btn.id == btnId) {
            notes.add(btn.push + state.tuning1.offset);
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
    if (state.detectorSelectedButtons.isEmpty) return;
    final notes = <int>[];
    for (final btnId in state.detectorSelectedButtons) {
      for (final row in state.trebleData1.values) {
        for (final btn in row) {
          if (btn.id == btnId) {
            notes.add(btn.push + state.tuning1.offset);
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

  void _recalculateDetectedChord() {
    if (state.detectorSelectedButtons.length < 2) {
      state = state.copyWith(detectedChord: null);
      return;
    }
    // Simulación de análisis armónico inteligente en Dart / Rust
    final detected = DetectedChordModel(
      name: 'Bb Mayor (Tríada)',
      root: 'Si♭',
      bass: 'Si♭',
      formula: '1 - 3 - 5',
      type: 'Tríada Mayor',
      inversion: 'Estado Fundamental',
      alternatives: ['Gm7/Bb', 'D#sus2'],
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
final activeChordPitchClassesProvider =
    Provider.family<Set<int>, int>((ref, accordionNumber) {
  final isPrimary = accordionNumber == 1;
  final trebleData = ref.watch(accordionSimulatorProvider.select(
    (s) => isPrimary ? s.trebleData1 : s.trebleData2,
  ));
  final freeChordRoot = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordRoot));
  final freeChordType = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordType));
  final freeChordFourth = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordFourth));
  final detectorSelected = ref.watch(accordionSimulatorProvider.select((s) => s.detectorSelectedButtons));
  final syncDiapason = ref.watch(accordionSimulatorProvider.select((s) => s.syncDiapason));
  final isPlaying = ref.watch(accordionSimulatorProvider.select((s) => s.isPlayingAudio));
  final playingChordNotes = ref.watch(accordionSimulatorProvider.select((s) => s.playingChordNotes));

  final isFreeChordFixed = ref.watch(accordionSimulatorProvider.select((s) => s.isFreeChordFixed));

  final generated = ChordCatalog.notesFor(
    root: freeChordRoot,
    type: freeChordType,
    extension: freeChordFourth,
  );

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

  // Si isFreeChordFixed es verdadero, el acorde del constructor permanece siempre activo.
  // Si no está fijo y la canción está sonando con sincronización, la canción toma precedencia.
  final chordFromConstructor = (isFreeChordFixed || !isPlaying || !syncDiapason)
      ? generated
      : const <int>[];

  return ChordCatalog.activePitchClasses(
    generated: chordFromConstructor,
    playing: syncDiapason && isPlaying ? playingChordNotes : const <int>[],
    selected: selectedChordNotes,
  );
});

