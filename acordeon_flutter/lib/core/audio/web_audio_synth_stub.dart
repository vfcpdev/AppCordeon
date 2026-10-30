import 'acordeon_engine_ffi.dart';
import 'web_audio_synth_interface.dart';

WebAudioSynth getWebAudioSynth() => WebAudioSynthStub();

/// Implementación para plataformas nativas (Windows desktop)
/// conectada al motor DSP y sintetizador en Rust mediante FFI y WASAPI.
class WebAudioSynthStub implements WebAudioSynth {
  final AcordeonEngineFFI _engine = AcordeonEngineFFI.instance;

  @override
  void init() {
    _engine.init(sampleRate: 44100.0);
  }

  @override
  void noteOn(int midiNote, double frequency, {double velocity = 0.8}) {
    _engine.noteOn(midiNote);
  }

  @override
  void noteOff(int midiNote) {
    _engine.noteOff(midiNote);
  }

  @override
  void allNotesOff() {
    _engine.allNotesOff();
  }

  @override
  void setVolume(double volume) {
    _engine.setVolume(volume);
  }
}
