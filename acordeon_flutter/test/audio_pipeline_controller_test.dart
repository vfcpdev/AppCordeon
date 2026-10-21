import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/core/audio/audio_analyzer_service.dart';

void main() {
  group('Audio Loading & Analysis Controller Pipeline Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state has no audio report and is not analyzing', () {
      final state = container.read(accordionSimulatorProvider);
      expect(state.audioReport, isNull);
      expect(state.loadedAudioFileName, isNull);
      expect(state.isAnalyzingAudio, isFalse);
      expect(state.isPlayingAudio, isFalse);
    });

    test('processAudioBytes executes analysis, updates report, applies tuning and populates measures', () async {
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Generar bytes de prueba simulando audio
      final dummyAudio = Uint8List(44100 * 2 * 3); // 3 segundos
      for (int i = 0; i < dummyAudio.length; i++) {
        dummyAudio[i] = (i * 7) % 256;
      }

      await notifier.processAudioBytes(dummyAudio, 'test_song.mp3', null);

      final state = container.read(accordionSimulatorProvider);

      // 1. Verificar reporte de audio
      expect(state.isAnalyzingAudio, isFalse);
      expect(state.loadedAudioFileName, equals('test_song.mp3'));
      expect(state.audioReport, isNotNull);
      expect(state.audioReport!.duration, greaterThan(0));
      expect(state.audioReport!.bpm, inInclusiveRange(60, 220));

      // 2. Verificar afinación recomendada aplicada al Acordeón 1
      expect(state.tuning1.name, isNotEmpty);

      // 3. Verificar que los acordes detectados se trasladaron a la cuadrícula de compases
      expect(state.measures.isNotEmpty, isTrue);
      final hasAssignedChords = state.measures.any((m) => m.beats.any((b) => b.chord.isNotEmpty));
      expect(hasAssignedChords, isTrue, reason: 'Los compases deben contener los acordes detectados');

      // 4. Probar reproducción de transporte con compases
      notifier.togglePlayAudio();
      final playingState = container.read(accordionSimulatorProvider);
      expect(playingState.isPlayingAudio, isTrue);

      notifier.stopAudio();
      final stoppedState = container.read(accordionSimulatorProvider);
      expect(stoppedState.isPlayingAudio, isFalse);
      expect(stoppedState.currentAudioTime, equals(0.0));

      // 5. Probar limpieza de pista
      notifier.clearAudioReport();
      final clearedState = container.read(accordionSimulatorProvider);
      expect(clearedState.audioReport, isNull);
      expect(clearedState.loadedAudioFileName, isNull);
    });

    test('AudioAnalyzerService correctly identifies key signature and recommended accordion tuning', () async {
      final service = AudioAnalyzerService();
      final testAudio = Uint8List(44100 * 2 * 4); // 4 segundos
      for (int i = 0; i < testAudio.length; i++) {
        testAudio[i] = ((i % 128) * 2);
      }

      final report = await service.analyzeAudio(testAudio, 'vallenato_clasico.mp3');

      expect(report.mainKey.keyNameLat, isNotEmpty);
      expect(report.mainKey.recommendedTuning, isNotEmpty);
      expect(report.mainKey.correlation, greaterThan(0.0));
      expect(report.chords.length, greaterThan(0));
      expect(report.engine, contains('Rust'));
    });
  });
}
