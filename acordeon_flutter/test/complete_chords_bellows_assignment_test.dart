import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/tuning.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('Asignación y Decisión de Acordes Completos en Fuelle', () {
    test('assignCompleteChordsBellows asigna push/pull y marca amarillos para decisión', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Usar afinación Cinco Letras (Bb-Eb-Ab)
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      // Configurar compás 0 con acordes de prueba
      notifier.updateMeasureBeat(0, 0, 'Bb');
      notifier.updateMeasureBeat(0, 1, 'Eb');
      notifier.updateMeasureBeat(0, 2, 'F');
      notifier.updateMeasureBeat(0, 3, 'C');

      final result = notifier.assignCompleteChordsBellows(1);
      final state = container.read(accordionSimulatorProvider);

      // Verificamos que se detectaron asignados o amarillos
      expect(result['assigned']! + result['yellow']!, greaterThan(0));

      // Si hay amarillos, probar applyYellowDecision
      if (state.yellowDecisionBeats.isNotEmpty) {
        final yellowCount = state.yellowDecisionBeats.length;
        final applied = notifier.applyYellowDecision(BellowsMode.push);
        expect(applied, yellowCount);
        expect(container.read(accordionSimulatorProvider).yellowDecisionBeats, isEmpty);
      }
    });

    test('selectCompleteChordsBeats marca las casillas de los tiempos con acordes completos', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      notifier.updateMeasureBeat(0, 0, 'Bb');
      notifier.updateMeasureBeat(0, 1, 'Eb');

      final selectedCount = notifier.selectCompleteChordsBeats(1);
      final state = container.read(accordionSimulatorProvider);

      expect(selectedCount, greaterThan(0));
      expect(state.markedBeats.contains(0), isTrue); // Beat 0 (Bb) está seleccionado
    });

    testWidgets('Botón de opciones de acordes completos está a la derecha del BPM en Compás', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      notifier.updateMeasureBeat(0, 0, 'Bb');
      notifier.updateMeasureBeat(0, 1, 'Eb');
      notifier.updateMeasureBeat(0, 2, 'F');
      notifier.updateMeasureBeat(0, 3, 'C');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MeasureGridWidget(accordionNumber: 1, width: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el botón existe por Key
      final buttonFinder = find.byKey(const ValueKey('complete_chords_btn_1'));
      expect(buttonFinder, findsOneWidget);

      // Abrir el menú popup
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verificar elementos del menú por Key
      expect(find.byKey(const ValueKey('assign_complete_chords_opt')), findsOneWidget);
      expect(find.byKey(const ValueKey('select_complete_chords_opt')), findsOneWidget);
      expect(find.byKey(const ValueKey('mark_yellow_chords_opt')), findsOneWidget);

      // Pulsar "Marcar amarillos para decidir"
      await tester.tap(find.byKey(const ValueKey('mark_yellow_chords_opt')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      if (state.yellowDecisionBeats.isNotEmpty) {
        // Verificar que aparece el banner de decisión
        expect(find.textContaining('abren o cierran'), findsOneWidget);
        expect(find.byKey(const ValueKey('apply_yellow_pull_quick_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('apply_yellow_push_quick_1')), findsOneWidget);

        // Pulsar botón rápido "Cierra" en el banner
        await tester.tap(find.byKey(const ValueKey('apply_yellow_push_quick_1')));
        await tester.pumpAndSettle();

        // El banner desaparece y los amarillos se limpian
        expect(container.read(accordionSimulatorProvider).yellowDecisionBeats, isEmpty);
        expect(find.textContaining('abren o cierran'), findsNothing);
      }
    });

    testWidgets('Seleccionar fuelle individual en un beat amarillo limpia su marca amarilla', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      notifier.updateMeasureBeat(0, 0, 'Bb');
      notifier.updateMeasureBeat(0, 1, 'Eb');
      notifier.updateMeasureBeat(0, 2, 'F');
      notifier.updateMeasureBeat(0, 3, 'C');

      // Marcar manualmente los tiempos en amarillo para decidir
      notifier.markYellowDecisionBeats(1);
      final initialYellow = container.read(accordionSimulatorProvider).yellowDecisionBeats;

      if (initialYellow.isNotEmpty) {
        final firstYellowKey = initialYellow.first;
        final barIdx = firstYellowKey ~/ 4;
        final beatIdx = firstYellowKey % 4;

        // Establecer fuelle para ese beat
        notifier.setBeatBellows(barIdx, beatIdx, BellowsMode.pull);

        // El beat ya no debe estar en yellowDecisionBeats
        expect(container.read(accordionSimulatorProvider).yellowDecisionBeats.contains(firstYellowKey), isFalse);
      }
    });
  });
}
