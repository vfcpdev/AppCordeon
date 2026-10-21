import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/models/accordion_data.dart';
import 'package:acordeon_flutter/domain/models/tuning.dart';
import 'package:acordeon_flutter/domain/theory/music_theory.dart';

void main() {
  group('MusicTheory Tests', () {
    test('MIDI 60 should be Do / C in octave 4', () {
      expect(MusicTheory.midiToName(60, notation: NotationMode.latina), 'Do4');
      expect(MusicTheory.midiToName(60, notation: NotationMode.alemana), 'C4');
      expect(MusicTheory.midiToName(60, notation: NotationMode.latina, ignoreOctave: true), 'Do');
    });

    test('MIDI 58 in Cinco Letras should be Si♭3', () {
      expect(MusicTheory.midiToName(58, notation: NotationMode.latina, tuningOffset: 0), 'Si♭3');
      expect(MusicTheory.midiToName(58, notation: NotationMode.alemana, tuningOffset: 0), 'Bb3');
    });

    test('MIDI 69 (A4) frequency should be 440 Hz', () {
      expect(MusicTheory.midiToFrequency(69), closeTo(440.0, 0.01));
    });
  });

  group('AccordionData Tests', () {
    test('Cinco Letras Treble should have 10-11-10 buttons', () {
      final treble = AccordionData.getTransposedTreble(0);
      expect(treble['row1']!.length, 10);
      expect(treble['row2']!.length, 11);
      expect(treble['row3']!.length, 10);
    });

    test('Transposition to Rey Vallenato (-3 semitones)', () {
      final baseTreble = AccordionData.getTransposedTreble(0);
      final reyTreble = AccordionData.getTransposedTreble(-3);

      // B2 in row1 base push is 58 (Bb3), in Rey Vallenato should be 55 (G3)
      expect(baseTreble['row1']![1].push, 58);
      expect(reyTreble['row1']![1].push, 55);
      expect(MusicTheory.midiToName(reyTreble['row1']![1].push, notation: NotationMode.latina, tuningOffset: -3), 'Sol3');
    });

    test('Bass buttons should have 12 buttons (6 fund, 6 chord)', () {
      final basses = AccordionData.getTransposedBasses(0);
      expect(basses.length, 12);
      final funds = basses.where((b) => b.type == ButtonType.fundamental).toList();
      final chords = basses.where((b) => b.type == ButtonType.chord).toList();
      expect(funds.length, 6);
      expect(chords.length, 6);
    });
  });

  group('TuningRegistry Tests', () {
    test('Contains 7 traditional Vallenato tunings', () {
      expect(TuningRegistry.defaultTunings.length, 7);
      expect(TuningRegistry.getById('cinco_letras').offset, 0);
      expect(TuningRegistry.getById('rey_vallenato').offset, -3);
      expect(TuningRegistry.getById('sabanera').offset, 2);
    });
  });
}
