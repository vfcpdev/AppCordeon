import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/main.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/accordion_button_3d.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_button_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  testWidgets('Acordeón 2 no muestra panel de bajos; solo Acordeón 1 lo tiene',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Solo debe haber 1 BassPanelWidget (para Acordeón 1)
    expect(find.byType(BassPanelWidget), findsOneWidget);
    final bassWidget = tester.widget<BassPanelWidget>(find.byType(BassPanelWidget));
    expect(bassWidget.accordionNumber, 1);
  });

  testWidgets('Los botones de bajos solo se marcan para colorearse si coinciden con el acorde del diapasón',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BassPanelWidget)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);

    // Seleccionamos Re Mayor (root: 2) para verificar la concordancia armónica con los bajos
    notifier.setFreeChordRoot(2); // Re
    await tester.pumpAndSettle();

    final buttons3D = tester.widgetList<AccordionButton3D>(
      find.descendant(
        of: find.byType(BassPanelWidget),
        matching: find.byType(AccordionButton3D),
      ),
    ).toList();

    expect(buttons3D.isNotEmpty, isTrue);

    // Debe haber botones que coinciden y botones que no coinciden
    final matchingButtons = buttons3D.where((b) => b.isChordPull || b.isChordPush).toList();
    final nonMatchingButtons = buttons3D.where((b) => !b.isChordPull && !b.isChordPush).toList();

    expect(matchingButtons.isNotEmpty, isTrue,
        reason: 'Los bajos cuyas notas pertenezcan al acorde deben tener isChordPull o isChordPush');
    expect(nonMatchingButtons.isNotEmpty, isTrue,
        reason: 'Los bajos cuyas notas NO pertenezcan al acorde no deben tener isChordPull ni isChordPush');
  });

  testWidgets('El cuadro de compás es acoplable, desacoplable y movible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AcordeonApp)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);

    // Estado inicial: acoplado
    expect(container.read(accordionSimulatorProvider).isCompas1Undocked, isFalse);

    // Desacoplar el compás 1
    notifier.toggleUndockCompas(1);
    await tester.pumpAndSettle();

    expect(container.read(accordionSimulatorProvider).isCompas1Undocked, isTrue);
    expect(find.text('Compás (Móvil)'), findsOneWidget);
    expect(find.text('Compás flotante'), findsOneWidget);

    // Mover posición
    notifier.setCompasPosition(1, const Offset(300, 150));
    await tester.pumpAndSettle();
    expect(container.read(accordionSimulatorProvider).compas1Position, const Offset(300, 150));

    // Volver a acoplar
    notifier.toggleUndockCompas(1);
    await tester.pumpAndSettle();

    expect(container.read(accordionSimulatorProvider).isCompas1Undocked, isFalse);
    expect(find.text('Compás (Móvil)'), findsNothing);
  });

  testWidgets('Acordeón 2 tiene cuadro de compás completo con 185px y todas las opciones',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
    await tester.pumpAndSettle();

    final grids = find.byType(MeasureGridWidget);
    expect(grids, findsNWidgets(2));

    // Ambos tienen 185 px
    expect(tester.getSize(grids.at(0)).width, 185.0);
    expect(tester.getSize(grids.at(1)).width, 185.0);

    // El título de Acordeón 2 dice 'Compás A2'
    expect(find.text('Compás A2'), findsOneWidget);
  });

  testWidgets('Al cambiar o avanzar el compás, la cuadrícula de compases actualiza la selección',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
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
  });

  testWidgets('Barra de canción: botones de reproducción horizontales, opciones agrupadas y desacople eficaz',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AcordeonApp)),
    );
    final notifier = container.read(accordionSimulatorProvider.notifier);

    // Cargar la pista demo para activar la barra de la canción
    await notifier.loadDemoAudioTrack();
    await tester.pumpAndSettle();

    // La barra de la canción debe estar visible
    expect(find.text('La Gota Fría - Demo Vallenato.wav'), findsOneWidget);

    // Botones de reproducción horizontales (Atrás, Play, Adelante, Detener)
    expect(find.byTooltip('Compás Anterior'), findsOneWidget);
    expect(find.byTooltip('Reproducir'), findsOneWidget);
    expect(find.byTooltip('Siguiente Compás'), findsOneWidget);
    expect(find.byTooltip('Detener'), findsOneWidget);

    // Opciones agrupadas (Tono, BPM, Cargar Acordes)
    expect(find.textContaining('Tono:'), findsOneWidget);
    expect(find.textContaining('BPM'), findsWidgets);
    expect(find.text('Cargar Acordes'), findsOneWidget);

    // Desacoplar la barra de la canción
    notifier.toggleUndockSongBar();
    await tester.pumpAndSettle();

    expect(container.read(accordionSimulatorProvider).isSongBarUndocked, isTrue);
    expect(find.text('Barra de Canción (Móvil)'), findsOneWidget);
    expect(find.text('Barra de canción desacoplada (flotante)'), findsOneWidget);

    // Volver a acoplar
    notifier.toggleUndockSongBar();
    await tester.pumpAndSettle();

    expect(container.read(accordionSimulatorProvider).isSongBarUndocked, isFalse);
    expect(find.text('Barra de Canción (Móvil)'), findsNothing);
  });

  testWidgets('Garantiza que el acorde en el Compás se muestre en el Diapasón principal',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
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
    expect(container.read(accordionSimulatorProvider).activeCompasChord, 'Sol7');

    // 2. Comprobamos la etiqueta flotante sobre el Diapasón Principal
    final labelFinder = find.byKey(const ValueKey('diapason_chord_label_1'));
    expect(labelFinder, findsOneWidget);
    final labelWidget = tester.widget<Text>(labelFinder);
    final labelText = labelWidget.textSpan?.toPlainText() ?? '';
    expect(labelText, contains('Sol7'));
    expect(labelText, contains('Sol'));
    expect(labelText, contains('Si'));
    expect(labelText, contains('Re'));
    expect(labelText, contains('Fa'));

    // 3. Comprobamos que activeChordPitchClassesProvider(1) contenga las clases de altura de Sol7 (7, 11, 2, 5)
    final activePcs = container.read(activeChordPitchClassesProvider(1));
    expect(activePcs, containsAll(<int>{7, 11, 2, 5}));

    // 4. Verificamos que los botones correspondientes a Sol7 en el Diapasón 1 estén coloreados/marcados
    final diapason1Buttons = tester.widgetList<DiapasonButtonWidget>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is DiapasonWidget && w.accordionNumber == 1,
        ),
        matching: find.byType(DiapasonButtonWidget),
      ),
    ).toList();

    expect(diapason1Buttons.isNotEmpty, isTrue);
    final sol7Buttons = diapason1Buttons.where(
      (btn) => activePcs.contains(btn.pullMidi % 12) || activePcs.contains(btn.pushMidi % 12),
    );
    expect(sol7Buttons.isNotEmpty, isTrue);
    for (final btn in sol7Buttons) {
      if (activePcs.contains(btn.pullMidi % 12)) {
        expect(btn.isChordPull, isTrue);
      }
      if (activePcs.contains(btn.pushMidi % 12)) {
        expect(btn.isChordPush, isTrue);
      }
    }

    // 5. Verificamos que al cambiar la notación a alemana, la etiqueta del compás se actualice a G7
    notifier.setNotation(NotationMode.alemana);
    await tester.pumpAndSettle();

    final labelWidgetGerman = tester.widget<Text>(labelFinder);
    final labelTextGerman = labelWidgetGerman.textSpan?.toPlainText() ?? '';
    expect(labelTextGerman, contains('G7'));
    expect(labelTextGerman, contains('G'));
    expect(labelTextGerman, contains('B'));
    expect(labelTextGerman, contains('D'));
    expect(labelTextGerman, contains('F'));

    // 6. Si se asigna dirección de fuelle 'Cierra' (push) al beat del compás, el fuelle del diapasón 1 se sincroniza
    notifier.setBeatBellows(0, 0, BellowsMode.push);
    await tester.pumpAndSettle();
    expect(container.read(accordionSimulatorProvider).bellows1, BellowsMode.push);
  });
}
