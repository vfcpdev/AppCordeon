/// Ajusta el tamaño de fuente de un símbolo de acorde para que la cadena se
/// muestre completa dentro de un ancho disponible acotado.
///
/// Clase pura y sin estado (Alta Cohesión: única responsabilidad de calcular el
/// tamaño; Bajo Acoplamiento: no conoce widgets, estilos ni controladores).
///
/// Enfoque formal con Triplas de Hoare para [fitFontSize]:
/// - Precondición {P}:
///   - `availableWidth > 0`
///   - `minFontSize > 0 && minFontSize <= baseFontSize`
///   - `charWidthFactor > 0`
/// - Ejecución {C}:
///   Sea $L = max(len(text.trim()), 1)$ y
///   $W = availableWidth - horizontalPadding$.
///   `candidato = W / (L * charWidthFactor)`;
///   `result = clamp(candidato, minFontSize, baseFontSize)`.
/// - Poscondición {Q}:
///   - $0 < result \\le baseFontSize$
///   - Si $result > minFontSize$, entonces
///     $L * charWidthFactor * result + horizontalPadding \\le availableWidth$
///     (el ajuste es siempre por debajo del ancho disponible).
///   - Si $result == minFontSize$, se utilizó el tamaño mínimo permitido
///     como mejor esfuerzo ante textos más largos que la celda.
///   - Monotonía: textos más largos no producen tamaños mayores.
class ChordTextFitter {
  const ChordTextFitter._();

  /// Factor de ancho estimado por carácter para la tipografía del acorde
  /// (conservador para glifos anchos como `m` o `b`).
  static const double defaultCharWidthFactor = 0.58;

  /// Calcula el tamaño de fuente tal que el texto completo quepa con seguridad
  /// en [availableWidth]. Nunca devuelve tamaños no positivos.
  static double fitFontSize({
    required String text,
    required double availableWidth,
    required double baseFontSize,
    required double minFontSize,
    double horizontalPadding = 0.0,
    double charWidthFactor = defaultCharWidthFactor,
  }) {
    assert(
      availableWidth > 0,
      'Violación {P}: availableWidth ($availableWidth) debe ser positivo.',
    );
    assert(
      minFontSize > 0 && minFontSize <= baseFontSize,
      'Violación {P}: minFontSize ($minFontSize) debe estar en (0, baseFontSize].',
    );
    assert(
      charWidthFactor > 0,
      'Violación {P}: charWidthFactor ($charWidthFactor) debe ser positivo.',
    );

    final usableWidth = (availableWidth - horizontalPadding).clamp(0.0, double.infinity);
    final length = text.trim().length.clamp(1, 1 << 31);
    final perChar = length * charWidthFactor;

    final candidate = usableWidth / perChar;
    return candidate.clamp(minFontSize, baseFontSize);
  }
}
