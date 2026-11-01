import 'package:flutter/material.dart';
import '../../core/constants/layout_constants.dart';
import 'chord_quality_selector_widget.dart';
import 'measure_grid_widget.dart';

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
    final link = LayerLink();
    return Row(
      key: ValueKey('measure_grid_with_chord_quality_$accordionNumber'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MeasureGridWidget(
          accordionNumber: accordionNumber,
          width: width,
          isUndocked: isUndocked,
          chordQualityLink: link,
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: Offset(width, 0),
          child: const ChordQualitySelectorWidget(),
        ),
      ],
    );
  }
}
