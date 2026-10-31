import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/memento/grid_memento.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

void main() {
  group('Triplas de Hoare {P} C {Q} y Contratos en Comandos de Dominio', () {
    test('ClearDiapasonCommand: {P: True} C {Q: Diapasón Limpio y Audio Cancelado}', () {
      bool audioCancelled = false;
      bool updaterCalled = false;

      final command = ClearDiapasonCommand(
        ({
          required freeChordRoot,
          required isFreeChordFixed,
          required activeButtons,
          required detectorSelectedButtons,
          required detectedChord,
          required playingChordNotes,
        }) {
          updaterCalled = true;
          // Verificación de Poscondición {Q}
          expect(freeChordRoot, equals(-1));
          expect(isFreeChordFixed, isFalse);
          expect(activeButtons, isEmpty);
          expect(detectorSelectedButtons, isEmpty);
          expect(detectedChord, isNull);
          expect(playingChordNotes, isEmpty);
        },
        onCancelAudioPlayback: () {
          audioCancelled = true;
        },
      );

      expect(command.canExecute(), isTrue);
      command.execute();
      expect(updaterCalled, isTrue);
      expect(audioCancelled, isTrue);
    });

    test('AssignDetectedChordCommand: Precondición {P} falla en índices negativos', () {
      final command = AssignDetectedChordCommand(
        chord: const DetectedChordModel(
          name: 'Do Mayor',
          root: 'C',
          bass: 'C',
          formula: '1 - 3 - 5',
          type: 'maj',
          inversion: 'Fundamental',
          alternatives: [],
          chordSymbol: 'C',
          pitchClasses: {0, 4, 7},
          rootPitchClass: 0,
          bassPitchClass: 0,
          notes: [60, 64, 67],
        ),
        barIndex: -1,
        beatIndex: 0,
        notation: NotationMode.latina,
        trebleData: const {},
        onUpdateBeat: (bar, beat, symbol) {},
        onSetBellows: (bar, beat, bellows) {},
      );

      expect(command.canExecute(), isFalse);
      expect(
        () => command.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });

    test('ApplyMultiBeatChordCommand: Precondición {P} rechaza compases superiores a maxAllowedMeasures', () {
      const command = ApplyMultiBeatChordCommand(
        chord: 'Do',
        pattern: '150.1',
        currentMeasures: [],
        maxAllowedMeasures: 128,
      );

      expect(command.canExecute(), isFalse);
      expect(
        () => command.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });

    test('ApplyMultiBeatChordCommand: {P} C {Q} asigna compases y garantiza marcación', () {
      final initialMeasures = [
        MeasureRow(
          barNumber: 1,
          beats: List.generate(4, (b) => MeasureBeat(barIndex: 0, beatIndex: b, chord: '', timeText: '00:00')),
        ),
      ];

      final command = ApplyMultiBeatChordCommand(
        chord: 'Sol',
        pattern: '1.1, 2.3',
        currentMeasures: initialMeasures,
        replaceExisting: true,
      );

      expect(command.canExecute(), isTrue);
      final result = command.execute();

      // Verificación de Poscondición {Q}
      expect(result.appliedCount, equals(2));
      expect(result.updatedMeasures.length, greaterThanOrEqualTo(2));
      expect(result.updatedMeasures[0].beats[0].chord, equals('Sol'));
      expect(result.updatedMeasures[1].beats[2].chord, equals('Sol'));
      expect(result.markedBeats.contains(0), isTrue); // Bar 0, Beat 0
      expect(result.markedBeats.contains(1 * 4 + 2), isTrue); // Bar 1, Beat 2
    });

    test('ApplyYellowDecisionCommand: {P: yellowDecisionBeats > 0} C {Q: bellows asignado y yellowDecisionBeats limpio}', () {
      final measures = [
        MeasureRow(
          barNumber: 1,
          beats: List.generate(
            4,
            (b) => MeasureBeat(barIndex: 0, beatIndex: b, chord: 'Do', timeText: '00:00', bellows: BellowsMode.both),
          ),
        ),
      ];

      final command = ApplyYellowDecisionCommand(
        measures: measures,
        yellowDecisionBeats: {0, 1},
        mode: BellowsMode.push,
      );

      expect(command.canExecute(), isTrue);
      final result = command.execute();

      expect(result.appliedCount, equals(2));
      expect(result.updatedMeasures[0].beats[0].bellows, equals(BellowsMode.push));
      expect(result.updatedMeasures[0].beats[1].bellows, equals(BellowsMode.push));
      expect(result.remainingYellowBeats, isEmpty);
    });

    test('ApplyYellowDecisionCommand: Precondición {P} falla si la lista de decisión está vacía', () {
      const command = ApplyYellowDecisionCommand(
        measures: [],
        yellowDecisionBeats: {},
        mode: BellowsMode.pull,
      );

      expect(command.canExecute(), isFalse);
      expect(
        () => command.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });

    test('TransferDetectedChordCommand: Transfiere fielmente raíz, cualidad y bajo de acorde menor con 7ma', () {
      const detected = DetectedChordModel(
        name: 'Do Menor 7ma',
        root: 'C',
        bass: 'Bb',
        formula: '1 - ♭3 - 5 - ♭7',
        type: 'min7',
        inversion: 'Tercera Inversión',
        alternatives: [],
        chordSymbol: 'Cm7/Bb',
        pitchClasses: {0, 3, 7, 10},
        rootPitchClass: 0,
        bassPitchClass: 10,
        notes: [60, 63, 67, 70],
      );

      const command = TransferDetectedChordCommand(detected);
      expect(command.canExecute(), isTrue);

      final params = command.execute();
      expect(params, isNotNull);
      expect(params!.root, equals(0)); // Do
      expect(params.type, equals('min'));
      expect(params.fourth, equals('dom7'));
      expect(params.bass, equals('7')); // Bajo alterado en séptima
      expect(params.isFixed, isTrue);
    });
  });

  group('Patrón Memento: Historial de Cuadrícula (Undo / Redo)', () {
    test('GridHistoryManager guarda snapshots y permite undo/redo fielmente', () {
      final manager = GridHistoryManager(maxHistory: 5);

      final stateA = [
        MeasureRow(
          barNumber: 1,
          beats: List.generate(4, (b) => MeasureBeat(barIndex: 0, beatIndex: b, chord: 'A', timeText: '00:00')),
        ),
      ];
      final stateB = [
        MeasureRow(
          barNumber: 1,
          beats: List.generate(4, (b) => MeasureBeat(barIndex: 0, beatIndex: b, chord: 'B', timeText: '00:00')),
        ),
      ];

      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);

      // Guardamos snapshot del estado A antes de cambiar a B
      manager.saveSnapshot(
        measures: stateA,
        markedBeats: {0},
        yellowDecisionBeats: {},
      );

      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);

      // Realizamos Undo (recuperamos estado A)
      final restoredA = manager.undo(
        currentMeasures: stateB,
        currentMarkedBeats: {1},
        currentYellowDecisionBeats: {},
      );

      expect(restoredA, isNotNull);
      expect(restoredA!.measures.first.beats.first.chord, equals('A'));
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isTrue);

      // Realizamos Redo (recuperamos estado B)
      final restoredB = manager.redo(
        currentMeasures: stateA,
        currentMarkedBeats: {0},
        currentYellowDecisionBeats: {},
      );

      expect(restoredB, isNotNull);
      expect(restoredB!.measures.first.beats.first.chord, equals('B'));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
    });

    test('AccordionSimulatorNotifier integra undoGrid() y redoGrid() en cambios de compases', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      expect(notifier.canUndoGrid, isFalse);

      // 1. Aplicamos un acorde multitiempo
      notifier.applyMultiBeatChord(chord: 'Fa', pattern: '1.1, 1.2');
      expect(container.read(accordionSimulatorProvider).measures[0].beats[0].chord, equals('Fa'));
      expect(notifier.canUndoGrid, isTrue);

      // 2. Aplicamos otro acorde
      notifier.applyMultiBeatChord(chord: 'Sol', pattern: '1.3, 1.4');
      expect(container.read(accordionSimulatorProvider).measures[0].beats[2].chord, equals('Sol'));

      // 3. Deshacer el cambio de 'Sol'
      notifier.undoGrid();
      expect(container.read(accordionSimulatorProvider).measures[0].beats[2].chord, equals(''));
      expect(notifier.canRedoGrid, isTrue);

      // 4. Rehacer el cambio de 'Sol'
      notifier.redoGrid();
      expect(container.read(accordionSimulatorProvider).measures[0].beats[2].chord, equals('Sol'));
    });
  });
}
