import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/analysis/tuning_recommender.dart';
import '../../core/audio/audio_analyzer.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/audio/audio_file_loader_interface.dart';
import '../../core/audio/demo_track_generator.dart';
import '../../core/constants/enums.dart';
import '../../core/di/providers.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/audio_analysis_models.dart';
import '../../domain/models/measure_models.dart';
import '../../domain/models/tuning.dart';
import '../../domain/theory/chord_catalog.dart';

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
  final bool sequenceMode;
  final int visibleGridRows;
  final List<MeasureRow> measures;
  final int? selectedBarIndex;
  final int? selectedBeatIndex;

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
    required this.sequenceMode,
    required this.visibleGridRows,
    required this.measures,
    this.selectedBarIndex,
    this.selectedBeatIndex,
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
    bool? sequenceMode,
    int? visibleGridRows,
    List<MeasureRow>? measures,
    int? selectedBarIndex,
    int? selectedBeatIndex,
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
      sequenceMode: sequenceMode ?? this.sequenceMode,
      visibleGridRows: visibleGridRows ?? this.visibleGridRows,
      measures: measures ?? this.measures,
      selectedBarIndex: selectedBarIndex ?? this.selectedBarIndex,
      selectedBeatIndex: selectedBeatIndex ?? this.selectedBeatIndex,
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
  late DemoTrackGenerator _demoGenerator;

  @override
  AccordionSimulatorState build() {
    _audioBridge = ref.read(audioEngineProvider);
    _analyzer = ref.read(audioAnalyzerProvider);
    _fileLoader = ref.read(audioFileLoaderProvider);
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
    state = state.copyWith(notation: notation);
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
    state = state.copyWith(
      isAnalyzingAudio: true,
      loadedAudioFileName: fileName,
    );

    final report = await _analyzer.analyzeAudio(bytes, fileName);

    state = state.copyWith(
      isAnalyzingAudio: false,
      audioReport: report,
      totalAudioDuration: report.duration,
      currentAudioTime: 0.0,
    );

    // Auto-aplicar afinación sugerida al Acordeón 1
    applyDetectedTuning(report.keyResult);

    // Auto-aplicar acordes detectados a la cuadrícula de compases
    applyChordsToMeasures(report.chords);

    return AudioLoadSuccess(report, fileName);
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

  void applyChordsToMeasures(List<DetectedChordSegment> chords) {
    if (chords.isEmpty) return;

    final updatedMeasures = <MeasureRow>[];
    int chordIdx = 0;

    for (int bar = 1; bar <= 8; bar++) {
      final beats = <MeasureBeat>[];
      for (int b = 1; b <= 4; b++) {
        final ch = chords[chordIdx % chords.length].chordSymbol;
        beats.add(MeasureBeat(
          barIndex: bar,
          beatIndex: b,
          chord: ch,
          timeText: '${((bar - 1) * 2.0 + (b - 1) * 0.5).toStringAsFixed(1)}s',
        ));
        if (b % 2 == 0) {
          chordIdx++;
        }
      }
      updatedMeasures.add(MeasureRow(barNumber: bar, beats: beats));
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
    final isMinor = rest.contains('m') && !rest.contains('maj') && !rest.contains('dim');
    final isDim = rest.contains('dim');
    final isAug = rest.contains('aug');
    final isSus4 = rest.contains('sus4') || rest.contains('4');
    final isSus = rest.contains('sus') && !isSus4;

    final notes = <int>[rootMidi + 12]; // tónica en octava 4
    if (isDim) {
      notes.add(rootMidi + 12 + 3); // tercera menor
      notes.add(rootMidi + 12 + 6); // quinta disminuida
      if (has7) notes.add(rootMidi + 12 + 9); // séptima disminuida
    } else if (isAug) {
      notes.add(rootMidi + 12 + 4); // tercera mayor
      notes.add(rootMidi + 12 + 8); // quinta aumentada
      if (has7) notes.add(rootMidi + 12 + 10); // séptima dominante
    } else if (isSus4) {
      notes.add(rootMidi + 12 + 5); // cuarta justa
      notes.add(rootMidi + 12 + 7); // quinta justa
      if (has7) notes.add(rootMidi + 12 + 10);
    } else if (isSus) {
      notes.add(rootMidi + 12 + 5); // cuarta suspendida
      notes.add(rootMidi + 12 + 7);
    } else if (isMinor) {
      notes.add(rootMidi + 12 + 3); // tercera menor
      notes.add(rootMidi + 12 + 7); // quinta justa
      if (has7) notes.add(rootMidi + 12 + 10);
    } else {
      // Mayor
      notes.add(rootMidi + 12 + 4); // tercera mayor
      notes.add(rootMidi + 12 + 7); // quinta justa
      if (has7) notes.add(rootMidi + 12 + 10);
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

    if (barIndex < 0 || barIndex >= state.measures.length) return;
    final row = state.measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return;

    final chord = row.beats[beatIndex].chord.trim();
    if (chord.isEmpty) return;

    final notes = _chordSymbolToMidi(chord);
    for (final n in notes) {
      _audioBridge.noteOn(n, velocity: 0.65);
    }
    _currentBeatNotes = notes;
  }

  void togglePlayAudio() {
    final nextPlaying = !state.isPlayingAudio;
    state = state.copyWith(isPlayingAudio: nextPlaying);
    _playbackTimer?.cancel();

    if (!nextPlaying) {
      // Al pausar: apagar notas activas
      for (final n in _currentBeatNotes) {
        _audioBridge.noteOff(n);
      }
      _currentBeatNotes = [];
    }

    if (nextPlaying) {
      _lastPlayedBar = null;
      _lastPlayedBeat = null;

      final bpm = state.audioReport?.bpm ?? 120.0;
      final intervalMs = ((60.0 / bpm / 2.0) * 1000).toInt().clamp(50, 1000);

      _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
        if (!state.isPlayingAudio) {
          timer.cancel();
          return;
        }

        final nextTime = state.currentAudioTime + (intervalMs / 1000.0);
        final totalDur = state.totalAudioDuration > 0 ? state.totalAudioDuration : 16.0;
        final wrappedTime = nextTime >= totalDur ? 0.0 : nextTime;

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
  }

  void stopAudio() {
    _playbackTimer?.cancel();
    state = state.copyWith(
      isPlayingAudio: false,
      currentAudioTime: 0.0,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
    );
    _audioBridge.allNotesOff();
  }

  void seekAudio(double time) {
    state = state.copyWith(currentAudioTime: time);
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

  // Sección 5: Acorde Libre
  void setFreeChordRoot(int root) => state = state.copyWith(freeChordRoot: root);
  void setFreeChordType(String type) =>
      state = state.copyWith(freeChordType: type);
  void setFreeChordFourth(String fourth) =>
      state = state.copyWith(freeChordFourth: fourth);
  void setFreeChordOctave(String oct) =>
      state = state.copyWith(freeChordOctave: oct);
  void setFreeChordMode(String mode) =>
      state = state.copyWith(freeChordMode: mode);
  void toggleFreeChordFixed() =>
      state = state.copyWith(isFreeChordFixed: !state.isFreeChordFixed);
  void setFreeChordBellows(BellowsMode m) =>
      state = state.copyWith(freeChordBellows: m);
  void setFreeChordScaleHarmonicMode(String mode) =>
      state = state.copyWith(freeChordScaleHarmonicMode: mode);

  void selectFreeChordDegree(int semitones, String quality) {
    final newRoot = (state.freeChordRoot + semitones) % 12;
    String newType = 'maj';
    if (quality.toLowerCase().contains('menor')) newType = 'min';
    if (quality.toLowerCase().contains('disminuido')) newType = 'dim';
    state = state.copyWith(
      freeChordRoot: newRoot,
      freeChordType: newType,
    );
    if (state.freeChordMode == 'harmonic') {
      playFreeChord();
    } else {
      arpeggioFreeChord();
    }
  }

  void playFreeChord() {
    final notes = _calculateFreeChordNotes();
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
    }
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
      await Future.delayed(const Duration(milliseconds: 220));
      _audioBridge.noteOff(midi);
    }
  }

  List<int> _calculateFreeChordNotes() => ChordCatalog.notesFor(
        root: state.freeChordRoot,
        type: state.freeChordType,
        extension: state.freeChordFourth,
      );

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
