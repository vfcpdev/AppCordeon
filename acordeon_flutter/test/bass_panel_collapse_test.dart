import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';

void main() {
  testWidgets(
    'el panel de bajos se pliega como etiqueta vertical y se restaura',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: BassPanelWidget())),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.byKey(const ValueKey('bass_panel_title_1')),
      );
      expect(title.data, 'Bajos');
      expect(title.style?.fontSize, 13);
      expect(title.style?.fontWeight, FontWeight.w900);
      expect(title.style?.color, const Color(0xFF059669));
      expect(find.byKey(const ValueKey('bass_panel_header_1')), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BassPanelWidget)),
      );
      await tester.tap(find.byKey(const ValueKey('bass_panel_collapse_btn_1')));
      await tester.pumpAndSettle();

      expect(
        container.read(accordionSimulatorProvider).isBass1Collapsed,
        isTrue,
      );
      expect(find.text('Bajos'), findsOneWidget);
      expect(
        tester
            .widget<RotatedBox>(
              find.descendant(
                of: find.byKey(const ValueKey('bass_panel_restore_btn_1')),
                matching: find.byType(RotatedBox),
              ),
            )
            .quarterTurns,
        3,
      );

      await tester.tap(find.byKey(const ValueKey('bass_panel_restore_btn_1')));
      await tester.pumpAndSettle();

      expect(
        container.read(accordionSimulatorProvider).isBass1Collapsed,
        isFalse,
      );
      expect(find.byKey(const ValueKey('bass_panel_header_1')), findsOneWidget);
    },
  );
}
