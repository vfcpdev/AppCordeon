import 'package:flutter/material.dart';
import '../../core/constants/layout_constants.dart';
import 'chord_quality_selector_widget.dart';
import 'measure_grid_widget.dart';

/// Contenedor de la sección de Compás que integra la cuadrícula de compases,
/// la barra de herramientas, la matriz de tónicas y el selector de cualidades.
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Actúa como façade de integración de la sección de compás.
/// - Open/Closed Principle (OCP): Permite acoplar y desacoplar sin alterar la lógica interna.
class MeasureGridWithChordQualityWidget extends StatelessWidget {
  static double contentWidth(double gridWidth) =>
      gridWidth + ChordQualitySelectorWidget.layoutWidth;

  final int accordionNumber;
  final double width;
  final bool isUndocked;

  const MeasureGridWithChordQualityWidget({
    super.key,
    this.accordionNumber = 1,
    this.width = CompasCardMetrics.gridWidth,
    this.isUndocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return MeasureGridWidget(
      key: ValueKey('measure_grid_with_chord_quality_$accordionNumber'),
      accordionNumber: accordionNumber,
      width: width,
      isUndocked: isUndocked,
    );
  }
}
