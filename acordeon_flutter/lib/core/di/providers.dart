import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_analyzer.dart';
import '../audio/audio_analyzer_service.dart';
import '../audio/audio_engine_bridge.dart';
import '../audio/audio_file_loader.dart';
import '../audio/audio_file_player.dart';
import '../audio/demo_track_generator.dart';
import '../audio/file_picker_audio_loader.dart';
import '../storage/file_storage.dart';

/// Composition root: único lugar donde se eligen implementaciones concretas.
/// En pruebas se sustituyen con `ProviderContainer(overrides: [...])`.

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AcordeonEngineBridge();
  engine.init();
  ref.onDispose(engine.allNotesOff);
  return engine;
});

final audioAnalyzerProvider =
    Provider<AudioAnalyzer>((_) => AudioAnalyzerService());

final audioFileLoaderProvider = Provider<AudioFileLoader>((_) {
  return FallbackAudioLoader([
    if (kIsWeb) createAudioFileLoader(),
    const FilePickerAudioLoader(),
  ]);
});

final demoTrackGeneratorProvider =
    Provider<DemoTrackGenerator>((_) => const DemoTrackGenerator());

/// Reproductor del archivo de audio cargado (independiente del sintetizador).
final audioFilePlayerProvider = Provider<AudioFilePlayer>((ref) {
  final player = createAudioFilePlayer();
  ref.onDispose(player.stop);
  return player;
});

final fileStorageProvider = Provider<FileStorageService>((_) {
  return createFileStorageService();
});
