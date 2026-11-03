/// Modelo inmutable de selecciones de la cuadrícula de compases (Value Object / Domain Model).
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Encapsula exclusivamente la gestión de casillas
///   y tiempos marcados (por checkbox y por toque directo en cajas de texto).
/// - Alta Cohesión y Bajo Acoplamiento: Lógica de selección desacoplada del controlador y de la UI.
/// - Tripla de Hoare:
///   - Invariante {I}: Todos los conjuntos internos son inmutables.
class GridSelectionModel {
  final Set<int> markedBeats;
  final Set<int> targetBeats;

  const GridSelectionModel({
    this.markedBeats = const {},
    this.targetBeats = const {},
  });

  /// Conjunto unificado de todas las casillas activamente seleccionadas (Single Source of Truth).
  Set<int> get allSelected => {...markedBeats, ...targetBeats};

  /// Indica si no existe ninguna selección activa en la cuadrícula.
  bool get isEmpty => markedBeats.isEmpty && targetBeats.isEmpty;

  /// Indica si existe al menos una casilla seleccionada.
  bool get isNotEmpty => !isEmpty;

  /// Cantidad total de casillas únicas seleccionadas.
  int get count => allSelected.length;

  /// Verifica si una clave específica (m * 4 + b) se encuentra seleccionada.
  bool isSelected(int key) => markedBeats.contains(key) || targetBeats.contains(key);

  /// Verifica si todas las casillas de la cuadrícula están seleccionadas.
  bool isAllSelected(int totalBeats) => totalBeats > 0 && allSelected.length >= totalBeats;

  /// Alterna la marca de un checkbox en una clave específica.
  GridSelectionModel toggleMark(int key) {
    final next = Set<int>.from(markedBeats);
    if (!next.remove(key)) next.add(key);
    return copyWith(markedBeats: next);
  }

  /// Alterna la selección de una caja de texto como objetivo de asignación masiva.
  GridSelectionModel toggleTarget(int key) {
    final next = Set<int>.from(targetBeats);
    if (!next.remove(key)) next.add(key);
    return copyWith(targetBeats: next);
  }

  /// Marca todas las casillas desde 0 hasta [totalBeats] - 1 en ambos conjuntos.
  GridSelectionModel selectAll(int totalBeats) {
    final allKeys = {for (var i = 0; i < totalBeats; i++) i};
    return copyWith(
      markedBeats: allKeys,
      targetBeats: allKeys,
    );
  }

  /// Limpia todas las selecciones y marcas de la cuadrícula.
  GridSelectionModel clear() {
    return const GridSelectionModel(
      markedBeats: {},
      targetBeats: {},
    );
  }

  GridSelectionModel copyWith({
    Set<int>? markedBeats,
    Set<int>? targetBeats,
  }) {
    return GridSelectionModel(
      markedBeats: markedBeats ?? this.markedBeats,
      targetBeats: targetBeats ?? this.targetBeats,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridSelectionModel &&
          _setEquals(markedBeats, other.markedBeats) &&
          _setEquals(targetBeats, other.targetBeats);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(markedBeats),
        Object.hashAll(targetBeats),
      );

  static bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

