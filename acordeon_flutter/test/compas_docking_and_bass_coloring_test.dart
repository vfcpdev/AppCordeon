import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/layout_constants.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/main.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/accordion_button_3d.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_button_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  test(
    'Hoare: {P casilla vacía} C seleccionar {Q constructor y diapasón limpios}',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.setFreeChordRoot(7);
      notifier.setFreeChordType('min');
      notifier.setFreeChordFourth('dom7');
      notifier.setFreeChordOctave('4');
      notifier.setFreeChordBass('3');
      notifier.setFreeChordScaleHarmonicMode('seventh');
      notifier.state = notifier.state.copyWith(
        freeChordMode: 'melodic',
        freeChordBellows: BellowsMode.pull,
        isFreeChordFixed: true,
        activeButtons: {'button-1'},
        playingChordNotes: {60},
        detectorMode: true,
        detectorSelectedButtons: ['button-2'],
      );

      notifier.selectBeat(0, 0);

      final state = container.read(accordionSimulatorProvider);
      expect(state.activeCompasChord, isEmpty);
      expect(state.freeChordRoot, -1);
      expect(state.freeChordType, isEmpty);
      expect(state.freeChordFourth, isEmpty);
      expect(state.freeChordOctave, isEmpty);
      expect(state.freeChordMode, isEmpty);
      expect(state.freeChordBass, isEmpty);
      expect(state.freeChordScaleHarmonicMode, isEmpty);
      expect(state.isFreeChordFixed, isFalse);
      expect(state.activeButtons, isEmpty);
      expect(state.playingChordNotes, isEmpty);
      expect(state.detectorMode, isFalse);
      expect(state.detectorSelectedButtons, isEmpty);
      expect(container.read(activeChordPitchClassesProvider(1)), isEmpty);
    },
  );

  test(
    'Hoare: {P casilla con Solm7/Si♭} C seleccionar {Q constructor sincronizado}',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Solm7/Si♭');
      notifier.selectBeat(0, 0);

      final state = container.read(accordionSimulatorProvider);
      expect(state.activeCompasChord, 'Solm7/Si♭');
      expect(state.freeChordRoot, 7);
      expect(state.freeChordType, 'min');
      expect(state.freeChordFourth, 'dom7');
      expect(state.freeChordBass, '3');
      expect(state.freeChordOctave, 'all');
      expect(state.freeChordScaleHarmonicMode, 'seventh');
      expect(container.read(activeChordPitchClassesProvider(1)), {2, 5, 7, 10});
    },
  );

  testWidgets(
    'Hoare: {P acorde y octava} C resaltado {Q todas y solo las posiciones coinciden}',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => DiapasonWidget(
                  currentTuning: ref.watch(
                    accordionSimulatorProvider.select((state) => state.tuning1),
                  ),
                  onTuningChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiapasonWidget)),
      );
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setFreeChordRoot(9);
      final chordPitchClasses = {9, 1, 4};
      expect(chordPitchClasses.length, 3);

      for (final octave in ['3', '4', '5']) {
        notifier.setFreeChordOctave(octave);
        await tester.pumpAndSettle();

        final buttons = tester
            .widgetList<DiapasonButtonWidget>(find.byType(DiapasonButtonWidget))
            .toList();
        for (final button in buttons) {
          final pushMatchesChord =
              chordPitchClasses.contains(button.pushMidi % 12) &&
              (button.pushMidi ~/ 12) - 1 == int.parse(octave);
          final pullMatchesChord =
              chordPitchClasses.contains(button.pullMidi % 12) &&
              (button.pullMidi ~/ 12) - 1 == int.parse(octave);

          expect(button.isChordPush, pushMatchesChord);
          expect(button.isChordPull, pullMatchesChord);
        }
      }
    },
  );

  testWidgets(
    'Acordeón 2 no muestra panel de bajos; solo Acordeón 1 lo tiene',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      // Solo debe haber 1 BassPanelWidget (para Acordeón 1)
      expect(find.byType(BassPanelWidget), findsOneWidget);
      final bassWidget = tester.widget<BassPanelWidget>(
        find.byType(BassPanelWidget),
      );
      expect(bassWidget.accordionNumber, 1);
    },
  );

  testWidgets(
    'Los botones de bajos solo se marcan para colorearse si coinciden con el acorde del diapasón',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BassPanelWidget)),
      );
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Seleccionamos Re Mayor (root: 2) para verificar la concordancia armónica con los bajos
      notifier.setFreeChordRoot(2); // Re
      await tester.pumpAndSettle();

      final st = container.read(accordionSimulatorProvider);
      final pcs = container.read(activeChordPitchClassesProvider(1));
      expect(st.freeChordRoot, equals(2));
      expect(pcs, isNotEmpty);
      final buttons3D = tester
          .widgetList<AccordionButton3D>(
            find.descendant(
              of: find.byType(BassPanelWidget),
              matching: find.byType(AccordionButton3D),
            ),
          )
          .toList();

      expect(buttons3D.isNotEmpty, isTrue);

      // Debe haber botones que coinciden y botones que no coinciden
      final matchingButtons = buttons3D
          .where((b) => b.isChordPull || b.isChordPush)
          .toList();
      final nonMatchingButtons = buttons3D
          .where((b) => !b.isChordPull && !b.isChordPush)
          .toList();

      expect(
        matchingButtons.isNotEmpty,
        isTrue,
        reason:
            'Los bajos cuyas notas pertenezcan al acorde deben tener isChordPull o isChordPush',
      );
      expect(
        nonMatchingButtons.isNotEmpty,
        isTrue,
        reason:
            'Los bajos cuyas notas NO pertenezcan al acorde no deben tener isChordPull ni isChordPush',
      );
    },
  );

  testWidgets('El cuadro de compás es acoplable, desacoplable y movible', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AcordeonApp)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);

    // Estado inicial: acoplado
    expect(
      container.read(accordionSimulatorProvider).isCompas1Undocked,
      isFalse,
    );

    // Desacoplar el compás 1
    notifier.toggleUndockCompas(1);
    await tester.pumpAndSettle();

    expect(
      container.read(accordionSimulatorProvider).isCompas1Undocked,
      isTrue,
    );
    expect(find.text('Compás (Móvil)'), findsOneWidget);
    expect(find.text('Compás flotante'), findsOneWidget);

    // Mover posición
    notifier.setCompasPosition(1, const Offset(300, 150));
    await tester.pumpAndSettle();
    expect(
      container.read(accordionSimulatorProvider).compas1Position,
      const Offset(300, 150),
    );

    // Volver a acoplar
    notifier.toggleUndockCompas(1);
    await tester.pumpAndSettle();

    expect(
      container.read(accordionSimulatorProvider).isCompas1Undocked,
      isFalse,
    );
    expect(find.text('Compás (Móvil)'), findsNothing);
  });

  testWidgets(
    'Acordeón 2 tiene cuadro de compás ampliado y todas las opciones',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      final grids = find.byType(MeasureGridWidget);
      expect(grids, findsNWidgets(2));

      // Ambos tienen el ancho ampliado un 5 %.
      expect(tester.getSize(grids.at(0)).width, CompasCardMetrics.gridWidth);
      expect(tester.getSize(grids.at(1)).width, CompasCardMetrics.gridWidth);

      // El título de Acordeón 2 dice 'Compás A2'
      expect(find.text('Compás A2'), findsOneWidget);
    },
  );

  testWidgets(
    'Al cambiar o avanzar el compás, la cuadrícula de compases actualiza la selección',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AcordeonApp)),
      );
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Cambiar compás a 2 (penúltimo compás visible)
      notifier.selectBeat(2, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(container.read(accordionSimulatorProvider).selectedBarIndex, 2);
    },
  );

  testWidgets(
    'Barra de canción: botones de reproducción horizontales, opciones agrupadas y desacople eficaz',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AcordeonApp)),
      );
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Cargar y analizar explícitamente la pista demo para activar la barra de la canción
      await notifier.loadDemoAudioTrack();
      await notifier.analyzeLoadedAudio();
      await tester.pumpAndSettle();

      // La barra de la canción debe estar visible
      expect(find.text('La Gota Fría - Demo Vallenato.wav'), findsOneWidget);

      // Botones de reproducción horizontales (Atrás, Play, Adelante, Detener) y Slider
      expect(find.byTooltip('Compás Anterior'), findsOneWidget);
      expect(find.byTooltip('Reproducir'), findsOneWidget);
      expect(find.byTooltip('Siguiente Compás'), findsOneWidget);
      expect(find.byTooltip('Detener'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('track_playback_slider')),
        findsOneWidget,
      );

      // Opciones agrupadas (Tono y Cargar Acordes, BPM removido a favor de la barra de Compás)
      expect(find.textContaining('Tono:'), findsOneWidget);
      expect(find.text('Cargar Acordes'), findsOneWidget);

      // Desacoplar la barra de la canción
      notifier.toggleUndockSongBar();
      await tester.pumpAndSettle();

      expect(
        container.read(accordionSimulatorProvider).isSongBarUndocked,
        isTrue,
      );
      expect(find.text('Barra de Canción (Móvil)'), findsOneWidget);
      expect(
        find.text('Barra de canción desacoplada (flotante)'),
        findsOneWidget,
      );

      // Volver a acoplar
      notifier.toggleUndockSongBar();
      await tester.pumpAndSettle();

      expect(
        container.read(accordionSimulatorProvider).isSongBarUndocked,
        isFalse,
      );
      expect(find.text('Barra de Canción (Móvil)'), findsNothing);
    },
  );

  testWidgets(
    'Garantiza que el acorde en el Compás se muestre en el Diapasón principal',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiapasonWidget).first),
      );
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // 1. Registramos un acorde en el Compás 1, Beat 0: "Sol7" y seleccionamos ese beat
      notifier.updateMeasureBeat(0, 0, 'Sol7');
      notifier.selectBeat(0, 0);
      await tester.pumpAndSettle();

      // Verificamos que activeCompasChord en el estado sea 'Sol7'
      expect(
        container.read(accordionSimulatorProvider).activeCompasChord,
        'Sol7',
      );

      // 2. Comprobamos la etiqueta flotante sobre el Diapasón Principal
      final labelFinder = find.byKey(const ValueKey('diapason_chord_label_1'));
      expect(labelFinder, findsOneWidget);
      final labelWidget = tester.widget<Text>(labelFinder);
      expect(
        labelWidget.textSpan?.toPlainText(),
        'Sol7   (Sol - Si - Re - Fa)',
      );

      // 3. Verificamos la poscondición del acorde Sol7.
      final activePcs = container.read(activeChordPitchClassesProvider(1));
      expect(activePcs, equals(<int>{7, 11, 2, 5}));

      // 4. Verificamos que los botones correspondientes a Sol7 en el Diapasón 1 estén coloreados/marcados
      final diapason1Buttons = tester
          .widgetList<DiapasonButtonWidget>(
            find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is DiapasonWidget && w.accordionNumber == 1,
              ),
              matching: find.byType(DiapasonButtonWidget),
            ),
          )
          .toList();

      expect(diapason1Buttons.isNotEmpty, isTrue);
      var highlightedSol7Positions = 0;
      for (final button in diapason1Buttons) {
        final pushMatchesChord = activePcs.contains(button.pushMidi % 12);
        final pullMatchesChord = activePcs.contains(button.pullMidi % 12);
        expect(button.isChordPush, pushMatchesChord);
        expect(button.isChordPull, pullMatchesChord);
        if (pushMatchesChord || pullMatchesChord) {
          highlightedSol7Positions++;
        }
      }
      expect(highlightedSol7Positions, greaterThan(activePcs.length));

      // 5. Verificamos que al cambiar la notación a alemana, la etiqueta del compás se actualice a G7
      notifier.setNotation(NotationMode.alemana);
      await tester.pumpAndSettle();

      final labelWidgetGerman = tester.widget<Text>(labelFinder);
      expect(labelWidgetGerman.textSpan?.toPlainText(), 'G7   (G - B - D - F)');

      // 6. Si se asigna dirección de fuelle 'Cierra' (push) al beat del compás, el fuelle del diapasón 1 se sincroniza
      notifier.setBeatBellows(0, 0, BellowsMode.push);
      await tester.pumpAndSettle();
      expect(
        container.read(accordionSimulatorProvider).bellows1,
        BellowsMode.push,
      );

      // Cada casilla es independiente: al seleccionar una vacía no se hereda
      // el acorde de la casilla anterior.
      notifier.selectBeat(0, 1);
      await tester.pumpAndSettle();
      expect(
        container.read(accordionSimulatorProvider).activeCompasChord,
        isEmpty,
      );
      expect(
        container.read(accordionSimulatorProvider).measures[0].beats[0].chord,
        'G7',
      );
    },
  );

  testWidgets('Los bajos diferencian coincidencia exacta y cercanía armónica', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BassPanelWidget)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);

    // Aseguramos que esté seleccionado Do Mayor (root: 0) en Cinco Letras:
    // Cierra (push) tiene Bajo 4 (Do) y Acorde 4 (Do Maj) como EXACTOS.
    // Tiene Bajo 2 (Sol / V) y Acorde 2 (Sol Maj / V) como CERCANOS.
    if (container.read(accordionSimulatorProvider).freeChordRoot != 0) {
      notifier.setFreeChordRoot(0);
    }
    notifier.setBellows1(BellowsMode.push);
    await tester.pumpAndSettle();

    final buttons3D = tester
        .widgetList<AccordionButton3D>(
          find.descendant(
            of: find.byType(BassPanelWidget),
            matching: find.byType(AccordionButton3D),
          ),
        )
        .toList();

    final exactButtons = buttons3D
        .where((b) => b.bassMatchPush == BassMatchType.exact)
        .toList();
    final closeButtons = buttons3D
        .where((b) => b.bassMatchPush == BassMatchType.close)
        .toList();
    final noneButtons = buttons3D
        .where((b) => b.bassMatchPush == BassMatchType.none)
        .toList();

    expect(
      exactButtons,
      isNotEmpty,
      reason: 'Debe haber bajos con coincidencia exacta (Do)',
    );
    expect(
      closeButtons,
      isNotEmpty,
      reason: 'Debe haber bajos por cercanía armónica (Sol / Fa)',
    );
    expect(
      noneButtons,
      isNotEmpty,
      reason: 'Debe haber bajos sin coincidencia armónica',
    );
  });

  testWidgets(
    'Al reproducir acorde o arpegio, los bajos acompañantes se muestran presionados según el fuelle',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AcordeonApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BassPanelWidget)),
      );
      final notifier = container.read(accordionSimulatorProvider.notifier);

      if (container.read(accordionSimulatorProvider).freeChordRoot != 0) {
        notifier.setFreeChordRoot(0); // Do
      }
      notifier.setBellows1(BellowsMode.push);
      notifier.playFreeChord();
      await tester.pump();

      final buttons3D = tester
          .widgetList<AccordionButton3D>(
            find.descendant(
              of: find.byType(BassPanelWidget),
              matching: find.byType(AccordionButton3D),
            ),
          )
          .toList();

      final pressedBasses = buttons3D.where((b) => b.isPressed).toList();
      expect(
        pressedBasses,
        isNotEmpty,
        reason: 'Los bajos acompañantes deben presionarse al dar play',
      );
      for (final btn in pressedBasses) {
        expect(
          btn.bassMatchPush.isMatch,
          isTrue,
          reason: 'Solo los bajos que acompañan en push deben presionarse',
        );
      }

      await tester.pump(const Duration(milliseconds: 1000));
    },
  );
}
