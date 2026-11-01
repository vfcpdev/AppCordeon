import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/layout_constants.dart';
import 'package:acordeon_flutter/core/text/chord_text_fitter.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('Ajuste del texto en cuadros del compás (Trijas de Hoare integradas)', () {
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

    testWidgets(
        '{Q}: un acorde largo reduce su tamaño por debajo del base sin desbordar',
        (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 1, 'Dom7b5/Sol');
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      expect(state.measures[0].beats[1].chord, equals('Dom7b5/Sol'));

      // Encuentra el TextField del cuadro (0, 1) e inspecciona su tipografía
      final cellField = tester.widget<TextField>(
        find
            .byType(TextField)
            .where((w) =>
                w.controller?.text != null &&
                w.controller!.text == 'Dom7b5/Sol')
            .first,
      );
      final fontSize = cellField.style?.fontSize;
      expect(fontSize, isNotNull);
      expect(fontSize!, lessThan(10.0));
      // {Q}: cotas del ajustador local
      expect(fontSize, greaterThanOrEqualTo(6.0));
      expect(fontSize, lessThanOrEqualTo(10.0));
    });

    testWidgets(
        '{Q}: acordes cortos se muestran con el tamaño base en celdas del nuevo ancho',
        (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Do');
      await tester.pumpAndSettle();

      final cellField = tester.widget<TextField>(
        find
            .byType(TextField)
            .where((w) => w.controller?.text == 'Do')
            .first,
      );
      expect(cellField.style?.fontSize, equals(10.0));

      // El cuadro de compás ahora mide CompasCardMetrics.width de ancho
      final grid = tester.getSize(find.byType(MeasureGridWidget));
      expect(grid.width, CompasCardMetrics.width);
    });
  });
}
