import '../../core/constants/enums.dart';

/// Mapeador puro para convertir pulsaciones físicas del panel de bajos
/// a botones de la matriz 2x2 de captura.
///
/// Centraliza la regla que antes estaba duplicada en el widget para
/// garantizar alta cohesión, bajo acoplamiento y OCP.
///
/// Layout:
/// - Columna EXTERIOR (rhythmButtonOffset == 0): pares impares (1,3,5)
///   -> fila1 (btnIndex==1) = botón 7; fila2 (btnIndex==3) = botón 8
///   (btnIndex==5 queda fuera de la matriz 2x2)
/// - Columna INTERIOR (rhythmButtonOffset == 1): pares pares (2,4,6)
///   -> fila1 (btnIndex==2) = botón 4; fila2 (btnIndex==4) = botón 5
///   (btnIndex==6 queda fuera de la matriz 2x2)
///
/// # Triplas de Hoare
/// - {P}: `type == ButtonType.fundamental` y `btnIndex ∈ {1..6}`
/// - {Q}: retorna `int?` ∈ {4,5,7,8} o `null` si no pertenece a la matriz 2x2
abstract final class BassCaptureMatrixMapper {
  /// Determina qué botón de matriz corresponde al botón físico pulsado.
  ///
  /// {P}: los parámetros representan un botón fundamental del panel de bajos
  /// {Q}: botón de matriz o `null` si queda fuera de la matriz 2x2
  static int? fromPhysical({
    required int rhythmButtonOffset,
    required int btnIndex,
    required ButtonType type,
  }) {
    if (type != ButtonType.fundamental) return null;

    if (rhythmButtonOffset == 0) {
      // Columna EXTERIOR → pares impares (1, 3, 5)
      if (btnIndex == 1) return 7;
      if (btnIndex == 3) return 8;
      return null;
    } else {
      // Columna INTERIOR → pares pares (2, 4, 6)
      if (btnIndex == 2) return 4;
      if (btnIndex == 4) return 5;
      return null;
    }
  }
}
