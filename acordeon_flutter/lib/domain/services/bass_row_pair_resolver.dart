import '../../core/constants/enums.dart';

/// Define el par de botones físicos (1-based, 1 a 6) asociados a un rol armónico.
class BassPairMapping {
  final int pairIndex; // 1 a 6
  final int bassButtonIndex; // Índice en la lista de 12 botones del panel
  final int chordButtonIndex;

  const BassPairMapping({
    required this.pairIndex,
    required this.bassButtonIndex,
    required this.chordButtonIndex,
  });
}

/// Estrategia y resolución de pares de bajos según la hilera objetivo (OOP + SRP + OCP).
///
/// En el acordeón diatónico estándar:
/// - Columna Exterior del panel: Pares 1, 3, 5 (botones 1, 0; 3, 2; 5, 4).
/// - Columna Interior del panel: Pares 2, 4, 6 (botones 7, 6; 9, 8; 11, 10).
///
/// Convención diatónica vallenata según la hilera melódica activa:
/// - Hilera Externa: Tónica en Par 1 (ej. Bb cerrando o Sol según afinación), Dominante en Par 3 / Par 2.
/// - Hilera Media: Tónica en Par 3 (ej. Eb cerrando / Bb abriendo o Do), Dominante en Par 1 / Par 4.
/// - Hilera Interna: Tónica en Par 5 (ej. Ab cerrando / Eb abriendo o Fa), Dominante en Par 3 / Par 6.
class BassRowPairResolver {
  /// Devuelve el par de bajos tónico y dominante para la hilera indicada.
  ///
  /// # Triplas de Hoare:
  /// - {P}: `target` válido (externalRow, middleRow o internalRow).
  /// - {Q}: retorna pares válidos con índices dentro de `[0, 11]`.
  static ({BassPairMapping tonic, BassPairMapping dominant}) resolvePairsFor({
    required AccordionRowTarget target,
  }) {
    switch (target) {
      case AccordionRowTarget.externalRow:
        return (
          tonic: _createMapping(pairIndex: 1, isExteriorColumn: true, rowInColumn: 0),
          dominant: _createMapping(pairIndex: 3, isExteriorColumn: true, rowInColumn: 1),
        );
      case AccordionRowTarget.middleRow:
        return (
          tonic: _createMapping(pairIndex: 3, isExteriorColumn: true, rowInColumn: 1),
          dominant: _createMapping(pairIndex: 1, isExteriorColumn: true, rowInColumn: 0),
        );
      case AccordionRowTarget.internalRow:
        return (
          tonic: _createMapping(pairIndex: 5, isExteriorColumn: true, rowInColumn: 2),
          dominant: _createMapping(pairIndex: 3, isExteriorColumn: true, rowInColumn: 1),
        );
    }
  }

  /// Transpone un conjunto de índices de botones para que apunten a la hilera especificada.
  static int remapButtonIndex(int originalButtonIndex, AccordionRowTarget target) {
    if (originalButtonIndex < 0 || originalButtonIndex >= 12) {
      return originalButtonIndex;
    }
    final isChord = originalButtonIndex % 2 == 0;
    final pairs = resolvePairsFor(target: target);
    
    // Si el índice correspondía a un bajo o acorde del par 1/3/5, se transpone coherentemente
    return isChord ? pairs.tonic.chordButtonIndex : pairs.tonic.bassButtonIndex;
  }

  static BassPairMapping _createMapping({
    required int pairIndex,
    required bool isExteriorColumn,
    required int rowInColumn,
  }) {
    final colOffset = isExteriorColumn ? 0 : 6;
    final chordIdx = colOffset + rowInColumn * 2;
    final bassIdx = chordIdx + 1;

    return BassPairMapping(
      pairIndex: pairIndex,
      bassButtonIndex: bassIdx,
      chordButtonIndex: chordIdx,
    );
  }
}

