abstract class WebAudioSynth {
  factory WebAudioSynth() => getWebAudioSynth();

  void init();
  void noteOn(int midiNote, double frequency, {double velocity = 0.8});
  void noteOff(int midiNote);
  void allNotesOff();
  void setVolume(double volume);
}

WebAudioSynth getWebAudioSynth() => throw UnsupportedError('Stub');
