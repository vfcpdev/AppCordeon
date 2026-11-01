/// Métricas únicas de diseño del cuadro de Compás.
///
/// Fuente única de verdad del layout (SRP: solo define dimensiones;
/// OCP: extender con nuevas métricas no modifica a los clientes;
/// DRY: elimina los números mágicos 185px / 330px repartidos por el código).
class CompasCardMetrics {
  const CompasCardMetrics._();

  static const double gridWidth = 400.0;
  static const int visibleMeasureCount = 6;

  /// La altura deja visibles seis compases completos, más el padding exterior.
  static const double gridMaxHeight =
      visibleMeasureCount * measureRowHeight + 8;

  /// {P} Se muestran cuatro tiempos en la misma fila.
  /// {C} Cada celda mide 42 px de alto y recibe una fracción del ancho de 400 px.
  /// {Q} Las casillas quedan apaisadas y caben seis compases dentro del viewport.
  static const double beatCellHeight = 42;

  /// Alto de una fila de compás, incluyendo el margen vertical entre filas.
  static const double measureRowHeight = beatCellHeight + 5.0;
}
