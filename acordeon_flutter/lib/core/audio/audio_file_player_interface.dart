import 'dart:typed_data';

/// Reproductor del archivo de audio cargado por el usuario (MP3/WAV/OGG…).
///
/// La reproducción es independiente del motor de síntesis de acordeón: el
/// archivo se escucha tal cual mientras la cuadrícula y los diapasones se
/// sincronizan con su posición.
abstract class AudioFilePlayer {
  /// Carga los bytes en memoria y deja el reproductor listo para sonar.
  void load(Uint8List bytes, String mimeType);

  void play();
  void pause();
  void stop();
  void seek(double seconds);
  void setVolume(double volume);

  /// `true` cuando hay un archivo cargado y listo para reproducir.
  bool get isLoaded;

  /// Posición actual en segundos (0 si no hay archivo).
  double get positionSeconds;

  /// Duración real del archivo en segundos (0 si aún no se conoce).
  double get durationSeconds;
}
