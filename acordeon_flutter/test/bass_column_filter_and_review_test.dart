import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/bass_rhythm_pattern.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_rhythm_capture_dialog.dart';

void main() {
  group('BassColumnFilter State and Controller Unit Tests', () {
    test('el estado inicial tiene bassColumnFilter en all', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(accordionSimulatorProvider);
      expect(state.bassColumnFilter, BassColumnFilter.all);
    });

    test('selectBassColumnFilter muta correctamente el filtro en el controller', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(accordionSimulatorProvider.notifier);
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.all);

      notifier.selectBassColumnFilter(BassColumnFilter.externalOnly);
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.externalOnly);

      notifier.selectBassColumnFilter(BassColumnFilter.internalOnly);
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.internalOnly);

      notifier.selectBassColumnFilter(BassColumnFilter.all);
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.all);
    });
  });

  group('BassPanelWidget Column Filter UI Tests', () {
    testWidgets('renderiza el selector de hileras [Todos | Ext | Int] en acordeón 1', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BassPanelWidget(accordionIndex: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final allBtnFinder = find.byKey(const ValueKey('bass_column_filter_all_1'));
      final extBtnFinder = find.byKey(const ValueKey('bass_column_filter_externalOnly_1'));
      final intBtnFinder = find.byKey(const ValueKey('bass_column_filter_internalOnly_1'));

      expect(allBtnFinder, findsOneWidget);
      expect(extBtnFinder, findsOneWidget);
      expect(intBtnFinder, findsOneWidget);

      // Clic en 'Ext'
      await tester.tap(extBtnFinder);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.externalOnly);

      // Clic en 'Int'
      await tester.tap(intBtnFinder);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.internalOnly);

      // Clic en 'Todos'
      await tester.tap(allBtnFinder);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).bassColumnFilter, BassColumnFilter.all);
    });
  });

  group('BassRhythmCapturePanel Timeline, Review and 2-Button Pairing Tests', () {
    testWidgets('muestra línea de tiempo, scrubber y permite alternar 1 vs 2 botones', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final patternWithHits = BassRhythmPattern(
        id: 'test_pat_review',
        name: 'Patrón de Prueba Review',
        timeSignature: BassTimeSignature.fourFour,
        durationBeats: 4,
        hits: const [
          BassRhythmHit(
            buttonIndex: 7, // fundamental Fila 1 ext
            onsetQuarterBeats: 0.0,
            durationQuarterBeats: 1.0,
          ),
          BassRhythmHit(
            buttonIndex: 4, // acorde Fila 1 int
            pairedButtonIndex: 7, // ambos
            onsetQuarterBeats: 1.0,
            durationQuarterBeats: 1.0,
          ),
        ],
      );

      // Asignar el patrón al estado
      container.read(accordionSimulatorProvider.notifier).updateBassRhythmPattern(patternWithHits);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: BassRhythmCapturePanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe estar el botón para conmutar a audición y edición
      final reviewTabFinder = find.byKey(const ValueKey('capture_mode_review_tab'));
      expect(reviewTabFinder, findsOneWidget);

      await tester.tap(reviewTabFinder);
      await tester.pumpAndSettle();

      // Debe mostrar controles de transporte
      expect(find.byKey(const ValueKey('review_play_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('review_stop_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('review_bpm_slider')), findsOneWidget);
      expect(find.byKey(const ValueKey('review_timeline_scrubber')), findsOneWidget);

      // Verificar que los hits aparecen en el timeline
      final hit0Finder = find.byKey(const ValueKey('capture_timeline_hit_0'));
      final hit1Finder = find.byKey(const ValueKey('capture_timeline_hit_1'));
      expect(hit0Finder, findsOneWidget);
      expect(hit1Finder, findsOneWidget);

      // Seleccionar hit 0
      await tester.tap(hit0Finder);
      await tester.pumpAndSettle();

      // Verificar que existen los dos cuadros pequeños para Bajo Fundamental y Acorde Acompañante
      final fundBoxFinder = find.byKey(const ValueKey('hit_button_box_fundamental'));
      final chordBoxFinder = find.byKey(const ValueKey('hit_button_box_chord'));
      expect(fundBoxFinder, findsOneWidget);
      expect(chordBoxFinder, findsOneWidget);

      // Hit 0 actualmente tiene solo fundamental (pairedButtonIndex == null).
      // Al hacer tap en el cuadro de acorde acompañante, se debe activar la pareja (2 botones).
      await tester.tap(chordBoxFinder);
      await tester.pumpAndSettle();

      // Al activarse el par, se muestra "2 Botones" en el badge
      expect(find.text('2 Botones'), findsAtLeastNWidgets(1));

      // Guardar cambios con el botón de aplicar
      final saveBtnFinder = find.byKey(const ValueKey('save_reviewed_pattern_button'));
      expect(saveBtnFinder, findsOneWidget);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Verificar que el patrón en el notifier ahora tiene el hit 0 emparejado
      final updatedPattern = container.read(accordionSimulatorProvider).bassRhythmPattern;
      expect(updatedPattern.hits[0].pairedButtonIndex, isNotNull);
    });
  });
}
