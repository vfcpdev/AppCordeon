import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/accordion_controller.dart';

class ChordQualitySelectorWidget extends ConsumerWidget {
  static const double layoutWidth = 61;

  const ChordQualitySelectorWidget({super.key});

  static const _qualities = [
    (symbol: 'M', name: 'Mayor', value: 'maj'),
    (symbol: 'm', name: 'Menor', value: 'min'),
    (symbol: '°', name: 'Disminuido', value: 'dim'),
    (symbol: '+', name: 'Aumentado', value: 'aug'),
    (symbol: 'Sus2', name: 'Suspendido 2', value: 'sus2'),
    (symbol: 'Sus4', name: 'Suspendido 4', value: 'sus4'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedValues = ref.watch(
      accordionSimulatorProvider.select(
        (state) => (
          quality: state.freeChordType,
          structure: state.freeChordScaleHarmonicMode,
        ),
      ),
    );
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(top: 4.5, left: 2, right: 2),
      child: SizedBox(
        width: layoutWidth - 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('chord_qualities_container'),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final quality in _qualities) ...[
                    if (quality != _qualities.first) const SizedBox(height: 2),
                    Tooltip(
                      message: quality.name,
                      child: InkWell(
                        key: ValueKey('chord_quality_${quality.value}'),
                        onTap: () => notifier.setFreeChordType(quality.value),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 90),
                          width: 45,
                          height: 19,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selectedValues.quality == quality.value
                                ? const Color(0xFF059669)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selectedValues.quality == quality.value
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              quality.symbol,
                              style: TextStyle(
                                fontSize: quality.symbol.length > 1 ? 8 : 10,
                                fontWeight: FontWeight.w900,
                                color: selectedValues.quality == quality.value
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              key: const ValueKey('chord_structure_container'),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Estructura',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
                  _buildStructureButton(
                    key: 'chord_structure_triad',
                    label: '3',
                    tooltip: 'Tríada: 3 notas',
                    isSelected: selectedValues.structure == 'triad',
                    onTap: () =>
                        notifier.setFreeChordScaleHarmonicMode('triad'),
                  ),
                  const SizedBox(height: 2),
                  _buildStructureButton(
                    key: 'chord_structure_seventh',
                    label: '4',
                    tooltip: 'Cuatríada: 4 notas',
                    isSelected: selectedValues.structure == 'seventh',
                    onTap: () =>
                        notifier.setFreeChordScaleHarmonicMode('seventh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructureButton({
    required String key,
    required String label,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 45,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEA580C) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC2410C)
                  : const Color(0xFFFDBA74),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : const Color(0xFF9A3412),
            ),
          ),
        ),
      ),
    );
  }
}
