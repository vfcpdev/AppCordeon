import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

    test('ChordCatalog.maxChordName es la cadena de texto más grande generable (12 caracteres)', () {
      expect(ChordCatalog.maxChordName, 'Sol#sus4maj7');
      expect(ChordCatalog.maxChordName.length, 12);

      // Generado directamente por symbolFor
      final generated = ChordCatalog.symbolFor(
        root: 8, // Sol#
        type: 'sus4',
        extension: 'maj7',
        latin: true,
      );
      expect(generated, 'Sol#sus4maj7');

      // Comprobar exhaustivamente todas las combinaciones posibles en ChordCatalog
      var longestFound = '';
      for (var r = 0; r < 12; r++) {
        for (final t in ['', 'min', 'dim', 'aug', 'sus4']) {
          for (final ext in ['', 'octave', 'dom7', 'maj7', 'maj6', 'add9', 'min7', 'dim7']) {
            final latinSym = ChordCatalog.symbolFor(root: r, type: t, extension: ext, latin: true);
            if (latinSym.length > longestFound.length) {
              longestFound = latinSym;
            }
            final germanSym = ChordCatalog.symbolFor(root: r, type: t, extension: ext, latin: false);
            if (germanSym.length > longestFound.length) {
              longestFound = germanSym;
            }
          }
        }
      }

      expect(longestFound.length, 12);
      expect(longestFound, 'Sol#sus4maj7');
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

      final jsonStr = MeasureJsonSerializer.exportToJson(
        rows,
        tuning: 'Cinco Letras (SOL-DO-FA)',
        bpm: 130,
        markedBeats: {0, 1},
      );
      final parsed = MeasureJsonSerializer.parseJsonData(jsonStr);

      expect(parsed.tuning, 'Cinco Letras (SOL-DO-FA)');
      expect(parsed.bpm, 130);
      expect(parsed.markedBeats, {0, 1});
      expect(parsed.timeSignature, '4/4');
      expect(parsed.measures.first.beats[0].bellows, BellowsMode.pull);
      expect(parsed.measures.first.beats[1].bellows, BellowsMode.push);
      expect(parsed.measures.first.beats[2].bellows, BellowsMode.both);

      final restored = MeasureJsonSerializer.importFromJson(jsonStr);
      expect(restored.first.beats[0].bellows, BellowsMode.pull);
      expect(restored.first.beats[1].bellows, BellowsMode.push);
      expect(restored.first.beats[2].bellows, BellowsMode.both);
    });
  });

  group('AccordionSimulatorNotifier - Flechas de Fuelle en Tiempos', () {
    test('setBeatBellows solo asigna dirección si hay acorde registrado y no modifica el acorde', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Si el tiempo 1 no tiene acorde, setBeatBellows no hace nada
      notifier.setBeatBellows(0, 1, BellowsMode.pull);
      var state = container.read(accordionSimulatorProvider);
      expect(state.measures[0].beats[1].bellows, BellowsMode.both);
      expect(state.measures[0].beats[1].chord, '');

      // Registramos un acorde en el tiempo 1: 'Sol'
      notifier.updateMeasureBeat(0, 1, 'Sol');

      // Ahora asignar Abre sí aplica el fuelle al tiempo con acorde registrado
      notifier.setBeatBellows(0, 1, BellowsMode.pull);
      state = container.read(accordionSimulatorProvider);
      var beat = state.measures[0].beats[1];

      expect(beat.bellows, BellowsMode.pull);
      expect(beat.chord, 'Sol');
      expect(state.bellows1, BellowsMode.pull);
      expect(state.selectedBarIndex, 0);
      expect(state.selectedBeatIndex, 1);

      // Al tocar de nuevo el mismo fuelle, alterna de vuelta a both
      notifier.setBeatBellows(0, 1, BellowsMode.pull);
      final stateAfterToggle = container.read(accordionSimulatorProvider);
      expect(stateAfterToggle.measures[0].beats[1].bellows, BellowsMode.both);
      expect(stateAfterToggle.measures[0].beats[1].chord, 'Sol');
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

      // Asigna un acorde al primer tiempo para habilitar las flechas de fuelle
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MeasureGridWidget)),
      );
      container.read(accordionSimulatorProvider.notifier).updateMeasureBeat(0, 0, 'Do');
      await tester.pumpAndSettle();

      // Verifica que existan tooltips o íconos de flechas en los tiempos
      expect(find.byTooltip('Abre (Fuelle abriendo)'), findsWidgets);
      expect(find.byTooltip('Cierra (Fuelle cerrando)'), findsWidgets);

      // Verifica el botón de guardar con icono floppyDisk
      expect(find.byTooltip('Guardar compases en JSON (Exportar)'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is FaIcon && w.icon?.codePoint == FontAwesomeIcons.floppyDisk.codePoint),
        findsOneWidget,
      );
    });

    test('AccordionSimulatorNotifier exporta e importa compases preservando afinación y selecciones', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.setBeatChord(0, 0, 'DoM');
      notifier.setBeatBellows(0, 0, BellowsMode.pull);
      notifier.toggleBeatMark(0, 0);

      final key00 = AccordionSimulatorNotifier.beatKey(0, 0);
      final jsonStr = notifier.exportMeasuresToJson();
      expect(jsonStr.contains('Cinco Letras'), isTrue);
      expect(jsonStr.contains('$key00'), isTrue);

      final success = notifier.loadMeasuresFromJson(jsonStr);
      expect(success, isTrue);

      final state = container.read(accordionSimulatorProvider);
      expect(state.measures[0].beats[0].chord, 'DoM');
      expect(state.measures[0].beats[0].bellows, BellowsMode.pull);
      expect(state.markedBeats.contains(key00), isTrue);
    });
  });
}
