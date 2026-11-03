import 'grid_selection_model.dart';
import 'measure_models.dart';

/// Sub-estado cohesivo inmutable para la gestión de la cuadrícula de compases.
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Agrupa y gestiona exclusivamente el estado
///   y operaciones de lectura de la cuadrícula de compases.
/// - Value Object / Inmutabilidad: Todas las transformaciones retornan nuevas instancias.
class CompasGridState {
  final List<MeasureRow> measures;
  final GridSelectionModel selection;
  final Set<int> yellowDecisionBeats;

  const CompasGridState({
    this.measures = const [],
    this.selection = const GridSelectionModel(),
    this.yellowDecisionBeats = const {},
  });

  /// Total de tiempos en la cuadrícula (4 por cada compás registrado).
  int get totalBeats => measures.length * 4;

  /// Cantidad total de acordes no vacíos registrados en la cuadrícula.
  int get nonEmptyChordCount {
    var count = 0;
    for (final row in measures) {
      for (final beat in row.beats) {
        if (beat.chord.trim().isNotEmpty) count++;
      }
    }
    return count;
  }

  /// Indica si la cuadrícula contiene al menos un acorde registrado.
  bool get hasChords => nonEmptyChordCount > 0;

  /// Obtiene el texto del acorde en un compás y tiempo específicos.
  String getChord(int barIndex, int beatIndex) {
    if (barIndex < 0 || barIndex >= measures.length) return '';
    final row = measures[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return '';
    return row.beats[beatIndex].chord;
  }

  CompasGridState copyWith({
    List<MeasureRow>? measures,
    GridSelectionModel? selection,
    Set<int>? yellowDecisionBeats,
  }) {
    return CompasGridState(
      measures: measures ?? this.measures,
      selection: selection ?? this.selection,
      yellowDecisionBeats: yellowDecisionBeats ?? this.yellowDecisionBeats,
    );
  }
}

