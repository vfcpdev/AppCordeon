import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('SPEC-002: Pruebas E2E de Asignación Masiva en Cascada de Fuelle', () {
    testWidgets(
      'Activar botón de Cascada y pulsar Abre asigna fuelle en cascada a todos los compases con ese mismo acorde',
      (tester) async {
        final container = ProviderContainer();
        final notifier = container.read(accordionSimulatorProvider.notifier);

        // Preparamos varios compases con diferentes acordes:
        // C1.1: 'Do', C1.2: 'Sol7', C1.3: 'Do', C1.4: ''
        // C2.1: 'Do', C2.2: 'Fa',   C2.3: 'Sol7', C2.4: 'Do'
        notifier.updateMeasureBeat(0, 0, 'Do');
        notifier.updateMeasureBeat(0, 1, 'Sol7');
        notifier.updateMeasureBeat(0, 2, 'Do');
        notifier.updateMeasureBeat(1, 0, 'Do');
        notifier.updateMeasureBeat(1, 1, 'Fa');
        notifier.updateMeasureBeat(1, 2, 'Sol7');
        notifier.updateMeasureBeat(1, 3, 'Do');

        // Seleccionamos la celda C1.1 ('Do')
        notifier.selectBeat(0, 0);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MeasureGridWidget(accordionNumber: 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verificamos que inicialmente todas las celdas tienen fuelle 'both' (indefinido)
        var state = container.read(accordionSimulatorProvider);
        expect(state.measures[0].beats[0].bellows, equals(BellowsMode.both));
        expect(state.measures[0].beats[2].bellows, equals(BellowsMode.both));
        expect(state.measures[1].beats[0].bellows, equals(BellowsMode.both));
        expect(state.measures[1].beats[3].bellows, equals(BellowsMode.both));
        expect(state.isCascadeBellowsActive, isFalse);

        // 2. Buscamos y pulsamos el botón de Cascada por su tooltip único
        final cascadeBtnFinder = find.byTooltip('Fuelle en Cascada INACTIVO: Pulsa para activar asignación en cascada (o usa Ctrl+Clic)');
        expect(cascadeBtnFinder, findsOneWidget);

        await tester.tap(cascadeBtnFinder);
        await tester.pumpAndSettle();

        // Verificamos que el modo cascada está ahora activo en el estado
        state = container.read(accordionSimulatorProvider);
        expect(state.isCascadeBellowsActive, isTrue);

        // 3. Pulsamos la flecha de 'Abre' (Pull)
        final pullBtnFinder = find.byTooltip('Abre (Fuelle abriendo)');
        expect(pullBtnFinder, findsOneWidget);

        await tester.tap(pullBtnFinder);
        await tester.pumpAndSettle();

        // 4. VERIFICACIÓN CRÍTICA:
        // Todos los cuadros que tienen el acorde 'Do' deben haber cambiado a BellowsMode.pull
        state = container.read(accordionSimulatorProvider);
        expect(state.measures[0].beats[0].bellows, equals(BellowsMode.pull), reason: 'C1.1 (Do) debe abrir');
        expect(state.measures[0].beats[2].bellows, equals(BellowsMode.pull), reason: 'C1.3 (Do) debe abrir');
        expect(state.measures[1].beats[0].bellows, equals(BellowsMode.pull), reason: 'C2.1 (Do) debe abrir');
        expect(state.measures[1].beats[3].bellows, equals(BellowsMode.pull), reason: 'C2.4 (Do) debe abrir');

        // Los otros acordes ('Sol7', 'Fa', y vacíos) DEBEN PERMANECER INVARIANTES en BellowsMode.both
        expect(state.measures[0].beats[1].bellows, equals(BellowsMode.both), reason: 'C1.2 (Sol7) debe ser intacto');
        expect(state.measures[1].beats[1].bellows, equals(BellowsMode.both), reason: 'C2.2 (Fa) debe ser intacto');
        expect(state.measures[1].beats[2].bellows, equals(BellowsMode.both), reason: 'C2.3 (Sol7) debe ser intacto');
        expect(state.measures[0].beats[3].bellows, equals(BellowsMode.both), reason: 'C1.4 (vacío) debe ser intacto');

        // 5. Verificamos Deshacer Atómico (Memento Pattern):
        // Un solo Undo debe revertir TODAS las celdas afectadas por la cascada
        final undoSuccess = notifier.undoGrid();
        expect(undoSuccess, isTrue);

        state = container.read(accordionSimulatorProvider);
        expect(state.measures[0].beats[0].bellows, equals(BellowsMode.both), reason: 'Undo revierte C1.1');
        expect(state.measures[0].beats[2].bellows, equals(BellowsMode.both), reason: 'Undo revierte C1.3');
        expect(state.measures[1].beats[0].bellows, equals(BellowsMode.both), reason: 'Undo revierte C2.1');
        expect(state.measures[1].beats[3].bellows, equals(BellowsMode.both), reason: 'Undo revierte C2.4');
      },
    );

    testWidgets(
      'Asignación directa vía setBeatBellows con cascadeToSameChord: true modifica todos los acordes homónimos',
      (tester) async {
        final container = ProviderContainer();
        final notifier = container.read(accordionSimulatorProvider.notifier);

        notifier.updateMeasureBeat(0, 0, 'Sol Mayor');
        notifier.updateMeasureBeat(0, 1, 'Re7');
        notifier.updateMeasureBeat(2, 2, 'Sol Mayor');
        notifier.updateMeasureBeat(3, 0, 'Sol Mayor');

        // Ejecutar en cascada hacia 'Cierra' (Push)
        notifier.setBeatBellows(0, 0, BellowsMode.push, cascadeToSameChord: true);

        final state = container.read(accordionSimulatorProvider);
        expect(state.measures[0].beats[0].bellows, equals(BellowsMode.push));
        expect(state.measures[2].beats[2].bellows, equals(BellowsMode.push));
        expect(state.measures[3].beats[0].bellows, equals(BellowsMode.push));

        // Re7 permanece invariante
        expect(state.measures[0].beats[1].bellows, equals(BellowsMode.both));
      },
    );
  });
}
