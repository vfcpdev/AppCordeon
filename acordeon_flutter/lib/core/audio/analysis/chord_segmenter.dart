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

/// Segmentador temporal de acordes con supresión de armónicos y ponderación de bajos.
class HarmonicChordSegmenter implements ChordSegmenter {
  static const List<String> noteNamesLat = [
    'Do', 'Do♯', 'Re', 'Mi♭', 'Mi', 'Fa', 'Fa♯', 'Sol', 'Sol♯', 'La', 'Si♭', 'Si'
  ];
  static const List<String> noteNamesAle = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'
  ];

  const HarmonicChordSegmenter();

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

    final chordProfiles = [
      ('maj', '', 'Mayor', [0, 4, 7], [1, 2, 3, 5, 6, 8, 9, 10, 11]),
      ('min', 'm', 'Menor', [0, 3, 7], [1, 2, 4, 5, 6, 8, 9, 10, 11]),
      ('dom7', '7', '7ma', [0, 4, 7, 10], [1, 2, 3, 5, 6, 8, 9, 11]),
      ('min7', 'm7', 'Menor 7ma', [0, 3, 7, 10], [1, 2, 4, 5, 6, 8, 9, 11]),
      ('sus4', 'sus4', 'Sus4', [0, 5, 7], [1, 2, 3, 4, 6, 8, 9, 10, 11]),
    ];

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
          for (final inv in p.$4) {
            hScore += harm[(r + inv) % 12];
          }
          hScore /= p.$4.length;

          double pen = 0.0;
          for (final inv in p.$5) {
            pen += harm[(r + inv) % 12];
          }
          pen /= p.$5.length;

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

      // Si cambia el acorde o llegamos a una ventana razonable
      if ((frameRoot != currentRoot || frameProf.$1 != currentQuality) && (i - startFrame >= 3)) {
        segments.add(DetectedChordSegment(
          startTime: double.parse((startFrame * frameDuration).toStringAsFixed(1)),
          endTime: double.parse((i * frameDuration).toStringAsFixed(1)),
          rootMod: currentRoot,
          quality: currentQuality,
          chordName: currentName,
          chordSymbol: currentSymbol,
          noteMods: [currentRoot, (currentRoot + 4) % 12, (currentRoot + 7) % 12],
          playbackMidis: [48 + currentRoot, 52 + currentRoot, 55 + currentRoot],
          confidence: 0.88,
        ));

        currentRoot = frameRoot;
        currentQuality = frameProf.$1;
        currentName = '${noteNamesLat[currentRoot]} ${frameProf.$3}';
        currentSymbol = '${noteNamesAle[currentRoot]}${frameProf.$2}';
        startFrame = i;
      }
    }

    // Segmento final
    segments.add(DetectedChordSegment(
      startTime: double.parse((startFrame * frameDuration).toStringAsFixed(1)),
      endTime: double.parse((chromagram.length * frameDuration).toStringAsFixed(1)),
      rootMod: currentRoot,
      quality: currentQuality,
      chordName: currentName,
      chordSymbol: currentSymbol,
      noteMods: [currentRoot, (currentRoot + 4) % 12, (currentRoot + 7) % 12],
      playbackMidis: [48 + currentRoot, 52 + currentRoot, 55 + currentRoot],
      confidence: 0.92,
    ));

    return segments;
  }
}
