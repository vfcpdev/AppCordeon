import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/theory/music_theory.dart';

abstract class AudioEngine {
  Future<void> init({double sampleRate = 44100.0});
  void noteOn(int midiNote, {double velocity = 0.8});
  void noteOff(int midiNote);
  void allNotesOff();
  void setVolume(double volume);
}

/// Implementación del motor de síntesis de acordeón con Web Audio / Multi-plataforma
/// Preparado para enlazar con el crate de Rust `acordeon_engine` vía FFI o WASM
class AcordeonEngineBridge implements AudioEngine {
  static final AcordeonEngineBridge _instance = AcordeonEngineBridge._internal();
  factory AcordeonEngineBridge() => _instance;
  AcordeonEngineBridge._internal();

  bool _initialized = false;
  double _volume = 0.8;
  final Set<int> _activeMidiNotes = {};

  @override
  Future<void> init({double sampleRate = 44100.0}) async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('AcordeonEngineBridge inicializado (Sample Rate: $sampleRate Hz)');
  }

  @override
  void noteOn(int midiNote, {double velocity = 0.8}) {
    _activeMidiNotes.add(midiNote);
    final freq = MusicTheory.midiToFrequency(midiNote);
    debugPrint('Rust Engine / Audio -> NOTE_ON: MIDI $midiNote (${freq.toStringAsFixed(1)} Hz)');
  }

  @override
  void noteOff(int midiNote) {
    _activeMidiNotes.remove(midiNote);
    debugPrint('Rust Engine / Audio -> NOTE_OFF: MIDI $midiNote');
  }

  @override
  void allNotesOff() {
    _activeMidiNotes.clear();
    debugPrint('Rust Engine / Audio -> ALL_NOTES_OFF');
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    debugPrint('Rust Engine / Audio -> VOLUME: ${(_volume * 100).toInt()}%');
  }
}
