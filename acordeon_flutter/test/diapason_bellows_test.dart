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

    // Latina por defecto: Do mayor.
    expect(label().data, 'Do');
    expect(label().style?.color, Colors.black);

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
      const Color(0xFFF59E0B),
    );

    notifier.setFreeChordType('dim');
    notifier.setFreeChordFourth('dim7');
    await tester.pumpAndSettle();
    expect(label().data, 'Do°7');

    // Al cambiar a notación alemana cambia la tónica, no la cualidad.
    notifier.setNotation(NotationMode.alemana);
    await tester.pumpAndSettle();
    expect(label().data, 'C°7');
  });
}
