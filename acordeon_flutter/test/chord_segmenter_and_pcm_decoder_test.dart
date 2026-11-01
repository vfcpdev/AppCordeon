import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/analysis/chord_segmenter.dart';
import 'package:acordeon_flutter/core/audio/analysis/pcm_decoder.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';

KeyDetectionResult _key({int rootMod = 0, String mode = 'major'}) =>
    KeyDetectionResult(
      rootMod: rootMod,
      mode: mode,
      keyNameLat: 'Do Mayor',
      keyNameAle: 'C Major',
      recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
      recommendedOffset: 10,
      recommendedRow: 'row2',
      correlation: 0.9,
    );

void main() {
  group('HarmonicChordSegmenter', () {
    const segmenter = HarmonicChordSegmenter();
    const hopSize = 512;
    const sampleRate = 44100.0;

    test('chromagrama vacío devuelve lista vacía', () {
      final result = segmenter.segmentChords(
        const [],
        const [],
        const [],
        hopSize,
        sampleRate,
        _key(),
      );
      expect(result, isEmpty);
    });

    test('un frame aislado produce un único segmento que cubre todo', () {
      final result = segmenter.segmentChords(
        [List.filled(12, 0.1)],
        [List.filled(12, 0.0)],
        [List.filled(12, 0.1)],
        hopSize,
        sampleRate,
        _key(),
      );
      expect(result, hasLength(1));
      expect(result.first.startTime, 0.0);
      expect(
        result.first.endTime,
        closeTo(1 * hopSize / sampleRate, 0.05),
      );
      expect(result.first.rootMod, 0);
			expect(result.first.quality, 'maj');
    });

    test('los segmentos consecutivos son contiguos (fin == inicio)', () {
      // 10 frames con tonic bien marcado alternando cada 5 frames para
      // provocar al menos un cambio de acorde estable.
      final chroma = List.generate(10, (i) {
        final frame = List.filled(12, 0.0);
        // Frames 0-4: tonic Do; frames 5-9: quinta Sol.
        frame[i < 5 ? 0 : 7] = 1.0;
        return frame;
      });
      final result = segmenter.segmentChords(
        chroma,
        List.generate(10, (i) => List.filled(12, i < 5 ? 1.0 : 0.0)),
        chroma,
        hopSize,
        sampleRate,
        _key(),
      );

      expect(result, isNotEmpty);
      for (var i = 1; i < result.length; i++) {
        expect(result[i].startTime, result[i - 1].endTime);
      }
      // Cobertura completa desde 0 hasta la duración total.
      expect(result.first.startTime, 0.0);
      expect(
        result.last.endTime,
        closeTo(chroma.length * hopSize / sampleRate, 0.05),
      );
    });

    test('qualidades calculan noteMods y playbackMidis correctos', () {
      final result = segmenter.segmentChords(
        [List.filled(12, 0.1)],
        [List.filled(12, 0.0)],
        [List.filled(12, 0.1)],
        hopSize,
        sampleRate,
        _key(mode: 'minor'),
      );
      expect(result, hasLength(1));
      expect(result.first.quality, 'min');
      // Menor sobre Do: Do, Mi♭, Sol → 0, 3, 7
      expect(result.first.noteMods, [0, 3, 7]);
      expect(result.first.playbackMidis, [48, 51, 55]);
    });

    test('tonalidad menor inicializa el primer segmento como menor', () {
      final result = segmenter.segmentChords(
        [List.filled(12, 0.1)],
        [List.filled(12, 0.0)],
        [List.filled(12, 0.1)],
        hopSize,
        sampleRate,
        _key(rootMod: 9, mode: 'minor'), // La menor
      );
      expect(result.first.rootMod, 9);
      expect(result.first.chordSymbol, 'Am');
    });
  });

  group('StandardPcmDecoder', () {
    const decoder = StandardPcmDecoder();

    test('entrada vacía devuelve Float32List vacío', () {
      final result = decoder.decodePcmOrSimulate(Uint8List(0));
      expect(result, isEmpty);
    });

    test('decodifica WAV de 16 bits little-endian correctamente', () {
      const headerLen = 44;
      const numSamples = 4;
      final bytes = Uint8List(headerLen + numSamples * 2);
      // Cabecera RIFF/WAVE mínima reconocida por el decodificador.
      bytes[0] = 0x52; // R
      bytes[1] = 0x49; // I
      bytes[2] = 0x46; // F
      bytes[3] = 0x46; // F
      bytes[8] = 0x57; // W
      bytes[9] = 0x41; // A
      bytes[10] = 0x56; // V
      bytes[11] = 0x45; // E

      final data = ByteData.sublistView(bytes, headerLen);
      data.setInt16(0, 32767, Endian.little); // ~+1.0
      data.setInt16(2, 0, Endian.little); // 0.0
      data.setInt16(4, -32768, Endian.little); // ~-1.0
      data.setInt16(6, 16384, Endian.little); // ~+0.5

      final result = decoder.decodePcmOrSimulate(bytes);
      expect(result.length, numSamples);
      expect(result[0], closeTo(1.0, 0.001));
      expect(result[1], 0.0);
      expect(result[2], closeTo(-1.0, 0.001));
      expect(result[3], closeTo(0.5, 0.001));
    });

    test('WAV truncado (menos de 44 bytes de encabezado) usa síntesis', () {
      // 40 bytes: no alcanza para el encabezado completo reconocido.
      final bytes = Uint8List(40);
      bytes[0] = 0x52;
      bytes[1] = 0x49;
      bytes[2] = 0x46;
      bytes[8] = 0x57;
      final result = decoder.decodePcmOrSimulate(bytes);
      // 12 segundos representativos a 44100 Hz.
      expect(result.length, 44100 * 12);
    });

    test('formato no WAV (MP3) sintetiza 12 segundos representativos', () {
      final bytes = Uint8List.fromList(List.filled(1000, 0x7F));
      final result = decoder.decodePcmOrSimulate(bytes);
      expect(result.length, 44100 * 12);
      // Todas las muestras dentro del rango [-1, 1].
      for (final s in result) {
        expect(s.inDoubleRange(-1.0001, 1.0001), isTrue);
      }
    });

    test('mismos bytes producen síntesis determinista', () {
      final bytes = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final a = decoder.decodePcmOrSimulate(bytes);
      final b = decoder.decodePcmOrSimulate(bytes);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i += 997) {
        expect(a[i], b[i]);
      }
    });
  });
}

extension on double {
  bool inDoubleRange(double low, double high) => this >= low && this <= high;
}
