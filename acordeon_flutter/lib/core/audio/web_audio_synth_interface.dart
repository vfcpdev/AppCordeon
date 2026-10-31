abstract class WebAudioSynth {
  void init();
  void noteOn(int midiNote, double frequency, {double velocity = 0.8});
  void noteOff(int midiNote);
  void allNotesOff();
  void setVolume(double volume);
  void playPercussiveClick({bool isDownbeat = true, double volume = 0.8});
}
