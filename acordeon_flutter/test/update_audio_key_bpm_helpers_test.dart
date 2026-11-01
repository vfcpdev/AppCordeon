import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/domain/models/measure_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

void main() {
  group('_buildKeyNames', () {
    test('genera nombre latino y alemán para tonalidad mayor', () {
      final names = AccordionSimulatorNotifier.buildKeyNamesForTest(
        rootMod: 0,
        mode: 'major',
      );
      expect(names.$1, 'Do Mayor');
      expect(names.$2, 'C Major');
    });

    test('genera nombre para tonalidad menor con rootMod fuera de rango', () {
      final names = AccordionSimulatorNotifier.buildKeyNamesForTest(
        rootMod: 14,
        mode: 'minor',
      );
      expect(names.$1, 'Re Menor');
      expect(names.$2, 'D Minor');
    });

    test('modos desconocidos se tratan como menor', () {
      final names = AccordionSimulatorNotifier.buildKeyNamesForTest(
        rootMod: 8,
        mode: 'dorian',
      );
      expect(names.$1, 'Sol♯ Menor');
 expect(names.$2, 'G# Minor');
    });
  });

  group('_transposeTimelineChords', () {
    DetectedChordSegment seg(String symbol, String name, int rootMod) =>
        DetectedChordSegment(
          startTime: 0,
          endTime: 1,
          chordSymbol: symbol,
          chordName: name,
          rootMod: rootMod,
          quality: '',
          noteMods: const [],
          playbackMidis: const [],
          confidence: 1.0,
        );

    test('sin cambios devuelve la misma lista (sin copiar)', () {
      final chords = [seg('C', 'Do', 0)];
      final result = AccordionSimulatorNotifier.transposeTimelineChordsForTest(
        chords: chords,
        semitoneOffset: 0,
        newMode: 'major',
        previousMode: 'major',
        preferFlats: false,
      );
      expect(identical(result, chords), isTrue);
    });

    test('transpone símbolos, nombres y rootMod con wrap-around', () {
      final chords = [seg('B', 'Si', 11)];
      final result = AccordionSimulatorNotifier.transposeTimelineChordsForTest(
        chords: chords,
        semitoneOffset: 2,
        newMode: 'major',
        previousMode: 'major',
        preferFlats: false,
      );
      expect(result, hasLength(1));
      expect(result.first.chordSymbol, 'C#');
      expect(result.first.chordName, 'Do#');
      expect(result.first.rootMod, 1);
    });
  });

  group('_rebuildMeasuresForKeyChange', () {
    MeasureRow rowWithChords(int barNumber) => MeasureRow(
          barNumber: barNumber,
          beats: List.generate(
            4,
            (b) => MeasureBeat(
              barIndex: barNumber - 1,
              beatIndex: b,
              chord: 'C',
              timeText: '00:00',
            ),
          ),
        );

    test('rellena acordes desde el timeline cuando ya había acordes', () {
      final result =
          AccordionSimulatorNotifier.rebuildMeasuresForKeyChangeForTest(
        currentMeasures: [rowWithChords(1)],
        chords: [
          DetectedChordSegment(
            startTime: 0,
            endTime: 100,
            chordSymbol: 'G7',
            chordName: 'Sol7',
            rootMod: 7,
            quality: '',
            noteMods: const [],
            playbackMidis: const [],
            confidence: 1.0,
          ),
        ],
        totalBars: 1,
        secondsPerBeat: 0.5,
        bpmChanged: false,
        semitoneOffset: 0,
        preferFlats: false,
      );
      expect(result, hasLength(1));
      expect(result.first.beats.every((b) => b.chord == 'G7'), isTrue);
    });

    test('regenera compases vacíos cuando cambió el BPM', () {
      final result =
          AccordionSimulatorNotifier.rebuildMeasuresForKeyChangeForTest(
        currentMeasures: const [],
        chords: const [],
        totalBars: 2,
        secondsPerBeat: 0.5,
        bpmChanged: true,
        semitoneOffset: 0,
        preferFlats: false,
      );
      expect(result, hasLength(2));
      expect(result.first.beats.every((b) => b.chord.isEmpty), isTrue);
      expect(result.first.beats.first.timeText, '00:00');
      expect(result.last.beats.last.timeText, '00:03');
    });

    test('transpone acordes ya cargados sin reconstruir la cuadrícula', () {
      final result =
          AccordionSimulatorNotifier.rebuildMeasuresForKeyChangeForTest(
        currentMeasures: [rowWithChords(1)],
        chords: const [],
        totalBars: 1,
        secondsPerBeat: 0.5,
        bpmChanged: false,
        semitoneOffset: 2,
        preferFlats: false,
      );
      expect(result.first.barNumber, 1);
      expect(result.first.beats.every((b) => b.chord == 'D'), isTrue);
    });

    test('sin cambios devuelve los compases actuales intactos', () {
      final measures = [rowWithChords(1)];
      final result =
          AccordionSimulatorNotifier.rebuildMeasuresForKeyChangeForTest(
        currentMeasures: measures,
        chords: const [],
        totalBars: 1,
        secondsPerBeat: 0.5,
        bpmChanged: false,
        semitoneOffset: 0,
        preferFlats: false,
      );
      expect(identical(result, measures), isTrue);
    });
  });
}
