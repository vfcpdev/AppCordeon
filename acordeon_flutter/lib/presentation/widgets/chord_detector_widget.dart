import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';

class ChordDetectorWidget extends ConsumerWidget {
  const ChordDetectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    final chord = state.detectedChord;
    final hasSelection = state.detectorSelectedButtons.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Título y Controles
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.microchip, size: 14, color: Color(0xFF7C3AED)),
                  SizedBox(width: 6),
                  Text(
                    'Detector de Acordes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),

              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Botón Modo Selección (ON / OFF)
                  InkWell(
                    onTap: notifier.toggleDetectorMode,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: state.detectorMode ? const Color(0xFF7C3AED) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF7C3AED)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.handPointer,
                            size: 9,
                            color: state.detectorMode ? Colors.white : const Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Modo: ${state.detectorMode ? "ON" : "OFF"}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: state.detectorMode ? Colors.white : const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tocar
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.play, size: 9),
                    label: const Text('Tocar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(0, 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {},
                  ),

                  // Arpegio
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.music, size: 9),
                    label: const Text('Arpegio', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(0, 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {},
                  ),

                  // Limpiar
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.trashCan, size: 10, color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    onPressed: notifier.clearDetector,
                    tooltip: 'Limpiar selección',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Subbarra de dirección de fuelle al seleccionar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Fuelle:', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                    const SizedBox(width: 4),
                    ToggleButtons(
                      isSelected: [
                        state.detectorDirection == 'auto',
                        state.detectorDirection == 'push',
                        state.detectorDirection == 'pull',
                      ],
                      onPressed: (idx) {
                        final dirs = ['auto', 'push', 'pull'];
                        notifier.setDetectorDirection(dirs[idx]);
                      },
                      borderRadius: BorderRadius.circular(4),
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFF7C3AED),
                      constraints: const BoxConstraints(minHeight: 18, minWidth: 32),
                      children: const [
                        Text('Auto', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                        Text('Cierra', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                        Text('Abre', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${state.detectorSelectedButtons.length} botones',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Tira de botones seleccionados
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: hasSelection
                ? Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: state.detectorSelectedButtons.map((btnId) {
                      return Chip(
                        label: Text(btnId, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFFE0E7FF),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  )
                : const Text(
                    'Haz clic en los botones del diapasón para seleccionarlos...',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                  ),
          ),
          const SizedBox(height: 8),

          // Tarjeta de Resultado Armónico
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF4FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF0ABFC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACORDE IDENTIFICADO:',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7C3AED),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (chord != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Text(
                          chord.inversion,
                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                Text(
                  chord != null ? chord.name : 'Selecciona 2 o más botones',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: chord != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),

                // 4 Cajas Métricas (TÓNICA, BAJO REAL, ESTRUCTURA, TIPO)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        'TÓNICA',
                        chord?.root ?? '-',
                        const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildStatBox(
                        'BAJO REAL',
                        chord?.bass ?? '-',
                        const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildStatBox(
                        'ESTRUCTURA',
                        chord?.formula ?? '-',
                        const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildStatBox(
                        'TIPO',
                        chord?.type ?? '-',
                        const Color(0xFFDB2777),
                      ),
                    ),
                  ],
                ),

                if (chord != null && chord.alternatives.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'También puede ser: ${chord.alternatives.join(", ")}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
