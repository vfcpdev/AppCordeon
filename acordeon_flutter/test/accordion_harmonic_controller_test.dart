import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/subcontrollers/accordion_harmonic_controller.dart';

void main() {
  group('AccordionHarmonicController Tests (SPEC-001)', () {
    late AccordionHarmonicController controller;

    setUp(() {
      controller = AccordionHarmonicController();
    });

    test('toggleFreeChordRoot conmuta tónica como interruptor', () {
      expect(controller.toggleFreeChordRoot(0, 0), equals(-1));
      expect(controller.toggleFreeChordRoot(-1, 0), equals(0));
      expect(controller.toggleFreeChordRoot(2, 5), equals(5));
    });

    test('toggleFreeChordType conmuta cualidad', () {
      expect(controller.toggleFreeChordType('maj', 'maj'), equals(''));
      expect(controller.toggleFreeChordType('', 'min'), equals('min'));
    });

    test('resolveExtensionForScaleHarmonicMode asigna extensiones según cualidad', () {
      // Triad limpia la séptima
      expect(
        controller.resolveExtensionForScaleHarmonicMode(
          targetMode: 'triad',
          currentFourth: 'dom7',
          currentType: 'maj',
        ),
        equals(''),
      );

      // Seventh en menor asigna min7
      expect(
        controller.resolveExtensionForScaleHarmonicMode(
          targetMode: 'seventh',
          currentFourth: '',
          currentType: 'min',
        ),
        equals('min7'),
      );

      // Seventh en disminuido asigna dim7
      expect(
        controller.resolveExtensionForScaleHarmonicMode(
          targetMode: 'seventh',
          currentFourth: 'none',
          currentType: 'dim',
        ),
        equals('dim7'),
      );
    });

    test('detectChordFromMidiNotes detecta tríada mayor correctamente', () {
      // Do Mayor: C4 (60), E4 (64), G4 (67) -> Por convención de AppCordeon
      final chord = controller.detectChordFromMidiNotes([60, 64, 67]);
      expect(chord, isNotNull);
      expect(chord!.root, equals('Do'));
      expect(chord.type, equals('Tríada Mayor'));
      expect(chord.name, equals('Do Mayor'));
    });
  });
}
