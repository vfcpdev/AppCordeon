import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/theory/music_theory.dart';
import 'web_audio_synth.dart';

abstract class AudioEngine {
  Future<void> init({double sampleRate = 44100.0});
  void noteOn(int midiNote, {double velocity = 0.8});
  void noteOff(int midiNote);
  void allNotesOff();
  void setVolume(double volume);
}

/// Implementación del motor de síntesis de acordeón con Web Audio / Multi-plataforma
/// Preparado para enlazar con el crate de Rust `acordeon_engine` vía FFI o WASM.
/// Su ciclo de vida lo gestiona `audioEngineProvider` (ya no es singleton).
class AcordeonEngineBridge implements AudioEngine {
  AcordeonEngineBridge();

  bool _initialized = false;
  double _volume = 0.8;
  final Set<int> _activeMidiNotes = {};
  WebAudioSynth? _synth;

  Set<int> get activeNotes => Set.unmodifiable(_activeMidiNotes);

  void _guard(String op, void Function() action) {
    try {
      action();
    } catch (e) {
      debugPrint('AcordeonEngineBridge.$op falló: $e');
    }
  }

  @override
  Future<void> init({double sampleRate = 44100.0}) async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) {
      _guard('init', () {
        _synth = createWebAudioSynth();
        _synth?.init();
        _synth?.setVolume(_volume);
      });
    }
    debugPrint('AcordeonEngineBridge inicializado (Sample Rate: $sampleRate Hz)');
  }

  @override
  void noteOn(int midiNote, {double velocity = 0.8}) {
    _activeMidiNotes.add(midiNote);
    final freq = MusicTheory.midiToFrequency(midiNote);
    _guard('noteOn', () => _synth?.noteOn(midiNote, freq, velocity: velocity));
  }

  @override
  void noteOff(int midiNote) {
    _activeMidiNotes.remove(midiNote);
    _guard('noteOff', () => _synth?.noteOff(midiNote));
  }

  @override
  void allNotesOff() {
    _activeMidiNotes.clear();
    _guard('allNotesOff', () => _synth?.allNotesOff());
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _guard('setVolume', () => _synth?.setVolume(_volume));
  }
}
