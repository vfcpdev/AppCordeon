import 'web_audio_synth_interface.dart';

WebAudioSynth getWebAudioSynth() => WebAudioSynthStub();

class WebAudioSynthStub implements WebAudioSynth {
  @override
  void init() {}

  @override
  void noteOn(int midiNote, double frequency, {double velocity = 0.8}) {}

  @override
  void noteOff(int midiNote) {}

  @override
  void allNotesOff() {}

  @override
  void setVolume(double volume) {}
}
