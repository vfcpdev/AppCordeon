import '../models/bass_rhythm_pattern.dart';

/// Ritmos disponibles desde que inicia la aplicación, sin importar archivos.
class BassRhythmCatalog {
  static final List<BassRhythmPattern> patterns = List.unmodifiable([
    _pattern(
      id: 'builtin:paseo',
      name: 'Paseo Vallenato',
      meterBeats: 4,
      beatType: 4,
      bpm: 130,
      events: const [
        (0.0, BassRhythmButtonType.fundamental, false, false),
        (0.5, BassRhythmButtonType.fundamental, false, false),
        (1.0, BassRhythmButtonType.chord, false, false),
        (2.0, BassRhythmButtonType.fundamental, false, false),
        (3.0, BassRhythmButtonType.chord, false, false),
      ],
    ),
    _pattern(
      id: 'builtin:merengue',
      name: 'Merengue Vallenato',
      meterBeats: 6,
      beatType: 8,
      bpm: 207,
      events: const [
        (0.0, BassRhythmButtonType.fundamental, false, false),
        (0.75, BassRhythmButtonType.fundamental, false, false),
        (1.5, BassRhythmButtonType.chord, true, false),
        (2.25, BassRhythmButtonType.fundamental, false, false),
      ],
    ),
    _pattern(
      id: 'builtin:puya',
      name: 'Puya Vallenata',
      meterBeats: 6,
      beatType: 8,
      bpm: 232,
      events: const [
        (0.0, BassRhythmButtonType.fundamental, true, true),
        (0.75, BassRhythmButtonType.fundamental, false, true),
        (1.5, BassRhythmButtonType.chord, false, true),
        (2.25, BassRhythmButtonType.fundamental, false, true),
      ],
    ),
    _pattern(
      id: 'builtin:son',
      name: 'Son Vallenato (Bajo Arrastrado)',
      meterBeats: 2,
      beatType: 4,
      bpm: 72,
      events: const [
        (0.0, BassRhythmButtonType.fundamental, false, false),
        (0.75, BassRhythmButtonType.fundamental, false, false),
        (1.0, BassRhythmButtonType.fundamental, false, false),
      ],
    ),
    _pattern(
      id: 'builtin:chande',
      name: 'Chandé',
      meterBeats: 4,
      beatType: 4,
      bpm: 145,
      events: const [
        (0.0, BassRhythmButtonType.fundamental, false, false),
        (0.75, BassRhythmButtonType.chord, false, false),
        (2.0, BassRhythmButtonType.fundamental, false, false),
        (2.75, BassRhythmButtonType.chord, false, false),
      ],
    ),
    _pattern(
      id: 'builtin:cumbia',
      name: 'Cumbia Colombiana',
      meterBeats: 4,
      beatType: 4,
      bpm: 100,
      events: const [
        (0.0, BassRhythmButtonType.fundamental, false, false),
        (1.0, BassRhythmButtonType.chord, false, false),
        (2.0, BassRhythmButtonType.fundamental, false, false),
        (3.0, BassRhythmButtonType.chord, false, false),
      ],
    ),
  ]);

  static BassRhythmPattern _pattern({
    required String id,
    required String name,
    required int meterBeats,
    required int beatType,
    required double bpm,
    required List<(double, BassRhythmButtonType, bool, bool)> events,
  }) {
    var hitIndex = 0;
    final hits = events.map((event) {
      // Cada golpe se toca con la pareja bajo + acorde de la misma nota:
      // el índice (2) va en el bajo y el medio (3) en el acorde.
      final pairIndex = hitIndex++;
      final bassButtonIndex = _panelButtonIndex(pairIndex, isChord: false);
      final chordButtonIndex = _panelButtonIndex(pairIndex, isChord: true);
      return BassRhythmHit(
        onsetQuarterBeats: event.$1,
        durationQuarterBeats: 0.125,
        buttonIndex: bassButtonIndex,
        pairedButtonIndex: chordButtonIndex,
        buttonType: event.$2,
        fingerNumber: 2,
        pairedFingerNumber: 3,
        isAccented: event.$3,
        isStaccato: event.$4,
      );
    }).toList();
    return BassRhythmPattern(
      id: id,
      name: name,
      partName: 'Catálogo',
      measureNumber: 1,
      beatsPerMeasure: meterBeats,
      beatType: beatType,
      durationQuarterBeats: meterBeats * 4 / beatType,
      quarterNotesPerMinute: bpm,
      hits: hits,
    );
  }

  /// Índice del botón de bajo o de acorde para la pareja [pairIndex].
  ///
  /// Las parejas alternan columnas: exterior (1-2, 3-4, 5-6) e interior
  /// (1-2, 3-4, 5-6), de arriba hacia abajo.
  static int _panelButtonIndex(int pairIndex, {required bool isChord}) {
    final pairRow = (pairIndex ~/ 2) % 3;
    final columnOffset = pairIndex.isEven ? 0 : 6;
    final typeOffset = isChord ? 0 : 1;
    return columnOffset + pairRow * 2 + typeOffset;
  }
}
