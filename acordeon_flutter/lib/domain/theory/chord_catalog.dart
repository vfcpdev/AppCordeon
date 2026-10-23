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
  };

  /// Calcula las notas MIDI del acorde a partir de la raíz (0-11) en la octava 4.
  static List<int> notesFor({
    required int root,
    required String type,
    required String extension,
    int baseMidi = 60,
  }) {
    final intervals = <int>[...(triadIntervals[type] ?? triadIntervals['maj']!)];
    final ext = extensionIntervals[extension];
    if (ext != null) intervals.add(ext);
    final base = baseMidi + root;
    return intervals.map((i) => base + i).toList();
  }
}
