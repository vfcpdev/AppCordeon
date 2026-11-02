import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/audio/audio_file_loader_interface.dart';
import 'package:acordeon_flutter/core/audio/audio_file_player_interface.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/track_info_card_widget.dart';

/// Motor silencioso: las pruebas no requieren síntesis real.
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

/// Reproductor con duración resoluble manualmente.
///
/// Simula el comportamiento web: al cargar, `durationSeconds` todavía es 0 y
/// la duración real llega después por `loadedmetadata`.
class _HydratingAudioFilePlayer implements AudioFilePlayer {
  bool _loaded = false;
  double _position = 0;
  double _duration = 0;
  Completer<double> _durationCompleter = Completer<double>();
  int playCalls = 0;

  @override
  bool get isLoaded => _loaded;

  @override
  double get positionSeconds => _position;

  @override
  double get durationSeconds => _duration;

  @override
  Future<double> waitForDuration({
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (_duration > 0) return Future<double>.value(_duration);
    return _durationCompleter.future;
  }

  @override
  void load(Uint8List bytes, String mimeType) {
    _loaded = true;
    _duration = 0;
    _position = 0;
    _durationCompleter = Completer<double>();
  }

  /// Emula `loadedmetadata`: publica la duración real y despierta a los
  /// consumidores que esperaban en [waitForDuration].
  void publishDuration(double seconds) {
    _duration = seconds;
    if (!_durationCompleter.isCompleted) {
      _durationCompleter.complete(seconds);
    }
  }

  @override
  void play() {
    playCalls++;
  }

  @override
  void pause() {}

  @override
  void stop() {
    _loaded = false;
    _position = 0;
  }

  @override
  void seek(double seconds) {
    _position = seconds;
  }

  @override
  void setVolume(double volume) {}
}

/// Reproductor que nunca publica metadatos: el archivo no es decodificable.
class _UndecodableAudioFilePlayer implements AudioFilePlayer {
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  double get positionSeconds => 0;

  @override
  double get durationSeconds => 0;

  @override
  Future<double> waitForDuration({
    Duration timeout = const Duration(seconds: 10),
  }) async => 0;

  @override
  void load(Uint8List bytes, String mimeType) => _loaded = true;

  @override
  void play() {}

  @override
  void pause() {}

  @override
  void stop() => _loaded = false;

  @override
  void seek(double seconds) {}

  @override
  void setVolume(double volume) {}
}

/// Selector de archivos fijo para pruebas del flujo completo de carga.
class _StaticAudioFileLoader implements AudioFileLoader {
  final String fileName;

  _StaticAudioFileLoader({this.fileName = 'rota.mp3'});

  @override
  Future<PickedAudioData?> pickAudioFile() async =>
      PickedAudioData(name: fileName, bytes: Uint8List.fromList([9, 9, 9]));
}

void main() {  late ProviderContainer container;
  late _HydratingAudioFilePlayer player;

  setUp(() {
    player = _HydratingAudioFilePlayer();
    container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
        audioFilePlayerProvider.overrideWithValue(player),
      ],
    );
  });

  tearDown(() => container.dispose());

  AudioLoadResult loadTrack({
    String fileName = 'pista_larga.mp3',
  }) {
    return container
        .read(accordionSimulatorProvider.notifier)
        .loadAudioBytes(Uint8List.fromList([1, 2, 3, 4]), fileName);
  }

  group('Carga efectiva y duración completa', () {
    test('la pista se acepta aunque la duración aún no se conozca', () {
      final result = loadTrack();

      expect(result, isA<AudioLoadSuccess>());
      final state = container.read(accordionSimulatorProvider);
      expect(state.loadedAudioFileName, 'pista_larga.mp3');
      expect(state.totalAudioDuration, 0.0);
      expect(player.isLoaded, isTrue);
    });

    test('la duración se hidrata cuando el reproductor la publica', () async {
      loadTrack();

      player.publishDuration(95.4);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(accordionSimulatorProvider);
      expect(state.totalAudioDuration, closeTo(95.4, 0.001));
    });

    testWidgets('el slider y el contador muestran la duración completa',
        (tester) async {
      final notifier =
          container.read(accordionSimulatorProvider.notifier);
      loadTrack();
      notifier.state = notifier.state.copyWith(currentAudioTime: 12.0);
      player.publishDuration(95.4);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TrackInfoCardWidget()),
          ),
        ),
      );
      await tester.pump();

      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('track_playback_slider')),
      );
      expect(slider.min, 0.0);
      expect(slider.max, closeTo(95.4, 0.001));
      expect(slider.value, closeTo(12.0, 0.001));
      expect(find.text('00:12 / 01:35'), findsOneWidget);
    });

    test('cerrar la pista invalida la hidratación pendiente', () async {
      loadTrack(fileName: 'pista.mp3');
      final notifier =
          container.read(accordionSimulatorProvider.notifier);

      notifier.clearAudioReport();
      player.publishDuration(40.0);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(accordionSimulatorProvider);
      expect(state.loadedAudioFileName, isNull);
      expect(state.totalAudioDuration, 0.0);
    });

    test('una pista no decodificable se rechaza sin dejar pista fantasma',
        () async {
      final badContainer = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(_SilentAudioEngine()),
          audioFilePlayerProvider
              .overrideWithValue(_UndecodableAudioFilePlayer()),
          audioFileLoaderProvider
              .overrideWithValue(_StaticAudioFileLoader()),
        ],
      );
      addTearDown(badContainer.dispose);

      final result = await badContainer
          .read(accordionSimulatorProvider.notifier)
          .pickAndLoadAudio();

      expect(result, isA<AudioLoadFailure>());
      expect(
        badContainer.read(accordionSimulatorProvider).loadedAudioFileName,
        isNull,
      );
    });
  });

  group('Opciones de tono y BPM siempre disponibles', () {
    testWidgets('se muestran antes del análisis y el BPM se puede cambiar',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      loadTrack();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TrackInfoCardWidget()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('audio_not_analyzed_status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('audio_key_bpm_options')),
        findsOneWidget,
      );

      // Abrir el editor desde la opción de BPM.
      final bpmOption = find.byKey(const ValueKey('audio_bpm_option'));
      await tester.ensureVisible(bpmOption);
      await tester.pump();
      await tester.tap(bpmOption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final bpmField = find.byType(TextField);
      expect(bpmField, findsOneWidget);
      await tester.enterText(bpmField, '140');
      await tester.pump();

      await tester.tap(find.text('Guardar y Aplicar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = container.read(accordionSimulatorProvider);
      expect(state.audioReport, isNotNull);
      expect(state.audioReport!.bpm, 140);
      expect(find.text('BPM: 140'), findsOneWidget);
    });

    testWidgets('el tono se puede cambiar y los acordes se transponen',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier =
          container.read(accordionSimulatorProvider.notifier);
      loadTrack();
      notifier.setAudioReport(
        AudioAnalysisReport.placeholder(120).copyWith(
          duration: 95.4,
          chords: const [
            DetectedChordSegment(
              startTime: 0,
              endTime: 2,
              rootMod: 0,
              quality: 'maj',
              chordName: 'Do',
              chordSymbol: 'C',
              noteMods: [0, 4, 7],
              playbackMidis: [60, 64, 67],
              confidence: 0.9,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TrackInfoCardWidget()),
          ),
        ),
      );
      await tester.pump();

      final keyOption = find.byKey(const ValueKey('audio_key_option'));
      await tester.ensureVisible(keyOption);
      await tester.pump();
      await tester.tap(keyOption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Sol / G').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Guardar y Aplicar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final report =
          container.read(accordionSimulatorProvider).audioReport!;
      expect(report.mainKey.rootMod, 7);
      expect(report.mainKey.keyNameLat, 'Sol Mayor');
      expect(report.chords.single.rootMod, 7);
      expect(report.chords.single.chordSymbol, 'G');
      expect(report.duration, closeTo(95.4, 0.001));
    });
  });
}
