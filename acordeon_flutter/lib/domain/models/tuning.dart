/// Definición y registro de afinaciones para acordeón diatónico.
class TuningDefinition {
  final String id;
  final String name;
  final String rowsDescription;
  final int offset;
  final bool preferFlats;

  const TuningDefinition({
    required this.id,
    required this.name,
    required this.rowsDescription,
    required this.offset,
    required this.preferFlats,
  });
}

class TuningRegistry {
  static const List<TuningDefinition> defaultTunings = [
    TuningDefinition(
      id: 'cinco_letras',
      name: 'Cinco Letras (Bb - Eb - Ab)',
      rowsDescription: 'Si♭ - Mi♭ - La♭',
      offset: 0,
      preferFlats: true,
    ),
    TuningDefinition(
      id: 'rey_vallenato',
      name: 'Rey Vallenato (G - C - F)',
      rowsDescription: 'Sol - Do - Fa',
      offset: -3,
      preferFlats: false,
    ),
    TuningDefinition(
      id: 'guacamayo',
      name: 'Guacamayo (A - D - G)',
      rowsDescription: 'La - Re - Sol',
      offset: -1,
      preferFlats: false,
    ),
    TuningDefinition(
      id: 'simila',
      name: 'Simila (B - E - A)',
      rowsDescription: 'Si - Mi - La',
      offset: 1,
      preferFlats: false,
    ),
    TuningDefinition(
      id: 'cuatro_letras',
      name: 'Cuatro Letras (F - Bb - Eb)',
      rowsDescription: 'Fa - Si♭ - Mi♭',
      offset: -5,
      preferFlats: true,
    ),
    TuningDefinition(
      id: 'sabanera',
      name: 'Sabanera (C - F - Bb)',
      rowsDescription: 'Do - Fa - Si♭',
      offset: 2,
      preferFlats: true,
    ),
    TuningDefinition(
      id: 'anisada',
      name: 'Anisada (E - A - D)',
      rowsDescription: 'Mi - La - Re',
      offset: -7,
      preferFlats: false,
    ),
    TuningDefinition(
      id: 'lluvia',
      name: 'Lluvia (C# - F# - B)',
      rowsDescription: 'Do♯ - Fa♯ - Si',
      offset: 3,
      preferFlats: false,
    ),
  ];

  static List<TuningDefinition> _orderedTunings = List.from(defaultTunings);

  /// Lista ordenada actual de afinaciones (personalizada o por tono).
  static List<TuningDefinition> get orderedTunings => List.unmodifiable(_orderedTunings);

  /// Actualiza la lista con un orden personalizado (por ejemplo mediante Drag & Drop).
  static void setOrderedTunings(List<TuningDefinition> tunings) {
    _orderedTunings = List.from(tunings);
  }

  /// Restablece el orden al predeterminado de fábrica.
  static void resetToDefaultOrder() {
    _orderedTunings = List.from(defaultTunings);
  }

  /// Ordena la lista de forma ascendente por tono (del acordeón más grave al más agudo, según offset).
  static void sortByPitchAscending() {
    _orderedTunings.sort((a, b) => a.offset.compareTo(b.offset));
  }

  static TuningDefinition getById(String id) {
    return defaultTunings.firstWhere(
      (t) => t.id == id,
      orElse: () => defaultTunings.first,
    );
  }

  static TuningDefinition getByOffset(int offset) {
    return defaultTunings.firstWhere(
      (t) => t.offset == offset,
      orElse: () => defaultTunings.first,
    );
  }

  static bool usesFlats(int offset) {
    return getByOffset(offset).preferFlats;
  }
}
