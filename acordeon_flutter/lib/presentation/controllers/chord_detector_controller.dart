import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/di/providers.dart';
import '../../domain/models/measure_models.dart';

class ChordDetectorState {
  final bool isEnabled;
  final String direction; // auto, push, pull
  final List<String> selectedButtons;
  final DetectedChordModel? detectedChord;

  const ChordDetectorState({
    required this.isEnabled,
    required this.direction,
    required this.selectedButtons,
    this.detectedChord,
  });

  ChordDetectorState copyWith({
    bool? isEnabled,
    String? direction,
    List<String>? selectedButtons,
    DetectedChordModel? detectedChord,
    bool clearDetected = false,
  }) {
    return ChordDetectorState(
      isEnabled: isEnabled ?? this.isEnabled,
      direction: direction ?? this.direction,
      selectedButtons: selectedButtons ?? this.selectedButtons,
      detectedChord: clearDetected ? null : (detectedChord ?? this.detectedChord),
    );
  }
}

class ChordDetectorNotifier extends Notifier<ChordDetectorState> {
  late AudioEngine _audioBridge;

  @override
  ChordDetectorState build() {
    _audioBridge = ref.read(audioEngineProvider);
    return const ChordDetectorState(
      isEnabled: false,
      direction: 'auto',
      selectedButtons: [],
      detectedChord: null,
    );
  }

  void toggleMode() {
    state = state.copyWith(
      isEnabled: !state.isEnabled,
      selectedButtons: const [],
      clearDetected: true,
    );
  }

  void setDirection(String dir) {
    state = state.copyWith(direction: dir);
  }

  void toggleButton(String buttonId) {
    final list = List<String>.from(state.selectedButtons);
    if (list.contains(buttonId)) {
      list.remove(buttonId);
    } else {
      list.add(buttonId);
    }
    state = state.copyWith(selectedButtons: list);
    _recalculateDetectedChord();
  }

  void clear() {
    state = state.copyWith(
      selectedButtons: const [],
      clearDetected: true,
    );
  }

  void playChord(List<int> notes) {
    if (notes.isEmpty) return;
    for (final note in notes) {
      _audioBridge.noteOn(note);
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      for (final note in notes) {
        _audioBridge.noteOff(note);
      }
    });
  }

  void arpeggioChord(List<int> notes) async {
    if (notes.isEmpty) return;
    for (final note in notes) {
      _audioBridge.noteOn(note);
      await Future.delayed(const Duration(milliseconds: 220));
      _audioBridge.noteOff(note);
    }
  }

  void _recalculateDetectedChord() {
    if (state.selectedButtons.length < 2) {
      state = state.copyWith(clearDetected: true);
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

final chordDetectorProvider =
    NotifierProvider<ChordDetectorNotifier, ChordDetectorState>(() {
  return ChordDetectorNotifier();
});
