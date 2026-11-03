import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/accordion_controller.dart';

/// Selector horizontal de cualidades de acordes (Mayor, Menor, Disminuido, Aumentado, Sus2, Sus4).
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Encapsula la selección de la cualidad del acorde.
/// - Tripla de Hoare:
///   - Precondición {P}: `quality.value` es uno de los tipos soportados ('maj', 'min', 'dim', 'aug', 'sus2', 'sus4').
///   - Ejecución {C}: `notifier.setFreeChordType(quality.value)`.
///   - Poscondición {Q}: `state.freeChordType == quality.value`.
class ChordQualitySelectorWidget extends ConsumerWidget {
  static const double layoutWidth = 0;

  const ChordQualitySelectorWidget({super.key});

  static const qualities = [
    (symbol: 'M', name: 'Mayor', value: 'maj'),
    (symbol: 'm', name: 'Menor', value: 'min'),
    (symbol: '°', name: 'Disminuido', value: 'dim'),
    (symbol: '+', name: 'Aumentado', value: 'aug'),
    (symbol: 'Sus2', name: 'Suspendido 2', value: 'sus2'),
    (symbol: 'Sus4', name: 'Suspendido 4', value: 'sus4'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedValue = ref.watch(
      accordionSimulatorProvider.select((state) => state.freeChordType),
    );
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Container(
      key: const ValueKey('chord_qualities_container'),
      child: Row(
        children: qualities.map((quality) {
          final isSelected = selectedValue == quality.value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Tooltip(
                message: quality.name,
                child: InkWell(
                  key: ValueKey('chord_quality_${quality.value}'),
                  onTap: () => notifier.setFreeChordType(quality.value),
                  borderRadius: BorderRadius.circular(4),
                  child: AspectRatio(
                    aspectRatio: 2.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF059669) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                          width: isSelected ? 1.2 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 0.5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            quality.symbol,
                            style: TextStyle(
                              fontSize: quality.symbol.length > 2 ? 8.5 : 10.0,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
