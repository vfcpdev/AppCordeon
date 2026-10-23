import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/tuning.dart';

/// Modal de selección de afinación de acordeón.
/// Muestra la lista de acordeones disponibles como items con nombre, hileras y offset.
Future<void> showTuningPickerDialog({
  required BuildContext context,
  required TuningDefinition currentTuning,
  required ValueChanged<TuningDefinition?> onTuningChanged,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => _TuningPickerDialog(
      currentTuning: currentTuning,
      onTuningChanged: onTuningChanged,
    ),
  );
}

class _TuningPickerDialog extends StatefulWidget {
  final TuningDefinition currentTuning;
  final ValueChanged<TuningDefinition?> onTuningChanged;

  const _TuningPickerDialog({
    required this.currentTuning,
    required this.onTuningChanged,
  });

  @override
  State<_TuningPickerDialog> createState() => _TuningPickerDialogState();
}

class _TuningPickerDialogState extends State<_TuningPickerDialog> {
  late TuningDefinition _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentTuning;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cabecera ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.music,
                      size: 18,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Acordeón',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Afinaciones diatónicas disponibles',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // ── Lista de acordeones ───────────────────────────────────
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: TuningRegistry.defaultTunings.length,
                itemBuilder: (ctx, i) {
                  final tuning = TuningRegistry.defaultTunings[i];
                  final isSelected = tuning.id == _selected.id;

                  return _TuningListItem(
                    tuning: tuning,
                    isSelected: isSelected,
                    index: i,
                    onTap: () {
                      setState(() => _selected = tuning);
                      widget.onTuningChanged(tuning);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TuningListItem extends StatelessWidget {
  final TuningDefinition tuning;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;

  const _TuningListItem({
    required this.tuning,
    required this.isSelected,
    required this.index,
    required this.onTap,
  });

  // Colores de acento cíclicos para dar vida a la lista
  static const _accents = [
    Color(0xFF0284C7), // sky
    Color(0xFF059669), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
    Color(0xFF0891B2), // cyan
    Color(0xFFD97706), // orange
    Color(0xFF0369A1), // sky-700
  ];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accent.withValues(alpha: 0.6) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Indicador de color / índice
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? accent : accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Nombre + hileras
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tuning.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tuning.rowsDescription,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? accent.withValues(alpha: 0.9) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Offset badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tuning.offset == 0
                        ? '±0'
                        : (tuning.offset > 0 ? '+${tuning.offset}' : '${tuning.offset}'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
