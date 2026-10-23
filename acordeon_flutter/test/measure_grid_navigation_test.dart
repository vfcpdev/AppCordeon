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

  testWidgets('Typing numbers 1-7 while in active TextField edit mode writes C scale notes (1=Do, 2=Re, 5+7=Sol7)',
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

    // 2. Type '1' while editing -> should write 'Do'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 3. Type '2' -> should replace with 'Re'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.text('Re'), findsOneWidget);

    // 4. Type '5' -> should replace with 'Sol'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pumpAndSettle();
    expect(find.text('Sol'), findsOneWidget);

    // 5. Type '7' after 'Sol' -> should append to 'Sol7'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.pumpAndSettle();
    expect(find.text('Sol7'), findsOneWidget);
  });

  testWidgets('MeasureGrid chord modifiers (0=Mayor, .=Menor, /=7ma, +=Aumentada, -=Disminuida, 8=Sus, 9=Cuarta) in selection mode',
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

    // Tap first beat, then Arrow Right to exit edit mode leaving it selected
    await tester.tap(firstBeatFinder);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // 1. Press 1 -> 'Do'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 2. Press '.' -> Menor ('Dom')
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(find.text('Dom'), findsOneWidget);

    // 3. Press '/' -> 7ma ('Dom7')
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.text('Dom7'), findsOneWidget);

    // 4. Press '0' -> Mayor (clears minor, leaves 'Do7')
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(find.text('Do7'), findsOneWidget);

    // 5. Press '/' -> Toggles 7th off ('Do')
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 6. Press '+' (numpad add) -> Aumentada ('Doaug')
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pumpAndSettle();
    expect(find.text('Doaug'), findsOneWidget);

    // 7. Press '-' -> Disminuida ('Dodim')
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pumpAndSettle();
    expect(find.text('Dodim'), findsOneWidget);

    // 8. Press '8' -> Sus ('Dosus')
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.pumpAndSettle();
    expect(find.text('Dosus'), findsOneWidget);

    // 9. Press '9' -> Cuarta ('Dosus4')
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pumpAndSettle();
    expect(find.text('Dosus4'), findsOneWidget);

    // 10. Press '0' -> Mayor ('Do')
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);
  });

  testWidgets('MeasureGrid chord modifiers in active TextField edit mode',
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
    await tester.tap(firstBeatFinder);
    await tester.pumpAndSettle();

    // 1. Type '1' -> 'Do'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 2. Type '.' -> 'Dom'
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(find.text('Dom'), findsOneWidget);

    // 3. Type '/' -> 'Dom7'
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.text('Dom7'), findsOneWidget);

    // 4. Type '0' -> 'Do7'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(find.text('Do7'), findsOneWidget);

    // 5. Type '/' -> 'Do'
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);

    // 6. Type '+' (numpad add) -> 'Doaug'
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pumpAndSettle();
    expect(find.text('Doaug'), findsOneWidget);

    // 7. Type '-' -> 'Dodim'
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pumpAndSettle();
    expect(find.text('Dodim'), findsOneWidget);

    // 8. Type '8' -> 'Dosus'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.pumpAndSettle();
    expect(find.text('Dosus'), findsOneWidget);

    // 9. Type '9' -> 'Dosus4'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pumpAndSettle();
    expect(find.text('Dosus4'), findsOneWidget);

    // 10. Type '0' -> 'Do'
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pumpAndSettle();
    expect(find.text('Do'), findsOneWidget);
  });
}
