import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../controllers/accordion_controller.dart';

class FreeChordWidget extends ConsumerWidget {
  const FreeChordWidget({super.key});

  static const List<String> roots = [
    'Do', 'Do#', 'Re', 'Mi♭', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'Si♭', 'Si'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final rootName = roots[state.freeChordRoot];

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
          // Cabecera: Título, Notas del acorde y Factibilidad
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.music, size: 13, color: Color(0xFF059669)),
                  const SizedBox(width: 2),
                  const Text(
                    'Constructor de Acorde',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                    ),
                  ),
                  // Tónica seleccionada (sigla del acorde resultante)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF22C55E)),
                    ),
                    child: Text(
                      '$rootName${_typeSymbol(state.freeChordType)}${_extensionSymbol(state.freeChordFourth, state.freeChordType)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),

              // Botones de acción: Play Acorde, Play Arpegio
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.play, size: 9),
                    label: const Text('Acorde', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      minimumSize: const Size(0, 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: notifier.playFreeChord,
                  ),
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.music, size: 9),
                    label: const Text('Arpegio', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      minimumSize: const Size(0, 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: notifier.arpeggioFreeChord,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fuelle para Acorde Libre
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Ambos (Abrir y Cerrar)',
                  child: InkWell(
                    onTap: () => notifier.setFreeChordBellows(BellowsMode.both),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: state.freeChordBellows == BellowsMode.both
                            ? const Color(0xFF4F46E5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.arrowsLeftRight,
                        size: 10,
                        color: state.freeChordBellows == BellowsMode.both
                            ? Colors.white
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Abre (Fuelle)',
                  child: InkWell(
                    onTap: () => notifier.setFreeChordBellows(BellowsMode.pull),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: state.freeChordBellows == BellowsMode.pull
                            ? const Color(0xFF2563EB)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.arrowLeft,
                        size: 10,
                        color: state.freeChordBellows == BellowsMode.pull
                            ? Colors.white
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Cierra (Fuelle)',
                  child: InkWell(
                    onTap: () => notifier.setFreeChordBellows(BellowsMode.push),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: state.freeChordBellows == BellowsMode.push
                            ? const Color(0xFFDC2626)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.arrowRight,
                        size: 10,
                        color: state.freeChordBellows == BellowsMode.push
                            ? Colors.white
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ══════════════ CONSTRUCTOR DE ACORDE (MATRICIAL) ══════════════
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tónica: 12 notas en matriz 4 × 3
              _buildMatrixSection(
                title: 'Tónica',
                color: const Color(0xFF0284C7),
                child: _buildMatrixGrid(
                  columns: 4,
                  cells: List.generate(roots.length, (idx) {
                    return _buildOptionButton(
                      sigla: roots[idx],
                      tooltip: 'Tónica ${roots[idx]}',
                      isActive: state.freeChordRoot == idx,
                      activeColor: const Color(0xFF059669),
                      onTap: () => notifier.setFreeChordRoot(idx),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),

              // Cualidad
              _buildMatrixSection(
                title: 'Cualidad',
                color: const Color(0xFF059669),
                child: _buildMatrixGrid(
                  columns: 5,
                  cells: [
                    _buildOptionButton(
                      sigla: 'M',
                      tooltip: 'Mayor',
                      isActive: state.freeChordType == 'maj',
                      activeColor: const Color(0xFF059669),
                      onTap: () => notifier.setFreeChordType('maj'),
                    ),
                    _buildOptionButton(
                      sigla: 'm',
                      tooltip: 'Menor',
                      isActive: state.freeChordType == 'min',
                      activeColor: const Color(0xFF059669),
                      onTap: () => notifier.setFreeChordType('min'),
                    ),
                    _buildOptionButton(
                      sigla: '°',
                      tooltip: 'Disminuido',
                      isActive: state.freeChordType == 'dim',
                      activeColor: const Color(0xFF059669),
                      onTap: () => notifier.setFreeChordType('dim'),
                    ),
                    _buildOptionButton(
                      sigla: '+',
                      tooltip: 'Aumentado',
                      isActive: state.freeChordType == 'aug',
                      activeColor: const Color(0xFF059669),
                      onTap: () => notifier.setFreeChordType('aug'),
                    ),
                    _buildOptionButton(
                      sigla: 'sus4',
                      tooltip: 'Suspendido 4',
                      isActive: state.freeChordType == 'sus4',
                      activeColor: const Color(0xFF059669),
                      onTap: () => notifier.setFreeChordType('sus4'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Estructura
              _buildMatrixSection(
                title: 'Estructura',
                color: const Color(0xFFEA580C),
                child: _buildMatrixGrid(
                  columns: 2,
                  cells: [
                    _buildOptionButton(
                      sigla: '3',
                      tooltip: 'Tríada',
                      isActive: state.freeChordScaleHarmonicMode == 'triad',
                      activeColor: const Color(0xFFEA580C),
                      onTap: () => notifier.setFreeChordScaleHarmonicMode('triad'),
                    ),
                    _buildOptionButton(
                      sigla: '4',
                      tooltip: 'Cuatríada (7mas)',
                      isActive: state.freeChordScaleHarmonicMode == 'seventh',
                      activeColor: const Color(0xFFEA580C),
                      onTap: () => notifier.setFreeChordScaleHarmonicMode('seventh'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

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

              // Extensión: matriz 4 columnas × 2 filas
              // Fila 1: séptimas · Fila 2: añadidas + casilla "sin extensión"
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
                      sigla: 'm7',
                      tooltip: 'Séptima menor',
                      isActive: state.freeChordFourth == 'min7',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('min7'),
                    ),
                    _buildOptionButton(
                      sigla: '°7',
                      tooltip: 'Séptima disminuida',
                      isActive: state.freeChordFourth == 'dim7',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('dim7'),
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
                      isActive: state.freeChordFourth == 'none',
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => notifier.setFreeChordFourth('none'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Escala del Acorde Libre (Grados I, ii, iii, IV, V, vi, vii°)
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), style: BorderStyle.solid)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Grados de la escala de $rootName',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Chips de Grados Armónicos
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildDegreeChip('I', rootName, 'Mayor', () => notifier.selectFreeChordDegree(0, 'Mayor'), isActive: true),
                    _buildDegreeChip('ii', _getRelative(rootName, 2), 'menor', () => notifier.selectFreeChordDegree(2, 'menor')),
                    _buildDegreeChip('iii', _getRelative(rootName, 4), 'menor', () => notifier.selectFreeChordDegree(4, 'menor')),
                    _buildDegreeChip('IV', _getRelative(rootName, 5), 'Mayor', () => notifier.selectFreeChordDegree(5, 'Mayor')),
                    _buildDegreeChip('V', _getRelative(rootName, 7), 'Mayor', () => notifier.selectFreeChordDegree(7, 'Mayor')),
                    _buildDegreeChip('vi', _getRelative(rootName, 9), 'menor', () => notifier.selectFreeChordDegree(9, 'menor')),
                    _buildDegreeChip('vii°', _getRelative(rootName, 11), 'disminuido', () => notifier.selectFreeChordDegree(11, 'disminuido')),
                  ],
                ),
              ],
            ),
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
            Text(
              title,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.3,
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
            boxShadow: isActive
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 6)]
                : null,
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

  /// Sigla de la cualidad (M, m, °, +, sus4).
  static String _typeSymbol(String type) {
    switch (type) {
      case 'maj':
        return '';
      case 'min':
        return 'm';
      case 'dim':
        return '°';
      case 'aug':
        return '+';
      case 'sus4':
        return 'sus4';
      default:
        return '';
    }
  }

  /// Sigla de la extensión (—, 8, 6, add9, 7, maj7, m7, °7).
  static String _extensionSymbol(String ext, [String type = '']) {
    switch (ext) {
      case 'octave':
        return '8';
      case 'dom7':
        return '7';
      case 'maj7':
        return 'maj7';
      case 'maj6':
        return '6';
      case 'add9':
        return 'add9';
      case 'min7':
        return type == 'min' ? '7' : 'm7';
      case 'dim7':
        return type == 'dim' ? '7' : '°7';
      default:
        return '';
    }
  }

  Widget _buildDegreeChip(String roman, String note, String quality, VoidCallback onTap, {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            Text(
              roman,
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: isActive ? const Color(0xFF059669) : const Color(0xFF059669)),
            ),
            Text(
              note,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF065F46) : const Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }



  static String _getRelative(String root, int semitones) {
    final idx = roots.indexOf(root);
    if (idx == -1) return '';
    return roots[(idx + semitones) % 12];
  }
}
