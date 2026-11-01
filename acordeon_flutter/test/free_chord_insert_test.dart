import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/layout_constants.dart';
import 'package:acordeon_flutter/core/text/chord_text_fitter.dart';
import 'package:acordeon_flutter/domain/theory/chord_catalog.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/free_chord_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_with_chord_quality_widget.dart';

void main() {
  testWidgets('la cuadrícula amplía sus celdas y muestra seis compases', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MeasureGridWidget())),
      ),
    );
    await tester.pumpAndSettle();

    final gridSize = tester.getSize(
      find.byKey(const ValueKey('measure_grid_section_card')),
    );
    final listFinder = find.descendant(
      of: find.byKey(const ValueKey('measure_grid_section_card')),
      matching: find.byType(ListView),
    );
    final listRect = tester.getRect(listFinder);
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(MeasureGridWidget)),
    ).read(accordionSimulatorProvider.notifier);
    notifier.updateMeasureBeat(5, 0, ChordCatalog.maxChordName);
    await tester.pumpAndSettle();

    final sixthCellFinder = find.byKey(const ValueKey('beat_cell_5_0'));
    final sixthMeasureCell = tester.getRect(sixthCellFinder);
    final chordField = tester.widget<TextField>(
      find.descendant(of: sixthCellFinder, matching: find.byType(TextField)),
    );

    expect(gridSize.width, CompasCardMetrics.gridWidth);
    expect(sixthMeasureCell.width, greaterThan(sixthMeasureCell.height));
    expect(CompasCardMetrics.measureRowHeight * 6, 282);
    expect(CompasCardMetrics.gridMaxHeight, 290);
    expect(sixthMeasureCell.bottom, lessThanOrEqualTo(listRect.bottom + 1));
    expect(chordField.controller?.text, ChordCatalog.maxChordName);
    final fittedFontSize = chordField.style!.fontSize!;
    expect(fittedFontSize, greaterThanOrEqualTo(6));
    expect(fittedFontSize, lessThanOrEqualTo(10));
    expect(
      ChordCatalog.maxChordName.length *
              ChordTextFitter.defaultCharWidthFactor *
              fittedFontSize <=
          tester
              .getSize(
                find.descendant(
                  of: sixthCellFinder,
                  matching: find.byType(TextField),
                ),
              )
              .width,
      isTrue,
    );
  });

  testWidgets('la sección de acordes no muestra botones de tónica', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: FreeChordWidget())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(RegExp(r'^Tónica ')), findsNothing);
    expect(
      find.byKey(const ValueKey('insert_chord_to_compas_btn')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('multi_beat_modal_checkbox')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tonic_bar_full_chord_name')),
      findsNothing,
    );
    for (final section in ['Octava', 'Extensión', 'Bajo (/)']) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('Estructura'), findsNothing);
    expect(find.text('Cualidad'), findsNothing);
    expect(find.byTooltip('Suspendido 2'), findsNothing);
    expect(find.byTooltip('Séptima menor'), findsNothing);
  });

  testWidgets(
    'la columna vertical de cualidades cambia la cualidad del acorde',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: FreeChordWidget()),
                  MeasureGridWithChordQualityWidget(width: 185),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MeasureGridWithChordQualityWidget)),
      );
      final qualityKeys = [
        'chord_quality_maj',
        'chord_quality_min',
        'chord_quality_dim',
        'chord_quality_aug',
        'chord_quality_sus2',
        'chord_quality_sus4',
      ];
      for (final key in qualityKeys) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }

      expect(
        find.byKey(const ValueKey('chord_qualities_container')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chord_structure_container')),
        findsOneWidget,
      );
      final qualityContainer = tester.getRect(
        find.byKey(const ValueKey('chord_qualities_container')),
      );
      final structureContainer = tester.getRect(
        find.byKey(const ValueKey('chord_structure_container')),
      );
      final sus4Rect = tester.getRect(
        find.byKey(const ValueKey('chord_quality_sus4')),
      );
      final triadRect = tester.getRect(
        find.byKey(const ValueKey('chord_structure_triad')),
      );
      final seventhRect = tester.getRect(
        find.byKey(const ValueKey('chord_structure_seventh')),
      );
      final firstTonic = tester.getTopLeft(
        find.byKey(const ValueKey('tonic_matrix_btn_0')),
      );
      expect(qualityContainer.top, closeTo(firstTonic.dy, 1));
      expect(structureContainer.top, greaterThan(qualityContainer.bottom));
      expect(triadRect.top, greaterThan(sus4Rect.bottom));
      expect(seventhRect.top, greaterThan(triadRect.bottom));
      final compasCardRect = tester.getRect(
        find.byKey(const ValueKey('measure_grid_section_card')),
      );
      final qualityRect = tester.getRect(
        find.byKey(const ValueKey('chord_quality_maj')),
      );
      final layoutRect = tester.getRect(
        find.byKey(const ValueKey('measure_grid_with_chord_quality_1')),
      );
      expect(qualityContainer.left, greaterThan(compasCardRect.right));
      expect(
        qualityContainer.left,
        lessThanOrEqualTo(compasCardRect.right + 10),
      );
      expect(qualityRect.right, lessThanOrEqualTo(layoutRect.right));
      expect(qualityRect.left, greaterThanOrEqualTo(qualityContainer.left));
      expect(qualityRect.right, lessThanOrEqualTo(qualityContainer.right));
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('chord_quality_maj')),
          matching: find.byKey(const ValueKey('measure_grid_section_card')),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('chord_quality_sus4'))).dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('chord_quality_sus2')))
              .dy,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('chord_structure_seventh')));
      await tester.pumpAndSettle();
      expect(
        container.read(accordionSimulatorProvider).freeChordScaleHarmonicMode,
        'seventh',
      );

      await tester.tap(find.byKey(const ValueKey('chord_quality_sus2')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      expect(state.freeChordType, 'sus2');
      expect(
        ChordCatalog.notesFor(
          root: 0,
          type: state.freeChordType,
          extension: 'none',
        ),
        [60, 62, 67],
      );
      expect(
        ChordCatalog.symbolFor(
          root: 0,
          type: state.freeChordType,
          extension: 'none',
        ),
        'Dosus2',
      );
    },
  );

  testWidgets(
    'seleccionar una casilla inicia edición y selección múltiple requiere activar su modo',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: MeasureGridWidget(width: 600)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstCell = find.byKey(const ValueKey('beat_cell_0_0'));
      final secondCell = find.byKey(const ValueKey('beat_cell_0_1'));
      Finder textFieldFor(Finder cell) =>
          find.descendant(of: cell, matching: find.byType(TextField));

      await tester.tap(firstCell);
      await tester.pumpAndSettle();
      var firstTextField = tester.widget<TextField>(textFieldFor(firstCell));
      expect(firstTextField.readOnly, isFalse);
      expect(firstTextField.focusNode!.hasFocus, isTrue);

      await tester.tap(secondCell);
      await tester.pumpAndSettle();
      firstTextField = tester.widget<TextField>(textFieldFor(firstCell));
      final secondTextField = tester.widget<TextField>(
        textFieldFor(secondCell),
      );
      expect(firstTextField.focusNode!.hasFocus, isFalse);
      expect(secondTextField.readOnly, isFalse);
      expect(secondTextField.focusNode!.hasFocus, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('multi_beat_assignment_mode_btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(firstCell);
      await tester.tap(secondCell);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(textFieldFor(firstCell)).readOnly,
        isTrue,
      );
      expect(
        tester.widget<TextField>(textFieldFor(secondCell)).readOnly,
        isTrue,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MeasureGridWidget)),
      );
      expect(
        container.read(accordionSimulatorProvider).multiBeatAssignmentTargets,
        {0, 1},
      );
    },
  );

  testWidgets('el botón Compás inserta el acorde en la celda seleccionada', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 280,
                  child: SingleChildScrollView(child: FreeChordWidget()),
                ),
                MeasureGridWidget(width: 185),
              ],
            ),
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

    await tester.tap(find.byKey(const ValueKey('insert_chord_to_compas_btn')));
    await tester.pumpAndSettle();

    final state = container.read(accordionSimulatorProvider);
    expect(state.measures[1].beats[3].chord, 'Solm7');
  });

  testWidgets('asigna el acorde a casillas marcadas de compases distintos', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 280,
                  child: SingleChildScrollView(child: FreeChordWidget()),
                ),
                MeasureGridWidget(width: 600),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FreeChordWidget)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);
    notifier.setFreeChordRoot(7);
    notifier.setFreeChordType('min');
    notifier.setFreeChordFourth('dom7');
    notifier.updateMeasureBeat(0, 1, 'Do');
    notifier.updateMeasureBeat(2, 0, 'La');
    notifier.toggleBeatMark(0, 0);
    notifier.toggleBeatMark(2, 3);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('select_all_beats_btn')), findsOneWidget);
    expect(container.read(accordionSimulatorProvider).markedBeats, {0, 11});
    await tester.tap(
      find.byKey(const ValueKey('multi_beat_assignment_mode_btn')),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).isMultiBeatAssignmentMode,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('beat_cell_0_0')));
    await tester.tap(find.byKey(const ValueKey('beat_cell_2_3')));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).multiBeatAssignmentTargets,
      {0, 11},
    );
    expect(container.read(accordionSimulatorProvider).markedBeats, {0, 11});

    await tester.tap(find.byKey(const ValueKey('beat_cell_0_0')));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).multiBeatAssignmentTargets,
      {11},
    );
    await tester.tap(find.byKey(const ValueKey('beat_cell_0_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('insert_chord_to_compas_btn')));
    await tester.pumpAndSettle();

    final state = container.read(accordionSimulatorProvider);
    expect(state.isMultiBeatAssignmentMode, isFalse);
    expect(state.multiBeatAssignmentTargets, isEmpty);
    expect(state.markedBeats, {0, 11});
    expect(state.measures[0].beats[0].chord, 'Solm7');
    expect(state.measures[2].beats[3].chord, 'Solm7');
    expect(state.measures[0].beats[1].chord, 'Do');
    expect(state.measures[2].beats[0].chord, 'La');
  });

  testWidgets(
    'el título de Compás iguala el tamaño de Acorde y no lleva icono',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: FreeChordWidget()),
                  MeasureGridWidget(width: 400),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chordTitle = tester.widget<Text>(
        find.byKey(const ValueKey('free_chord_title')),
      );
      final measureTitle = tester.widget<Text>(
        find.byKey(const ValueKey('compas_title_1')),
      );
      expect(measureTitle.style?.fontSize, chordTitle.style?.fontSize);
      expect(measureTitle.style?.fontWeight, chordTitle.style?.fontWeight);
      expect(measureTitle.style?.color, chordTitle.style?.color);
      final titleRow = tester.widget<Row>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('compas_title_1')),
              matching: find.byType(Row),
            )
            .first,
      );
      expect(titleRow.children.first, isA<Text>());
      expect(
        (titleRow.children.first as Text).key,
        const ValueKey('compas_title_1'),
      );
    },
  );

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

  testWidgets('el checkbox del Compás marca y desmarca tiempos', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MeasureGridWidget())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeasureGridWidget)),
    );

    expect(container.read(accordionSimulatorProvider).markedBeats, isEmpty);

    // Primer toque en checkbox del compás 0: marca sus 4 tiempos
    await tester.tap(find.byKey(const ValueKey('measure_checkbox_0')));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      containsAll(<int>[
        AccordionSimulatorNotifier.beatKey(0, 0),
        AccordionSimulatorNotifier.beatKey(0, 1),
        AccordionSimulatorNotifier.beatKey(0, 2),
        AccordionSimulatorNotifier.beatKey(0, 3),
      ]),
    );
    expect(
      container.read(accordionSimulatorProvider).markedBeats.length,
      equals(4),
    );

    // Marcar compás 1: marca sus 4 tiempos, sin afectar el compás 0
    await tester.tap(find.byKey(const ValueKey('measure_checkbox_1')));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      containsAll(<int>[
        AccordionSimulatorNotifier.beatKey(0, 0),
        AccordionSimulatorNotifier.beatKey(0, 3),
        AccordionSimulatorNotifier.beatKey(1, 0),
        AccordionSimulatorNotifier.beatKey(1, 2),
        AccordionSimulatorNotifier.beatKey(1, 3),
      ]),
    );
    expect(
      container.read(accordionSimulatorProvider).markedBeats.length,
      equals(8),
    );

    // Marcar no debe abrir la edición del acorde.
    final firstBeatField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(firstBeatField.focusNode?.hasFocus, isFalse);

    // Segundo toque en compás 0: desmarca sus 4 tiempos, el compás 1 permanece
    await tester.tap(find.byKey(const ValueKey('measure_checkbox_0')));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      isNot(contains(AccordionSimulatorNotifier.beatKey(0, 0))),
    );
    expect(
      container.read(accordionSimulatorProvider).markedBeats,
      contains(AccordionSimulatorNotifier.beatKey(1, 2)),
    );
    expect(
      container.read(accordionSimulatorProvider).markedBeats.length,
      equals(4),
    );
  });
}
