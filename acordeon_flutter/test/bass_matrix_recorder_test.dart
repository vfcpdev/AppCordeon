import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/domain/models/bass_matrix_layout.dart';
import 'package:acordeon_flutter/domain/models/bass_rhythm_pattern.dart';

void main() {
  group('BassMatrixLayout', () {
    test('mapea las cuatro cajas a los botones físicos 7, 8, 4 y 5', () {
      expect(BassMatrixLayout.buttonNumberFor(row: 0, column: 0), 7);
      expect(BassMatrixLayout.buttonNumberFor(row: 1, column: 0), 8);
      expect(BassMatrixLayout.buttonNumberFor(row: 0, column: 1), 4);
      expect(BassMatrixLayout.buttonNumberFor(row: 1, column: 1), 5);
    });

    test('columna 0 = bajos externos y columna 1 = bajos internos', () {
      expect(
        BassMatrixLayout.columnLabelFor(0),
        BassMatrixLayout.exteriorLabel,
      );
      expect(
        BassMatrixLayout.columnLabelFor(1),
        BassMatrixLayout.interiorLabel,
      );
    });

    test('lista canónica de números de botón es [7, 8, 4, 5]', () {
      expect(BassMatrixLayout.buttonNumbers, [7, 8, 4, 5]);
    });
  });

  group('BassRhythmRecorder', () {
    test('no registra golpes si no está activo ({P})', () {
      final recorder = BassRhythmRecorder();
      expect(recorder.isRecording, isFalse);
      expect(recorder.recordButton(7), isFalse);
      expect(recorder.hits, isEmpty);
    });

    test('registra onset y cierra duración por tiempo de captura', () {
      final recorder = BassRhythmRecorder();
      recorder.start(
        name: 'Mi Paseo',
        beatSeconds: 0.5,
        quarterNotesPerMinute: 120,
        beatsPerMeasure: 4,
        beatType: 4,
        selectedButtons: const {7, 5},
      );
      expect(recorder.isRecording, isTrue);

      recorder.captureDuration = const Duration(milliseconds: 0);
      expect(recorder.recordButton(7), isTrue);
      recorder.captureDuration = const Duration(milliseconds: 500);
      expect(recorder.recordButton(5), isTrue);

      final hits = recorder.hits;
      expect(hits, hasLength(2));
      expect(hits.first.onsetQuarterBeats, 0.0);

      expect(hits.last.onsetQuarterBeats, closeTo(1.0, 1e-9));
      // Las duraciones provisionales se cierran en buildPattern.
    });

    test('ignora botones ausentes de la selección de la matriz', () {
      final recorder = BassRhythmRecorder();
      recorder.start(
        name: 'x',
        beatSeconds: 0.5,
        quarterNotesPerMinute: 120,
        beatsPerMeasure: 4,
        beatType: 4,
        selectedButtons: const {7},
      );
      expect(recorder.recordButton(4), isFalse);
      expect(recorder.hits, isEmpty);
    });

    test('buildPattern normaliza el nombre y trunca duraciones colgantes', () {
      final recorder = BassRhythmRecorder();
      recorder.start(
        name: '   ',
        beatSeconds: 0.5,
        quarterNotesPerMinute: 100,
        beatsPerMeasure: 4,
        beatType: 4,
        selectedButtons: const {7},
      );
      recorder.captureDuration = const Duration(milliseconds: 0);
      recorder.recordButton(7);

      final pattern = recorder.buildPattern(totalSeconds: 2.0);
      expect(pattern.name, 'Patrón sin nombre');
      expect(pattern.quarterNotesPerMinute, 100);
      expect(pattern.beatsPerMeasure, 4);
      expect(pattern.hits, hasLength(1));
      expect(pattern.durationQuarterBeats, greaterThan(0));
      // Sin captura posterior el golpe no dura más que el resto del patrón.
      expect(
        pattern.hits.first.durationQuarterBeats,
        lessThanOrEqualTo(4.0),
      );
    });

    test('buildPattern respeta un nombre explícito', () {
      final recorder = BassRhythmRecorder();
      recorder.start(
        name: 'Paseo 2',
        beatSeconds: 0.4,
        quarterNotesPerMinute: 150,
        beatsPerMeasure: 4,
        beatType: 4,
        selectedButtons: const {7, 5},
      );
      recorder.recordButton(7);
      final pattern = recorder.buildPattern(totalSeconds: 1.6);
      expect(pattern.name, 'Paseo 2');
      expect(pattern.hits.first.buttonIndex, 7);
    });
  });
}
