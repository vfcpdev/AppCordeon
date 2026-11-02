import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/acordeon_engine_ffi.dart';
import '../audio/audio_analyzer.dart';
import '../audio/audio_analyzer_service.dart';
import '../audio/rust_audio_analyzer.dart';
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

final audioAnalyzerProvider = Provider<AudioAnalyzer>((ref) {
  // Ruta Rust-first: si la DLL del motor DSP está disponible se usa el
  // análisis nativo; si no, degrada automáticamente al pipeline Dart.
  //
  // {I} (exclusión de flutter_tester): el binario `flutter_tester` que corre
  // los tests sufre corrupción de heap (0xC0000374) en llamadas largas de
  // análisis vía FFI (detectado en la sonda FFI). En runtime real (flutter
  // run -d windows / dart CLI) la misma llamada funciona y devuelve JSON
  // válido, por lo que el guard sólo excluye el entorno de pruebas.
  final inFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';
  final engine = AcordeonEngineFFI.instance;
  if (!inFlutterTest && engine.analysisAvailable) {
    debugPrint('[DI] Análisis de audio vía Rust FFI');
    return RustAudioAnalyzer(engine: engine);
  }
  return AudioAnalyzerService();
});

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
