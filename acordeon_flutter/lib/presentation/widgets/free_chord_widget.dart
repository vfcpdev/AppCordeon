import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';

class FreeChordWidget extends ConsumerWidget {
  const FreeChordWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(8),
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
          // Cabecera: título, botones de reproducción (aumentados 50%) y checkbox Fijo
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Text(
                'Acorde',
                key: ValueKey('free_chord_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF059669),
                ),
              ),

              // Botones de acción: Play Acorde (+50%), Play Arpegio (+50%) y Checkbox Fijo
              Wrap(
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tooltip(
                    message: 'Reproducir Acorde',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(32, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: notifier.playFreeChord,
                      child: const FaIcon(FontAwesomeIcons.play, size: 13),
                    ),
                  ),
                  Tooltip(
                    message: 'Reproducir Arpegio',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(32, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: notifier.arpeggioFreeChord,
                      child: const FaIcon(FontAwesomeIcons.music, size: 13),
                    ),
                  ),
                  // Checkbox para mantener el acorde fijo en el acordeón seleccionado
                  Tooltip(
                    message: 'Fijar acorde en el acordeón',
                    child: InkWell(
                      key: const ValueKey('free_chord_fixed_checkbox'),
                      onTap: notifier.toggleFreeChordFixed,
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: Checkbox(
                              value: state.isFreeChordFixed,
                              onChanged: (_) => notifier.toggleFreeChordFixed(),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              activeColor: const Color(0xFF059669),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Fijo',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ══════════════ CONSTRUCTOR DE ACORDE (MATRICIAL) ══════════════
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Octava
              _buildMatrixSection(
                title: 'Octava',
                color: const Color(0xFF0284C7),
                child: _buildMatrixGrid(
                  columns: 4,
                  cells: [
                    _buildOptionButton(
                      sigla: 'Todas',
                      tooltip: 'Todas las octavas',
                      isActive: state.freeChordOctave == 'all',
                      activeColor: const Color(0xFF0284C7),
                      onTap: () => notifier.setFreeChordOctave('all'),
                    ),
                    _buildOptionButton(
                      sigla: '3',
                      tooltip: 'Octava 3',
                      isActive: state.freeChordOctave == '3',
                      activeColor: const Color(0xFF0284C7),
                      onTap: () => notifier.setFreeChordOctave('3'),
                    ),
                    _buildOptionButton(
                      sigla: '4',
                      tooltip: 'Octava 4',
                      isActive: state.freeChordOctave == '4',
                      activeColor: const Color(0xFF0284C7),
                      onTap: () => notifier.setFreeChordOctave('4'),
                    ),
                    _buildOptionButton(
                      sigla: '5',
                      tooltip: 'Octava 5',
                      isActive: state.freeChordOctave == '5',
                      activeColor: const Color(0xFF0284C7),
                      onTap: () => notifier.setFreeChordOctave('5'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              _buildMatrixSection(
                title: 'Extensión',
                color: const Color(0xFF7C3AED),
                child: _buildMatrixGrid(
                  columns: 4,
                  cells: [
                    _buildOptionButton(
                      sigla: '7',
                      tooltip: 'Séptima dominante',
                      isActive: state.freeChordFourth == 'dom7',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('dom7'),
                    ),
                    _buildOptionButton(
                      sigla: 'maj7',
                      tooltip: 'Séptima mayor',
                      isActive: state.freeChordFourth == 'maj7',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('maj7'),
                    ),
                    _buildOptionButton(
                      sigla: '6',
                      tooltip: 'Sexta mayor',
                      isActive: state.freeChordFourth == 'maj6',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('maj6'),
                    ),
                    _buildOptionButton(
                      sigla: 'add9',
                      tooltip: 'Novena añadida',
                      isActive: state.freeChordFourth == 'add9',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('add9'),
                    ),
                    _buildOptionButton(
                      sigla: '8',
                      tooltip: 'Octava añadida',
                      isActive: state.freeChordFourth == 'octave',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('octave'),
                    ),
                    _buildOptionButton(
                      sigla: '—',
                      tooltip: 'Sin extensión',
                      isActive:
                          state.freeChordRoot >= 0 &&
                          (state.freeChordFourth == 'none' ||
                              state.freeChordFourth.isEmpty),
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('none'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Bajo alterado / Inversión con barra '/'
              _buildMatrixSection(
                title: 'Bajo (/)',
                color: const Color(0xFF0D9488),
                child: _buildMatrixGrid(
                  columns: 4,
                  cells: [
                    _buildOptionButton(
                      sigla: '—',
                      tooltip: 'Fundamental (sin bajo alterado)',
                      isActive:
                          state.freeChordRoot >= 0 &&
                          (state.freeChordBass.isEmpty ||
                              state.freeChordBass == 'none'),
                      activeColor: const Color(0xFF0D9488),
                      onTap: () => notifier.setFreeChordBass(''),
                    ),
                    _buildOptionButton(
                      sigla: '/3',
                      tooltip: '1ª Inversión (Bajo en 3ra)',
                      isActive:
                          state.freeChordBass == '3' ||
                          state.freeChordBass == '/3',
                      activeColor: const Color(0xFF0D9488),
                      onTap: () => notifier.setFreeChordBass('3'),
                    ),
                    _buildOptionButton(
                      sigla: '/5',
                      tooltip: '2ª Inversión (Bajo en 5ta)',
                      isActive:
                          state.freeChordBass == '5' ||
                          state.freeChordBass == '/5',
                      activeColor: const Color(0xFF0D9488),
                      onTap: () => notifier.setFreeChordBass('5'),
                    ),
                    _buildOptionButton(
                      sigla: '/7',
                      tooltip: '3ª Inversión (Bajo en 7ma)',
                      isActive:
                          state.freeChordBass == '7' ||
                          state.freeChordBass == '/7',
                      activeColor: const Color(0xFF0D9488),
                      onTap: () => notifier.setFreeChordBass('7'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sección matricial: etiqueta pequeña + rejilla de celdas alineadas.
  Widget _buildMatrixSection({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: child,
        ),
      ],
    );
  }

  /// Distribuye las celdas en filas de [columns] columnas de igual ancho.
  Widget _buildMatrixGrid({
    required int columns,
    required List<Widget> cells,
    double spacing = 3,
    double rowHeight = 24,
  }) {
    final rows = <Widget>[];
    for (var start = 0; start < cells.length; start += columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) SizedBox(width: spacing),
                Expanded(
                  child: start + col < cells.length
                      ? cells[start + col]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  /// Botón compacto con sigla de acorde (M, m, °, +, 7, maj7…).
  Widget _buildOptionButton({
    required String sigla,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    double minWidth = 26,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 22),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isActive ? activeColor : const Color(0xFFCBD5E1),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              sigla,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: isActive ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
