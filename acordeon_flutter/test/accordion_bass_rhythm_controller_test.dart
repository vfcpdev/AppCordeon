import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/domain/models/bass_rhythm_pattern.dart';
import 'package:acordeon_flutter/presentation/controllers/subcontrollers/accordion_bass_rhythm_controller.dart';

void main() {
  group('AccordionBassRhythmController Tests (SPEC-001)', () {
    late AccordionBassRhythmController controller;
    final List<BassRhythmPattern> testPatterns = [
      BassRhythmPattern(
        id: 'paseo_vallenato',
        name: 'Paseo Vallenato',
        partName: 'Bajos',
        measureNumber: 1,
        beatsPerMeasure: 4,
        beatType: 4,
        durationQuarterBeats: 4.0,
        quarterNotesPerMinute: 120.0,
        hits: const [],
      ),
      BassRhythmPattern(
        id: 'merengue_vallenato',
        name: 'Merengue Vallenato',
        partName: 'Bajos',
        measureNumber: 1,
        beatsPerMeasure: 6,
        beatType: 8,
        durationQuarterBeats: 3.0,
        quarterNotesPerMinute: 140.0,
        hits: const [],
      ),
    ];

    setUp(() {
      controller = AccordionBassRhythmController();
    });

    test('validateAndSelectPatternId acepta id válido o nulo', () {
      expect(controller.validateAndSelectPatternId('paseo_vallenato', testPatterns), equals('paseo_vallenato'));
      expect(controller.validateAndSelectPatternId(null, testPatterns), isNull);
    });

    test('validateAndSelectPatternId lanza ArgumentError si el id no existe', () {
      expect(
        () => controller.validateAndSelectPatternId('id_inexistente', testPatterns),
        throwsArgumentError,
      );
    });

    test('nudgeBeatOnset ajusta y acota el onset dentro de [0.0, maxDuration]', () {
      expect(controller.nudgeBeatOnset(1.0, 0.1), closeTo(1.1, 0.001));
      expect(controller.nudgeBeatOnset(0.05, -0.1), equals(0.0));
      expect(controller.nudgeBeatOnset(3.95, 0.2, maxDurationQuarterBeats: 4.0), equals(4.0));
    });

    test('quantizeBeatOnset aproxima al múltiplo más cercano de la rejilla', () {
      expect(controller.quantizeBeatOnset(1.08, 0.25), closeTo(1.0, 0.001));
      expect(controller.quantizeBeatOnset(1.15, 0.25), closeTo(1.25, 0.001));
      expect(controller.quantizeBeatOnset(1.4, 0.5), closeTo(1.5, 0.001));
    });
  });
}
