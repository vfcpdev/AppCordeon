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
}

