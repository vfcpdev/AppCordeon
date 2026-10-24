import 'dart:typed_data';

import 'audio_file_player_interface.dart';

AudioFilePlayer getAudioFilePlayer() => AudioFilePlayerStub();

/// Implementación sin audio para plataformas no web.
/// Mantiene la misma API para que el controlador funcione igual.
class AudioFilePlayerStub implements AudioFilePlayer {
  @override
  bool get isLoaded => false;

  @override
  double get positionSeconds => 0;

  @override
  double get durationSeconds => 0;

  @override
  void load(Uint8List bytes, String mimeType) {}

  @override
  void play() {}

  @override
  void pause() {}

  @override
  void stop() {}

  @override
  void seek(double seconds) {}

  @override
  void setVolume(double volume) {}
}
