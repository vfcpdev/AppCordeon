import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/audio/audio_analyzer_service.dart';

void main() {
  group('AudioAnalyzerService Tests', () {
    final service = AudioAnalyzerService();

    test('Analyzes simulated audio bytes and produces Key, BPM and Chords', () async {
      // 44100 Hz mono PCM mock audio
      final dummyBytes = Uint8List(44100 * 2 * 4); // ~4 segundos
      for (int i = 0; i < dummyBytes.length; i++) {
        dummyBytes[i] = (i % 256);
      }

      final report = await service.analyzeAudio(dummyBytes, 'cancion_vallenata.mp3');

      expect(report.duration, greaterThan(0.0));
      expect(report.bpm, inInclusiveRange(60, 200));
      expect(report.mainKey.keyNameLat.isNotEmpty, isTrue);
      expect(report.mainKey.recommendedTuning.isNotEmpty, isTrue);
      expect(report.chords.isNotEmpty, isTrue);
      expect(report.chords.first.chordSymbol.isNotEmpty, isTrue);
    });
  });
}
