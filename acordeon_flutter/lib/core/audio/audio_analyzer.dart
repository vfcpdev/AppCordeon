import 'dart:typed_data';
import '../../domain/models/audio_analysis_models.dart';

/// Abstracción del analizador espectral (DIP): el controlador depende de esto,
/// no de la implementación concreta (Dart DSP hoy, Rust FFI/WASM mañana).
abstract class AudioAnalyzer {
  Future<AudioAnalysisReport> analyzeAudio(Uint8List bytes, String fileName);
}
