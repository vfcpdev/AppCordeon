import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/main.dart';

void main() {
  testWidgets('AcordeonApp renders home screen with diapasón and controls',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: AcordeonApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify app title exists
    expect(find.text('Acordeón Diatónico Pro'), findsOneWidget);
    // Verify treble rows exist (Afuera, Medio, Adentro)
    expect(find.textContaining('Afuera'), findsWidgets);
    expect(find.textContaining('Medio'), findsWidgets);
    expect(find.textContaining('Adentro'), findsWidgets);
    // Verify bass headers exist
    expect(find.text('Exterior'), findsWidgets);
    expect(find.text('Interior'), findsWidgets);
  });
}
