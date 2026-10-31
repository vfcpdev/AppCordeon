import 'dart:math';
import '../../core/constants/enums.dart';
import '../models/accordion_data.dart';
import '../models/measure_models.dart';
import 'chord_catalog.dart';

/// Descriptor de fórmula de acorde para el motor de detección armónica.
class _ChordPattern {
  final String typeKey;
  final String typeName;
  final String symbolSuffix;
  final String formula;
  final Set<int> intervals;
  final int priority;

  const _ChordPattern({
    required this.typeKey,
    required this.typeName,
    required this.symbolSuffix,
    required this.formula,
    required this.intervals,
    required this.priority,
  });
}

/// Motor de análisis armónico y detección inteligente de acordes en tiempo real.
/// Implementa principios SOLID, alta cohesión y bajo acoplamiento.
class ChordDetectorEngine {
  static const List<_ChordPattern> _patterns = [
    // Tríadas estándar
    _ChordPattern(
      typeKey: 'maj',
      typeName: 'Tríada Mayor',
      symbolSuffix: '',
      formula: '1 - 3 - 5',
      intervals: {0, 4, 7},
      priority: 100,
    ),
    _ChordPattern(
      typeKey: 'min',
      typeName: 'Tríada Menor',
      symbolSuffix: 'm',
      formula: '1 - ♭3 - 5',
      intervals: {0, 3, 7},
      priority: 95,
    ),
    _ChordPattern(
      typeKey: 'dim',
      typeName: 'Tríada Disminuida',
      symbolSuffix: 'dim',
      formula: '1 - ♭3 - ♭5',
      intervals: {0, 3, 6},
      priority: 90,
    ),
    _ChordPattern(
      typeKey: 'aug',
      typeName: 'Tríada Aumentada',
      symbolSuffix: 'aug',
      formula: '1 - 3 - ♯5',
      intervals: {0, 4, 8},
      priority: 90,
    ),
    _ChordPattern(
      typeKey: 'sus4',
      typeName: 'Suspendido 4',
      symbolSuffix: 'sus4',
      formula: '1 - 4 - 5',
      intervals: {0, 5, 7},
      priority: 85,
    ),
    _ChordPattern(
      typeKey: 'sus2',
      typeName: 'Suspendido 2',
      symbolSuffix: 'sus2',
      formula: '1 - 2 - 5',
      intervals: {0, 2, 7},
      priority: 85,
    ),

    // Cuatríadas y Séptimas
    _ChordPattern(
      typeKey: 'dom7',
      typeName: 'Séptima Dominante',
      symbolSuffix: '7',
      formula: '1 - 3 - 5 - ♭7',
      intervals: {0, 4, 7, 10},
      priority: 92,
    ),
    _ChordPattern(
      typeKey: 'maj7',
      typeName: 'Séptima Mayor',
      symbolSuffix: 'maj7',
      formula: '1 - 3 - 5 - 7',
      intervals: {0, 4, 7, 11},
      priority: 90,
    ),
    _ChordPattern(
      typeKey: 'min7',
      typeName: 'Séptima Menor',
      symbolSuffix: 'm7',
      formula: '1 - ♭3 - 5 - ♭7',
      intervals: {0, 3, 7, 10},
      priority: 90,
    ),
    _ChordPattern(
      typeKey: 'dim7',
      typeName: 'Séptima Disminuida',
      symbolSuffix: 'dim7',
      formula: '1 - ♭3 - ♭5 - 𝄫7',
      intervals: {0, 3, 6, 9},
      priority: 88,
    ),
    _ChordPattern(
      typeKey: 'm7b5',
      typeName: 'Semidisminuida (m7♭5)',
      symbolSuffix: 'm7b5',
      formula: '1 - ♭3 - ♭5 - ♭7',
      intervals: {0, 3, 6, 10},
      priority: 88,
    ),
    _ChordPattern(
      typeKey: 'maj6',
      typeName: 'Sexta Mayor',
      symbolSuffix: '6',
      formula: '1 - 3 - 5 - 6',
      intervals: {0, 4, 7, 9},
      priority: 85,
    ),
    _ChordPattern(
      typeKey: 'min6',
      typeName: 'Sexta Menor',
      symbolSuffix: 'm6',
      formula: '1 - ♭3 - 5 - 6',
      intervals: {0, 3, 7, 9},
      priority: 85,
    ),
    _ChordPattern(
      typeKey: 'add9',
      typeName: 'Novena Añadida',
      symbolSuffix: 'add9',
      formula: '1 - 2 - 3 - 5',
      intervals: {0, 2, 4, 7},
      priority: 82,
    ),

    // Séptimas sin 5ta (comunes en acordes de acordeón por economía de notas)
    _ChordPattern(
      typeKey: 'dom7_no5',
      typeName: 'Séptima (sin 5ta)',
      symbolSuffix: '7',
      formula: '1 - 3 - ♭7',
      intervals: {0, 4, 10},
      priority: 80,
    ),
    _ChordPattern(
      typeKey: 'min7_no5',
      typeName: 'Menor 7ma (sin 5ta)',
      symbolSuffix: 'm7',
      formula: '1 - ♭3 - ♭7',
      intervals: {0, 3, 10},
      priority: 80,
    ),
    _ChordPattern(
      typeKey: 'maj7_no5',
      typeName: 'Mayor 7ma (sin 5ta)',
      symbolSuffix: 'maj7',
      formula: '1 - 3 - 7',
      intervals: {0, 4, 11},
      priority: 80,
    ),

    // Power chord
    _ChordPattern(
      typeKey: '5',
      typeName: 'Quinta (Power Chord)',
      symbolSuffix: '5',
      formula: '1 - 5',
      intervals: {0, 7},
      priority: 70,
    ),
  ];

  /// Detecta el acorde construido a partir de una lista de notas MIDI.
  static DetectedChordModel? detect({
    required List<int> midiNotes,
    NotationMode notation = NotationMode.latina,
  }) {
    if (midiNotes.length < 2) return null;

    final sortedNotes = List<int>.from(midiNotes)..sort();
    final pitchClasses = sortedNotes.map((n) => n % 12).toSet();
    if (pitchClasses.length < 2) return null;

    final bassMidi = sortedNotes.first;
    final bassPc = bassMidi % 12;

    final candidates = <_ChordCandidate>[];

    // Evaluar cada tónica posible de 0 a 11
    for (int r = 0; r < 12; r++) {
      if (!pitchClasses.contains(r)) continue;

      // Desplazar las clases de altura respecto a la tónica candidata `r`
      final intervals = pitchClasses.map((pc) => (pc - r + 12) % 12).toSet();

      for (final pat in _patterns) {
        if (_matches(intervals, pat.intervals)) {
          final isExact = intervals.length == pat.intervals.length;
          final isRootPosition = (bassPc == r);
          
          // Bonificación si la tónica coincide con el bajo o es coincidencia exacta
          int score = pat.priority;
          if (isExact) score += 20;
          if (isRootPosition) score += 15;

          candidates.add(_ChordCandidate(
            rootPc: r,
            bassPc: bassPc,
            pattern: pat,
            score: score,
            isRootPosition: isRootPosition,
          ));
        }
      }
    }

    if (candidates.isEmpty) {
      // Fallback: construir un acorde libre con la nota más grave como tónica
      final rootName = _nameForPc(bassPc, notation);
      return DetectedChordModel(
        name: '$rootName (Complejo)',
        root: rootName,
        bass: rootName,
        formula: 'Libre',
        type: 'Notas Combinadas',
        inversion: 'Personalizado',
        alternatives: const [],
        chordSymbol: rootName,
        pitchClasses: pitchClasses,
        rootPitchClass: bassPc,
        bassPitchClass: bassPc,
        notes: sortedNotes,
      );
    }

    // Ordenar candidatos por puntuación descendente
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;

    final isLatin = notation != NotationMode.alemana;
    final rootName = _nameForPc(best.rootPc, notation);
    final bassName = _nameForPc(best.bassPc, notation);

    // Determinar la inversión armónica y símbolo con barra '/' si aplica
    String inversionLabel;
    String symbol;
    String displayName;

    final relativeBassInterval = (best.bassPc - best.rootPc + 12) % 12;
    if (best.isRootPosition) {
      inversionLabel = 'Estado Fundamental';
      symbol = '$rootName${best.pattern.symbolSuffix}';
      displayName = isLatin
          ? '$rootName ${_cleanTypeLabel(best.pattern.typeName)}'
          : symbol;
    } else {
      // Es un acorde con bajo alterado (Slash Chord)
      if (relativeBassInterval == 3 || relativeBassInterval == 4) {
        inversionLabel = '1ª Inversión (Bajo en 3ra)';
      } else if (relativeBassInterval == 6 || relativeBassInterval == 7 || relativeBassInterval == 8) {
        inversionLabel = '2ª Inversión (Bajo en 5ta)';
      } else if (relativeBassInterval == 9 || relativeBassInterval == 10 || relativeBassInterval == 11) {
        inversionLabel = '3ª Inversión (Bajo en 7ma)';
      } else {
        inversionLabel = 'Bajo alterado (/$bassName)';
      }

      final baseSym = '$rootName${best.pattern.symbolSuffix}';
      symbol = '$baseSym/$bassName';
      displayName = isLatin
          ? '$baseSym/$bassName ($inversionLabel)'
          : symbol;
    }

    // Alternativas (otros candidatos detectados)
    final alternatives = <String>[];
    for (int i = 1; i < min(4, candidates.length); i++) {
      final alt = candidates[i];
      final altRoot = _nameForPc(alt.rootPc, notation);
      final altSym = '$altRoot${alt.pattern.symbolSuffix}';
      final altLabel = alt.isRootPosition
          ? altSym
          : '$altSym/${_nameForPc(alt.bassPc, notation)}';
      if (!alternatives.contains(altLabel) && altLabel != symbol) {
        alternatives.add(altLabel);
      }
    }

    return DetectedChordModel(
      name: displayName,
      root: rootName,
      bass: bassName,
      formula: best.pattern.formula,
      type: best.pattern.typeName,
      inversion: inversionLabel,
      alternatives: alternatives,
      chordSymbol: symbol,
      pitchClasses: pitchClasses,
      rootPitchClass: best.rootPc,
      bassPitchClass: best.bassPc,
      notes: sortedNotes,
    );
  }

  /// Evalúa la disponibilidad del acorde en el diapasón abriendo y cerrando el fuelle.
  static ChordBellowsAvailability evaluateDiapasonBellows({
    required Set<int> chordPitchClasses,
    required Map<String, List<TrebleButtonModel>> trebleData,
  }) {
    if (chordPitchClasses.isEmpty) {
      return const ChordBellowsAvailability(
        pushButtons: [],
        pullButtons: [],
        pushMatchedPcs: {},
        pullMatchedPcs: {},
        isCompletePush: false,
        isCompletePull: false,
      );
    }

    final pushMatchedPcs = <int>{};
    final pullMatchedPcs = <int>{};
    final pushButtons = <String>[];
    final pullButtons = <String>[];

    for (final row in trebleData.values) {
      for (final btn in row) {
        final pushPc = btn.push % 12;
        final pullPc = btn.pull % 12;

        if (chordPitchClasses.contains(pushPc)) {
          pushMatchedPcs.add(pushPc);
          pushButtons.add(btn.id);
        }
        if (chordPitchClasses.contains(pullPc)) {
          pullMatchedPcs.add(pullPc);
          pullButtons.add(btn.id);
        }
      }
    }

    final isCompletePush = pushMatchedPcs.containsAll(chordPitchClasses);
    final isCompletePull = pullMatchedPcs.containsAll(chordPitchClasses);

    return ChordBellowsAvailability(
      pushButtons: pushButtons,
      pullButtons: pullButtons,
      pushMatchedPcs: pushMatchedPcs,
      pullMatchedPcs: pullMatchedPcs,
      isCompletePush: isCompletePush,
      isCompletePull: isCompletePull,
    );
  }

  static bool _matches(Set<int> input, Set<int> pattern) {
    if (input.length == pattern.length) {
      return input.containsAll(pattern);
    }
    // Permite que input sea un subconjunto con al menos 2 notas coincidentes
    return input.intersection(pattern).length >= min(2, pattern.length) &&
        input.difference(pattern).isEmpty;
  }

  static String _nameForPc(int pc, NotationMode notation) {
    if (notation == NotationMode.alemana) {
      return ChordCatalog.germanRootNames[pc % 12];
    }
    return ChordCatalog.latinRootNames[pc % 12];
  }

  static String _cleanTypeLabel(String type) {
    return type.replaceAll('Tríada ', '').replaceAll('Séptima ', '7ma ');
  }
}

class _ChordCandidate {
  final int rootPc;
  final int bassPc;
  final _ChordPattern pattern;
  final int score;
  final bool isRootPosition;

  const _ChordCandidate({
    required this.rootPc,
    required this.bassPc,
    required this.pattern,
    required this.score,
    required this.isRootPosition,
  });
}

/// Reporte de disponibilidad de un acorde en el fuelle (Abre y Cierra).
class ChordBellowsAvailability {
  final List<String> pushButtons;
  final List<String> pullButtons;
  final Set<int> pushMatchedPcs;
  final Set<int> pullMatchedPcs;
  final bool isCompletePush;
  final bool isCompletePull;

  const ChordBellowsAvailability({
    required this.pushButtons,
    required this.pullButtons,
    required this.pushMatchedPcs,
    required this.pullMatchedPcs,
    required this.isCompletePush,
    required this.isCompletePull,
  });

  bool get isCompleteBoth => isCompletePush && isCompletePull;
}
