import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('Botón de Borrado de la Minibarra - Comportamiento según Casilla Masiva', () {
    Future<ProviderContainer> pumpGrid(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MeasureGridWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('con casilla desmarcada borra solo los acordes de las casillas marcadas',
        (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Registrar acordes en (0, 0) y (0, 1); marcar únicamente (0, 0)
      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.updateMeasureBeat(0, 1, 'Sol');
      notifier.toggleBeatMark(0, 0);
      await tester.pumpAndSettle();

      // Presionar el botón de borrar con la casilla masiva desmarcada
      await tester.tap(find.byKey(const ValueKey('delete_grid_chords_btn')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      // {Q}: la casilla marcada pierde el acorde
      expect(state.measures[0].beats[0].chord, isEmpty);
      // {Q} + Invariante {I}: la casilla no marcada conserva el acorde
      expect(state.measures[0].beats[1].chord, equals('Sol'));
      // {Q}: las casillas borradas quedan desmarcadas
      expect(state.markedBeats, isEmpty);
    });

    testWidgets('con casilla marcada borra todos los acordes de la cuadrícula',
        (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.updateMeasureBeat(0, 1, 'Sol');
      notifier.updateMeasureBeat(1, 2, 'La');

      // Marcar la casilla masiva (seleccionar todos)
      await tester.tap(find.byKey(const ValueKey('select_all_beats_btn')));
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).markedBeats.length,
          equals(container.read(accordionSimulatorProvider).measures.length * 4));

      // Presionar el botón de borrar
      await tester.tap(find.byKey(const ValueKey('delete_grid_chords_btn')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      for (final row in state.measures) {
        for (final beat in row.beats) {
          expect(beat.chord, isEmpty, reason: 'Compás ${row.barNumber} conservó acorde');
        }
      }
      expect(state.markedBeats, isEmpty);
    });
  });
}
