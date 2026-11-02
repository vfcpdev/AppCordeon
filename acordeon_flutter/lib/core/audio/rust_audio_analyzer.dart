import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/audio_analysis_models.dart';
import 'acordeon_engine_ffi.dart';
import 'analysis/pcm_decoder.dart';
import 'audio_analyzer.dart';
import 'audio_analyzer_service.dart';
import 'web_audio_decoder.dart';

/// Analizador que delega el DSP pesado en el crate Rust vía FFI.
///
/// Estrategia (DIP + OCP): implementa la misma interfaz [AudioAnalyzer] que
/// [AudioAnalyzerService], de modo que el Composition Root elige la
/// implementación Rust cuando la DLL está disponible y cae al fallback Dart
/// cuando no (sin cambiar nada del controlador).
///
/// # Triplas de Hoare
/// - `analyzeAudio` {P}: `bytes` contiene audio decodificable.
///   {Q}: SIEMPRE retorna un [AudioAnalysisReport] válido (nunca lanza):
///   vía Rust si la DLL produjo JSON utilizable, o vía el pipeline Dart
///   puro como fallback garantizado ante cualquier fallo de Rust (DLL
///   ausente, JSON con "error", muestras insuficientes, excepción FFI).
///   La causa del fallback queda registrada en el log de depuración.
class RustAudioAnalyzer implements AudioAnalyzer {
  final AcordeonEngineFFI _engine;
  final AudioAnalyzer _dartFallback;

  RustAudioAnalyzer({
    AcordeonEngineFFI? engine,
    AudioAnalyzer? dartFallback,
  })  : _engine = engine ?? AcordeonEngineFFI.instance,
        _dartFallback = dartFallback ?? AudioAnalyzerService();

  @override
  Future<AudioAnalysisReport> analyzeAudio(
    Uint8List bytes,
    String fileName,
  ) async {
    // 1. Decodificación de muestras: la API Rust espera Float32 PCM mono.
    //    Reusamos el decoder del entorno (web decodifica con AudioContext;
    //    nativo usa el decodificador WAV/simulación).
    final Float32List samples;
    double sampleRate = 44100.0;

    final decoded = await createAudioDecoder().decode(bytes);
    if (decoded != null && decoded.samples.isNotEmpty) {
      samples = decoded.samples;
      sampleRate = decoded.sampleRate;
    } else {
      samples = pcmDecoderShared.decodePcmOrSimulate(bytes);
    }

    // 2. Intento Rust: TODAS las muestras (el buffer de Rust crece dinámicamente;
    //    sin límite — el análisis cubre el audio completo cargado).
    try {
      final json = _engine.analyzeAudioJson(samples, sampleRate);
      if (json != null && json.isNotEmpty) {
        final decodedJson = jsonDecode(json) as Map<String, dynamic>;
        if (decodedJson.containsKey('error')) {
          debugPrint(
            '[RustAudioAnalyzer] Rust rechazó $fileName: '
            '${decodedJson['error']}',
          );
        } else {
          debugPrint('[RustAudioAnalyzer] análisis listo para $fileName');
          return AudioAnalysisReport.fromJson(decodedJson);
        }
      } else {
        debugPrint(
          '[RustAudioAnalyzer] Rust no devolvió análisis para $fileName '
          '(¿DLL cargada? ¿muestras ≥ 4096?). Usando fallback Dart.',
        );
      }
    } catch (rustError) {
      debugPrint(
        '[RustAudioAnalyzer] fallo vía FFI para $fileName: $rustError. '
        'Usando fallback Dart.',
      );
    }

    // 3. Fallback garantizado: el pipeline Dart puro produce el reporte.
    return _dartFallback.analyzeAudio(bytes, fileName);
  }

  /// Detección de acorde puntual desde notas MIDI (uso directo por el
  /// detector de acordes del diapasón cuando Rust esté disponible).
  String? detectChordJson(List<int> midiNotes) =>
      _engine.detectChordJson(midiNotes);

  /// Acordes sincronizados por compás (BPM + offset conocidos).
  String? detectBeatChordsJson(
    Float32List samples,
    double sampleRate, {
    required double bpm,
    required double startOffset,
  }) =>
      _engine.detectBeatChordsJson(
        samples,
        sampleRate,
        bpm: bpm,
        startOffset: startOffset,
      );
}

/// Instancia compartida del decodificador PCM de respaldo (SRP: una sola
/// fuente de síntesis de emergencia para Rust y para el pipeline Dart).
const StandardPcmDecoder pcmDecoderShared = StandardPcmDecoder();
