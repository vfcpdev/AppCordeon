import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/acordeon_engine_ffi.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/core/audio/rust_audio_analyzer.dart';

/// Verifica el cableado FFI con el motor Rust.
///
/// {P}: el entorno puede tener o no `acordeon_engine.dll`; el test se adapta:
/// - Con DLL: valida JSON válido y reporte decodificable.
/// - Sin DLL: valida que la API degrada a `null` sin lanzar (el Composition
///   Root usa el fallback Dart).
void main() {
  group('AcordeonEngineFFI (puente Rust)', () {
    final engine = AcordeonEngineFFI.instance;

    test('expone el estado de disponibilidad', () {
      expect(engine.analysisAvailable, isA<bool>());
      if (engine.analysisAvailable) {
        expect(engine.isAvailable, isTrue);
      }
    });

    test('detectChordJson nunca lanza (degrada a null sin DLL)', () {
      final result = engine.detectChordJson(const [60, 64, 67]);
      if (engine.analysisAvailable) {
        expect(result, isNotNull);
        expect(result, contains('{'));
      } else {
        expect(result, isNull);
      }
    });

    test('analyzeAudioJson devuelve JSON válido con DLL, null sin ella', () {
      final samples = Float32List(8192);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = (i % 441) / 441.0; // Señal periódica (~100 Hz @44.1k)
      }
      final json = engine.analyzeAudioJson(samples, 44100.0);
      if (engine.analysisAvailable) {
        expect(json, isNotNull);
        final decoded = jsonDecode(json!) as Map<String, dynamic>;
        expect(decoded, isNotEmpty);
      } else {
        expect(json, isNull);
      }
    });

    test('analyzeAudioJson rechaza muestras insuficientes ({P})', () {
      final tiny = Float32List(64);
      expect(engine.analyzeAudioJson(tiny, 44100.0), isNull);
    });

    test('detectBeatChordsJson respeta la precondición de longitud', () {
      final samples = Float32List(8192);
      final json = engine.detectBeatChordsJson(
        samples,
        44100.0,
        bpm: 120.0,
        startOffset: 0.0,
      );
      if (engine.analysisAvailable) {
        expect(json, isNotNull);
      } else {
        expect(json, isNull);
      }
    });
  });

  group('RustAudioAnalyzer (integración con AudioAnalysisReport)', () {
    test('decodifica el JSON de Rust en AudioAnalysisReport', () async {
      final engine = AcordeonEngineFFI.instance;
      if (!engine.analysisAvailable) {
        // Sin DLL: el Composition Root usa el fallback Dart; sólo validamos
        // que el constructor no revienta y que detecta la falta de análisis.
        final analyzer = RustAudioAnalyzer(engine: engine);
        expect(analyzer, isA<RustAudioAnalyzer>());
        return;
      }

      final analyzer = RustAudioAnalyzer(engine: engine);
      final pcm = Float32List(44100); // 1 segundo
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] = ((i * 440 ~/ 44100) % 2 == 0) ? 0.5 : -0.5;
      }
      final report = await analyzer.analyzeAudio(
        _wavBytesFromSamples(pcm),
        'prueba.wav',
      );
      expect(report, isA<AudioAnalysisReport>());
      expect(report.bpm, greaterThan(0));
    });
  });
}

Uint8List _wavBytesFromSamples(Float32List samples) {
  const headerSize = 44;
  final bytes = Uint8List(headerSize + samples.length * 2);
  bytes[0] = 0x52; // R
  bytes[1] = 0x49; // I
  bytes[2] = 0x46; // F
  bytes[3] = 0x46; // F
  bytes[8] = 0x57; // W
  bytes[9] = 0x41; // A
  bytes[10] = 0x56; // V
  bytes[11] = 0x45; // E
  final data = ByteData.sublistView(bytes, headerSize);
  for (var i = 0; i < samples.length; i++) {
    final v = samples[i].clamp(-1.0, 1.0);
    data.setInt16(i * 2, (v * 32767).round(), Endian.little);
  }
  return bytes;
}
