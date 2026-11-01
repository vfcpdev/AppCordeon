import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/accordion_controller.dart';

class ChordQualitySelectorWidget extends ConsumerWidget {
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
    final selectedQuality = ref.watch(
      accordionSimulatorProvider.select((state) => state.freeChordType),
    );
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(top: 4.5, left: 2, right: 2),
      child: SizedBox(
        width: 31,
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
                    width: 27,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedQuality == quality.value
                          ? const Color(0xFF059669)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: selectedQuality == quality.value
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
                          color: selectedQuality == quality.value
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
    );
  }
}
