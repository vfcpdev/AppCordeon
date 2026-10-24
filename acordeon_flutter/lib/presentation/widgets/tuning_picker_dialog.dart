import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/tuning.dart';

// Paleta minimalista clara
const Color _green = Color(0xFF059669);
const Color _greenSoft = Color(0xFFECFDF5);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE2E8F0);

/// Modal de selección de afinación de acordeón.
/// Muestra la lista de acordeones disponibles como items con nombre, hileras y offset.
Future<void> showTuningPickerDialog({
  required BuildContext context,
  required TuningDefinition currentTuning,
  required ValueChanged<TuningDefinition?> onTuningChanged,
}) {
  return showDialog(
    context: context,
    // Sin fondo oscuro: modal minimalista sobre la interfaz
    barrierColor: Colors.transparent,
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
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cabecera ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _greenSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.music,
                      size: 14,
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar acordeón',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Afinaciones diatónicas disponibles',
                          style: TextStyle(fontSize: 10.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),

            // ── Lista de acordeones ───────────────────────────────────
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shrinkWrap: true,
                itemCount: TuningRegistry.defaultTunings.length,
                itemBuilder: (ctx, i) {
                  final tuning = TuningRegistry.defaultTunings[i];
                  return _TuningListItem(
                    tuning: tuning,
                    isSelected: tuning.id == _selected.id,
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

  @override
  Widget build(BuildContext context) {
    final offsetLabel = tuning.offset == 0
        ? '±0'
        : (tuning.offset > 0 ? '+${tuning.offset}' : '${tuning.offset}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              // Solo el acordeón activo lleva color; el resto queda neutro
              color: isSelected ? _greenSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _green.withValues(alpha: 0.45) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Indicador: check verde si está activo, número neutro si no
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected ? _green : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isSelected ? _green : _line,
                    ),
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _muted,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nombre + hileras
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tuning.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? _green : _ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        tuning.rowsDescription,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Offset
                Text(
                  offsetLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _green : _muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
