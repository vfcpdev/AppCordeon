import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/audio/audio_analyzer.dart';
import 'package:acordeon_flutter/core/audio/audio_file_player_interface.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/core/audio/audio_analyzer_service.dart';
import 'package:acordeon_flutter/presentation/widgets/app_header_widget.dart';

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

    test('cargar audio no analiza hasta solicitarlo y luego aplica el reporte', () async {
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Generar bytes de prueba simulando audio
      final dummyAudio = Uint8List(44100 * 2 * 3); // 3 segundos
      for (int i = 0; i < dummyAudio.length; i++) {
        dummyAudio[i] = (i * 7) % 256;
      }

      final loadResult = notifier.loadAudioBytes(dummyAudio, 'test_song.mp3');
      expect(loadResult, isA<AudioLoadSuccess>());

      var state = container.read(accordionSimulatorProvider);

      // La carga prepara el reproductor, pero no genera análisis ni altera acordes.
      expect(state.isAnalyzingAudio, isFalse);
      expect(state.loadedAudioFileName, equals('test_song.mp3'));
      expect(state.audioReport, isNull);
      expect(state.measures.any((m) => m.beats.any((b) => b.chord.isNotEmpty)), isFalse);

      final analysisResult = await notifier.analyzeLoadedAudio();
      expect(analysisResult, isA<AudioAnalysisSuccess>());
      state = container.read(accordionSimulatorProvider);
      expect(state.isAnalyzingAudio, isFalse);
      expect(state.audioReport, isNotNull);
      expect(state.audioReport!.duration, greaterThan(0));
      expect(state.audioReport!.bpm, inInclusiveRange(60, 220));

      // 2. Verificar afinación recomendada aplicada al Acordeón 1
      expect(state.tuning1.name, isNotEmpty);

      // 3. Verificar que la cantidad de compases coincide con la duración del audio
      // y que los acordes inicialmente quedan vacíos hasta decisión del usuario.
      expect(state.measures.isNotEmpty, isTrue);
      final hasInitialChords = state.measures.any((m) => m.beats.any((b) => b.chord.isNotEmpty));
      expect(hasInitialChords, isFalse, reason: 'Los acordes no se cargan automáticamente sin decisión posterior');

      // Aplicar acordes por decisión posterior
      notifier.applyChordsToMeasures(state.audioReport!.chords);
      final stateWithChords = container.read(accordionSimulatorProvider);
      final hasAssignedChords = stateWithChords.measures.any((m) => m.beats.any((b) => b.chord.isNotEmpty));
      expect(hasAssignedChords, isTrue, reason: 'Al solicitarlo, los compases se pueblan con los acordes');

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

    testWidgets('el botón Analizar inicia el análisis de la pista cargada',
        (WidgetTester tester) async {
      final analyzer = _CountingAudioAnalyzer();
      final player = _TestAudioFilePlayer();
      final widgetContainer = ProviderContainer(
        overrides: [
          audioAnalyzerProvider.overrideWithValue(analyzer),
          audioFilePlayerProvider.overrideWithValue(player),
        ],
      );
      addTearDown(widgetContainer.dispose);

      final notifier = widgetContainer.read(accordionSimulatorProvider.notifier);
      expect(
        notifier.loadAudioBytes(Uint8List.fromList([1, 2, 3]), 'test.wav'),
        isA<AudioLoadSuccess>(),
      );
      expect(analyzer.calls, 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: widgetContainer,
          child: const MaterialApp(
            home: Scaffold(body: AppHeaderWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analyzeButton = find.byKey(const ValueKey('analyze_loaded_audio_btn'));
      expect(analyzeButton, findsOneWidget);
      await tester.tap(analyzeButton);
      await tester.pumpAndSettle();

      expect(analyzer.calls, 1);
      expect(widgetContainer.read(accordionSimulatorProvider).audioReport, isNotNull);
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

class _CountingAudioAnalyzer implements AudioAnalyzer {
  int calls = 0;

  @override
  Future<AudioAnalysisReport> analyzeAudio(Uint8List bytes, String fileName) async {
    calls++;
    return const AudioAnalysisReport(
      duration: 6,
      bpm: 120,
      mainKey: KeyDetectionResult(
        rootMod: 0,
        mode: 'major',
        keyNameLat: 'Do Mayor',
        keyNameAle: 'C Major',
        recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
        recommendedOffset: 0,
        recommendedRow: 'row1',
        correlation: 0.9,
      ),
      chords: [],
    );
  }
}

class _TestAudioFilePlayer implements AudioFilePlayer {
  bool _isLoaded = false;

  @override
  double get durationSeconds => 6;

  @override
  bool get isLoaded => _isLoaded;

  @override
  double get positionSeconds => 0;

  @override
  void load(Uint8List bytes, String mimeType) {
    _isLoaded = true;
  }

  @override
  void pause() {}

  @override
  void play() {}

  @override
  void seek(double seconds) {}

  @override
  void setVolume(double volume) {}

  @override
  void stop() {
    _isLoaded = false;
  }
}
