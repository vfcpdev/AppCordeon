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
/// Muestra la lista de acordeones disponibles con nombre, hileras y desplazamiento
/// expresado en tonos y semitonos (ej. +1½ T, -2½ T), permitiendo ordenar por
/// tono ascendente y reorganizar mediante Drag & Drop.
Future<void> showTuningPickerDialog({
  required BuildContext context,
  required TuningDefinition currentTuning,
  required ValueChanged<TuningDefinition?> onTuningChanged,
}) {
  return showDialog(
    context: context,
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
  late List<TuningDefinition> _tunings;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentTuning;
    _tunings = List.from(TuningRegistry.orderedTunings);
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _tunings.removeAt(oldIndex);
      _tunings.insert(newIndex, item);
    });
    TuningRegistry.setOrderedTunings(_tunings);
  }

  void _sortByPitchAscending() {
    setState(() {
      _tunings.sort((a, b) => a.offset.compareTo(b.offset));
    });
    TuningRegistry.setOrderedTunings(_tunings);
  }

  void _resetOrder() {
    setState(() {
      _tunings = List.from(TuningRegistry.defaultTunings);
    });
    TuningRegistry.setOrderedTunings(_tunings);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Container(
        width: 350,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cabecera Principal ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _greenSoft,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.music,
                      size: 13,
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar acordeón',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Afinaciones diatónicas',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // ── Barra de herramientas: Tono ascendente y Restablecer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón: Ordenar de forma ascendente por tono
                    InkWell(
                      key: const ValueKey('btn_sort_pitch_asc'),
                      onTap: _sortByPitchAscending,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: _greenSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _green.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(FontAwesomeIcons.arrowUpWideShort, size: 9.5, color: _green),
                            SizedBox(width: 4),
                            Text(
                              'Tono ascendente',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Botón: Restablecer orden predeterminado
                    InkWell(
                      key: const ValueKey('btn_reset_tuning_order'),
                      onTap: _resetOrder,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _line),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 8.5, color: _muted),
                            SizedBox(width: 4),
                            Text(
                              'Restablecer',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: _line),

            // ── Lista reordenable con Drag & Drop ──────────────────────
            Flexible(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                shrinkWrap: true,
                itemCount: _tunings.length,
                onReorderItem: _onReorderItem,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 6,
                    color: Colors.transparent,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    child: child,
                  );
                },
                itemBuilder: (ctx, i) {
                  final tuning = _tunings[i];
                  return _TuningListItem(
                    key: ValueKey(tuning.id),
                    tuning: tuning,
                    isSelected: tuning.id == _selected.id,
                    index: i,
                    onTap: () {
                      setState(() => _selected = tuning);
                      widget.onTuningChanged(tuning);
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
    super.key,
    required this.tuning,
    required this.isSelected,
    required this.index,
    required this.onTap,
  });

  /// Convierte el desplazamiento en semitonos a expresión en tonos y semitonos (ej: +1½ T, -2½ T).
  static String formatToneOffset(int offset) {
    if (offset == 0) return 'Base';
    final sign = offset > 0 ? '+' : '-';
    final abs = offset.abs();
    final tones = abs ~/ 2;
    final hasHalf = abs % 2 == 1;

    if (tones == 0 && hasHalf) {
      return '$sign½ T';
    } else if (tones > 0 && !hasHalf) {
      return '$sign$tones T';
    } else {
      return '$sign$tones½ T';
    }
  }

  /// Explicación completa para el tooltip.
  static String toneOffsetTooltip(int offset) {
    if (offset == 0) return 'Afinación base (±0 semitonos)';
    final abs = offset.abs();
    final tones = abs ~/ 2;
    final hasHalf = abs % 2 == 1;
    String toneStr;
    if (tones == 0 && hasHalf) {
      toneStr = 'medio tono (1 semitono)';
    } else if (tones > 0 && !hasHalf) {
      toneStr = '$tones tono${tones > 1 ? "s" : ""} ($abs semitonos)';
    } else {
      toneStr = '$tones tono${tones > 1 ? "s" : ""} y medio ($abs semitonos)';
    }
    final direction = offset > 0 ? 'más agudo' : 'más grave';
    return '$toneStr $direction que Cinco Letras';
  }

  @override
  Widget build(BuildContext context) {
    final toneLabel = formatToneOffset(tuning.offset);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? _greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? _green.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.3 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Área clickeable para seleccionar la afinación
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                    child: Row(
                      children: [
                        // Indicador de posición o selección
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected ? _green : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? _green : _line,
                            ),
                          ),
                          child: Center(
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: _muted,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Nombre + hileras
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tuning.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? _green : _ink,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                tuning.rowsDescription,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Badge de desplazamiento expresado en tonos y semitonos (ej: +1½ T, -2½ T)
                        Tooltip(
                          message: toneOffsetTooltip(tuning.offset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _green.withValues(alpha: 0.15)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSelected
                                    ? _green.withValues(alpha: 0.35)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              toneLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? _green : const Color(0xFF334155),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Separador vertical sutil
              Container(
                width: 1,
                height: 20,
                color: const Color(0xFFE2E8F0),
              ),

              // Manilla para arrastrar y soltar (Drag & Drop)
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: 'Arrastrar para personalizar el orden',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      key: ValueKey('drag_handle_${tuning.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                      color: Colors.transparent,
                      child: const FaIcon(
                        FontAwesomeIcons.gripVertical,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
