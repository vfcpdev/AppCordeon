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
                    'Acorde Libre',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Notas: $rootName · ${_getThird(rootName, state.freeChordType)} · ${_getFifth(rootName, state.freeChordType)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

          // Selectores: Tónica, Tipo, 4ta nota y Octava
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Selector Tónica
              DropdownButton<int>(
                value: state.freeChordRoot,
                isDense: true,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                items: List.generate(roots.length, (idx) {
                  return DropdownMenuItem(value: idx, child: Text(roots[idx]));
                }),
                onChanged: (v) {
                  if (v != null) notifier.setFreeChordRoot(v);
                },
              ),

              // Selector Tipo
              DropdownButton<String>(
                value: state.freeChordType,
                isDense: true,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'maj', child: Text('Mayor')),
                  DropdownMenuItem(value: 'min', child: Text('Menor')),
                  DropdownMenuItem(value: 'dim', child: Text('Disminuido')),
                  DropdownMenuItem(value: 'aug', child: Text('Aumentado')),
                  DropdownMenuItem(value: 'sus4', child: Text('Suspendido 4')),
                ],
                onChanged: (v) {
                  if (v != null) notifier.setFreeChordType(v);
                },
              ),

              // Selector 4ta nota
              DropdownButton<String>(
                value: state.freeChordFourth,
                isDense: true,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Sin 4ta (Tríada)')),
                  DropdownMenuItem(value: 'octave', child: Text('+ Octava (+8va)')),
                  DropdownMenuItem(value: 'dom7', child: Text('+ 7ma Dominante')),
                  DropdownMenuItem(value: 'maj7', child: Text('+ 7ma Mayor (Maj7)')),
                  DropdownMenuItem(value: 'maj6', child: Text('+ 6ta Mayor')),
                  DropdownMenuItem(value: 'add9', child: Text('+ 9na (Add9)')),
                ],
                onChanged: (v) {
                  if (v != null) notifier.setFreeChordFourth(v);
                },
              ),

              // Toggle Octava
              ToggleButtons(
                isSelected: [
                  state.freeChordOctave == 'all',
                  state.freeChordOctave == '3',
                  state.freeChordOctave == '4',
                  state.freeChordOctave == '5',
                ],
                onPressed: (idx) {
                  final vals = ['all', '3', '4', '5'];
                  notifier.setFreeChordOctave(vals[idx]);
                },
                borderRadius: BorderRadius.circular(6),
                selectedColor: Colors.white,
                fillColor: const Color(0xFF0284C7),
                constraints: const BoxConstraints(minHeight: 22, minWidth: 32),
                children: const [
                  Text('Todas', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('3', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('4', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('5', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                ],
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
                      'Escala del Acorde: $rootName Mayor',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                        letterSpacing: 0.3,
                      ),
                    ),
                    ToggleButtons(
                      isSelected: [
                        state.freeChordScaleHarmonicMode == 'triad',
                        state.freeChordScaleHarmonicMode == 'seventh',
                      ],
                      onPressed: (idx) {
                        notifier.setFreeChordScaleHarmonicMode(idx == 0 ? 'triad' : 'seventh');
                      },
                      borderRadius: BorderRadius.circular(4),
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFF059669),
                      constraints: const BoxConstraints(minHeight: 18, minWidth: 44),
                      children: const [
                        Text('Tríadas', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                        Text('7mas', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Chips de Grados Armónicos
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildDegreeChip('I', rootName, 'Mayor', () => notifier.selectFreeChordDegree(0, 'Mayor')),
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

  Widget _buildDegreeChip(String roman, String note, String quality, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            Text(
              roman,
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
            ),
            Text(
              note,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  static String _getThird(String root, String type) {
    final idx = roots.indexOf(root);
    if (idx == -1) return '';
    final semitones = (type == 'min' || type == 'dim') ? 3 : 4;
    return roots[(idx + semitones) % 12];
  }

  static String _getFifth(String root, String type) {
    final idx = roots.indexOf(root);
    if (idx == -1) return '';
    final semitones = type == 'dim' ? 6 : (type == 'aug' ? 8 : 7);
    return roots[(idx + semitones) % 12];
  }

  static String _getRelative(String root, int semitones) {
    final idx = roots.indexOf(root);
    if (idx == -1) return '';
    return roots[(idx + semitones) % 12];
  }
}
