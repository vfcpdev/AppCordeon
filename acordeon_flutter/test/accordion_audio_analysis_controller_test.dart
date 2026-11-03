import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/presentation/controllers/subcontrollers/accordion_audio_analysis_controller.dart';

void main() {
  group('AccordionAudioAnalysisController Tests (SPEC-001)', () {
    const controller = AccordionAudioAnalysisController();

    test('buildKeyNames produce nombres latinos y anglosajones correctos', () {
      final majorNames = controller.buildKeyNames(rootMod: 0, mode: 'Mayor');
      expect(majorNames.$1, equals('Do Mayor'));
      expect(majorNames.$2, equals('C Major'));

      final minorNames = controller.buildKeyNames(rootMod: 9, mode: 'Menor');
      expect(minorNames.$1, equals('La Menor'));
      expect(minorNames.$2, equals('A Minor'));
    });

    test('transposeTimelineChords transpone acorde y nombre preservando invariantes', () {
      final initialChords = [
        const DetectedChordSegment(
          startTime: 0.0,
          endTime: 2.0,
          chordSymbol: 'C',
          chordName: 'Do Mayor',
          rootMod: 0,
          quality: 'maj',
          noteMods: [0, 4, 7],
          playbackMidis: [60, 64, 67],
          confidence: 0.95,
        ),
      ];

      // Transponer 2 semitonos (Do -> Re)
      final transposed = controller.transposeTimelineChords(
        chords: initialChords,
        semitoneOffset: 2,
        newMode: 'Major',
        previousMode: 'Major',
        preferFlats: false,
      );

      expect(transposed.length, equals(1));
      expect(transposed[0].rootMod, equals(2));
      expect(transposed[0].chordSymbol, equals('D'));
      expect(transposed[0].chordName, equals('Re Mayor'));
    });

    test('recalculateReportWithKeyAndBpm actualiza reporte, tonalidad y acordes', () {
      final baseReport = AudioAnalysisReport.placeholder(120);
      final updated = controller.recalculateReportWithKeyAndBpm(
        existingReport: baseReport,
        rootMod: 7, // Sol
        mode: 'Major',
        bpm: 135,
        totalAudioDuration: 180.0,
      );

      expect(updated.bpm, equals(135));
      expect(updated.mainKey.rootMod, equals(7));
      expect(updated.mainKey.keyNameLat, equals('Sol Mayor'));
      expect(updated.duration, equals(180.0));
    });
  });
}
