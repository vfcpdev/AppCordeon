import '../models/measure_models.dart';

/// Memento que captura un snapshot inmutable del estado de la cuadrícula de compases.
/// Patrón Memento para preservar y restaurar el estado sin violar encapsulamiento.
class GridMemento {
  final List<MeasureRow> measures;
  final Set<int> markedBeats;
  final Set<int> yellowDecisionBeats;
  final DateTime timestamp;

  GridMemento({
    required List<MeasureRow> measures,
    required Set<int> markedBeats,
    required Set<int> yellowDecisionBeats,
    DateTime? timestamp,
  })  : measures = List.unmodifiable(
          measures.map(
            (row) => MeasureRow(
              barNumber: row.barNumber,
              beats: List.unmodifiable(
                row.beats.map(
                  (b) => MeasureBeat(
                    barIndex: b.barIndex,
                    beatIndex: b.beatIndex,
                    chord: b.chord,
                    timeText: b.timeText,
                    bellows: b.bellows,
                  ),
                ),
              ),
            ),
          ),
        ),
        markedBeats = Set.unmodifiable(markedBeats),
        yellowDecisionBeats = Set.unmodifiable(yellowDecisionBeats),
        timestamp = timestamp ?? DateTime.now();
}

/// Caretaker del patrón Memento: gestiona el historial de deshacer y rehacer (Undo/Redo).
class GridHistoryManager {
  final int maxHistory;
  final List<GridMemento> _undoStack = [];
  final List<GridMemento> _redoStack = [];

  GridHistoryManager({this.maxHistory = 25});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// Guarda una instantánea del estado antes de una mutación.
  void saveSnapshot({
    required List<MeasureRow> measures,
    required Set<int> markedBeats,
    required Set<int> yellowDecisionBeats,
  }) {
    _redoStack.clear();
    _undoStack.add(
      GridMemento(
        measures: measures,
        markedBeats: markedBeats,
        yellowDecisionBeats: yellowDecisionBeats,
      ),
    );
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  /// Deshace la última acción y devuelve el estado previo, guardando el actual en redo.
  GridMemento? undo({
    required List<MeasureRow> currentMeasures,
    required Set<int> currentMarkedBeats,
    required Set<int> currentYellowDecisionBeats,
  }) {
    if (!canUndo) return null;

    final currentState = GridMemento(
      measures: currentMeasures,
      markedBeats: currentMarkedBeats,
      yellowDecisionBeats: currentYellowDecisionBeats,
    );
    _redoStack.add(currentState);

    return _undoStack.removeLast();
  }

  /// Rehace la última acción deshecha y devuelve el estado futuro, guardando el actual en undo.
  GridMemento? redo({
    required List<MeasureRow> currentMeasures,
    required Set<int> currentMarkedBeats,
    required Set<int> currentYellowDecisionBeats,
  }) {
    if (!canRedo) return null;

    final currentState = GridMemento(
      measures: currentMeasures,
      markedBeats: currentMarkedBeats,
      yellowDecisionBeats: currentYellowDecisionBeats,
    );
    _undoStack.add(currentState);

    return _redoStack.removeLast();
  }

  /// Limpia todo el historial.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

