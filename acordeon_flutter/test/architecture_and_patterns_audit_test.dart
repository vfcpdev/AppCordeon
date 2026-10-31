import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/models/accordion_data.dart';
import 'package:acordeon_flutter/domain/theory/bass_matching_strategy.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

void main() {
  group('OOP y Liskov Substitution Principle (LSP) - Jerarquía de Botones', () {
    test('TrebleButtonModel y BassButtonModel implementan polimórficamente AccordionButtonModel', () {
      final List<AccordionButtonModel> buttons = [
        const TrebleButtonModel(
          id: 'row1_1',
          rowKey: 'row1',
          btnIndex: 1,
          push: 64,
          pull: 66,
        ),
        const BassButtonModel(
          id: 'bass_1',
          type: ButtonType.fundamental,
          btnIndex: 1,
          label: 'Bajo 1',
          pushNotes: [46],
          pullNotes: [41],
          namePush: 'Bb',
          namePull: 'F',
        ),
      ];

      // Acceso polimórfico a id y btnIndex (LSP)
      expect(buttons[0].id, 'row1_1');
      expect(buttons[1].id, 'bass_1');

      // Transposición polimórfica (LSP)
      final transposed = buttons.map((b) => b.transpose(2)).toList();
      expect(transposed[0].notesForBellows(BellowsMode.push), [66]);
      expect(transposed[0].notesForBellows(BellowsMode.pull), [68]);
      expect(transposed[1].notesForBellows(BellowsMode.push), [48]);
      expect(transposed[1].notesForBellows(BellowsMode.pull), [43]);
    });
  });

  group('Strategy Pattern & OCP - Estrategia de Evaluación Armónica de Bajos', () {
    const strategy = StandardModalBassMatchingStrategy();

    test('Diferencia coincidencia exacta y resuelve conflicto modal en homónimos Fa menor vs Fa Mayor', () {
      // Fa menor: pitch classes {5, 8, 0}
      const faMinorPcs = {5, 8, 0};
      const chordRootFa = 5;

      // Par 4 pull: Fa menor [53, 56, 60] -> exacto
      final matchFm = strategy.evaluate(
        notes: [53, 56, 60],
        type: ButtonType.chord,
        chordRoot: chordRootFa,
        chordPitchClasses: faMinorPcs,
        btnIndex: 4,
      );
      expect(matchFm, BassMatchType.exact);

      // Par 1 pull: Fa Mayor [53, 57, 60] -> conflicto modal (3ra mayor vs 3ra menor) -> none
      final matchFMajInMinor = strategy.evaluate(
        notes: [53, 57, 60],
        type: ButtonType.chord,
        chordRoot: chordRootFa,
        chordPitchClasses: faMinorPcs,
        btnIndex: 1,
      );
      expect(matchFMajInMinor, BassMatchType.none);

      // Fundamental Par 4 (Fa menor) -> exacto
      final fundFm = strategy.evaluate(
        notes: [41],
        type: ButtonType.fundamental,
        chordRoot: chordRootFa,
        chordPitchClasses: faMinorPcs,
        btnIndex: 4,
      );
      expect(fundFm, BassMatchType.exact);

      // Fundamental Par 1 (Fa Mayor) -> degradado / close
      final fundFMajInMinor = strategy.evaluate(
        notes: [41],
        type: ButtonType.fundamental,
        chordRoot: chordRootFa,
        chordPitchClasses: faMinorPcs,
        btnIndex: 1,
      );
      expect(fundFMajInMinor, BassMatchType.close);
    });

    test('Diferencia coincidencia exacta y resuelve conflicto modal en homónimos Do menor vs Do Mayor', () {
      // Do menor: pitch classes {0, 3, 7}
      const doMinorPcs = {0, 3, 7};
      const chordRootDo = 0;

      // Par 2 pull: Do menor [60, 63, 67] -> exacto
      final matchCm = strategy.evaluate(
        notes: [60, 63, 67],
        type: ButtonType.chord,
        chordRoot: chordRootDo,
        chordPitchClasses: doMinorPcs,
        btnIndex: 2,
      );
      expect(matchCm, BassMatchType.exact);

      // Par 4 push: Do Mayor [60, 64, 67] -> conflicto modal -> none
      final matchCMajInMinor = strategy.evaluate(
        notes: [60, 64, 67],
        type: ButtonType.chord,
        chordRoot: chordRootDo,
        chordPitchClasses: doMinorPcs,
        btnIndex: 4,
      );
      expect(matchCMajInMinor, BassMatchType.none);

      // Fundamental Par 2 pull (Do menor) -> exacto
      final fundCm = strategy.evaluate(
        notes: [48],
        type: ButtonType.fundamental,
        chordRoot: chordRootDo,
        chordPitchClasses: doMinorPcs,
        btnIndex: 2,
      );
      expect(fundCm, BassMatchType.exact);
    });
  });

  group('Command Pattern - Acciones Encapsuladas', () {
    test('ClearDiapasonCommand limpia atómicamente el estado del diapasón', () {
      bool called = false;
      final command = ClearDiapasonCommand(({
        required freeChordRoot,
        required isFreeChordFixed,
        required activeButtons,
        required detectorSelectedButtons,
        required detectedChord,
        required playingChordNotes,
      }) {
        expect(freeChordRoot, -1);
        expect(isFreeChordFixed, isFalse);
        expect(activeButtons, isEmpty);
        expect(detectorSelectedButtons, isEmpty);
        expect(detectedChord, isNull);
        expect(playingChordNotes, isEmpty);
        called = true;
      });

      command.execute();
      expect(called, isTrue);
    });

    test('AssignDetectedChordCommand asigna acorde y calcula fuelle óptimo', () {
      String? updatedChord;
      BellowsMode? updatedBellows;

      final command = AssignDetectedChordCommand(
        chord: const DetectedChordModel(
          name: 'Do Mayor',
          root: 'Do',
          bass: 'Do',
          formula: '1 - 3 - 5',
          type: 'Tríada Mayor',
          inversion: 'Estado Fundamental',
          chordSymbol: 'Do',
          pitchClasses: {0, 4, 7},
        ),
        barIndex: 0,
        beatIndex: 1,
        notation: NotationMode.latina,
        trebleData: AccordionData.baseCincoLetrasTrebleTransposed,
        onUpdateBeat: (bar, beat, chord) {
          updatedChord = chord;
        },
        onSetBellows: (bar, beat, bellows) {
          updatedBellows = bellows;
        },
      );

      final result = command.execute();
      expect(result, isTrue);
      expect(updatedChord, 'Do');
      expect(updatedBellows, isNotNull);
    });
  });

  group('Interface Segregation Principle (ISP) - Selectores Atómicos en Riverpod', () {
    test('isDiapasonCleanProvider reporta correctamente estado limpio', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Limpiamos el diapasón
      notifier.clearDiapason();
      expect(container.read(isDiapasonCleanProvider), isTrue);

      // Si activamos el detector con 0 botones sigue limpio
      notifier.toggleDetectorMode();
      expect(container.read(isDiapasonCleanProvider), isTrue);

      // Al presionar un botón deja de estar limpio
      notifier.toggleDetectorButton('row1_2', 60);
      expect(container.read(isDiapasonCleanProvider), isFalse);
    });

    test('bellowsModeProvider expone el fuelle de forma atómica para cada acordeón', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      expect(container.read(bellowsModeProvider(1)), BellowsMode.both);
      notifier.setBellows1(BellowsMode.pull);
      expect(container.read(bellowsModeProvider(1)), BellowsMode.pull);
    });
  });
}
