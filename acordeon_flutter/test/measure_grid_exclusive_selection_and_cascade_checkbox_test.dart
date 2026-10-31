import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/measure_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('CascadeMarkBeatsCommand - Triplas de Hoare y Comportamiento Formal', () {
    test('{P} Precondiciones: lanza excepción ante parámetros fuera de rango o sin compases', () {
      expect(
        () => CascadeMarkBeatsCommand(
          currentMarkedBeats: {},
          barIndex: 0,
          beatIndex: 0,
          totalMeasures: 0,
        ).assertPreconditions(),
        throwsA(isA<PreconditionViolationException>()),
      );

      expect(
        () => CascadeMarkBeatsCommand(
          currentMarkedBeats: {},
          barIndex: 5,
          beatIndex: 0,
          totalMeasures: 4,
        ).assertPreconditions(),
        throwsA(isA<PreconditionViolationException>()),
      );

      expect(
        () => CascadeMarkBeatsCommand(
          currentMarkedBeats: {},
          barIndex: 1,
          beatIndex: 4,
          totalMeasures: 4,
        ).assertPreconditions(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });

    test('{Q} y {I}: Seleccionar checkbox mantiene selección previa y marca todos los siguientes', () {
      // Estado inicial con tiempos 1 y 2 marcados previamente
      final initialMarks = {1, 2};
      const barIndex = 1;
      const beatIndex = 1; // targetKey = 1 * 4 + 1 = 5
      const totalMeasures = 3; // totalBeats = 12 (0 a 11)

      final command = CascadeMarkBeatsCommand(
        currentMarkedBeats: initialMarks,
        barIndex: barIndex,
        beatIndex: beatIndex,
        totalMeasures: totalMeasures,
      );

      expect(command.canExecute(), isTrue);
      final result = command.execute();

      // Mantiene la selección previa {1, 2}
      expect(result.contains(1), isTrue);
      expect(result.contains(2), isTrue);

      // Los tiempos entre 0 y 4 que no estaban marcados siguen sin marcar {I}
      expect(result.contains(0), isFalse);
      expect(result.contains(3), isFalse);
      expect(result.contains(4), isFalse);

      // Marca todos los siguientes desde 5 hasta 11 {Q}
      for (var i = 5; i < 12; i++) {
        expect(result.contains(i), isTrue, reason: 'El pulso $i debe estar marcado.');
      }
    });

    test('{Q} y {I}: Desmarcar checkbox desmarca desde ese tiempo en adelante, manteniendo anteriores', () {
      // Estado con pulsos 0, 1, 4, 5, 6, 7, 8, 9, 10, 11 marcados
      final initialMarks = {0, 1, 4, 5, 6, 7, 8, 9, 10, 11};
      const barIndex = 2;
      const beatIndex = 0; // targetKey = 2 * 4 + 0 = 8
      const totalMeasures = 3; // totalBeats = 12

      final command = CascadeMarkBeatsCommand(
        currentMarkedBeats: initialMarks,
        barIndex: barIndex,
        beatIndex: beatIndex,
        totalMeasures: totalMeasures,
      );

      final result = command.execute();

      // Mantiene selección previa intacta < 8
      expect(result.contains(0), isTrue);
      expect(result.contains(1), isTrue);
      expect(result.contains(4), isTrue);
      expect(result.contains(5), isTrue);
      expect(result.contains(6), isTrue);
      expect(result.contains(7), isTrue);

      // Desmarca desde 8 hasta 11
      for (var i = 8; i < 12; i++) {
        expect(result.contains(i), isFalse, reason: 'El pulso $i debe quedar desmarcado.');
      }
    });
  });

  group('AccordionSimulatorNotifier - Cascada en Checkbox', () {
    test('toggleBeatMarkWithCascade aplica selección en cascada y preserva anteriores', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Iniciar con 2 compases (8 pulsos: 0..7)
      final dummyMeasures = [
        MeasureRow(measureIndex: 0, beats: [
          MeasureBeat(chord: 'Do', timeText: '0.00'),
          MeasureBeat(chord: '', timeText: '0.50'),
          MeasureBeat(chord: '', timeText: '1.00'),
          MeasureBeat(chord: '', timeText: '1.50'),
        ]),
        MeasureRow(measureIndex: 1, beats: [
          MeasureBeat(chord: 'Sol', timeText: '2.00'),
          MeasureBeat(chord: '', timeText: '2.50'),
          MeasureBeat(chord: '', timeText: '3.00'),
          MeasureBeat(chord: '', timeText: '3.50'),
        ]),
      ];
      notifier.setMeasures(dummyMeasures);

      // Marcar individualmente el pulso 0
      notifier.toggleBeatMark(0, 0);
      expect(container.read(accordionSimulatorProvider).markedBeats, equals({0}));

      // Ahora seleccionar con checkbox el pulso en compás 1, beat 0 (clave lineal = 4)
      notifier.toggleBeatMarkWithCascade(1, 0);

      // Debe mantener el pulso 0 y marcar 4, 5, 6, 7
      final marks = container.read(accordionSimulatorProvider).markedBeats;
      expect(marks, equals({0, 4, 5, 6, 7}));

      // Desmarcar desde compás 1, beat 2 (clave lineal = 6)
      notifier.toggleBeatMarkWithCascade(1, 2);
      final marksAfter = container.read(accordionSimulatorProvider).markedBeats;
      expect(marksAfter, equals({0, 4, 5}));
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

      final dummyMeasures = [
        MeasureRow(measureIndex: 0, beats: [
          MeasureBeat(chord: 'Do', timeText: '0.00'),
          MeasureBeat(chord: 'Sol', timeText: '0.50'),
          MeasureBeat(chord: 'Lam', timeText: '1.00'),
          MeasureBeat(chord: 'Fa', timeText: '1.50'),
        ]),
      ];
      container.read(accordionSimulatorProvider.notifier).setMeasures(dummyMeasures);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MeasureGridWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontrar los TextFields de los beats dentro de la cuadrícula
      // Los TextFields en MeasureGridWidget corresponden a los beats
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Seleccionar el primer cuadro (compás 0, beat 0)
      final firstBeatTextField = textFields.at(1); // at(0) puede ser el BPM o búsqueda
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
  });
}
