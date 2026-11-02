import 'package:flutter/services.dart';

import '../models/bass_matrix_layout.dart';

/// Mapeador puro (sin Flutter UI) de teclas a botones de la matriz 2x2
/// de captura de patrones rítmicos de bajos.
///
/// Layout de la matriz 2x2 (relación con botones físicos):
/// |            | Externos (col 0) | Internos (col 1) |
/// |------------|------------------|------------------|
/// | Fila 1     | botón 7          | botón 4          |
/// | Fila 2     | botón 8          | botón 5          |
///
/// Mapeo propuesto para captura por teclado:
/// | Tecla | Botón | Posición |
/// |-------|-------|----------|
/// | 7 / NumPad 7 | 7 | (fila1, col0) Externo |
/// | 8 / NumPad 8 | 8 | (fila2, col0) Externo |
/// | 4 / NumPad 4 | 4 | (fila1, col1) Interno |
/// | 5 / NumPad 5 | 5 | (fila2, col1) Interno |
///
/// Principios aplicados:
/// - SRP: única responsabilidad de mapear teclas
/// - OCP: extensible sin modificar consumidores
/// - Alta cohesión, bajo acoplamiento
/// - Triplas de Hoare
///
/// # Triplas de Hoare
/// - {P}: `key` es una `LogicalKeyboardKey` válida
/// - {Q}: retorna `int?` ∈ {4,5,7,8} ∩ `BassMatrixLayout.buttonNumbers` o `null`
abstract final class BassCaptureKeyMapper {
  static const Set<int> _validMatrixButtons = {4, 5, 7, 8};

  /// Convierte una tecla física/lógica al botón de matriz correspondiente.
  ///
  /// {P}: `key` proviene de un `KeyDownEvent`
  /// {Q}: botón de matriz válido o `null` si no está mapeado
  static int? map(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit7 ||
        key == LogicalKeyboardKey.numpad7) {
      return 7;
    }
    if (key == LogicalKeyboardKey.digit8 ||
        key == LogicalKeyboardKey.numpad8) {
      return 8;
    }
    if (key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.numpad4) {
      return 4;
    }
    if (key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.numpad5) {
      return 5;
    }
    return null;
  }

  /// Verifica que el botón pertenezca al conjunto válido de la matriz 2x2.
  ///
  /// {P}: `button >= 0`
  /// {Q}: `true` solo si está en {4,5,7,8} y en `BassMatrixLayout.buttonNumbers`
  static bool isValid(int button) {
    if (!_validMatrixButtons.contains(button)) return false;
    return BassMatrixLayout.buttonNumbers.contains(button);
  }

  /// Conjunto inmutable de botones válidos para captura por teclado.
  static Set<int> get validButtons =>
      Set.unmodifiable(BassMatrixLayout.buttonNumbers);
}
