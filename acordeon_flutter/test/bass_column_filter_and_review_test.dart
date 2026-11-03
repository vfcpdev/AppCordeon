import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_rhythm_capture_dialog.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

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

  group('Compas Bellows Undefined Synchronization Tests', () {
    test('celda sin definir fuelle (both) actualiza a doble flecha en diapasón', () {
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Ponemos el diapasón previamente en pull para comprobar el cambio
      notifier.setBellows1(BellowsMode.pull);
      expect(container.read(accordionSimulatorProvider).bellows1, BellowsMode.pull);

      // Celda 0, 0 tiene bellows en both por defecto
      notifier.selectBeat(0, 0);

      // Debe actualizar a BellowsMode.both (doble flecha)
      expect(container.read(accordionSimulatorProvider).bellows1, BellowsMode.both);
    });

    testWidgets('en cuadros sin definir si abre o cierra, ambas flechas de fuelle en compás están sin color', (tester) async {
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
      addTearDown(container.dispose);

      // Celda 0, 0 seleccionada en both
      container.read(accordionSimulatorProvider.notifier).selectBeat(0, 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MeasureGridWidget(accordionNumber: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Las flechas de fuelle en la barra de compás no deben tener color verde ni rojo
      final pullBtnFinder = find.byTooltip('Abre (Fuelle abriendo)');
      final pushBtnFinder = find.byTooltip('Cierra (Fuelle cerrando)');

      expect(pullBtnFinder, findsOneWidget);
      expect(pushBtnFinder, findsOneWidget);

      final pullContainer = tester.widget<Container>(
        find.descendant(of: pullBtnFinder, matching: find.byType(Container)).first,
      );
      final pushContainer = tester.widget<Container>(
        find.descendant(of: pushBtnFinder, matching: find.byType(Container)).first,
      );

      final pullDecor = pullContainer.decoration as BoxDecoration;
      final pushDecor = pushContainer.decoration as BoxDecoration;

      // Ambas deben tener color de fondo neutro Color(0xFFF1F5F9), no verde ni rojo
      expect(pullDecor.color, const Color(0xFFF1F5F9));
      expect(pushDecor.color, const Color(0xFFF1F5F9));
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

  group('BassRhythmCapturePanel Timeline, Review and Complete Hit Editing Tests', () {
    testWidgets('permite editar timing, duración, hilera, agregar y eliminar golpes', (tester) async {
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

      // Controles de transporte
      expect(find.byKey(const ValueKey('capture_review_play_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_review_stop_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_review_bpm_slider')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_review_scrubbing_slider')), findsOneWidget);

      // Controles de edición del golpe
      expect(find.byKey(const ValueKey('capture_hit_onset_minus_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_onset_plus_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_quantize_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_duration_025_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_duration_050_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_duration_100_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_row1_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_row2_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_hit_delete_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('capture_timeline_add_hit_btn')), findsOneWidget);

      // 1. Ajustar tiempo con +0.1q
      final initialOnsetText = find.byKey(const ValueKey('capture_hit_onset_text'));
      expect(initialOnsetText, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('capture_hit_onset_plus_btn')));
      await tester.pumpAndSettle();

      // 2. Cuantizar con Q 1/4
      await tester.tap(find.byKey(const ValueKey('capture_hit_quantize_btn')));
      await tester.pumpAndSettle();

      // 3. Ajustar duración a 1.0q
      await tester.tap(find.byKey(const ValueKey('capture_hit_duration_100_btn')));
      await tester.pumpAndSettle();

      // 4. Conmutar a Fila 2 (8/5)
      await tester.tap(find.byKey(const ValueKey('capture_hit_row2_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Botón 8'), findsOneWidget);

      // 5. Alternar botón de acorde acompañante para activar 2 botones
      final chordBoxFinder = find.byKey(const ValueKey('capture_hit_box_chord'));
      await tester.tap(chordBoxFinder);
      await tester.pumpAndSettle();
      expect(find.text('2 botones activos'), findsOneWidget);

      // 6. Añadir un nuevo golpe en cursor
      await tester.tap(find.byKey(const ValueKey('capture_timeline_add_hit_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('capture_timeline_hit_2')), findsOneWidget);

      // 7. Eliminar el golpe recién añadido
      await tester.tap(find.byKey(const ValueKey('capture_timeline_hit_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture_hit_delete_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('capture_timeline_hit_2')), findsNothing);

      // 8. Guardar patrón editado
      final saveBtnFinder = find.byKey(const ValueKey('capture_review_save_btn'));
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      final updatedPattern = container.read(accordionSimulatorProvider).selectedBassRhythmPattern;
      expect(updatedPattern, isNotNull);
      expect(updatedPattern!.hits.length, 2);
    });
  });
}
