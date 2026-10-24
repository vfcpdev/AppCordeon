import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/free_chord_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  testWidgets('el botón Compás inserta el acorde en la celda seleccionada',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FreeChordWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FreeChordWidget)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);

    // Prepara un acorde (Sol menor séptima) y selecciona el compás 2, tiempo 4.
    notifier.setFreeChordRoot(7);
    notifier.setFreeChordType('min');
    notifier.setFreeChordFourth('dom7');
    notifier.selectBeat(1, 3);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compás'));
    await tester.pumpAndSettle();

    final state = container.read(accordionSimulatorProvider);
    expect(state.measures[1].beats[3].chord, 'Solm7');
  });

  test('los tiempos marcados reciben el acorde de forma simultánea', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(accordionSimulatorProvider.notifier);

    notifier.setFreeChordRoot(7); // Sol
    notifier.setFreeChordType('min');
    notifier.setFreeChordFourth('dom7');
    notifier.toggleBeatMark(0, 0);
    notifier.toggleBeatMark(1, 2);
    notifier.toggleBeatMark(2, 3);

    final symbol = notifier.insertFreeChordIntoSelectedBeat();
    expect(symbol, 'Solm7');

    final state = container.read(accordionSimulatorProvider);
    expect(state.measures[0].beats[0].chord, 'Solm7');
    expect(state.measures[1].beats[2].chord, 'Solm7');
    expect(state.measures[2].beats[3].chord, 'Solm7');
    // Los tiempos no marcados conservan su acorde.
    expect(state.measures[0].beats[1].chord, '');
  });

  test('volver a pulsar el checkbox desmarca el tiempo', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(accordionSimulatorProvider.notifier);

    notifier.toggleBeatMark(0, 1);
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      contains(AccordionSimulatorNotifier.beatKey(0, 1)),
    );

    notifier.toggleBeatMark(0, 1);
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      isNot(contains(AccordionSimulatorNotifier.beatKey(0, 1))),
    );
  });

  testWidgets('el checkbox del Compás marca y desmarca tiempos',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MeasureGridWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeasureGridWidget)),
    );

    expect(container.read(accordionSimulatorProvider).markedBeats, isEmpty);

    await tester.tap(find.byKey(const ValueKey('beat_checkbox_0_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('beat_checkbox_1_2')));
    await tester.pumpAndSettle();

    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      containsAll(<int>[
        AccordionSimulatorNotifier.beatKey(0, 0),
        AccordionSimulatorNotifier.beatKey(1, 2),
      ]),
    );

    // Marcar no debe abrir la edición del acorde.
    final firstBeatField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(firstBeatField.focusNode?.hasFocus, isFalse);

    // Segundo toque: se desmarca sin abrir la edición del acorde.
    await tester.tap(find.byKey(const ValueKey('beat_checkbox_0_0')));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      isNot(contains(AccordionSimulatorNotifier.beatKey(0, 0))),
    );
  });
}
