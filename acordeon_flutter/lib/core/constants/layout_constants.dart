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
}
