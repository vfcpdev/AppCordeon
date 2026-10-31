import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/tuning.dart';
import 'package:acordeon_flutter/domain/theory/chord_catalog.dart';
import 'package:acordeon_flutter/domain/theory/chord_detector_engine.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/chord_detector_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('ChordDetectorEngine - Detección Armónica Real', () {
    test('Detecta tríada mayor en estado fundamental y en inversión con barra /', () {
      // Do Mayor fundamental: Do (60), Mi (64), Sol (67)
      final cMajor = ChordDetectorEngine.detect(
        midiNotes: [60, 64, 67],
        notation: NotationMode.latina,
      );
      expect(cMajor, isNotNull);
      expect(cMajor!.root, 'Do');
      expect(cMajor.type, 'Tríada Mayor');
      expect(cMajor.inversion, 'Estado Fundamental');
      expect(cMajor.chordSymbol, 'Do');

      // Do Mayor 1ª Inversión (C/E): Mi (52), Sol (55), Do (60)
      final cFirstInv = ChordDetectorEngine.detect(
        midiNotes: [52, 55, 60],
        notation: NotationMode.latina,
      );
      expect(cFirstInv, isNotNull);
      expect(cFirstInv!.root, 'Do');
      expect(cFirstInv.bass, 'Mi');
      expect(cFirstInv.chordSymbol, 'Do/Mi');
      expect(cFirstInv.inversion, contains('1ª Inversión'));

      // Notación Americana / Alemana
      final cFirstInvGerman = ChordDetectorEngine.detect(
        midiNotes: [52, 55, 60],
        notation: NotationMode.alemana,
      );
      expect(cFirstInvGerman, isNotNull);
      expect(cFirstInvGerman!.root, 'C');
      expect(cFirstInvGerman.bass, 'E');
      expect(cFirstInvGerman.chordSymbol, 'C/E');
    });

    test('Detecta acordes menores y con séptima', () {
      // La menor (Am): La (57), Do (60), Mi (64)
      final aMin = ChordDetectorEngine.detect(
        midiNotes: [57, 60, 64],
        notation: NotationMode.latina,
      );
      expect(aMin, isNotNull);
      expect(aMin!.root, 'La');
      expect(aMin.chordSymbol, 'Lam');

      // Sol 7ma dominante: Sol (55), Si (59), Re (62), Fa (65)
      final g7 = ChordDetectorEngine.detect(
        midiNotes: [55, 59, 62, 65],
        notation: NotationMode.latina,
      );
      expect(g7, isNotNull);
      expect(g7!.root, 'Sol');
      expect(g7.chordSymbol, 'Sol7');
    });

    test('Evalúa disponibilidad en el diapasón abriendo y cerrando', () {
      final container = ProviderContainer();
      final state = container.read(accordionSimulatorProvider);

      // Do Mayor en afinación por defecto (Cinco Letras Bb-Eb-Ab)
      final availability = ChordDetectorEngine.evaluateDiapasonBellows(
        chordPitchClasses: {0, 4, 7}, // Do, Mi, Sol
        trebleData: state.trebleData1,
      );

      expect(availability.pushMatchedPcs.isNotEmpty || availability.pullMatchedPcs.isNotEmpty, isTrue);
    });
  });

  group('ChordCatalog - Soporte de Acordes Slash / Inversiones con Barra', () {
    test('pitchClassesForChordSymbol extrae clases de altura de acordes con barra /', () {
      // C/E = C (0), E (4), G (7) + E (4)
      final pcsCE = ChordCatalog.pitchClassesForChordSymbol('C/E');
      expect(pcsCE, containsAll([0, 4, 7]));

      // Am/G = A (9), C (0), E (4) + G (7)
      final pcsAmG = ChordCatalog.pitchClassesForChordSymbol('Am/G');
      expect(pcsAmG, containsAll([9, 0, 4, 7]));

      // Do/Sol = Do (0), Mi (4), Sol (7)
      final pcsDoSol = ChordCatalog.pitchClassesForChordSymbol('Do/Sol');
      expect(pcsDoSol, containsAll([0, 4, 7]));
    });

    test('formatChordForNotation traduce ambas partes del acorde con barra /', () {
      expect(ChordCatalog.formatChordForNotation('C/E', NotationMode.latina), 'Do/Mi');
      expect(ChordCatalog.formatChordForNotation('Do/Sol', NotationMode.alemana), 'C/G');
      expect(ChordCatalog.formatChordForNotation('Am/F#', NotationMode.latina), 'Lam/Fa#');
    });

    test('symbolFor genera acordes con bajo alterado /', () {
      final sym1 = ChordCatalog.symbolFor(
        root: 0, // Do
        type: 'maj',
        extension: 'none',
        bass: '3', // 1ª inversión
        latin: true,
      );
      expect(sym1, 'Do/Mi');

      final sym2 = ChordCatalog.symbolFor(
        root: 0, // C
        type: 'maj',
        extension: 'none',
        bass: '5', // 2ª inversión
        latin: false,
      );
      expect(sym2, 'C/G');
    });
  });

  group('ChordDetectorWidget - Pruebas de Interfaz y Comportamiento', () {
    testWidgets('Muestra botones de cabecera: activo push button sin texto, play icono, arpegio icono',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ChordDetectorWidget(width: 185),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Botón push Activo/Inactivo (sin texto)
      final toggleBtn = find.byKey(const ValueKey('detector_toggle_active_btn'));
      expect(toggleBtn, findsOneWidget);

      // Botón Play (solo icono)
      final playBtn = find.byKey(const ValueKey('detector_play_btn'));
      expect(playBtn, findsOneWidget);

      // Botón Arpegio (solo icono)
      final arpeggioBtn = find.byKey(const ValueKey('detector_arpeggio_btn'));
      expect(arpeggioBtn, findsOneWidget);

      // Botón Desacoplar
      final undockBtn = find.byKey(const ValueKey('detector_undock_btn'));
      expect(undockBtn, findsOneWidget);

      // No hay botones de fuelle Auto / Abre / Cierra en el detector
      expect(find.text('Auto'), findsNothing);
      expect(find.text('Fuelle:'), findsNothing);

      // Activar detector mode pulsando el toggle
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).detectorMode, isTrue);
    });

    testWidgets('Asigna el acorde detectado al compás y tiempo activo', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      // Seleccionar un par de botones en el detector
      notifier.toggleDetectorMode();
      notifier.toggleDetectorButton('row1_2', 60); // Do
      notifier.toggleDetectorButton('row2_3', 64); // Mi
      notifier.toggleDetectorButton('row1_5', 67); // Sol

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ChordDetectorWidget(width: 185),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      expect(state.detectedChord, isNotNull);

      // Botón Asignar
      final assignBtn = find.byKey(const ValueKey('detector_assign_btn'));
      expect(assignBtn, findsOneWidget);

      await tester.tap(assignBtn);
      await tester.pumpAndSettle();

      // Verificar que el compás recibió el acorde
      final updatedState = container.read(accordionSimulatorProvider);
      final beat0 = updatedState.measures[0].beats[0];
      expect(beat0.chord.isNotEmpty, isTrue);
    });

    testWidgets('El Detector se encuentra directamente debajo de Estado del Acorde en MeasureGridWidget',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setTuning1(TuningRegistry.defaultTunings.first);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MeasureGridWidget(accordionNumber: 1, width: 185),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que tanto "Estado del Acorde" como el "Detector" están renderizados
      expect(find.text('Estado del Acorde'), findsOneWidget);
      expect(find.byKey(const ValueKey('detector_toggle_active_btn')), findsOneWidget);

      // Probar desacoplamiento
      final undockBtn = find.byKey(const ValueKey('detector_undock_btn'));
      await tester.tap(undockBtn);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).isChordDetectorUndocked, isTrue);
      // En su lugar debe mostrar el marcador de acoplar
      expect(find.byKey(const ValueKey('re_dock_detector_btn')), findsOneWidget);
    });
  });
}

