import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/bass_rhythm_pattern.dart';
import '../controllers/accordion_controller.dart';

/// Biblioteca de patrones rítmicos de bajos con soporte CRUD completo (Create/Copy, Read, Update, Delete).
///
/// Principios aplicados:
/// - **SRP**: sólo presenta la lista y diálogos auxiliares de edición, delegando la lógica al notifier.
/// - **ISP / bajo acoplamiento**: selectores finos para reactividad controlada.
/// - **Triplas de Hoare**: valida las precondiciones formales en el controlador.
class BassRhythmPatternLibraryWidget extends ConsumerWidget {
  final int accordionNumber;
  final double width;
  final double maxHeight;

  const BassRhythmPatternLibraryWidget({
    super.key,
    this.accordionNumber = 1,
    this.width = 240,
    this.maxHeight = 220,
  });

  static const double _rowExtent = 42.0;

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
                  onEdit: () => _showEditPatternDialog(context, pattern, notifier),
                  onDuplicate: () => notifier.duplicateBassRhythmPattern(pattern.id),
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

  void _showEditPatternDialog(
    BuildContext context,
    BassRhythmPattern pattern,
    AccordionSimulatorNotifier notifier,
  ) {
    final nameCtrl = TextEditingController(text: pattern.name);
    final bpmCtrl = TextEditingController(
      text: (pattern.quarterNotesPerMinute ?? 120.0).round().toString(),
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Editar Patrón de Bajos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del patrón',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bpmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tempo (BPM)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final parsedBpm = double.tryParse(bpmCtrl.text.trim());
              if (newName.isNotEmpty && parsedBpm != null && parsedBpm >= 30 && parsedBpm <= 300) {
                notifier.updateBassRhythmPattern(
                  patternId: pattern.id,
                  newName: newName,
                  newQuarterNotesPerMinute: parsedBpm,
                );
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  final BassRhythmPattern pattern;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  const _PatternRow({
    required this.pattern,
    required this.isSelected,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onSelect,
    required this.onEdit,
    required this.onDuplicate,
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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
              // Botón Editar (Update)
              IconButton(
                key: ValueKey('bass_pattern_edit_${pattern.id}'),
                tooltip: 'Editar patrón',
                onPressed: onEdit,
                constraints: const BoxConstraints.tightFor(width: 22, height: 22),
                padding: EdgeInsets.zero,
                splashRadius: 11,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              // Botón Duplicar (Create / Duplicate)
              IconButton(
                key: ValueKey('bass_pattern_copy_${pattern.id}'),
                tooltip: 'Duplicar patrón',
                onPressed: onDuplicate,
                constraints: const BoxConstraints.tightFor(width: 22, height: 22),
                padding: EdgeInsets.zero,
                splashRadius: 11,
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  key: ValueKey('bass_pattern_delete_${pattern.id}'),
                  tooltip: 'Eliminar patrón',
                  onPressed: onDelete,
                  constraints:
                      const BoxConstraints.tightFor(width: 22, height: 22),
                  padding: EdgeInsets.zero,
                  splashRadius: 11,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
