import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/audio_analysis_models.dart';
import 'acordeon_engine_ffi.dart';
import 'analysis/pcm_decoder.dart';
import 'audio_analyzer.dart';
import 'web_audio_decoder.dart';

/// Analizador que delega el DSP pesado en el crate Rust vía FFI.
///
/// Estrategia (DIP + OCP): implementa la misma interfaz [AudioAnalyzer] que
/// [AudioAnalyzerService], de modo que el Composition Root elige la
/// implementación Rust cuando la DLL está disponible y cae al fallback Dart
/// cuando no (sin cambiar nada del controlador).
///
/// # Triplas de Hoare
/// - `analyzeAudio` {P}: `bytes` contiene audio decodificable y la DLL Rust
///   está cargada. {Q}: retorna un [AudioAnalysisReport] válido o propaga la
///   excepción hacia `analyzeLoadedAudio`, que muestra el fallo en la UI.
/// - El fallback a Dart se decide en el Composition Root, no aquí (SRP).
class RustAudioAnalyzer implements AudioAnalyzer {
  final AcordeonEngineFFI _engine;

  /// Límite de muestras por llamada (DSP Rust procesa en bloque ~0.5 s a
  /// 44.1 kHz por frame de análisis; evita transacciones FFI excesivas).
  static const int _maxSamplesPerCall = 1 << 20;

  RustAudioAnalyzer({AcordeonEngineFFI? engine})
      : _engine = engine ?? AcordeonEngineFFI.instance;

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
      const decoder = StandardPcmDecoderFallback();
      samples = decoder.decodePcmOrSimulate(bytes);
    }

    // 2. Llamada FFI al análisis Rust. Las muestras largas se recortan al
    //    máximo soportado por transacción (suficiente para 12 s @44.1kHz).
    final clipped = samples.length > _maxSamplesPerCall
        ? Float32List.sublistView(samples, 0, _maxSamplesPerCall)
        : samples;
    final json = _engine.analyzeAudioJson(clipped, sampleRate);
    if (json == null || json.isEmpty) {
      throw StateError(
        'El motor Rust no devolvió análisis para $fileName '
        '(¿DLL cargada? ¿muestras ≥ 4096?).',
      );
    }
    debugPrint('[RustAudioAnalyzer] análisis listo para $fileName');

    // 3. El JSON de Rust ya respeta el formato de AudioAnalysisReport.
    final report = AudioAnalysisReport.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
    return report;
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

/// Envoltorio mínimo para no importar pcm_decoder aquí y mantener el
/// fallback explícito (SRP sin acoplar a los detalles del pipeline Dart).
class StandardPcmDecoderFallback {
  const StandardPcmDecoderFallback();

  Float32List decodePcmOrSimulate(Uint8List bytes) {
    // Reutiliza la misma lógica que el pipeline Dart: delega al servicio
    // compartido para no duplicar la síntesis de emergencia.
    return pcmDecoderShared.decodePcmOrSimulate(bytes);
  }
}
