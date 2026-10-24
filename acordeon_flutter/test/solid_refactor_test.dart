import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/audio/audio_analyzer.dart';
import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/audio/audio_file_loader_interface.dart';
import 'package:acordeon_flutter/core/audio/audio_file_player_interface.dart';
import 'package:acordeon_flutter/core/audio/demo_track_generator.dart';
import 'package:acordeon_flutter/core/audio/file_picker_audio_loader.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/domain/models/tuning.dart';
import 'package:acordeon_flutter/domain/theory/chord_catalog.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/core/audio/audio_analyzer_service.dart';

class FakeAudioEngine implements AudioEngine {
  final List<String> calls = [];
  @override
  Future<void> init({double sampleRate = 44100.0}) async => calls.add('init');
  @override
  void noteOn(int midiNote, {double velocity = 0.8}) => calls.add('on:$midiNote');
  @override
  void noteOff(int midiNote) => calls.add('off:$midiNote');
  @override
  void allNotesOff() => calls.add('allOff');
  @override
  void setVolume(double volume) => calls.add('vol:$volume');
}

class FakeLoader implements AudioFileLoader {
  final PickedAudioData? result;
  int calls = 0;
  FakeLoader(this.result);
  @override
  Future<PickedAudioData?> pickAudioFile() async {
    calls++;
    return result;
  }
}

class ThrowingAnalyzer implements AudioAnalyzer {
  @override
  Future<AudioAnalysisReport> analyzeAudio(Uint8List bytes, String fileName) =>
      throw StateError('boom');
}

class FakeAudioFilePlayer implements AudioFilePlayer {
  final List<String> calls = [];
  bool loaded = false;
  double position = 0;
  double duration = 10;

  @override
  bool get isLoaded => loaded;

  @override
  double get positionSeconds => position;

  @override
  double get durationSeconds => duration;

  @override
  void load(Uint8List bytes, String mimeType) {
    loaded = true;
    calls.add('load:${bytes.length}:$mimeType');
  }

  @override
  void play() => calls.add('play');

  @override
  void pause() => calls.add('pause');

  @override
  void stop() => calls.add('stop');

  @override
  void seek(double seconds) {
    position = seconds;
    calls.add('seek:$seconds');
  }

  @override
  void setVolume(double volume) => calls.add('vol:$volume');
}

void main() {
  late FakeAudioEngine engine;

  ProviderContainer makeContainer({
    AudioFileLoader? loader,
    AudioAnalyzer? analyzer,
    AudioFilePlayer? player,
  }) {
    engine = FakeAudioEngine();
    return ProviderContainer(overrides: [
      audioEngineProvider.overrideWithValue(engine),
      if (loader != null) audioFileLoaderProvider.overrideWithValue(loader),
      if (analyzer != null) audioAnalyzerProvider.overrideWithValue(analyzer),
      if (player != null) audioFilePlayerProvider.overrideWithValue(player),
    ]);
  }

  group('ChordCatalog (O/C: tabla de intervalos)', () {
    test('tríadas y extensiones producen las mismas notas que el switch original', () {
      expect(ChordCatalog.notesFor(root: 0, type: 'maj', extension: 'none'), [60, 64, 67]);
      expect(ChordCatalog.notesFor(root: 0, type: 'min', extension: 'none'), [60, 63, 67]);
      expect(ChordCatalog.notesFor(root: 0, type: 'dim', extension: 'none'), [60, 63, 66]);
      expect(ChordCatalog.notesFor(root: 0, type: 'aug', extension: 'none'), [60, 64, 68]);
      expect(ChordCatalog.notesFor(root: 0, type: 'sus4', extension: 'none'), [60, 65, 67]);
      expect(ChordCatalog.notesFor(root: 2, type: 'maj', extension: 'dom7'), [62, 66, 69, 72]);
      expect(ChordCatalog.notesFor(root: 0, type: 'maj', extension: 'octave').last, 72);
      expect(ChordCatalog.notesFor(root: 0, type: 'maj', extension: 'maj7').last, 71);
      expect(ChordCatalog.notesFor(root: 0, type: 'maj', extension: 'maj6').last, 69);
      expect(ChordCatalog.notesFor(root: 0, type: 'maj', extension: 'add9').last, 74);
      expect(ChordCatalog.notesFor(root: 0, type: '???', extension: 'none'), [60, 64, 67]);
    });
  });

  group('Inyección de dependencias (DIP)', () {
    test('el controlador usa el AudioEngine inyectado', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);
      n.pressButton('b1', 64);
      n.releaseButton('b1', 64);
      expect(engine.calls, containsAllInOrder(['on:64', 'off:64']));
    });

    test('playFreeChord envía las notas del catálogo al motor', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);
      n.setFreeChordType('min');
      n.playFreeChord();
      expect(engine.calls, containsAll(['on:60', 'on:63', 'on:67']));
    });

    test('pickAndAnalyzeAudio devuelve Cancelled si el loader no devuelve archivo', () async {
      final loader = FakeLoader(null);
      final c = makeContainer(loader: loader);
      addTearDown(c.dispose);
      final r = await c.read(accordionSimulatorProvider.notifier).pickAndAnalyzeAudio();
      expect(r, isA<AudioLoadCancelled>());
      expect(loader.calls, 1);
      expect(c.read(accordionSimulatorProvider).audioReport, isNull);
    });

    test('pickAndAnalyzeAudio analiza el archivo devuelto y retorna Success', () async {
      final bytes = const DemoTrackGenerator().generate();
      final c = makeContainer(loader: FakeLoader(PickedAudioData(name: 'x.wav', bytes: bytes)));
      addTearDown(c.dispose);
      final r = await c.read(accordionSimulatorProvider.notifier).pickAndAnalyzeAudio();
      expect(r, isA<AudioLoadSuccess>());
      expect(c.read(accordionSimulatorProvider).loadedAudioFileName, 'x.wav');
    });

    test('un fallo del analizador se traduce en Failure sin dejar isAnalyzing colgado', () async {
      final c = makeContainer(
        loader: FakeLoader(PickedAudioData(name: 'x.mp3', bytes: Uint8List(10))),
        analyzer: ThrowingAnalyzer(),
      );
      addTearDown(c.dispose);
      final r = await c.read(accordionSimulatorProvider.notifier).pickAndAnalyzeAudio();
      expect(r, isA<AudioLoadFailure>());
      expect(c.read(accordionSimulatorProvider).isAnalyzingAudio, isFalse);
    });

    test('el archivo se entrega al reproductor aunque el análisis falle', () async {
      final player = FakeAudioFilePlayer();
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final c = makeContainer(
        loader: FakeLoader(PickedAudioData(name: 'cancion.mp3', bytes: bytes)),
        analyzer: ThrowingAnalyzer(),
        player: player,
      );
      addTearDown(c.dispose);
      final r = await c.read(accordionSimulatorProvider.notifier).pickAndAnalyzeAudio();
      expect(r, isA<AudioLoadFailure>());
      expect(player.loaded, isTrue);
      expect(player.calls, contains('load:4:audio/mpeg'));
    });

    test('play, pausa y stop delegan en el reproductor del archivo', () async {
      final player = FakeAudioFilePlayer();
      final c = makeContainer(
        loader: FakeLoader(PickedAudioData(
          name: 'demo.wav',
          bytes: const DemoTrackGenerator().generate(),
        )),
        player: player,
      );
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);

      final r = await n.pickAndAnalyzeAudio();
      expect(r, isA<AudioLoadSuccess>());
      expect(player.loaded, isTrue);

      n.togglePlayAudio();
      expect(player.calls, contains('play'));

      n.togglePlayAudio();
      expect(player.calls, contains('pause'));

      n.togglePlayAudio();
      n.stopAudio();
      expect(player.calls, contains('stop'));
    });

    test('FallbackAudioLoader prueba los cargadores en orden', () async {
      final a = FakeLoader(null);
      final b = FakeLoader(PickedAudioData(name: 'b', bytes: Uint8List(1)));
      final picked = await FallbackAudioLoader([a, b]).pickAudioFile();
      expect(picked?.name, 'b');
      expect(a.calls, 1);
      expect(b.calls, 1);
    });
  });

  group('Golden: pista demo', () {
    test('el informe de la demo es estable tras el refactor', () async {
      final report = await AudioAnalyzerService()
          .analyzeAudio(const DemoTrackGenerator().generate(), DemoTrackGenerator.demoFileName);
      expect(report.duration, closeTo(4.0, 0.1));
      expect(report.chords, isNotEmpty);
      expect(report.mainKey.keyNameLat, isNotEmpty);
    });
  });

  group('Caracterización: diapasones y cuadrícula', () {
    test('volumen sincronizado y toggles de diapasón', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);
      n.setVolume1(0.5);
      var s = c.read(accordionSimulatorProvider);
      expect(s.volume1, 0.5);
      expect(s.volume2, 0.5);
      expect(engine.calls, contains('vol:0.5'));
      n.toggleSyncVolume();
      n.setVolume1(0.3);
      s = c.read(accordionSimulatorProvider);
      expect(s.volume2, 0.5);
      n.setBellows2(BellowsMode.push);
      n.toggleMirror1();
      n.setTuning2(TuningRegistry.defaultTunings[0]);
      s = c.read(accordionSimulatorProvider);
      expect(s.bellows2, BellowsMode.push);
      expect(s.mirror1, isTrue);
      expect(s.tuning2, TuningRegistry.defaultTunings[0]);
    });

    test('el volumen del Compás es independiente del volumen del diapasón', () async {
      final player = FakeAudioFilePlayer();
      final c = makeContainer(
        loader: FakeLoader(PickedAudioData(
          name: 'demo.wav',
          bytes: const DemoTrackGenerator().generate(),
        )),
        player: player,
      );
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);

      await n.pickAndAnalyzeAudio();
      expect(player.calls, contains('vol:0.8'));

      n.setCompasVolume(0.35);
      expect(c.read(accordionSimulatorProvider).compasVolume, 0.35);
      expect(player.calls, contains('vol:0.35'));

      player.calls.clear();
      n.setVolume1(0.5);
      expect(player.calls, isNot(contains('vol:0.5')));
    });

    test('acoplar/desacoplar decide si la pista manda en el transporte', () async {
      final player = FakeAudioFilePlayer();
      final c = makeContainer(
        loader: FakeLoader(PickedAudioData(
          name: 'demo.wav',
          bytes: const DemoTrackGenerator().generate(),
        )),
        player: player,
      );
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);

      await n.pickAndAnalyzeAudio();
      expect(c.read(accordionSimulatorProvider).isAudioCoupled, isTrue);

      // Desacoplado: la pista se pausa y el Compás sigue por su reloj.
      n.toggleAudioCoupling();
      expect(c.read(accordionSimulatorProvider).isAudioCoupled, isFalse);
      expect(player.calls, contains('pause'));

      // Reacoplado: la pista retoma en la posición del Compás.
      n.seekAudio(3.0);
      player.calls.clear();
      n.toggleAudioCoupling();
      expect(c.read(accordionSimulatorProvider).isAudioCoupled, isTrue);
      expect(player.calls, contains('seek:3.0'));

      // Reproduciendo, desacoplar pausa; reacoplar reanuda la pista.
      n.togglePlayAudio();
      expect(player.calls, contains('play'));
      player.calls.clear();
      n.toggleAudioCoupling();
      expect(player.calls, contains('pause'));
      player.calls.clear();
      n.toggleAudioCoupling();
      expect(player.calls.any((call) => call.startsWith('seek:')), isTrue);
      expect(player.calls, contains('play'));

      n.stopAudio();
    });

    test('edición de cuadrícula', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(accordionSimulatorProvider.notifier);
      expect(c.read(accordionSimulatorProvider).measures.length, 8);
      n.addMeasure();
      expect(c.read(accordionSimulatorProvider).measures.length, 9);
      n.updateMeasureBeat(1, 2, 'G7');
      expect(c.read(accordionSimulatorProvider).measures[1].beats[2].chord, 'G7');
      n.setBeatChord(2, 0, 'F');
      expect(c.read(accordionSimulatorProvider).measures[2].beats[0].chord, 'F');
      n.clearAllGridChords();
      final all = c.read(accordionSimulatorProvider).measures.expand((m) => m.beats);
      expect(all.every((b) => b.chord.isEmpty), isTrue);
    });
  });
}
