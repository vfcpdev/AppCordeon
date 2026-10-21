import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/tuning.dart';

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
  final AudioEngine _audioBridge = AcordeonEngineBridge();

  @override
  AccordionSimulatorState build() {
    _audioBridge.init();

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
  void togglePlayAudio() {
    state = state.copyWith(isPlayingAudio: !state.isPlayingAudio);
  }

  void stopAudio() {
    state = state.copyWith(isPlayingAudio: false, currentAudioTime: 0.0);
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

  List<int> _calculateFreeChordNotes() {
    final root = state.freeChordRoot;
    final baseMidi = 60 + root; // Octava 4
    final intervals = <int>[0];

    switch (state.freeChordType) {
      case 'min':
        intervals.addAll([3, 7]);
        break;
      case 'dim':
        intervals.addAll([3, 6]);
        break;
      case 'aug':
        intervals.addAll([4, 8]);
        break;
      case 'sus4':
        intervals.addAll([5, 7]);
        break;
      case 'maj':
      default:
        intervals.addAll([4, 7]);
        break;
    }

    switch (state.freeChordFourth) {
      case 'octave':
        intervals.add(12);
        break;
      case 'dom7':
        intervals.add(10);
        break;
      case 'maj7':
        intervals.add(11);
        break;
      case 'maj6':
        intervals.add(9);
        break;
      case 'add9':
        intervals.add(14);
        break;
    }

    return intervals.map((i) => baseMidi + i).toList();
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
