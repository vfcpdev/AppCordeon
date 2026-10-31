import 'package:flutter/painting.dart';
import '../../core/constants/enums.dart';

/// Catálogo de intervalos de acordes (Open/Closed: añadir un tipo = añadir una entrada).
class ChordCatalog {
  ChordCatalog._();

  /// Intervalos (semitonos desde la raíz) por tipo de tríada.
  static const Map<String, List<int>> triadIntervals = {
    'maj': [0, 4, 7],
    'min': [0, 3, 7],
    'dim': [0, 3, 6],
    'aug': [0, 4, 8],
    'sus4': [0, 5, 7],
  };

  /// Nota adicional (cuarta voz) por tipo de extensión.
  static const Map<String, int> extensionIntervals = {
    'octave': 12,
    'dom7': 10,
    'maj7': 11,
    'maj6': 9,
    'add9': 14,
    'min7': 10,
    'dim7': 9,
  };

  /// Calcula las notas MIDI del acorde a partir de la raíz (0-11) en la octava 4.
  /// Si la raíz es negativa (sin tónica) devuelve una lista vacía.
  static List<int> notesFor({
    required int root,
    required String type,
    required String extension,
    int baseMidi = 60,
  }) {
    if (root < 0) return const [];
    final intervals = <int>[
      if (type.isEmpty)
        0
      else
        ...(triadIntervals[type] ?? triadIntervals['maj']!),
    ];
    final ext = extensionIntervals[extension];
    if (ext != null) intervals.add(ext);
    final base = baseMidi + root;
    return intervals.map((i) => base + i).toList();
  }

  /// Clases de altura (0-11) del acorde que debe mostrarse en el diapasón.
  ///
  /// Une el acorde generado en el constructor, el que suena en el Compás
  /// (solo cuando la sincronización está activa) y los botones elegidos en
  /// el detector. Así cualquier contexto armónico activo conserva sus
  /// botones visibles al filtrar por la dirección del fuelle.
  static Set<int> activePitchClasses({
    Iterable<int> generated = const [],
    Iterable<int> playing = const [],
    Iterable<int> selected = const [],
  }) {
    return <int>{
      ...generated.map((n) => n % 12),
      ...playing.map((n) => n % 12),
      ...selected.map((n) => n % 12),
    };
  }

  /// Nombres de tónica en notación latina (Do, Re, Mi…) y alemana (C, D, E…).
  /// El índice corresponde a la clase de altura (0 = Do/C).
  static const List<String> latinRootNames = [
    'Do', 'Do#', 'Re', 'Mi♭', 'Mi', 'Fa',
    'Fa#', 'Sol', 'Sol#', 'La', 'Si♭', 'Si',
  ];
  static const List<String> germanRootNames = [
    'C', 'C#', 'D', 'Eb', 'E', 'F',
    'F#', 'G', 'Ab', 'A', 'Bb', 'B',
  ];

  /// Cadena de texto más larga que puede generarse para un nombre de acorde
  /// en el sistema ('Sol#' [4] + 'sus4' [4] + 'maj7' [4] = 'Sol#sus4maj7' [12 caracteres]).
  static const String maxChordName = 'Sol#sus4maj7';

  /// Símbolo textual del acorde (p. ej. `Dom7`, `Sol°7`, `Cadd9`) listo para
  /// guardarse en una celda del Compás. Devuelve vacío si no hay tónica.
  ///
  /// Se usan los sufijos que entiende el reproductor del Compás (`m`, `dim`,
  /// `aug`, `sus4`, `7`, `maj7`, `6`, `add9`), no las siglas abreviadas que
  /// muestra el constructor (° y +).
  static String symbolFor({
    required int root,
    required String type,
    required String extension,
    bool latin = true,
    bool display = false,
  }) {
    if (root < 0 || root > 11) return '';
    final rootName = (latin ? latinRootNames : germanRootNames)[root];

    final typeSymbol = switch (type) {
      'min' => 'm',
      'dim' => display ? '°' : 'dim',
      'aug' => display ? '+' : 'aug',
      'sus4' => 'sus4',
      _ => '',
    };

    final extensionSymbol = switch (extension) {
      'octave' => '8',
      'dom7' => '7',
      'maj7' => 'maj7',
      'maj6' => '6',
      'add9' => 'add9',
      'min7' => type == 'min' ? '7' : 'm7',
      'dim7' => type == 'dim' ? '7' : (display ? '°7' : 'dim7'),
      _ => '',
    };

    return '$rootName$typeSymbol$extensionSymbol';
  }

  /// Nombres de las notas que componen el acorde según la notación solicitada.
  static List<String> noteNamesFor({
    required int root,
    required String type,
    required String extension,
    bool latin = true,
  }) {
    if (root < 0 || root > 11) return const [];
    final midis = notesFor(root: root, type: type, extension: extension);
    final names = latin ? latinRootNames : germanRootNames;
    final result = <String>[];
    for (final m in midis) {
      final name = names[m % 12];
      if (!result.contains(name)) {
        result.add(name);
      }
    }
    return result;
  }

  static const Map<String, int> rootPitchClasses = {
    'Do#': 1, 'Reb': 1, 'Re♭': 1, 'Re#': 3, 'Mib': 3, 'Mi♭': 3, 'Fa#': 6, 'Solb': 6, 'Sol♭': 6, 'Sol#': 8, 'Lab': 8, 'La♭': 8, 'La#': 10, 'Sib': 10, 'Si♭': 10,
    'Do': 0, 'Re': 2, 'Mi': 4, 'Fa': 5, 'Sol': 7, 'La': 9, 'Si': 11,
    'C#': 1, 'Db': 1, 'D♭': 1, 'D#': 3, 'Eb': 3, 'E♭': 3, 'F#': 6, 'Gb': 6, 'G♭': 6, 'G#': 8, 'Ab': 8, 'A♭': 8, 'A#': 10, 'Bb': 10, 'B♭': 10,
    'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11,
  };

  /// Convierte el símbolo de un acorde a la notación especificada (latina o alemana),
  /// preservando el tipo y las extensiones armónicas (p. ej. 'Do7' <-> 'C7', 'Solm' <-> 'Gm').
  static String formatChordForNotation(String chord, NotationMode notation) {
    final trimmed = chord.trim();
    if (trimmed.isEmpty || trimmed == '-') return trimmed;

    String? matchedRoot;
    int? pitchClass;

    final sortedRoots = rootPitchClasses.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final r in sortedRoots) {
      if (trimmed.startsWith(r)) {
        matchedRoot = r;
        pitchClass = rootPitchClasses[r];
        break;
      }
    }

    if (matchedRoot == null || pitchClass == null) {
      return trimmed;
    }

    final rest = trimmed.substring(matchedRoot.length);
    final bool isSharp = matchedRoot.contains('#');
    String targetRootName;

    if (notation == NotationMode.alemana) {
      if (isSharp) {
        targetRootName = switch (pitchClass) {
          1 => 'C#',
          3 => 'D#',
          6 => 'F#',
          8 => 'G#',
          10 => 'A#',
          _ => germanRootNames[pitchClass],
        };
      } else {
        targetRootName = germanRootNames[pitchClass];
      }
    } else {
      if (isSharp) {
        targetRootName = switch (pitchClass) {
          1 => 'Do#',
          3 => 'Re#',
          6 => 'Fa#',
          8 => 'Sol#',
          10 => 'La#',
          _ => latinRootNames[pitchClass],
        };
      } else {
        targetRootName = latinRootNames[pitchClass];
      }
    }

    return '$targetRootName$rest';
  }

  /// Extrae las clases de altura (0..11) a partir de una cadena de acorde (p. ej. 'Do', 'Sol7', 'Am', etc.)
  static Set<int> pitchClassesForChordSymbol(String chord) {
    final trimmed = chord.trim();
    if (trimmed.isEmpty) return const {};

    int? rootPc;
    String rest = '';
    for (final entry in rootPitchClasses.entries) {
      if (trimmed.startsWith(entry.key)) {
        if (rootPc == null || entry.key.length > (trimmed.length - rest.length)) {
          rootPc = entry.value;
          rest = trimmed.substring(entry.key.length);
        }
      }
    }
    if (rootPc == null) return const {};

    final isDim = rest.contains('dim') || rest.contains('°');
    final isAug = rest.contains('aug') || rest.contains('+');
    final isSus4 = rest.contains('sus4') || rest.contains('4');
    final isSus = rest.contains('sus') && !isSus4;
    final isMinor = (rest.contains('m') && !rest.contains('maj') && !rest.contains('dim'));
    final has7 = rest.contains('7');
    final isMaj7 = rest.contains('maj7');

    final pcs = <int>{rootPc};
    if (isDim) {
      pcs.add((rootPc + 3) % 12);
      pcs.add((rootPc + 6) % 12);
    } else if (isAug) {
      pcs.add((rootPc + 4) % 12);
      pcs.add((rootPc + 8) % 12);
    } else if (isSus4 || isSus) {
      pcs.add((rootPc + 5) % 12);
      pcs.add((rootPc + 7) % 12);
    } else if (isMinor) {
      pcs.add((rootPc + 3) % 12);
      pcs.add((rootPc + 7) % 12);
    } else {
      // Mayor
      pcs.add((rootPc + 4) % 12);
      pcs.add((rootPc + 7) % 12);
    }

    if (has7) {
      pcs.add((rootPc + (isDim ? 9 : (isMaj7 ? 11 : 10))) % 12);
    }
    if (rest.contains('6') && !rest.contains('add9')) {
      pcs.add((rootPc + 9) % 12);
    }
    if (rest.contains('add9')) {
      pcs.add((rootPc + 2) % 12);
    }
    return pcs;
  }

  /// Genera un TextSpan con el nombre del acorde y sus notas entre paréntesis para la etiqueta flotante.
  static TextSpan buildChordLabelSpans({
    required String chord,
    required NotationMode notation,
    double fontSize = 9.0,
  }) {
    final latin = notation != NotationMode.alemana;
    final formatted = formatChordForNotation(chord, notation);
    final pcs = pitchClassesForChordSymbol(chord);
    final rootNames = latin ? latinRootNames : germanRootNames;

    final notes = <String>[];
    for (final pc in pcs) {
      final name = rootNames[pc % 12];
      if (!notes.contains(name)) notes.add(name);
    }
    final notesStr = notes.isNotEmpty ? '   (${notes.join(' - ')})' : '';

    return TextSpan(
      children: [
        TextSpan(
          text: formatted,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: 0.3,
          ),
        ),
        if (notesStr.isNotEmpty)
          TextSpan(
            text: notesStr,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF047857),
              letterSpacing: 0.2,
            ),
          ),
      ],
    );
  }

  /// Obtiene la clase de altura de la raíz (0..11) a partir del símbolo del acorde.
  static int? rootPitchClassForChordSymbol(String chord) {
    final trimmed = chord.trim();
    if (trimmed.isEmpty) return null;
    int? rootPc;
    int longestMatch = 0;
    for (final entry in rootPitchClasses.entries) {
      if (trimmed.startsWith(entry.key)) {
        if (entry.key.length > longestMatch) {
          longestMatch = entry.key.length;
          rootPc = entry.value;
        }
      }
    }
    return rootPc;
  }

  /// Evalúa si las notas de un botón de bajo acompañan al acorde activo,
  /// diferenciando entre coincidencia exacta (tónica / tríada idéntica)
  /// o cercanía armónica (grados IV/V, 5ta, relativo o notas en común).
  static BassMatchType evaluateBassMatch({
    required List<int> notes,
    required ButtonType type,
    required int chordRoot,
    required Set<int> chordPitchClasses,
  }) {
    if (notes.isEmpty || chordPitchClasses.isEmpty) return BassMatchType.none;

    final btnPcs = notes.map((n) => n % 12).toSet();
    final mainPc = notes.first % 12;

    if (type == ButtonType.fundamental) {
      // Coincidencia exacta: la nota del bajo es la tónica del acorde
      if (mainPc == chordRoot) {
        return BassMatchType.exact;
      }
      // Cercanía: es la 5ta del acorde (bajo alternante directo), grado IV,
      // relativo o nota del acorde (3ra)
      final isFifth = mainPc == (chordRoot + 7) % 12;
      final isFourth = mainPc == (chordRoot + 5) % 12;
      final isRelative = mainPc == (chordRoot + 9) % 12;
      final isChordTone = chordPitchClasses.contains(mainPc);

      if (isFifth || isFourth || isRelative || isChordTone) {
        return BassMatchType.close;
      }
    } else {
      // type == ButtonType.chord
      // Coincidencia exacta: todas las notas del acorde del bajo están en el acorde
      // y su tónica coincide con la raíz del acorde
      final allNotesInChord = btnPcs.every((pc) => chordPitchClasses.contains(pc));
      if (allNotesInChord && btnPcs.contains(chordRoot)) {
        return BassMatchType.exact;
      }

      // Cercanía: acorde de dominante (V), subdominante (IV), relativo,
      // o comparte al menos 2 notas con el acorde activo
      final isDominantRoot = mainPc == (chordRoot + 7) % 12;
      final isSubdominantRoot = mainPc == (chordRoot + 5) % 12;
      final isRelativeRoot = mainPc == (chordRoot + 9) % 12;
      final sharedCount = btnPcs.where((pc) => chordPitchClasses.contains(pc)).length;

      if (allNotesInChord || isDominantRoot || isSubdominantRoot || isRelativeRoot || sharedCount >= 2) {
        return BassMatchType.close;
      }
    }

    return BassMatchType.none;
  }
}

/// Resultado del análisis de completitud armónica según la dirección del fuelle.
class ChordBellowsAnalysis {
  final String chordName;
  final List<String> chordNotes;
  final Set<int> chordPitchClasses;
  final bool isCompletePush;
  final bool isCompletePull;
  final Set<int> missingPush;
  final Set<int> missingPull;
  final List<String> missingPushNames;
  final List<String> missingPullNames;

  const ChordBellowsAnalysis({
    required this.chordName,
    required this.chordNotes,
    required this.chordPitchClasses,
    required this.isCompletePush,
    required this.isCompletePull,
    required this.missingPush,
    required this.missingPull,
    required this.missingPushNames,
    required this.missingPullNames,
  });
}

