import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../controllers/accordion_controller.dart';

class MeasureGridWidget extends ConsumerWidget {
  final int accordionNumber;

  const MeasureGridWidget({
    super.key,
    this.accordionNumber = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;

    final bpm = state.audioReport?.bpm ?? 120;

    return Container(
      width: isPrimary ? 190 : 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera: Título "Compás" + Control de BPM editable con Subir / Bajar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFFF1F5F9) : const Color(0xFFD1FAE5),
              border: Border(bottom: BorderSide(color: isPrimary ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        isPrimary ? FontAwesomeIcons.music : FontAwesomeIcons.link,
                        size: 8,
                        color: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          isPrimary ? 'Compás' : 'Compás A2',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w900,
                            color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFF059669),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                // Control de BPM editable con botones subir/bajar
                _BpmInputControl(
                  bpm: bpm,
                  onChanged: (newVal) => notifier.updateAudioBpm(newVal),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Transporte y Seeker de Tiempo (Solo en Diapasón 1)
                if (isPrimary) ...[
                  _buildTransportAndSeeker(state, notifier),
                  const SizedBox(width: 4),
                ],

                // Columna Central: Cuadrícula de Compases con 4 Tiempos por fila
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 330),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.measures.length,
                      itemBuilder: (context, mIdx) {
                        final measure = state.measures[mIdx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              // Número de compás
                              Container(
                                width: 18,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                child: Center(
                                  child: Text(
                                    '${measure.barNumber}',
                                    style: const TextStyle(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),

                              // 4 Beats / Tiempos del compás
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: measure.beats.asMap().entries.map((entry) {
                                    final beatIdx = entry.key;
                                    final beat = entry.value;

                                    final isCurrentPlayhead = state.isPlayingAudio &&
                                        state.selectedBarIndex == mIdx &&
                                        state.selectedBeatIndex == beatIdx;

                                    return _InlineBeatChordEditor(
                                      accordionId: accordionNumber,
                                      measureIndex: mIdx,
                                      beatIndex: beatIdx,
                                      totalMeasures: state.measures.length,
                                      chord: beat.chord,
                                      timeText: beat.timeText,
                                      isCurrentPlayhead: isCurrentPlayhead,
                                      hasBottomBorder: beatIdx < measure.beats.length - 1,
                                      notation: state.notation,
                                      onChanged: (newChord) {
                                        notifier.updateMeasureBeat(mIdx, beatIdx, newChord);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Columna Derecha: Barra de Herramientas Vertical (Solo en Diapasón 1)
                if (isPrimary) ...[
                  const SizedBox(width: 6),
                  _buildVerticalActionToolbar(context, state, notifier),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportAndSeeker(AccordionSimulatorState state, AccordionSimulatorNotifier notifier) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTransportBtn(
          icon: FontAwesomeIcons.backwardStep,
          onTap: () {},
          tooltip: 'Compás Anterior',
        ),
        const SizedBox(height: 4),
        _buildTransportBtn(
          icon: state.isPlayingAudio ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
          isPrimary: true,
          onTap: notifier.togglePlayAudio,
          tooltip: 'Reproducir / Pausar',
        ),
        const SizedBox(height: 4),
        _buildTransportBtn(
          icon: FontAwesomeIcons.forwardStep,
          onTap: () {},
          tooltip: 'Siguiente Compás',
        ),
        const SizedBox(height: 4),
        _buildTransportBtn(
          icon: FontAwesomeIcons.stop,
          onTap: notifier.stopAudio,
          tooltip: 'Detener',
        ),
        const SizedBox(height: 4),
        _buildTransportBtn(
          icon: FontAwesomeIcons.arrowsRotate,
          isActive: state.syncDiapason,
          onTap: notifier.toggleSyncDiapason,
          tooltip: 'Sincronizar Diapasón',
        ),
        const SizedBox(height: 8),

        // Tiempo actual y Seeker Vertical
        Text(
          _formatTime(state.currentAudioTime),
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
        ),
        SizedBox(
          height: 140,
          width: 22,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3.5,
                activeTrackColor: const Color(0xFF0284C7),
                inactiveTrackColor: const Color(0xFFCBD5E1),
                thumbColor: const Color(0xFF0284C7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: state.currentAudioTime.clamp(0.0, state.totalAudioDuration > 0 ? state.totalAudioDuration : 1.0),
                min: 0.0,
                max: state.totalAudioDuration > 0 ? state.totalAudioDuration : 1.0,
                onChanged: (v) => notifier.seekAudio(v),
              ),
            ),
          ),
        ),
        Text(
          '-${_formatTime((state.totalAudioDuration - state.currentAudioTime).clamp(0.0, double.infinity))}',
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  String _formatTime(double sec) {
    final s = sec.clamp(0.0, 99999.0).toInt();
    final mins = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Widget _buildVerticalActionToolbar(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionBtn(
          icon: FontAwesomeIcons.listOl,
          isActive: state.sequenceMode,
          tooltip: 'Modo Secuencia',
          onTap: notifier.toggleSequenceMode,
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.checkDouble,
          tooltip: 'Seleccionar Todos (Ctrl+A)',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.fileArrowDown,
          tooltip: 'Guardar / Exportar acordes a CSV',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.fileArrowUp,
          tooltip: 'Cargar / Importar acordes desde CSV',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.keyboard,
          tooltip: 'Digitar Progresión Manualmente',
          onTap: () => _showManualProgressionDialog(context, notifier),
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.plus,
          tooltip: 'Agregar un compás vacío al final',
          onTap: notifier.addMeasure,
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.trashCan,
          tooltip: 'Borrar todos los acordes de la cuadrícula',
          color: const Color(0xFFDC2626),
          onTap: notifier.clearAllGridChords,
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.gear,
          tooltip: 'Configurar cantidad de filas visibles',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.upRightAndDownLeftFromCenter,
          tooltip: 'Desacoplar a ventana completa',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildTransportBtn({
    required FaIconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isPrimary = false,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF0284C7)
                : (isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF0369A1)
                  : (isActive ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 11,
              color: isPrimary
                  ? Colors.white
                  : (isActive ? const Color(0xFF0284C7) : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required FaIconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isActive ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 10,
              color: color ?? (isActive ? const Color(0xFF0284C7) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  void _showManualProgressionDialog(BuildContext context, AccordionSimulatorNotifier notifier) {
    final controller = TextEditingController(text: 'Bb | Eb | F7 | Bb');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digitar Progresión Manualmente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe los acordes separados por barra (|), espacio o coma. Ej: Sol | Re | Mim | Do',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'ej: Bb | Eb | F7 | Bb',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = controller.text;
              final parts = raw.split(RegExp(r'[|, \n]+')).where((s) => s.isNotEmpty).toList();
              for (int i = 0; i < parts.length; i++) {
                final mIdx = i ~/ 4;
                final bIdx = i % 4;
                notifier.updateMeasureBeat(mIdx, bIdx, parts[i]);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Cargar a Cuadrícula'),
          ),
        ],
      ),
    );
  }
}

/// Control de BPM compacto y editable con cuadro de texto y botones de subir / bajar
class _BpmInputControl extends StatefulWidget {
  final int bpm;
  final ValueChanged<int> onChanged;

  const _BpmInputControl({
    required this.bpm,
    required this.onChanged,
  });

  @override
  State<_BpmInputControl> createState() => _BpmInputControlState();
}

class _BpmInputControlState extends State<_BpmInputControl> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.bpm.toString());
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _commitValue();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _BpmInputControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm && !_focusNode.hasFocus) {
      _controller.text = widget.bpm.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitValue() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed >= 30 && parsed <= 300) {
      widget.onChanged(parsed);
    } else {
      _controller.text = widget.bpm.toString();
    }
  }

  void _step(int delta) {
    final current = int.tryParse(_controller.text.trim()) ?? widget.bpm;
    final next = (current + delta).clamp(30, 300);
    _controller.text = next.toString();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.9),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'BPM',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 2),
          // Cuadro de texto editable
          SizedBox(
            width: 32,
            height: 18,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _commitValue(),
            ),
          ),
          // Flechas subir / bajar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _step(1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: FaIcon(
                    FontAwesomeIcons.caretUp,
                    size: 8,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _step(-1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: FaIcon(
                    FontAwesomeIcons.caretDown,
                    size: 8,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modificadores de cualidad y extensión armónica para digitación rápida
enum _ChordModKey {
  mayor,      // '0'
  menor,      // '.' o ','
  septima,    // '/'
  aumentada,  // '+'
  disminuida, // '-'
  sus,        // '8'
  cuarta,     // '9'
}

class _ChordTools {
  static const roots = [
    'Do#', 'Dob', 'Do♭', 'Do',
    'Re#', 'Reb', 'Re♭', 'Re',
    'Mi#', 'Mib', 'Mi♭', 'Mi',
    'Fa#', 'Fab', 'Fa♭', 'Fa',
    'Sol#', 'Solb', 'Sol♭', 'Sol',
    'La#', 'Lab', 'La♭', 'La',
    'Si#', 'Sib', 'Si♭', 'Si',
    'C#', 'Db', 'C♭', 'C',
    'D#', 'Eb', 'D♭', 'D',
    'E#', 'Eb', 'E♭', 'E',
    'F#', 'Fb', 'F♭', 'F',
    'G#', 'Gb', 'G♭', 'G',
    'A#', 'Ab', 'A♭', 'A',
    'B#', 'Bb', 'B♭', 'B'
  ];

  static (String, String) splitChord(String chord) {
    final trimmed = chord.trim();
    for (final r in roots) {
      if (trimmed.startsWith(r)) {
        return (r, trimmed.substring(r.length));
      }
    }
    return ('', trimmed);
  }

  static _ChordModKey? parseModifierKey(KeyEvent event) {
    final char = event.character;
    if (char == '0') return _ChordModKey.mayor;
    if (char == '.' || char == ',') return _ChordModKey.menor;
    if (char == '/') return _ChordModKey.septima;
    if (char == '+') return _ChordModKey.aumentada;
    if (char == '-') return _ChordModKey.disminuida;
    if (char == '8') return _ChordModKey.sus;
    if (char == '9') return _ChordModKey.cuarta;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      return _ChordModKey.mayor;
    }
    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.comma) {
      return _ChordModKey.menor;
    }
    if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.numpadDivide) {
      return _ChordModKey.septima;
    }
    if (key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
      return _ChordModKey.aumentada;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      return _ChordModKey.disminuida;
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      return _ChordModKey.sus;
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      return _ChordModKey.cuarta;
    }
    return null;
  }

  static _ChordModKey? parseModifierChar(String char) {
    if (char == '0') return _ChordModKey.mayor;
    if (char == '.' || char == ',') return _ChordModKey.menor;
    if (char == '/') return _ChordModKey.septima;
    if (char == '+') return _ChordModKey.aumentada;
    if (char == '-') return _ChordModKey.disminuida;
    if (char == '8') return _ChordModKey.sus;
    if (char == '9') return _ChordModKey.cuarta;
    return null;
  }

  static String applyModifier(String chord, _ChordModKey mod, NotationMode notation) {
    var (root, rest) = splitChord(chord);
    if (root.isEmpty) {
      root = notation == NotationMode.alemana ? 'C' : 'Do';
    }

    final has7 = rest.contains('7');

    switch (mod) {
      case _ChordModKey.mayor:
        // Cero para Mayor: limpia menor (m), dim, aug, sus y deja la tríada mayor
        return has7 ? '${root}7' : root;

      case _ChordModKey.menor:
        // Punto para menor: 'm'
        return has7 ? '${root}m7' : '${root}m';

      case _ChordModKey.septima:
        // Barra diagonal con la 7ma: conmuta la séptima
        if (has7) {
          return root + rest.replaceAll('7', '');
        } else {
          return '$root$rest 7'.replaceAll(' ', '');
        }

      case _ChordModKey.aumentada:
        // Más para Aumentada: 'aug'
        if (rest.contains('aug')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}aug7' : '${root}aug';

      case _ChordModKey.disminuida:
        // Menos para Disminuida: 'dim'
        if (rest.contains('dim')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}dim7' : '${root}dim';

      case _ChordModKey.sus:
        // 8 para Sus: 'sus'
        if (rest.contains('sus')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}sus7' : '${root}sus';

      case _ChordModKey.cuarta:
        // 9 para la Cuarta: '4' o 'sus4'
        if (rest.contains('sus')) {
          return has7 ? '${root}sus47' : '${root}sus4';
        }
        if (rest.contains('4')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}47' : '${root}4';
    }
  }
}

/// Formateador que traduce la digitación de números 1 al 7 y modificadores armónicos
class _ScaleDegreeInputFormatter extends TextInputFormatter {
  final NotationMode notation;

  _ScaleDegreeInputFormatter({required this.notation});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final newText = newValue.text;
    final oldText = oldValue.text;

    if (newText.isNotEmpty) {
      final lastEnteredChar = newText.length == 1
          ? newText
          : (newValue.selection.baseOffset > 0 && newValue.selection.baseOffset <= newText.length
              ? newText[newValue.selection.baseOffset - 1]
              : newText[newText.length - 1]);

      // 1 al 7: Grados de la escala natural de Do (1=Do, 2=Re, 3=Mi, 4=Fa, 5=Sol, 6=La, 7=Si)
      if (['1', '2', '3', '4', '5', '6', '7'].contains(lastEnteredChar)) {
        final degree = int.parse(lastEnteredChar);
        final scale = notation == NotationMode.alemana
            ? const ['C', 'D', 'E', 'F', 'G', 'A', 'B']
            : const ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

        // Si se digita 7 al final de una nota ya existente, actúa como séptima
        if (degree == 7 && oldText.trim().isNotEmpty && !oldText.trim().endsWith('7')) {
          final appended = '${oldText.trim()}7';
          return TextEditingValue(
            text: appended,
            selection: TextSelection.collapsed(offset: appended.length),
          );
        }

        final replacementNote = scale[degree - 1];
        return TextEditingValue(
          text: replacementNote,
          selection: TextSelection.collapsed(offset: replacementNote.length),
        );
      }

      // Modificadores armónicos: 0 Mayor, . Menor, / 7ma, + Aumentada, - Disminuida, 8 Sus, 9 Cuarta
      final mod = _ChordTools.parseModifierChar(lastEnteredChar);
      if (mod != null) {
        final updated = _ChordTools.applyModifier(oldText, mod, notation);
        return TextEditingValue(
          text: updated,
          selection: TextSelection.collapsed(offset: updated.length),
        );
      }
    }

    return newValue;
  }
}

/// Celda de tiempo/acorde editable en línea: al hacer clic recibe foco directamente
/// sin abrir ningún diálogo modal.
class _InlineBeatChordEditor extends StatefulWidget {
  final int accordionId;
  final int measureIndex;
  final int beatIndex;
  final int totalMeasures;
  final String chord;
  final String timeText;
  final bool isCurrentPlayhead;
  final bool hasBottomBorder;
  final NotationMode notation;
  final ValueChanged<String> onChanged;

  const _InlineBeatChordEditor({
    required this.accordionId,
    required this.measureIndex,
    required this.beatIndex,
    required this.totalMeasures,
    required this.chord,
    required this.timeText,
    required this.isCurrentPlayhead,
    required this.hasBottomBorder,
    this.notation = NotationMode.latina,
    required this.onChanged,
  });

  @override
  State<_InlineBeatChordEditor> createState() => _InlineBeatChordEditorState();
}

class _InlineBeatChordEditorState extends State<_InlineBeatChordEditor> {
  // Registro separado por accordionId para evitar interferencia entre acordeones
  static final Map<int, Map<String, _InlineBeatChordEditorState>> _registries = {};
  static final Map<int, String?> _selectedKeys = {};

  Map<String, _InlineBeatChordEditorState> get _registry =>
      _registries.putIfAbsent(widget.accordionId, () => {});

  String? get _selectedKey => _selectedKeys[widget.accordionId];
  set _selectedKey(String? val) => _selectedKeys[widget.accordionId] = val;

  late TextEditingController _controller;
  late final FocusNode _focusNode;
  late final FocusNode _cellFocusNode;
  bool _isEditing = false;

  String get _nodeKey => '${widget.measureIndex}_${widget.beatIndex}';
  bool get _isSelected => _selectedKey == _nodeKey;
  bool get _isCellHighlighted => _isSelected && !_isEditing;


  @override
  void initState() {
    super.initState();
    _registry[_nodeKey] = this;
    _controller = TextEditingController(text: widget.chord);

    _cellFocusNode = FocusNode(debugLabel: 'beat_cell_$_nodeKey');
    _cellFocusNode.onKeyEvent = _handleCellKeyEvent;

    _focusNode = FocusNode(debugLabel: 'beat_text_$_nodeKey');
    _focusNode.onKeyEvent = _handleTextFieldKeyEvent;

    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      if (hasFocus) {
        if (!_isEditing) {
          _isEditing = true;
          _selectedKey = _nodeKey;
          _update();
        }
      } else {
        if (_isEditing) {
          _isEditing = false;
          _commit();
          _update();
        }
      }
    });

    _cellFocusNode.addListener(() {
      if (_cellFocusNode.hasFocus) {
        if (_selectedKey != _nodeKey) {
          final oldKey = _selectedKey;
          _selectedKey = _nodeKey;
          if (oldKey != null) {
            _registry[oldKey]?._setIdle();
          }
          _update();
        }
      } else {
        _update();
      }
    });

    if (_selectedKey == _nodeKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setSelected();
      });
    }
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _InlineBeatChordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measureIndex != widget.measureIndex || oldWidget.beatIndex != widget.beatIndex) {
      _registry.remove('${oldWidget.measureIndex}_${oldWidget.beatIndex}');
      _registry[_nodeKey] = this;
    }
    if (oldWidget.chord != widget.chord && !_isEditing) {
      _controller.text = widget.chord;
    }
  }

  @override
  void dispose() {
    _registry.remove(_nodeKey);
    if (_selectedKey == _nodeKey) {
      _selectedKey = null;
    }
    _controller.dispose();
    _focusNode.dispose();
    _cellFocusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final trimmed = _controller.text.trim();
    if (trimmed != widget.chord) {
      widget.onChanged(trimmed);
    }
  }

  void _moveSelection(int delta) {
    _commit();
    final currentIndex = widget.measureIndex * 4 + widget.beatIndex;
    final totalSlots = widget.totalMeasures * 4;
    final nextIndex = currentIndex + delta;

    if (nextIndex >= 0 && nextIndex < totalSlots) {
      final nextM = nextIndex ~/ 4;
      final nextB = nextIndex % 4;
      final targetKey = '${nextM}_$nextB';

      final oldKey = _selectedKey;
      _selectedKey = targetKey;
      if (oldKey != null && oldKey != targetKey) {
        _registry[oldKey]?._setIdle();
      }

      final targetState = _registry[targetKey];
      if (targetState != null) {
        targetState._setSelected();
      }
    }
  }

  void _setSelected() {
    _commit();
    _isEditing = false;
    _focusNode.unfocus();
    _cellFocusNode.requestFocus();
    if (mounted) {
      setState(() {});
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
      );
    }
  }

  void _setIdle() {
    _isEditing = false;
    if (mounted) setState(() {});
  }

  void _activateEdit() {
    final oldKey = _selectedKey;
    _selectedKey = _nodeKey;
    if (oldKey != null && oldKey != _nodeKey) {
      _registry[oldKey]?._setIdle();
    }
    _isEditing = true;
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    if (mounted) {
      setState(() {});
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
      );
    }
  }

  int? _parseScaleDegree(KeyEvent event) {
    final char = event.character;
    if (char != null && char.length == 1) {
      final code = char.codeUnitAt(0);
      if (code >= 49 && code <= 55) {
        return code - 48; // '1'..'7' -> 1..7
      }
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) return 1;
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) return 2;
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) return 3;
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) return 4;
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) return 5;
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) return 6;
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) return 7;
    return null;
  }

  String _chordForScaleDegree(int degree) {
    if (widget.notation == NotationMode.alemana) {
      const scale = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
      return scale[(degree - 1).clamp(0, 6)];
    } else {
      const scale = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
      return scale[(degree - 1).clamp(0, 6)];
    }
  }

  void _applyChord(String chord) {
    _controller.text = chord;
    widget.onChanged(chord);
    if (mounted) setState(() {});
  }

  KeyEventResult _handleCellKeyEvent(FocusNode node, KeyEvent event) {
    if (_isEditing) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      // Reconocer números 1 al 7 como grados de la escala natural de Do (Do, Re, Mi, Fa, Sol, La, Si)
      final degree = _parseScaleDegree(event);
      if (degree != null) {
        _applyChord(_chordForScaleDegree(degree));
        return KeyEventResult.handled;
      }
      // Modificadores armónicos: 0 Mayor, . Menor, / 7ma, + Aumentada, - Disminuida, 8 Sus, 9 Cuarta
      final mod = _ChordTools.parseModifierKey(event);
      if (mod != null) {
        final updated = _ChordTools.applyModifier(_controller.text, mod, widget.notation);
        _applyChord(updated);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        _applyChord('');
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Flecha izquierda: pone en foco el cuadro seleccionado para edición
        _activateEdit();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Flecha derecha: saca de foco / permanece el cuadro seleccionado
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Flecha abajo: cambia al compás/cuadro siguiente
        _moveSelection(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Flecha arriba: cambia al compás/cuadro anterior
        _moveSelection(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _activateEdit();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTextFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Reconocer números 1 al 7 como la escala natural de Do (1=Do, 2=Re, 3=Mi, 4=Fa, 5=Sol, 6=La, 7=Si)
      final degree = _parseScaleDegree(event);
      if (degree != null) {
        final text = _controller.text.trim();
        final sel = _controller.selection;
        final isAtEnd = sel.isCollapsed && sel.baseOffset == _controller.text.length;

        if (degree == 7 && text.isNotEmpty && isAtEnd && !text.endsWith('7')) {
          final appended = '${text}7';
          _controller.text = appended;
          _controller.selection = TextSelection.collapsed(offset: appended.length);
          _commit();
          _update();
          return KeyEventResult.handled;
        }

        final chord = _chordForScaleDegree(degree);
        _controller.text = chord;
        _controller.selection = TextSelection.collapsed(offset: chord.length);
        _commit();
        _update();
        return KeyEventResult.handled;
      }

      // Modificadores armónicos: 0 Mayor, . Menor, / 7ma, + Aumentada, - Disminuida, 8 Sus, 9 Cuarta
      final mod = _ChordTools.parseModifierKey(event);
      if (mod != null) {
        final updated = _ChordTools.applyModifier(_controller.text, mod, widget.notation);
        _controller.text = updated;
        _controller.selection = TextSelection.collapsed(offset: updated.length);
        _commit();
        _update();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Flecha derecha: saca de foco de edición, pero permanece el cuadro seleccionado
        _commit();
        _setSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Flecha abajo: cambia al compás/cuadro siguiente
        _moveSelection(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Flecha arriba: cambia al compás/cuadro anterior
        _moveSelection(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        // Tab o Escape: saca de foco de edición pero mantiene cuadro seleccionado
        _commit();
        _setSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _commit();
        _moveSelection(1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasChord = widget.chord.isNotEmpty;
    final isPlaying = widget.isCurrentPlayhead;
    final isCellSelected = _isCellHighlighted;
    final isFocusedOrSelected = _isEditing || isCellSelected;

    return Focus(
      focusNode: _cellFocusNode,
      child: GestureDetector(
        onTap: () {
          _activateEdit();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: isCellSelected
                ? const Color(0xFFDBEAFE) // Resaltado azul suave y vivo para cuadro seleccionado
                : (_isEditing
                    ? Colors.white // Fondo blanco limpio al editar
                    : (isPlaying ? const Color(0xFFFEF3C7) : Colors.white)),
            borderRadius: BorderRadius.circular(4),
            border: isCellSelected
                ? Border.all(color: const Color(0xFF2563EB), width: 1.8) // Cuadro resaltado nítido con borde completo
                : (_isEditing
                    ? Border.all(color: const Color(0xFF3B82F6), width: 1.8) // Borde activo de edición
                    : (isPlaying
                        ? Border.all(color: const Color(0xFFF59E0B), width: 1.8)
                        : Border.all(
                            color: widget.hasBottomBorder ? const Color(0xFFE2E8F0) : Colors.transparent,
                            width: 0.8,
                          ))),
            boxShadow: isCellSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      blurRadius: 4,
                      spreadRadius: 0.8,
                    ),
                  ]
                : (_isEditing
                    ? [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.20),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cuadro de texto interactivo con foco directo y navegación Tab + Arriba / Abajo
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: !_isEditing,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: (isFocusedOrSelected || hasChord) ? FontWeight.w900 : FontWeight.w500,
                    color: isPlaying
                        ? const Color(0xFFB45309)
                        : (isFocusedOrSelected
                            ? const Color(0xFF1D4ED8)
                            : (hasChord ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '-',
                    hintStyle: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  inputFormatters: [
                    _ScaleDegreeInputFormatter(notation: widget.notation),
                  ],
                  onChanged: (_) {
                    _commit();
                  },
                  onSubmitted: (_) {
                    _commit();
                    _moveSelection(1);
                  },
                ),
              ),
              const SizedBox(width: 2),
              Text(
                widget.timeText,
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: isCellSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isCellSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



