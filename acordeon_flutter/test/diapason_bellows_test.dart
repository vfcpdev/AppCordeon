import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/models/tuning.dart';
import 'package:acordeon_flutter/domain/theory/chord_catalog.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_button_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_widget.dart';

void main() {
  testWidgets('Abrir/Cerrar no ocultan botones; solo marcan los del acorde',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DiapasonWidget(
              currentTuning: TuningRegistry.defaultTunings[0],
              onTuningChanged: (_) {},
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
    final state = container.read(accordionSimulatorProvider);

    final allButtons = state.trebleData1.values.expand((row) => row).toList();
    final chordPitchClasses = ChordCatalog.notesFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
    ).map((n) => n % 12).toSet();

    // Ambos: todos los botones visibles.
    expect(find.byType(DiapasonButtonWidget), findsNWidgets(allButtons.length));

    // Abrir: siguen visibles todos; solo se marcan los del acorde.
    notifier.setBellows1(BellowsMode.pull);
    await tester.pumpAndSettle();
    expect(find.byType(DiapasonButtonWidget), findsNWidgets(allButtons.length));

    final pullWidgets =
        tester.widgetList<DiapasonButtonWidget>(find.byType(DiapasonButtonWidget));
    final pullChordButton = pullWidgets.firstWhere(
      (btn) => chordPitchClasses.contains(btn.pullMidi % 12),
    );
    final pullOtherButton = pullWidgets.firstWhere(
      (btn) => !chordPitchClasses.contains(btn.pullMidi % 12),
    );
    expect(pullChordButton.isChordPull, isTrue);
    expect(pullOtherButton.isChordPull, isFalse);

    // Cerrar: siguen visibles todos; solo se marcan los del acorde.
    notifier.setBellows1(BellowsMode.push);
    await tester.pumpAndSettle();
    expect(find.byType(DiapasonButtonWidget), findsNWidgets(allButtons.length));

    final pushWidgets =
        tester.widgetList<DiapasonButtonWidget>(find.byType(DiapasonButtonWidget));
    final pushChordButton = pushWidgets.firstWhere(
      (btn) => chordPitchClasses.contains(btn.pushMidi % 12),
    );
    final pushOtherButton = pushWidgets.firstWhere(
      (btn) => !chordPitchClasses.contains(btn.pushMidi % 12),
    );
    expect(pushChordButton.isChordPush, isTrue);
    expect(pushOtherButton.isChordPush, isFalse);
  });

  testWidgets('la etiqueta bajo la tonalidad usa la notación seleccionada',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DiapasonWidget(
              currentTuning: TuningRegistry.defaultTunings[0],
              onTuningChanged: (_) {},
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

    Text label() => tester.widget<Text>(
          find.byKey(const ValueKey('diapason_chord_label_1')),
        );

    // Latina por defecto: Do mayor con notas (Do - Mi - Sol).
    expect(label().textSpan?.toPlainText(), 'Do   Mayor   (Do - Mi - Sol)');

    final labelBox = tester.widget<Container>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('diapason_chord_label_1')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (labelBox.decoration as BoxDecoration).color,
      Colors.white,
    );

    notifier.setFreeChordType('dim');
    notifier.setFreeChordFourth('dim7');
    await tester.pumpAndSettle();
    expect(label().textSpan?.toPlainText(), 'Do   Disminuido   Séptima   (Do - Mi♭ - Fa# - La)');

    // Al cambiar a notación alemana cambia la tónica y las notas, no la cualidad.
    notifier.setNotation(NotationMode.alemana);
    await tester.pumpAndSettle();
    expect(label().textSpan?.toPlainText(), 'C   Disminuido   Séptima   (C - Eb - F# - A)');
  });

  testWidgets('el botón de tonalidad es funcional y abre el selector de afinación',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    TuningDefinition? selectedTuning;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DiapasonWidget(
              currentTuning: TuningRegistry.defaultTunings[0],
              onTuningChanged: (t) => selectedTuning = t,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El botón existe con la key asignada
    final tuningBtn = find.byKey(const ValueKey('diapason_tuning_btn_1'));
    expect(tuningBtn, findsOneWidget);

    // Al pulsarlo, se abre el diálogo de afinaciones
    await tester.tap(tuningBtn);
    await tester.pumpAndSettle();

    expect(find.text('Seleccionar acordeón'), findsOneWidget);

    // Seleccionamos otra afinación de la lista
    final secondTuning = TuningRegistry.defaultTunings[1];
    await tester.tap(find.text(secondTuning.name).first);
    await tester.pumpAndSettle();

    expect(selectedTuning, isNotNull);
    expect(selectedTuning?.id, secondTuning.id);
    // El diálogo permanece abierto para permitir probar o comparar afinaciones
    expect(find.text('Seleccionar acordeón'), findsOneWidget);
  });

  testWidgets('el diálogo de afinación permite ordenar por tono ascendente y restablecer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      TuningRegistry.resetToDefaultOrder();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DiapasonWidget(
              currentTuning: TuningRegistry.defaultTunings[0],
              onTuningChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abrir diálogo
    await tester.tap(find.byKey(const ValueKey('diapason_tuning_btn_1')));
    await tester.pumpAndSettle();

    expect(find.text('Tono ascendente'), findsOneWidget);
    // Verificamos que se expresen en tonos y semitonos (ej. Base, +1½ T)
    expect(find.text('Base'), findsOneWidget);
    expect(find.text('+1½ T'), findsOneWidget);

    // Pulsamos "Tono ascendente"
    await tester.tap(find.byKey(const ValueKey('btn_sort_pitch_asc')));
    await tester.pumpAndSettle();

    // Verificamos que Anisada (-7 -> -3½ T) ahora está presente
    expect(find.text('-3½ T'), findsOneWidget);

    // Verificamos que Anisada (-7) ahora está en primera posición
    expect(TuningRegistry.orderedTunings.first.id, 'anisada');
    expect(TuningRegistry.orderedTunings.last.id, 'lluvia');

    // Pulsamos "Restablecer"
    await tester.tap(find.byKey(const ValueKey('btn_reset_tuning_order')));
    await tester.pumpAndSettle();

    expect(TuningRegistry.orderedTunings.first.id, 'cinco_letras');
  });

  testWidgets(
      'Al dar play al acorde, solo se muestran presionados los botones según está el fuelle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DiapasonWidget(
              accordionNumber: 1,
              currentTuning: TuningRegistry.defaultTunings[0],
              onTuningChanged: (_) {},
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

    // 1. Cerrar (Push): solo los botones cuya nota push pertenece al acorde se muestran presionados
    notifier.setBellows1(BellowsMode.push);
    notifier.playFreeChord();
    await tester.pump();

    final pushButtons =
        tester.widgetList<DiapasonButtonWidget>(find.byType(DiapasonButtonWidget));
    final pressedInPush = pushButtons.where((btn) => btn.isPressed).toList();
    expect(pressedInPush, isNotEmpty);
    for (final btn in pressedInPush) {
      expect(btn.isChordPush, isTrue);
    }

    // Esperar a que se liberen los botones del acorde anterior
    await tester.pump(const Duration(milliseconds: 1000));

    // 2. Abrir (Pull): solo los botones cuya nota pull pertenece al acorde se muestran presionados
    notifier.setBellows1(BellowsMode.pull);
    notifier.playFreeChord();
    await tester.pump();

    final pullButtons =
        tester.widgetList<DiapasonButtonWidget>(find.byType(DiapasonButtonWidget));
    final pressedInPull = pullButtons.where((btn) => btn.isPressed).toList();
    expect(pressedInPull, isNotEmpty);
    for (final btn in pressedInPull) {
      expect(btn.isChordPull, isTrue);
    }

    // Esperar a que se liberen los botones del acorde anterior
    await tester.pump(const Duration(milliseconds: 1000));

    // 3. Arpegio: durante la reproducción del arpegio, los botones presionados corresponden al fuelle
    notifier.setBellows1(BellowsMode.push);
    notifier.arpeggioFreeChord();
    await tester.pump();

    final arpButtons =
        tester.widgetList<DiapasonButtonWidget>(find.byType(DiapasonButtonWidget));
    final pressedInArp = arpButtons.where((btn) => btn.isPressed).toList();
    expect(pressedInArp, isNotEmpty);
    for (final btn in pressedInArp) {
      expect(btn.isChordPush, isTrue);
    }

    // Limpieza de temporizadores de Future.delayed en el test
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
