import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_rhythm_capture_dialog.dart';

class _SilentAudioEngine implements AudioEngine {
  @override
  Future<void> init({double sampleRate = 44100.0}) async {}

  @override
  void noteOn(int midiNote, {double velocity = 0.8}) {}

  @override
  void noteOff(int midiNote) {}

  @override
  void allNotesOff() {}

  @override
  void setVolume(double volume) {}

  @override
  void playPercussiveClick({bool isDownbeat = true, double volume = 0.8}) {}
}

void main() {
  group('BassColumnFilter State and Controller Unit Tests', () {
    test('el estado inicial tiene bassColumnFilter en all', () {
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(accordionSimulatorProvider);
      expect(state.bassColumnFilter, BassColumnFilter.all);
    });

    test('selectBassColumnFilter muta correctamente el filtro en el controller', () {
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
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
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BassPanelWidget(accordionNumber: 1),
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
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
      addTearDown(container.dispose);

      // Capturar 2 hits con avance de tiempo para tener un patrón activo de 2 golpes
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.startBassRhythmCapture(
        name: 'Patrón de Prueba Review',
        selectedButtons: const {7, 8, 4, 5},
      );
      notifier.captureBassMatrixHit(7);
      container.read(accordionSimulatorProvider).bassRhythmRecorder?.tick(ticks: 50);
      notifier.captureBassMatrixHit(4);
      final capturedPattern = notifier.stopBassRhythmCapture();
      expect(capturedPattern, isNotNull);
      expect(capturedPattern!.hits.length, 2);

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
      expect(find.byKey(const ValueKey('capture_review_play_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_review_stop_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_review_bpm_slider')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_review_scrubbing_slider')), findsOneWidget);

      // Verificar que los hits aparecen en el timeline
      final hit0Finder = find.byKey(const ValueKey('capture_timeline_hit_0'));
      final hit1Finder = find.byKey(const ValueKey('capture_timeline_hit_1'));
      expect(hit0Finder, findsOneWidget);
      expect(hit1Finder, findsOneWidget);

      // Seleccionar hit 0
      await tester.tap(hit0Finder);
      await tester.pumpAndSettle();

      // Verificar que existen los dos cuadros pequeños para Bajo Fundamental y Acorde Acompañante
      final fundBoxFinder = find.byKey(const ValueKey('capture_hit_box_fundamental'));
      final chordBoxFinder = find.byKey(const ValueKey('capture_hit_box_chord'));
      expect(fundBoxFinder, findsOneWidget);
      expect(chordBoxFinder, findsOneWidget);

      // Hit 0 actualmente tiene solo fundamental (pairedButtonIndex == null).
      // Al hacer tap en el cuadro de acorde acompañante, se debe activar la pareja (2 botones).
      await tester.tap(chordBoxFinder);
      await tester.pumpAndSettle();

      // Al activarse el par, se muestra "2 botones activos"
      expect(find.text('2 botones activos'), findsOneWidget);

      // Guardar cambios con el botón de aplicar
      final saveBtnFinder = find.byKey(const ValueKey('capture_review_save_btn'));
      expect(saveBtnFinder, findsOneWidget);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Verificar que el patrón en el notifier ahora tiene el hit 0 emparejado
      final updatedPattern = container.read(accordionSimulatorProvider).selectedBassRhythmPattern;
      expect(updatedPattern, isNotNull);
      expect(updatedPattern!.hits[0].pairedButtonIndex, isNotNull);
    });
  });
}
