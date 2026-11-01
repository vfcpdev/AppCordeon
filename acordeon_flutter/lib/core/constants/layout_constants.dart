/// Métricas únicas de diseño del cuadro de Compás.
///
/// Fuente única de verdad del layout (SRP: solo define dimensiones;
/// OCP: extender con nuevas métricas no modifica a los clientes;
/// DRY: elimina los números mágicos 185px / 330px repartidos por el código).
class CompasCardMetrics {
  const CompasCardMetrics._();

  /// Ancho del cuadro de Compás (acoplado, desacoplado y marcador de acople).
  /// Ampliado para que los 4 cuadros en fila horizontal queden legibles.
  static const double width = 280.0;

  /// Altura máxima de la cuadrícula de compases antes de activar el scroll.
  static const double gridMaxHeight = 420.0;

  /// Altura base (medida en pantalla) de un cuadro del compás con el TextBox
  /// denso y su padding actual (~21.6px).
  static const double beatCellBaseHeight = 21.6;

  /// Altura de un cuadro del compás, aumentada un 5% sobre la base.
  ///
  /// Tripla de Hoare:
  /// - {P} La celda se renderiza dentro del compás horizontal.
  /// - {C} `height == beatCellBaseHeight * 1.05`.
  /// - {Q} La celda mantiene legibilidad de acordes y fuente ajustada con +5% de espacio vertical.
  static const double beatCellHeight = beatCellBaseHeight * 1.05; // 22.68

  /// Alto de una fila de compás, incluyendo el margen vertical entre filas.
  static const double measureRowHeight = beatCellHeight + 5.0;
}
