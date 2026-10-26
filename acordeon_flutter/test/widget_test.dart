import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/main.dart';
import 'package:acordeon_flutter/presentation/widgets/free_chord_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

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
    expect(find.text('AppCordeon'), findsOneWidget);
    // Verify the measure grid sections exist
    expect(find.textContaining('Compás'), findsWidgets);
    // Verify bass headers exist
    expect(find.text('Exterior'), findsWidgets);
    expect(find.text('Interior'), findsWidgets);

    // Verificar tamaños actuales de los widgets de compás y acordes
    final grids = find.byType(MeasureGridWidget);
    expect(grids, findsNWidgets(2));
    expect(tester.getSize(grids.first).width, 165.0);
    expect(tester.getSize(grids.last).width, 82.5);
    expect(tester.getSize(find.byType(FreeChordWidget)).width, 150.0);
  });
}
