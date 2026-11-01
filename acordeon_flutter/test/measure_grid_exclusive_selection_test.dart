import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/constants/layout_constants.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('ToggleBellowsCommand - Triplas de Hoare y Desacoplamiento de Teclado', () {
    test('{P} y {Q}: Alterna de push a pull y viceversa de forma determinista', () {
      const cmdPush = ToggleBellowsCommand(currentMode: BellowsMode.push);
      expect(cmdPush.canExecute(), isTrue);
      expect(cmdPush.execute(), equals(BellowsMode.pull));

      const cmdPull = ToggleBellowsCommand(currentMode: BellowsMode.pull);
      expect(cmdPull.canExecute(), isTrue);
      expect(cmdPull.execute(), equals(BellowsMode.push));

      const cmdBoth = ToggleBellowsCommand(currentMode: BellowsMode.both);
      expect(cmdBoth.execute(), equals(BellowsMode.push));
    });
  });

  group('MeasureGridWidget - Selección Exclusiva de Textbox de Cuadros', () {
    testWidgets('al seleccionar el textbox de un cuadro y luego otro, se deselecciona el anterior',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.updateMeasureBeat(0, 1, 'Sol');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MeasureGridWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontrar los TextFields en la cuadrícula
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Seleccionar el primer cuadro (compás 0, beat 0)
      final firstBeatTextField = textFields.at(1); // at(0) es el TextField del BPM en el encabezado
      await tester.tap(firstBeatTextField);
      await tester.pumpAndSettle();

      // Verificar que el estado del controlador apunta al primer beat
      var state = container.read(accordionSimulatorProvider);
      expect(state.selectedBarIndex, equals(0));
      expect(state.selectedBeatIndex, equals(0));

      // Ahora seleccionar el segundo cuadro (compás 0, beat 1)
      final secondBeatTextField = textFields.at(2);
      await tester.tap(secondBeatTextField);
      await tester.pumpAndSettle();

      // Verificar que el estado del controlador apunta exclusivamente al segundo beat
      state = container.read(accordionSimulatorProvider);
      expect(state.selectedBarIndex, equals(0));
      expect(state.selectedBeatIndex, equals(1));

      // El primer TextField ya no debe tener foco
      final firstFieldWidget = tester.widget<TextField>(firstBeatTextField);
      expect(firstFieldWidget.focusNode?.hasFocus, isFalse);

      // El segundo TextField ahora tiene el foco activo
      final secondFieldWidget = tester.widget<TextField>(secondBeatTextField);
      expect(secondFieldWidget.focusNode?.hasFocus, isTrue);
    });

    testWidgets('copia el acorde de una casilla y lo pega en otra con Ctrl+C y Ctrl+V',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.updateMeasureBeat(0, 0, 'Do7');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MeasureGridWidget(width: 600)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chordFields = find.byType(TextField);
      final sourceField = chordFields.at(1);
      final targetField = chordFields.at(2);

      await tester.tap(sourceField);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).copiedChord, 'Do7');

      await tester.tap(targetField);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).measures[0].beats[1].chord, 'Do7');
    });

    testWidgets('desplaza lentamente el siguiente compás arriba al alcanzar el 80 %',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.generateMeasuresForAudio(durationSeconds: 100, bpm: 120);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MeasureGridWidget(width: 600)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(RawScrollbar),
        matching: find.byType(Scrollable),
      ).first;
      final scrollableState = tester.state<ScrollableState>(scrollable);
      notifier.togglePlayAudio();
      await tester.pump();
      notifier.selectBeat(11, 0);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));
      expect(scrollableState.position.pixels, greaterThan(0));
      expect(
        scrollableState.position.pixels,
        lessThan(12 * CompasCardMetrics.measureRowHeight),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        scrollableState.position.pixels,
        closeTo(12 * CompasCardMetrics.measureRowHeight, 2.0),
      );
      notifier.stopAudio();
    });
  });
}
