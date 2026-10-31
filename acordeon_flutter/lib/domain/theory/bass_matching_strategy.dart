import '../../core/constants/enums.dart';

/// Contrato abstracto para estrategias de acompañamiento y evaluación de bajos (Strategy Pattern + OCP).
abstract class IBassMatchingStrategy {
  BassMatchType evaluate({
    required List<int> notes,
    required ButtonType type,
    required int chordRoot,
    required Set<int> chordPitchClasses,
    int? btnIndex,
  });
}

/// Estrategia armónica estándar y modal para acordeón vallenato/diatónico (Single Responsibility Principle).
/// Maneja:
/// 1. Coincidencia exacta de tónica en bajos fundamentales y tríadas en acordes.
/// 2. Resolución de conflicto modal en bajos homónimos (ej. Fa Mayor vs Fa menor, Do Mayor vs Do menor).
/// 3. Discriminación de parejas modales para botones fundamentales duplicados.
/// 4. Cercanía armónica (grados V y IV, bajo alternante en 5ta, relativo o notas compartidas).
class StandardModalBassMatchingStrategy implements IBassMatchingStrategy {
  const StandardModalBassMatchingStrategy();

  @override
  BassMatchType evaluate({
    required List<int> notes,
    required ButtonType type,
    required int chordRoot,
    required Set<int> chordPitchClasses,
    int? btnIndex,
  }) {
    if (notes.isEmpty || chordPitchClasses.isEmpty || chordRoot < 0) {
      return BassMatchType.none;
    }

    final btnPcs = notes.map((n) => n % 12).toSet();
    final mainPc = notes.first % 12;

    final isChordMinor = chordPitchClasses.contains((chordRoot + 3) % 12);
    final isChordMajor = chordPitchClasses.contains((chordRoot + 4) % 12);

    if (type == ButtonType.fundamental) {
      // Coincidencia de tónica
      if (mainPc == chordRoot) {
        // En acordeones diatónicos con bajos homónimos (Fa Mayor / Fa menor o Do Mayor / Do menor):
        // asociar con la pareja correcta según la modalidad (mayor vs menor)
        if (btnIndex != null) {
          // Caso Fa (root 5): Par 4 es menor en pull, Par 1 es mayor en pull
          if (mainPc == 5) {
            if (isChordMinor && btnIndex == 1) return BassMatchType.close;
            if (isChordMajor && btnIndex == 4) return BassMatchType.close;
          }
          // Caso Do (root 0): Par 2 es menor en pull, Par 4 es mayor en push
          if (mainPc == 0) {
            if (isChordMinor && btnIndex == 4) return BassMatchType.close;
            if (isChordMajor && btnIndex == 2) return BassMatchType.close;
          }
        }
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

      // Si comparte la misma tónica pero tiene una modalidad contraria (3ra menor vs 3ra mayor),
      // existe conflicto modal (no debe acompañar como "cercano")
      final isBtnMinor = btnPcs.contains((mainPc + 3) % 12);
      final isBtnMajor = btnPcs.contains((mainPc + 4) % 12);

      if (mainPc == chordRoot && ((isChordMinor && isBtnMajor) || (isChordMajor && isBtnMinor))) {
        return BassMatchType.none;
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

