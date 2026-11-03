import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/models/compas_grid_state.dart';
import 'package:acordeon_flutter/domain/models/grid_selection_model.dart';
import 'package:acordeon_flutter/domain/models/measure_models.dart';
import 'package:acordeon_flutter/domain/memento/grid_memento.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

void main() {
  group('GridSelectionModel (Value Object)', () {
    test('inmutabilidad y cálculo de allSelected y isSelected', () {
      const emptySelection = GridSelectionModel();
      expect(emptySelection.isEmpty, isTrue);
      expect(emptySelection.count, equals(0));
      expect(emptySelection.isSelected(0), isFalse);
      expect(emptySelection.isAllSelected(16), isFalse);

      final withMarks = emptySelection.toggleMark(5);
      expect(withMarks.isSelected(5), isTrue);
      expect(withMarks.count, equals(1));
      expect(withMarks.isNotEmpty, isTrue);
      // Inmutabilidad
      expect(emptySelection.count, equals(0));

      final allMarks = emptySelection.selectAll(4);
      expect(allMarks.count, equals(4));
      expect(allMarks.isAllSelected(4), isTrue);

      final cleared = allMarks.clear();
      expect(cleared.count, equals(0));
      expect(cleared.isAllSelected(4), isFalse);
    });

    test('soporte para selección de asignación múltiple (targets)', () {
      final model = const GridSelectionModel().toggleTarget(2).toggleTarget(3);
      expect(model.targetBeats.length, equals(2));
      expect(model.targetBeats.contains(2), isTrue);
      expect(model.targetBeats.contains(3), isTrue);
      expect(model.isSelected(2), isTrue);
      expect(model.isSelected(0), isFalse);
    });
  });

  group('CompasGridState (Descomposición de Estado Cohesiva)', () {
    test('cálculos de métricas del compás', () {
      final measures = [
        const MeasureRow(
          barNumber: 1,
          beats: [
            MeasureBeat(barIndex: 0, beatIndex: 0, chord: 'C', bellows: BellowsMode.push),
            MeasureBeat(barIndex: 0, beatIndex: 1, chord: '', bellows: BellowsMode.push),
            MeasureBeat(barIndex: 0, beatIndex: 2, chord: 'G', bellows: BellowsMode.pull),
            MeasureBeat(barIndex: 0, beatIndex: 3, chord: '', bellows: BellowsMode.both),
          ],
        ),
        const MeasureRow(
          barNumber: 2,
          beats: [
            MeasureBeat(barIndex: 1, beatIndex: 0, chord: '', bellows: BellowsMode.push),
            MeasureBeat(barIndex: 1, beatIndex: 1, chord: '', bellows: BellowsMode.push),
            MeasureBeat(barIndex: 1, beatIndex: 2, chord: '', bellows: BellowsMode.pull),
            MeasureBeat(barIndex: 1, beatIndex: 3, chord: '', bellows: BellowsMode.both),
          ],
        ),
      ];

      final gridState = CompasGridState(
        measures: measures,
        selection: const GridSelectionModel(markedBeats: {0, 2}),
      );

      expect(gridState.totalBeats, equals(8));
      expect(gridState.hasChords, isTrue);
      expect(gridState.nonEmptyChordCount, equals(2));
      expect(gridState.getChord(0, 0), equals('C'));
      expect(gridState.getChord(0, 2), equals('G'));
      expect(gridState.getChord(0, 1), isEmpty);
    });
  });

  group('GridMemento & GridHistoryManager (Patrón Memento / Undo-Redo)', () {
    test('flujo de apilado, deshacer y rehacer', () {
      final history = GridHistoryManager();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);

      final state1 = [
        const MeasureRow(
          barNumber: 1,
          beats: [
            MeasureBeat(barIndex: 0, beatIndex: 0, chord: 'Am'),
            MeasureBeat(barIndex: 0, beatIndex: 1, chord: ''),
            MeasureBeat(barIndex: 0, beatIndex: 2, chord: ''),
            MeasureBeat(barIndex: 0, beatIndex: 3, chord: ''),
          ],
        ),
      ];
      history.saveSnapshot(
        measures: state1,
        markedBeats: {0},
        yellowDecisionBeats: const {},
      );
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      final currentState = [
        const MeasureRow(
          barNumber: 1,
          beats: [
            MeasureBeat(barIndex: 0, beatIndex: 0, chord: ''),
            MeasureBeat(barIndex: 0, beatIndex: 1, chord: ''),
            MeasureBeat(barIndex: 0, beatIndex: 2, chord: ''),
            MeasureBeat(barIndex: 0, beatIndex: 3, chord: ''),
          ],
        ),
      ];

      final undone = history.undo(
        currentMeasures: currentState,
        currentMarkedBeats: const {},
        currentYellowDecisionBeats: const {},
      );
      expect(undone, isNotNull);
      expect(undone!.measures.first.beats[0].chord, equals('Am'));
      expect(undone.markedBeats.contains(0), isTrue);
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);

      final redone = history.redo(
        currentMeasures: undone.measures,
        currentMarkedBeats: undone.markedBeats,
        currentYellowDecisionBeats: undone.yellowDecisionBeats,
      );
      expect(redone, isNotNull);
      expect(redone!.measures.first.beats[0].chord, isEmpty);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });
  });

  group('AccordionSimulatorNotifier - Deshacer/Rehacer Compás Integrado', () {
    test('deshacer borrado de acordes restaura el estado previo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Asignar un acorde a un compás
      notifier.updateMeasureBeat(0, 0, 'C');
      expect(notifier.state.measures[0].beats[0].chord, equals('C'));

      // Marcar y borrar todos los acordes
      notifier.toggleAllBeatMarks();

      final deleted = notifier.deleteAllGridChords();
      expect(deleted, greaterThan(0));
      expect(notifier.state.measures[0].beats[0].chord, isEmpty);
      expect(notifier.state.canUndoGrid, isTrue);

      // Deshacer el borrado
      final undoSuccess = notifier.undoGrid();
      expect(undoSuccess, isTrue);
      expect(notifier.state.measures[0].beats[0].chord, equals('C'));
      expect(notifier.state.canRedoGrid, isTrue);

      // Rehacer el borrado
      final redoSuccess = notifier.redoGrid();
      expect(redoSuccess, isTrue);
      expect(notifier.state.measures[0].beats[0].chord, isEmpty);
    });
  });
}
