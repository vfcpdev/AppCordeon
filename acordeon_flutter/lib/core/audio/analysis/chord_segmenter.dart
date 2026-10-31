import '../../../domain/models/audio_analysis_models.dart';

abstract class ChordSegmenter {
  List<DetectedChordSegment> segmentChords(
    List<List<double>> chromagram,
    List<List<double>> bassChromagram,
    List<List<double>> harmonyChromagram,
    int hopSize,
    double sampleRate,
    KeyDetectionResult mainKey,
  );
}

class ChordProfileModel {
  final String quality;
  final String symbol;
  final String name;
  final List<int> intervals;
  final List<int> penalties;

  const ChordProfileModel(this.quality, this.symbol, this.name, this.intervals, this.penalties);
}

/// Segmentador temporal de acordes con supresión de armónicos, ponderación de bajos
/// y cálculo armónico modal riguroso.
///
/// # Triplas de Hoare:
/// - {P}: `chromagram.isNotEmpty && hopSize > 0 && sampleRate > 0.0`.
/// - {Q}: Retorna una lista continua de `DetectedChordSegment` cubriendo la duración del audio,
///        con `noteMods` y `playbackMidis` calculados de acuerdo con la cualidad del acorde.
class HarmonicChordSegmenter implements ChordSegmenter {
  static const List<String> noteNamesLat = [
    'Do', 'Do♯', 'Re', 'Mi♭', 'Mi', 'Fa', 'Fa♯', 'Sol', 'Sol♯', 'La', 'Si♭', 'Si'
  ];
  static const List<String> noteNamesAle = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'
  ];

  static const List<ChordProfileModel> chordProfiles = [
    ChordProfileModel('maj', '', 'Mayor', [0, 4, 7], [1, 2, 3, 5, 6, 8, 9, 10, 11]),
    ChordProfileModel('min', 'm', 'Menor', [0, 3, 7], [1, 2, 4, 5, 6, 8, 9, 10, 11]),
    ChordProfileModel('dom7', '7', '7ma', [0, 4, 7, 10], [1, 2, 3, 5, 6, 8, 9, 11]),
    ChordProfileModel('min7', 'm7', 'Menor 7ma', [0, 3, 7, 10], [1, 2, 4, 5, 6, 8, 9, 11]),
    ChordProfileModel('sus4', 'sus4', 'Sus4', [0, 5, 7], [1, 2, 3, 4, 6, 8, 9, 10, 11]),
  ];

  const HarmonicChordSegmenter();

  List<int> _computeNoteMods(int root, String quality) {
    switch (quality) {
      case 'min':
        return [root, (root + 3) % 12, (root + 7) % 12];
      case 'dom7':
        return [root, (root + 4) % 12, (root + 7) % 12, (root + 10) % 12];
      case 'min7':
        return [root, (root + 3) % 12, (root + 7) % 12, (root + 10) % 12];
      case 'sus4':
        return [root, (root + 5) % 12, (root + 7) % 12];
      case 'maj':
      default:
        return [root, (root + 4) % 12, (root + 7) % 12];
    }
  }

  List<int> _computePlaybackMidis(int root, String quality) {
    final baseMidi = 48 + root;
    switch (quality) {
      case 'min':
        return [baseMidi, baseMidi + 3, baseMidi + 7];
      case 'dom7':
        return [baseMidi, baseMidi + 4, baseMidi + 7, baseMidi + 10];
      case 'min7':
        return [baseMidi, baseMidi + 3, baseMidi + 7, baseMidi + 10];
      case 'sus4':
        return [baseMidi, baseMidi + 5, baseMidi + 7];
      case 'maj':
      default:
        return [baseMidi, baseMidi + 4, baseMidi + 7];
    }
  }

  @override
  List<DetectedChordSegment> segmentChords(
    List<List<double>> chromagram,
    List<List<double>> bassChromagram,
    List<List<double>> harmonyChromagram,
    int hopSize,
    double sampleRate,
    KeyDetectionResult mainKey,
  ) {
    final frameDuration = hopSize / sampleRate;
    final segments = <DetectedChordSegment>[];
    if (chromagram.isEmpty) return segments;

    int currentRoot = mainKey.rootMod;
    String currentQuality = mainKey.mode == 'major' ? 'maj' : 'min';
    String currentName = '${noteNamesLat[currentRoot]} ${mainKey.mode == 'major' ? "Mayor" : "Menor"}';
    String currentSymbol = '${noteNamesAle[currentRoot]}${mainKey.mode == 'major' ? "" : "m"}';
    int startFrame = 0;

    for (int i = 0; i < chromagram.length; i++) {
      final harm = harmonyChromagram[i];
      final bass = bassChromagram[i];

      double bestScore = -double.infinity;
      int frameRoot = currentRoot;
      var frameProf = chordProfiles[0];

      for (int r = 0; r < 12; r++) {
        for (final p in chordProfiles) {
          double hScore = 0.0;
          for (final inv in p.intervals) {
            hScore += harm[(r + inv) % 12];
          }
          hScore /= p.intervals.length;

          double pen = 0.0;
          for (final inv in p.penalties) {
            pen += harm[(r + inv) % 12];
          }
          pen /= p.penalties.length;

          final bScore = bass[r] * 0.40;
          double tonicBonus = 0.0;
          if (r == mainKey.rootMod) tonicBonus = 0.20;
          if (r == (mainKey.rootMod + 7) % 12) tonicBonus = 0.15;
          if (r == (mainKey.rootMod + 5) % 12) tonicBonus = 0.12;

          final total = hScore - (0.35 * pen) + bScore + tonicBonus;
          if (total > bestScore) {
            bestScore = total;
            frameRoot = r;
            frameProf = p;
          }
        }
      }

      // Hysteresis temporal: solo confirmar cambio tras al menos 3 frames consecutivos
      if ((frameRoot != currentRoot || frameProf.quality != currentQuality) && (i - startFrame >= 3)) {
        segments.add(DetectedChordSegment(
          startTime: double.parse((startFrame * frameDuration).toStringAsFixed(1)),
          endTime: double.parse((i * frameDuration).toStringAsFixed(1)),
          rootMod: currentRoot,
          quality: currentQuality,
          chordName: currentName,
          chordSymbol: currentSymbol,
          noteMods: _computeNoteMods(currentRoot, currentQuality),
          playbackMidis: _computePlaybackMidis(currentRoot, currentQuality),
          confidence: 0.88,
        ));

        currentRoot = frameRoot;
        currentQuality = frameProf.quality;
        currentName = '${noteNamesLat[currentRoot]} ${frameProf.name}';
        currentSymbol = '${noteNamesAle[currentRoot]}${frameProf.symbol}';
        startFrame = i;
      }
    }

    // Segmento final para cubrir la totalidad del archivo de audio
    segments.add(DetectedChordSegment(
      startTime: double.parse((startFrame * frameDuration).toStringAsFixed(1)),
      endTime: double.parse((chromagram.length * frameDuration).toStringAsFixed(1)),
      rootMod: currentRoot,
      quality: currentQuality,
      chordName: currentName,
      chordSymbol: currentSymbol,
      noteMods: _computeNoteMods(currentRoot, currentQuality),
      playbackMidis: _computePlaybackMidis(currentRoot, currentQuality),
      confidence: 0.92,
    ));

    return segments;
  }
}
