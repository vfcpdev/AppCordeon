import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  testWidgets('MeasureGrid arrow navigation: Arrow Right unfocuses, Arrow Left focuses, Arrow Down/Up navigates',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MeasureGridWidget(accordionNumber: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In MeasureGridWidget:
    // TextField.at(0) is the BPM input control in the header
    // TextField.at(1) is Beat 0_0
    // TextField.at(2) is Beat 0_1
    final firstBeatFinder = find.byType(TextField).at(1);
    expect(firstBeatFinder, findsOneWidget);

    // 1. Tap first beat -> enters edit mode
    await tester.tap(firstBeatFinder);
    await tester.pumpAndSettle();

    // Beat 0_0 is EditableText.at(1)
    final editableText1 = tester.widget<EditableText>(find.byType(EditableText).at(1));
    expect(editableText1.focusNode.hasFocus, isTrue, reason: 'TextField should have focus after tap');

    // 2. Press Arrow Right -> exits edit mode, but cell remains selected
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(editableText1.focusNode.hasFocus, isFalse, reason: 'TextField should lose edit focus after Arrow Right');

    // 3. Press Arrow Down -> moves to the next beat (cell 0_1)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // 4. Press Arrow Left -> enters edit mode for the newly selected beat (cell 0_1)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    final secondEditableText = tester.widget<EditableText>(find.byType(EditableText).at(2));
    expect(secondEditableText.focusNode.hasFocus, isTrue, reason: 'Second beat should have edit focus after Arrow Left');

    // 5. Press Arrow Right -> exits edit mode, keeping cell 0_1 selected
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(secondEditableText.focusNode.hasFocus, isFalse, reason: 'Second beat should lose edit focus after Arrow Right');

    // 6. Press Arrow Up -> moves back to first beat (cell 0_0)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    // 7. Press Arrow Left -> enters edit mode for first beat
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(editableText1.focusNode.hasFocus, isTrue, reason: 'First beat should regain edit focus after Arrow Up + Arrow Left');
  });

  testWidgets('MeasureGrid recognizes numbers 1-7 as C natural scale (Do, Re, Mi, Fa, Sol, La, Si) when cell is selected',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MeasureGridWidget(accordionNumber: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstBeatFinder = find.byType(TextField).at(1);

    // 1. Click first beat to edit, then Arrow Right to exit edit mode leaving it selected
    await tester.tap(firstBeatFinder);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // 2. Press 1 -> Should set to 'Do'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 3. Press 5 -> Should update to 'Sol'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pumpAndSettle();
    expect(find.text('Sol'), findsOneWidget);

    // 4. Press 4 -> Should update to 'Fa'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pumpAndSettle();
    expect(find.text('Fa'), findsOneWidget);

    // 5. Press 7 (numpad) -> Should update to 'Si'
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
    await tester.pumpAndSettle();
    expect(find.text('Si'), findsOneWidget);

    // 6. Press backspace -> Should clear chord
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('Si'), findsNothing);
  });
}
