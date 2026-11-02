import 'dart:typed_data';

/// Stub del motor Rust para plataformas sin `dart:ffi` (web).
///
/// Mantiene exactamente la API pública de la implementación nativa para que
/// el resto de la aplicación no necesite ramas por plataforma. Todas las
/// operaciones son no-op y `analysisAvailable` es `false`, lo que hace que
/// `RustAudioAnalyzer` delegue siempre en el pipeline Dart.
///
/// {I}: nunca expone tipos de `dart:ffi`, por lo que el árbol web compila.
class AcordeonEngineFFI {
  static AcordeonEngineFFI? _instance;
  static AcordeonEngineFFI get instance =>
      _instance ??= AcordeonEngineFFI._();

  AcordeonEngineFFI._();

  bool get isAvailable => false;

  bool get analysisAvailable => false;

  void init({double sampleRate = 44100.0}) {}

  void noteOn(int midiNote) {}

  void noteOff(int midiNote) {}

  void allNotesOff() {}

  void setVolume(double volume) {}

  String? detectChordJson(List<int> midiNotes) => null;

  String? analyzeAudioJson(Float32List samples, double sampleRate) => null;

  String? detectBeatChordsJson(
    Float32List samples,
    double sampleRate, {
    required double bpm,
    required double startOffset,
  }) =>
      null;
}
