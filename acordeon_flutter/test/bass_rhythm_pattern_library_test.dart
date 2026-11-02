import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/bass_rhythm_pattern.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';

/// Motor de audio silencioso para pruebas de reproducción de patrones.
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
  group('Guardar patrón en la biblioteca', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
    });

    tearDown(() => container.dispose());

    BassRhythmPattern captureAndSave(
      ProviderContainer container, {
      String name = 'Patrón de prueba',
    }) {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.startBassRhythmCapture(
        name: name,
        selectedButtons: const {7, 8, 4, 5},
      );
      notifier.captureBassMatrixHit(7);
      final pattern = notifier.stopBassRhythmCapture();
      expect(pattern, isNotNull);
      return pattern!;
    }

    test('detener la captura agrega el patrón al inicio de la lista', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final before =
          container.read(accordionSimulatorProvider).bassRhythmPatterns.length;

      final pattern = captureAndSave(container);

      final state = container.read(accordionSimulatorProvider);
      expect(state.bassRhythmPatterns.length, before + 1);
      expect(state.bassRhythmPatterns.first.id, pattern.id);
      expect(state.bassRhythmPatterns.first.name, 'Patrón de prueba');
      expect(state.bassRhythmPatterns.first.hits, hasLength(1));
      expect(state.selectedBassRhythmPatternId, pattern.id);
      expect(state.isBassCaptureActive, isFalse);

      notifier.stopBassRhythm();
    });

    test('el patrón guardado se reproduce y se detiene', () {
      final pattern = captureAndSave(container);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.toggleBassRhythmPatternPlayback(pattern.id);
      var state = container.read(accordionSimulatorProvider);
      expect(state.selectedBassRhythmPatternId, pattern.id);
      expect(state.isBassMetronomeActive, isTrue);

      notifier.toggleBassRhythmPatternPlayback(pattern.id);
      state = container.read(accordionSimulatorProvider);
      expect(state.isBassMetronomeActive, isFalse);

      notifier.stopBassRhythm();
    });

    test('reproducir sin selección usa el primer patrón disponible', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final firstId =
          container.read(accordionSimulatorProvider).bassRhythmPatterns.first.id;

      notifier.selectBassRhythmPattern(null);
      notifier.toggleSelectedBassRhythmPlayback();

      final state = container.read(accordionSimulatorProvider);
      expect(state.selectedBassRhythmPatternId, firstId);
      expect(state.isBassMetronomeActive, isTrue);

      notifier.stopBassRhythm();
    });

    test('eliminar un patrón capturado lo quita de la lista', () {
      final pattern = captureAndSave(container);
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.toggleBassRhythmPatternPlayback(pattern.id);

      notifier.deleteBassRhythmPattern(pattern.id);

      final state = container.read(accordionSimulatorProvider);
      expect(
        state.bassRhythmPatterns.any((p) => p.id == pattern.id),
        isFalse,
      );
      expect(state.selectedBassRhythmPatternId, isNot(pattern.id));
      expect(state.isBassMetronomeActive, isFalse);

      notifier.stopBassRhythm();
    });

    test('no se pueden eliminar patrones integrados del catálogo', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final builtinId = container
          .read(accordionSimulatorProvider)
          .bassRhythmPatterns
          .firstWhere((p) => p.id.startsWith('builtin:'))
          .id;

      expect(
        () => notifier.deleteBassRhythmPattern(builtinId),
        throwsA(isA<PreconditionViolationException>()),
      );
    });
  });

  group('Biblioteca de patrones en el panel de bajos', () {
    testWidgets('muestra el patrón guardado y permite reproducirlo',
        (tester) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: BassPanelWidget())),
        ),
      );
      await tester.pumpAndSettle();

      final notifier =
          container.read(accordionSimulatorProvider.notifier);

      // Abrir el panel de captura y guardar un patrón.
      await tester.tap(
        find.byKey(const ValueKey('bass_rhythm_capture_btn_1')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('bass_capture_name_field')),
        'Paseo propio',
      );
      await tester.tap(
        find.byKey(const ValueKey('bass_capture_start_btn')),
      );
      await tester.pump();

      notifier.captureBassMatrixHit(7);
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('bass_capture_stop_btn')),
      );
      await tester.pump();

      final pattern =
          container.read(accordionSimulatorProvider).bassRhythmPatterns.first;
      expect(pattern.name, 'Paseo propio');

      // La biblioteca permanece visible y lista para reproducir.
      expect(
        find.byKey(ValueKey('bass_pattern_row_${pattern.id}')),
        findsOneWidget,
      );
      expect(find.text('Paseo propio'), findsWidgets);

      await tester.tap(
        find.byKey(ValueKey('bass_pattern_toggle_${pattern.id}')),
      );
      await tester.pump();

      var state = container.read(accordionSimulatorProvider);
      expect(state.isBassMetronomeActive, isTrue);
      expect(state.selectedBassRhythmPatternId, pattern.id);

      // Detener antes de terminar para no dejar timers pendientes.
      notifier.stopBassRhythm();
      await tester.pump();
      state = container.read(accordionSimulatorProvider);
      expect(state.isBassMetronomeActive, isFalse);
    });
  });
}
