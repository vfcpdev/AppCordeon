import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';

/// Modal flotante y movible para asignar un acorde a múltiples compases y cuadros.
/// Formato de entrada: Compás.Cuadro separado por comas (ej: 1.1, 2.3, 5.2).
class MultiBeatChordDialog extends ConsumerStatefulWidget {
  const MultiBeatChordDialog({super.key});

  @override
  ConsumerState<MultiBeatChordDialog> createState() => _MultiBeatChordDialogState();
}

class _MultiBeatChordDialogState extends ConsumerState<MultiBeatChordDialog> {
  late final TextEditingController _controller;
  Offset _position = const Offset(260, 90);
  bool _hasCalculatedInitialPos = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(accordionSimulatorProvider);
    var pattern = state.multiBeatPattern;
    if (pattern.isEmpty) {
      final currentChord = state.multiBeatChord?.trim().isNotEmpty == true
          ? state.multiBeatChord!
          : ChordCatalog.symbolFor(
              root: state.freeChordRoot,
              type: state.freeChordType,
              extension: state.freeChordFourth,
              latin: state.notation != NotationMode.alemana,
            );
      if (currentChord.isNotEmpty) {
        final pos = <String>[];
        for (var m = 0; m < state.measures.length; m++) {
          for (var b = 0; b < state.measures[m].beats.length; b++) {
            if (state.measures[m].beats[b].chord.trim() == currentChord) {
              pos.add('${m + 1}.${b + 1}');
            }
          }
        }
        pattern = pos.join(', ');
      }
    }
    _controller = TextEditingController(text: pattern);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final state = ref.read(accordionSimulatorProvider);

    final chord = state.multiBeatChord?.trim().isNotEmpty == true
        ? state.multiBeatChord!
        : ChordCatalog.symbolFor(
            root: state.freeChordRoot,
            type: state.freeChordType,
            extension: state.freeChordFourth,
            latin: state.notation != NotationMode.alemana,
          );

    final pattern = _controller.text.trim();
    if (pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe al menos una posición en formato Compás.Cuadro (ej: 1.1, 2.3)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final count = notifier.applyMultiBeatChord(
      chord: chord,
      pattern: pattern,
      replaceExisting: true,
    );
    notifier.setShowMultiBeatModal(false);

    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Acorde $chord aplicado en $count cuadro(s) de compás.'
                  : 'No se encontraron posiciones válidas con formato Compás.Cuadro.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final screen = MediaQuery.sizeOf(context);

    // Escuchar cambios en multiBeatPattern para mantener sincronizado el cuadro de texto
    ref.listen<String>(
      accordionSimulatorProvider.select((s) => s.multiBeatPattern),
      (prev, next) {
        if (_controller.text != next) {
          _controller.text = next;
          _controller.selection = TextSelection.collapsed(offset: next.length);
          setState(() {});
        }
      },
    );

    // Ajustar posición inicial para que quede centrada/visible
    if (!_hasCalculatedInitialPos) {
      _hasCalculatedInitialPos = true;
      final startX = (screen.width - 330).clamp(20.0, double.infinity);
      final startY = (screen.height - 290).clamp(40.0, double.infinity);
      _position = Offset(
        (screen.width * 0.22).clamp(20.0, startX),
        85.0.clamp(20.0, startY),
      );
    }

    final currentChord = state.multiBeatChord?.trim().isNotEmpty == true
        ? state.multiBeatChord!
        : ChordCatalog.symbolFor(
            root: state.freeChordRoot,
            type: state.freeChordType,
            extension: state.freeChordFourth,
            latin: state.notation != NotationMode.alemana,
          );

    final chordPcs = ChordCatalog.pitchClassesForChordSymbol(currentChord);
    final isLatin = state.notation != NotationMode.alemana;
    final namesList = isLatin ? ChordCatalog.latinRootNames : ChordCatalog.germanRootNames;
    final notes = chordPcs.map((pc) => namesList[pc]).toList();
    final notesStr = notes.isNotEmpty ? '(${notes.join(' - ')})' : '';

    // Posiciones donde ya existe este acorde en todos los compases y cuadros
    final currentPositions = <String>[];
    for (var m = 0; m < state.measures.length; m++) {
      for (var b = 0; b < state.measures[m].beats.length; b++) {
        if (state.measures[m].beats[b].chord.trim() == currentChord) {
          currentPositions.add('${m + 1}.${b + 1}');
        }
      }
    }
    final currentPositionsStr = currentPositions.join(', ');

    // Cadena de texto de todos los compases y cuadros disponibles en la cuadrícula
    final allPositions = <String>[];
    for (var m = 0; m < state.measures.length; m++) {
      for (var b = 0; b < 4; b++) {
        allPositions.add('${m + 1}.${b + 1}');
      }
    }
    final allPositionsStr = allPositions.join(', ');

    return Positioned(
      left: _position.dx.clamp(10.0, (screen.width - 325).clamp(10.0, double.infinity)),
      top: _position.dy.clamp(10.0, (screen.height - 260).clamp(10.0, double.infinity)),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 315,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de título / Cabecera arrastrable
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.layerGroup,
                        size: 11,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Asignar a Múltiples Compases',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Cerrar ventana',
                        child: InkWell(
                          onTap: () => notifier.setShowMultiBeatModal(false),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            child: const FaIcon(
                              FontAwesomeIcons.xmark,
                              size: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Cuerpo del diálogo
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge del acorde a asignar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Acorde:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            currentChord,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          if (notesStr.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notesStr,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Explicación de formato
                    const Text(
                      'Cada compás tiene 4 cuadros: Compás.Cuadro\nEjemplo: 1.1 (compás 1, cuadro 1), 2.3 (compás 2, cuadro 3)',
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.3,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),

                    // Cuadro de texto para digitar los cuadros
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: '1.1, 2.3, 5.2',
                        hintStyle: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: Color(0xFF94A3B8),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const FaIcon(FontAwesomeIcons.xmark, size: 10),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Presets rápidos
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (currentPositions.isNotEmpty)
                          _buildPresetChip(
                            currentPositionsStr,
                            label: 'Actuales (${currentPositions.length})',
                            isHighlight: true,
                          ),
                        _buildPresetChip(
                          allPositionsStr,
                          label: 'Todos los cuadros (${allPositions.length})',
                        ),
                        _buildPresetChip('1.1, 2.1, 3.1, 4.1', label: 'Tiempos 1 (1-4)'),
                        _buildPresetChip('1.1, 1.2, 1.3, 1.4', label: 'Compás 1 completo'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Botones de acción (Cancelar / Confirmar)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => notifier.setShowMultiBeatModal(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _onConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          icon: const FaIcon(FontAwesomeIcons.check, size: 9),
                          label: const Text(
                            'Confirmar',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String pattern, {required String label, bool isHighlight = false}) {
    return InkWell(
      onTap: () {
        _controller.text = pattern;
        _controller.selection = TextSelection.collapsed(offset: pattern.length);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isHighlight ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
            width: isHighlight ? 1.0 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: isHighlight ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
