import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/theory/music_theory.dart';
import '../controllers/accordion_controller.dart';
import 'accordion_button_3d.dart';

class BassPanelWidget extends ConsumerWidget {
  final int accordionNumber;

  static const double _buttonSize = 50.0;

  const BassPanelWidget({
    super.key,
    this.accordionNumber = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;
    final isCollapsed = isPrimary ? state.isBass1Collapsed : state.isBass2Collapsed;

    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.only(right: 12),
        child: ElevatedButton.icon(
          onPressed: () {
            if (isPrimary) {
              notifier.toggleBass1();
            } else {
              notifier.toggleBass2();
            }
          },
          icon: const FaIcon(FontAwesomeIcons.drum, size: 14),
          label: Text('Bajos A$accordionNumber'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: const Color(0xFF0F172A),
          ),
        ),
      );
    }

    final basses = isPrimary ? state.bassData1 : state.bassData2;
    final funds = basses.where((b) => b.type == ButtonType.fundamental).toList();
    final chords = basses.where((b) => b.type == ButtonType.chord).toList();

    // Columna Exterior: pares 1, 3, 5 (Acorde, Bajo, Acorde, Bajo, Acorde, Bajo)
    final List<BassButtonModel> exteriorButtons = [
      chords[0], funds[0],
      chords[2], funds[2],
      chords[4], funds[4],
    ];

    // Columna Interior: pares 2, 4, 6
    final List<BassButtonModel> interiorButtons = [
      chords[1], funds[1],
      chords[3], funds[3],
      chords[5], funds[5],
    ];

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del panel de bajos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(FontAwesomeIcons.drum, size: 12, color: Color(0xFF0284C7)),
                const SizedBox(width: 4),
                Text(
                  'Bajos A$accordionNumber (12)',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (isPrimary) {
                      notifier.toggleBass1();
                    } else {
                      notifier.toggleBass2();
                    }
                  },
                  child: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Cuerpo: Tablero de bajos
          Padding(
            padding: const EdgeInsets.fromLTRB(2.2, 4.4, 6.5, 4.4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(19.6, 8.7, 6.5, 8.7),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBassColumn(
                    title: 'Exterior',
                    buttons: exteriorButtons,
                    state: state,
                    notifier: notifier,
                  ),
                  // Espacio suficiente para los números de la columna interior.
                  const SizedBox(width: 18.0),
                  _buildBassColumn(
                    title: 'Interior',
                    buttons: interiorButtons,
                    state: state,
                    notifier: notifier,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBassColumn({
    required String title,
    required List<BassButtonModel> buttons,
    required AccordionSimulatorState state,
    required AccordionSimulatorNotifier notifier,
  }) {
    final isPrimary = accordionNumber == 1;
    final currentTuning = isPrimary ? state.tuning1 : state.tuning2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabecera de columna
        Container(
          width: _buttonSize,
          height: 25.4,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(5.4),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6.5),
        // 6 Botones
        ...buttons.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final btn = entry.value;
          final isPressed = state.activeButtons.contains(btn.id);
          final pushMidi = btn.pushNotes.isNotEmpty ? btn.pushNotes.first : 0;
          final pullMidi = btn.pullNotes.isNotEmpty ? btn.pullNotes.first : 0;

          final isMinorPush = btn.namePush.toLowerCase().contains('min');
          final isMinorPull = btn.namePull.toLowerCase().contains('min');
          final rawPush = MusicTheory.midiToName(
            pushMidi,
            notation: state.notation,
            ignoreOctave: true,
            tuningOffset: currentTuning.offset,
          );
          final rawPull = MusicTheory.midiToName(
            pullMidi,
            notation: state.notation,
            ignoreOctave: true,
            tuningOffset: currentTuning.offset,
          );
          final pushName = btn.type == ButtonType.chord ? '$rawPush${isMinorPush ? "m" : ""}' : rawPush;
          final pullName = btn.type == ButtonType.chord ? '$rawPull${isMinorPull ? "m" : ""}' : rawPull;

          final currentBellows = isPrimary ? state.bellows1 : state.bellows2;
          // `bassData` ya está transpuesto según la afinación.
          final midiToPlay = currentBellows == BellowsMode.pull
              ? pullMidi
              : pushMidi;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.5),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  // Alineado a la derecha contra el borde izquierdo del botón:
                  // los números de 1 y 2 dígitos quedan en la misma columna.
                  right: _buttonSize + 4.8,
                  child: Text(
                    '$index',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: const [
                        Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
                        Shadow(color: Colors.black87, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
                AccordionButton3D(
                  size: _buttonSize,
                  isPressed: isPressed,
                  bellowsMode: currentBellows,
                  buttonType: btn.type,
                  onPointerDown: () => notifier.pressButton(btn.id, midiToPlay),
                  onPointerUp: () => notifier.releaseButton(btn.id, midiToPlay),
                  child: _buildBassButtonLabel(pushName, pullName, currentBellows),
                ),

                // Insignia flotante Abre / Cierra al presionar bajo
                if (isPressed && (currentBellows == BellowsMode.push || currentBellows == BellowsMode.pull))
                  Positioned(
                    top: -13.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 1.1),
                      decoration: BoxDecoration(
                        color: currentBellows == BellowsMode.push ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: currentBellows == BellowsMode.push ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentBellows == BellowsMode.push
                                ? const Color(0xFFDC2626).withValues(alpha: 0.80)
                                : const Color(0xFF2563EB).withValues(alpha: 0.80),
                            blurRadius: 14.5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        currentBellows == BellowsMode.push ? 'CIERRA' : 'ABRE',
                        style: const TextStyle(
                          fontSize: 8.7,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBassButtonLabel(String pushName, String pullName, BellowsMode bellows) {
    // Fuelle seleccionado: solo se muestra la nota que suena en esa
    // dirección. El cuerpo del botón ya está teñido de azul (Abre) o
    // rojo (Cierra), por eso el texto va en blanco.
    const labelShadows = [
      Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 2.5),
      Shadow(color: Colors.black87, blurRadius: 2),
    ];
    if (bellows == BellowsMode.push) {
      return Text(
        pushName,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: labelShadows,
        ),
      );
    }
    if (bellows == BellowsMode.pull) {
      return Text(
        pullName,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: labelShadows,
        ),
      );
    }

    // Modo Both: cada mitad del botón está teñida (azul/rojo), así que el
    // texto de ambas notas va en blanco para mantener el contraste.
    // Izquierda (azul) = Pull / Abre · Derecha (rojo) = Push / Cierra.
    return SizedBox(
      width: _buttonSize,
      height: _buttonSize,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pullName,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                    shadows: labelShadows,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 2.2,
            height: _buttonSize * 0.5,
            color: Colors.white54,
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pushName,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                    shadows: labelShadows,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
