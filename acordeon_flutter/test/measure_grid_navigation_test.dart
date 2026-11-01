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

  testWidgets('MeasureGrid leaves number keys without effect (numbers 1-7 do not trigger scale degrees)',
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

    // 2. Press 1 -> Should NOT set to 'Do' (numeric keys have no scale degree effect)
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsNothing);

    // 3. Press 5 -> Should NOT set to 'Sol'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pumpAndSettle();
    expect(find.text('Sol'), findsNothing);

    // 4. Press 7 (numpad) -> Should NOT set to 'Si'
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
    await tester.pumpAndSettle();
    expect(find.text('Si'), findsNothing);
  });

  testWidgets('Typing inside TextField writes chord directly without number translation (1 is not Do)',
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

    // 1. Tap to enter edit mode
    await tester.tap(firstBeatFinder);
    await tester.pumpAndSettle();

    // 2. Enter chord text directly
    await tester.enterText(firstBeatFinder, 'Sol7');
    await tester.pumpAndSettle();
    expect(find.text('Sol7'), findsOneWidget);

    // 3. Enter 'Do' directly
    await tester.enterText(firstBeatFinder, 'Do');
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);
  });

  testWidgets('MeasureGrid chord modifiers (.=Menor, /=7ma, +=Aumentada, -=Disminuida) in selection mode',
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

    // Enter chord 'Do' in first beat
    await tester.tap(firstBeatFinder);
    await tester.pumpAndSettle();
    await tester.enterText(firstBeatFinder, 'Do');
    await tester.pumpAndSettle();

    // Arrow Right to exit edit mode leaving it selected
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 1. Press '.' -> Menor ('Dom')
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(find.text('Dom'), findsOneWidget);

    // 2. Press '/' -> 7ma ('Dom7')
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.text('Dom7'), findsOneWidget);

    // 3. Numbers like '0', '8', '9' have no effect (numeric keys leave chord intact)
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(find.text('Dom7'), findsOneWidget);

    // 4. Press '/' -> Toggles 7th off ('Dom')
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.text('Dom'), findsOneWidget);

    // 5. Press '+' (numpad add) -> Aumentada ('Doaug')
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pumpAndSettle();
    expect(find.text('Doaug'), findsOneWidget);

    // 6. Press '-' -> Disminuida ('Dodim')
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pumpAndSettle();
    expect(find.text('Dodim'), findsOneWidget);
  });
}
