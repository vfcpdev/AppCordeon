import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_analyzer.dart';
import '../../core/audio/audio_file_loader_interface.dart';
import '../../core/audio/demo_track_generator.dart';
import '../../core/di/providers.dart';
import '../../domain/models/audio_analysis_models.dart';
import 'accordion_controller.dart'; // Para AudioLoadResult

class AudioAnalysisState {
  final AudioAnalysisReport? report;
  final bool isAnalyzing;
  final String? loadedFileName;

  const AudioAnalysisState({
    this.report,
    this.isAnalyzing = false,
    this.loadedFileName,
  });

  AudioAnalysisState copyWith({
    AudioAnalysisReport? report,
    bool? isAnalyzing,
    String? loadedFileName,
    bool clearReport = false,
  }) {
    return AudioAnalysisState(
      report: clearReport ? null : (report ?? this.report),
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      loadedFileName: clearReport ? null : (loadedFileName ?? this.loadedFileName),
    );
  }
}

class AudioAnalysisNotifier extends Notifier<AudioAnalysisState> {
  late AudioAnalyzer _analyzer;
  late AudioFileLoader _fileLoader;
  late DemoTrackGenerator _demoGenerator;

  @override
  AudioAnalysisState build() {
    _analyzer = ref.read(audioAnalyzerProvider);
    _fileLoader = ref.read(audioFileLoaderProvider);
    _demoGenerator = ref.read(demoTrackGeneratorProvider);
    return const AudioAnalysisState();
  }

  Future<AudioLoadResult> pickAndAnalyze() async {
    try {
      final picked = await _fileLoader.pickAudioFile();
      if (picked == null) return const AudioLoadCancelled();
      return await processBytes(picked.bytes, picked.name);
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      return AudioLoadFailure('Error al cargar audio: $e');
    }
  }

  Future<AudioLoadResult> loadDemo() async {
    try {
      return await processBytes(
        _demoGenerator.generate(),
        DemoTrackGenerator.demoFileName,
      );
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      return AudioLoadFailure('Error al procesar demo: $e');
    }
  }

  Future<AudioLoadResult> processBytes(Uint8List bytes, String fileName) async {
    state = state.copyWith(
      isAnalyzing: true,
      loadedFileName: fileName,
    );

    final report = await _analyzer.analyzeAudio(bytes, fileName);

    state = state.copyWith(
      isAnalyzing: false,
      report: report,
    );

    return AudioLoadSuccess(report, fileName);
  }

  void clear() {
    state = state.copyWith(clearReport: true);
  }
}

final audioAnalysisProvider =
    NotifierProvider<AudioAnalysisNotifier, AudioAnalysisState>(() {
  return AudioAnalysisNotifier();
});
