import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/theory/chord_catalog.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('ChordCatalog - Análisis de Fuelle y Clases de Altura', () {
    test('pitchClassesForChordSymbol extrae clases de altura exactas para tríadas y extensiones', () {
      // Do Mayor = Do (0), Mi (4), Sol (7)
      final cPcs = ChordCatalog.pitchClassesForChordSymbol('Do');
      expect(cPcs, containsAll([0, 4, 7]));
      expect(cPcs.length, 3);

      // Sol7 = Sol (7), Si (11), Re (2), Fa (5)
      final g7Pcs = ChordCatalog.pitchClassesForChordSymbol('Sol7');
      expect(g7Pcs, containsAll([7, 11, 2, 5]));
      expect(g7Pcs.length, 4);

      // Lam (A minor) = La (9), Do (0), Mi (4)
      final amPcs = ChordCatalog.pitchClassesForChordSymbol('Am');
      expect(amPcs, containsAll([9, 0, 4]));
      expect(amPcs.length, 3);
    });

    test('MeasureJsonSerializer preserva la propiedad bellows de MeasureBeat', () {
      final rows = [
        MeasureRow(
          barNumber: 1,
          beats: [
            const MeasureBeat(
              barIndex: 0,
              beatIndex: 0,
              chord: 'C',
              timeText: '00:00',
              bellows: BellowsMode.pull,
            ),
            const MeasureBeat(
              barIndex: 0,
              beatIndex: 1,
              chord: 'G',
              timeText: '00:01',
              bellows: BellowsMode.push,
            ),
            const MeasureBeat(
              barIndex: 0,
              beatIndex: 2,
              chord: 'F',
              timeText: '00:02',
              bellows: BellowsMode.both,
            ),
            const MeasureBeat(
              barIndex: 0,
              beatIndex: 3,
              chord: '',
              timeText: '00:03',
            ),
          ],
        ),
      ];

      final jsonStr = MeasureJsonSerializer.exportToJson(rows);
      final restored = MeasureJsonSerializer.importFromJson(jsonStr);

      expect(restored.first.beats[0].bellows, BellowsMode.pull);
      expect(restored.first.beats[1].bellows, BellowsMode.push);
      expect(restored.first.beats[2].bellows, BellowsMode.both);
    });
  });

  group('AccordionSimulatorNotifier - Flechas de Fuelle en Tiempos', () {
    test('setBeatBellows asigna dirección de fuelle y acorde en el tiempo seleccionado', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Configuramos un acorde en el constructor: Sol Mayor (root = 7)
      notifier.setFreeChordRoot(7); // Sol

      // Asignar Abre al tiempo 1 del compás 0 (que inicialmente no tiene acorde)
      notifier.setBeatBellows(0, 1, BellowsMode.pull);

      final state = container.read(accordionSimulatorProvider);
      final beat = state.measures[0].beats[1];

      expect(beat.bellows, BellowsMode.pull);
      expect(beat.chord, 'Sol');
      expect(state.bellows1, BellowsMode.pull);
      expect(state.selectedBarIndex, 0);
      expect(state.selectedBeatIndex, 1);

      // Al tocar de nuevo el mismo fuelle, alterna de vuelta a both
      notifier.setBeatBellows(0, 1, BellowsMode.pull);
      final stateAfterToggle = container.read(accordionSimulatorProvider);
      expect(stateAfterToggle.measures[0].beats[1].bellows, BellowsMode.both);
    });
  });

  group('MeasureGridWidget - Sección de Información de Acorde y Flechas', () {
    testWidgets('Renderiza flechas de Abre/Cierre y la tarjeta informativa de Estado del Acorde',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MeasureGridWidget(width: 150),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica que exista la sección de información bajo el compás
      expect(find.text('Estado del Acorde'), findsOneWidget);
      expect(find.text('Cierra'), findsOneWidget);
      expect(find.text('Abre'), findsOneWidget);

      // Verifica que existan tooltips o íconos de flechas en los tiempos
      expect(find.byTooltip('Abre (Fuelle abriendo)'), findsWidgets);
      expect(find.byTooltip('Cierra (Fuelle cerrando)'), findsWidgets);
    });
  });
}
