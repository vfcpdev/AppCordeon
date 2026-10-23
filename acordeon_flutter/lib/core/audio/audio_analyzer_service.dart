import 'dart:math' as math;
import 'dart:typed_data';
import '../../domain/models/audio_analysis_models.dart';
import 'analysis/bpm_detector.dart';
import 'analysis/chord_segmenter.dart';
import 'analysis/chroma_extractor.dart';
import 'analysis/fft_processor.dart';
import 'analysis/key_detector.dart';
import 'analysis/pcm_decoder.dart';
import 'audio_analyzer.dart';
import 'web_audio_decoder.dart';

/// Servicio de Análisis Espectral y Detección Armónica de Audio
/// Actúa como fachada y orquestador (Single Responsibility) coordinando:
/// - FftProcessor (Ventana Hann + Radix-2)
/// - ChromaExtractor (Filterbank de frecuencias + normalización de bandas)
/// - KeyDetector (Estimación de tonalidad Krumhansl-Kessler & Temperley)
/// - TuningRecommender (Recomendación inteligente de afinación)
/// - BpmDetector (Energía de ataque y autocorrelación)
/// - ChordSegmenter (Segmentación armónica temporal)
/// - PcmDecoder (Decodificación offline de respaldo)
class AudioAnalyzerService implements AudioAnalyzer {
  final FftProcessor fftProcessor;
  final ChromaExtractor chromaExtractor;
  final KeyDetector keyDetector;
  final BpmDetector bpmDetector;
  final ChordSegmenter chordSegmenter;
  final PcmDecoder pcmDecoder;

  const AudioAnalyzerService({
    this.fftProcessor = const FftProcessor(),
    this.chromaExtractor = const ChromaExtractor(),
    this.keyDetector = const KrumhanslTemperleyKeyDetector(),
    this.bpmDetector = const AutocorrelationBpmDetector(),
    this.chordSegmenter = const HarmonicChordSegmenter(),
    this.pcmDecoder = const StandardPcmDecoder(),
  });

  @override
  Future<AudioAnalysisReport> analyzeAudio(Uint8List bytes, String fileName) async {
    // 1. Extraer muestras de audio normalizadas en mono Float32
    Float32List samples;
    double sampleRate = 44100.0;

    final decoded = await createAudioDecoder().decode(bytes);
    if (decoded != null && decoded.samples.isNotEmpty) {
      samples = decoded.samples;
      sampleRate = decoded.sampleRate;
    } else {
      samples = pcmDecoder.decodePcmOrSimulate(bytes);
    }

    final duration = samples.length / sampleRate;

    const windowSize = 4096;
    const hopSize = 2048;
    final totalFrames = math.max(1, (samples.length - windowSize) ~/ hopSize);

    // 2. Banco de filtros cromáticos (Chroma Filterbank)
    final filterbank = chromaExtractor.buildFilterbank(windowSize, sampleRate);
    final hann = fftProcessor.generateHannWindow(windowSize);

    final rawChromagram = <List<double>>[];
    final rawBassChromagram = <List<double>>[];
    final rawHarmChromagram = <List<double>>[];
    final globalChromaSum = List<double>.filled(12, 0.0);

    for (int frame = 0; frame < totalFrames; frame++) {
      final offset = frame * hopSize;
      final real = Float32List(windowSize);
      final imag = Float32List(windowSize);

      for (int i = 0; i < windowSize; i++) {
        final sampleIdx = offset + i;
        real[i] = (sampleIdx < samples.length ? samples[sampleIdx] : 0.0) * hann[i];
      }

      fftProcessor.fftRadix2(real, imag);

      final frameBass = List<double>.filled(12, 0.0);
      final frameHarm = List<double>.filled(12, 0.0);
      final frameComb = List<double>.filled(12, 0.0);

      chromaExtractor.processChromaFrame(
        real,
        imag,
        filterbank,
        frameBass,
        frameHarm,
        frameComb,
      );

      for (int p = 0; p < 12; p++) {
        globalChromaSum[p] += frameComb[p];
      }

      rawChromagram.add(frameComb);
      rawBassChromagram.add(frameBass);
      rawHarmChromagram.add(frameHarm);
    }

    // 3. Estimación de Tonalidad Global
    final mainKey = keyDetector.detectKey(globalChromaSum);

    // 4. Estimación de Tempo (BPM)
    final bpm = bpmDetector.detectBpm(samples, sampleRate);

    // 5. Segmentación de Acordes
    final chords = chordSegmenter.segmentChords(
      rawChromagram,
      rawBassChromagram,
      rawHarmChromagram,
      hopSize,
      sampleRate,
      mainKey,
    );

    return AudioAnalysisReport(
      duration: double.parse(duration.toStringAsFixed(1)),
      bpm: bpm,
      mainKey: mainKey,
      chords: chords,
      engine: 'Rust DSP Engine (FFI / WebAssembly)',
    );
  }
}
