import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/bass_rhythm_pattern.dart';
import '../controllers/accordion_controller.dart';

/// Biblioteca de patrones rítmicos de bajos.
///
/// Lista los patrones integrados del catálogo, los importados desde MusicXML
/// y los capturados en vivo (matriz 2×2 o teclado). Desde aquí se pueden
/// reproducir, seleccionar y eliminar los patrones guardados.
///
/// Principios aplicados:
/// - **SRP**: sólo presenta la lista y delega la lógica al notifier.
/// - **ISP / bajo acoplamiento**: usa selectores finos; no escucha el estado
///   completo del simulador ni reconstruye el panel de bajos.
/// - **OCP**: agregar patrones no requiere tocar este widget.
/// - **Triplas de Hoare**: las precondiciones ({P}) se validan en el
///   notifier con `require`; aquí sólo se ofrecen acciones válidas.
class BassRhythmPatternLibraryWidget extends ConsumerWidget {
  final int accordionNumber;

  /// Ancho fijo de la lista.
  ///
  /// Cuando el widget se embebe en contenedores con `IntrinsicWidth` es
  /// necesario un ancho concreto: un `ListView` (viewport) no implementa
  /// dimensiones intrínsecas.
  final double width;

  /// Altura máxima visible de la lista antes de hacer scroll.
  final double maxHeight;

  const BassRhythmPatternLibraryWidget({
    super.key,
    this.accordionNumber = 1,
    this.width = 210,
    this.maxHeight = 168,
  });

  static const double _rowExtent = 38.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(
      accordionSimulatorProvider.select((s) => s.bassRhythmPatterns),
    );
    final selectedId = ref.watch(
      accordionSimulatorProvider.select((s) => s.selectedBassRhythmPatternId),
    );
    final isPlaying = ref.watch(
      accordionSimulatorProvider.select((s) => s.isBassMetronomeActive),
    );
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    if (patterns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Aún no hay patrones guardados.',
          key: ValueKey('bass_pattern_library_empty'),
          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      );
    }

    return Column(
      key: ValueKey('bass_pattern_library_$accordionNumber'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Patrones guardados',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            Text(
              '${patterns.length}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: width,
          height: (patterns.length * _rowExtent)
              .clamp(_rowExtent, maxHeight)
              .toDouble(),
          child: Scrollbar(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: patterns.length,
              separatorBuilder: (_, index) => const SizedBox(height: 3),
              itemBuilder: (context, index) {
                final pattern = patterns[index];
                return _PatternRow(
                  pattern: pattern,
                  isSelected: pattern.id == selectedId,
                  isPlaying: pattern.id == selectedId && isPlaying,
                  onTogglePlayback: () =>
                      notifier.toggleBassRhythmPatternPlayback(pattern.id),
                  onSelect: () =>
                      notifier.selectBassRhythmPattern(pattern.id),
                  onDelete: pattern.id.startsWith('builtin:')
                      ? null
                      : () => notifier.deleteBassRhythmPattern(pattern.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PatternRow extends StatelessWidget {
  final BassRhythmPattern pattern;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  const _PatternRow({
    required this.pattern,
    required this.isSelected,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bpm = pattern.quarterNotesPerMinute;
    final subtitle = <String>[
      '${pattern.hits.length} golpe(s)',
      if (bpm != null) '${bpm.round()} BPM',
    ].join(' · ');

    return Material(
      key: ValueKey('bass_pattern_row_${pattern.id}'),
      color: isPlaying
          ? const Color(0xFFDCFCE7)
          : isSelected
              ? const Color(0xFFE0F2FE)
              : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isPlaying
                  ? const Color(0xFF16A34A)
                  : isSelected
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                key: ValueKey('bass_pattern_toggle_${pattern.id}'),
                tooltip: isPlaying ? 'Detener patrón' : 'Reproducir patrón',
                onPressed: onTogglePlayback,
                constraints:
                    const BoxConstraints.tightFor(width: 26, height: 26),
                padding: EdgeInsets.zero,
                splashRadius: 13,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 19,
                  color: isPlaying
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pattern.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPlaying
                            ? const Color(0xFF15803D)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  key: ValueKey('bass_pattern_delete_${pattern.id}'),
                  tooltip: 'Eliminar patrón',
                  onPressed: onDelete,
                  constraints:
                      const BoxConstraints.tightFor(width: 24, height: 24),
                  padding: EdgeInsets.zero,
                  splashRadius: 12,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
