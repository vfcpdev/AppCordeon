import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/constants/enums.dart';
import '../../core/di/providers.dart';
import '../../domain/theory/chord_catalog.dart';

class FreeChordState {
  final int root; // 0=Do, 1=Do#, etc.
  final String type; // maj, min, dim, aug, sus4
  final String fourth; // none, octave, dom7, maj7, maj6, add9
  final String octave; // all, 3, 4, 5
  final String mode; // harmonic, melodic
  final bool isFixed;
  final BellowsMode bellows;
  final String scaleHarmonicMode; // triad, seventh

  const FreeChordState({
    required this.root,
    required this.type,
    required this.fourth,
    required this.octave,
    required this.mode,
    required this.isFixed,
    required this.bellows,
    required this.scaleHarmonicMode,
  });

  FreeChordState copyWith({
    int? root,
    String? type,
    String? fourth,
    String? octave,
    String? mode,
    bool? isFixed,
    BellowsMode? bellows,
    String? scaleHarmonicMode,
  }) {
    return FreeChordState(
      root: root ?? this.root,
      type: type ?? this.type,
      fourth: fourth ?? this.fourth,
      octave: octave ?? this.octave,
      mode: mode ?? this.mode,
      isFixed: isFixed ?? this.isFixed,
      bellows: bellows ?? this.bellows,
      scaleHarmonicMode: scaleHarmonicMode ?? this.scaleHarmonicMode,
    );
  }

  List<int> calculateNotes() {
    return ChordCatalog.notesFor(
      root: root,
      type: type,
      extension: fourth,
    );
  }
}

class FreeChordNotifier extends Notifier<FreeChordState> {
  late AudioEngine _audioBridge;

  @override
  FreeChordState build() {
    _audioBridge = ref.read(audioEngineProvider);
    return const FreeChordState(
      root: 0,
      type: 'maj',
      fourth: 'none',
      octave: 'all',
      mode: 'harmonic',
      isFixed: false,
      bellows: BellowsMode.both,
      scaleHarmonicMode: 'triad',
    );
  }

  void setRoot(int root) => state = state.copyWith(root: root);
  void setType(String type) => state = state.copyWith(type: type);
  void setFourth(String fourth) => state = state.copyWith(fourth: fourth);
  void setOctave(String oct) => state = state.copyWith(octave: oct);
  void setMode(String mode) => state = state.copyWith(mode: mode);
  void toggleFixed() => state = state.copyWith(isFixed: !state.isFixed);
  void setBellows(BellowsMode m) => state = state.copyWith(bellows: m);
  void setScaleHarmonicMode(String mode) =>
      state = state.copyWith(scaleHarmonicMode: mode);

  void selectDegree(int semitones, String quality) {
    final newRoot = (state.root + semitones) % 12;
    String newType = 'maj';
    if (quality.toLowerCase().contains('menor')) newType = 'min';
    if (quality.toLowerCase().contains('disminuido')) newType = 'dim';
    state = state.copyWith(root: newRoot, type: newType);
    if (state.mode == 'harmonic') {
      playChord();
    } else {
      arpeggioChord();
    }
  }

  void playChord() {
    final notes = state.calculateNotes();
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      for (final midi in notes) {
        _audioBridge.noteOff(midi);
      }
    });
  }

  void arpeggioChord() async {
    final notes = state.calculateNotes();
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
      await Future.delayed(const Duration(milliseconds: 220));
      _audioBridge.noteOff(midi);
    }
  }
}

final freeChordProvider =
    NotifierProvider<FreeChordNotifier, FreeChordState>(() {
  return FreeChordNotifier();
});
