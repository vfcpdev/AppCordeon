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
            padding: const EdgeInsets.fromLTRB(1, 2, 3, 2),
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 4, 3, 4),
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
                  const SizedBox(width: 3),
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
          width: 24,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 5.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
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
          final midiToPlay = currentBellows == BellowsMode.pull
              ? pullMidi + currentTuning.offset
              : pushMidi + currentTuning.offset;

          return Padding(
            padding: const EdgeInsets.only(bottom: 3.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: -9,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 5.5,
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
                  size: 23.0,
                  isPressed: isPressed,
                  bellowsMode: currentBellows,
                  buttonType: btn.type,
                  onPointerDown: () => notifier.pressButton(btn.id, midiToPlay),
                  onPointerUp: () => notifier.releaseButton(btn.id, midiToPlay),
                  child: _buildBassButtonLabel(pushName, pullName, currentBellows, isPressed),
                ),

                // Insignia flotante Abre / Cierra al presionar bajo
                if (isPressed && (currentBellows == BellowsMode.push || currentBellows == BellowsMode.pull))
                  Positioned(
                    top: -6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: currentBellows == BellowsMode.push ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: currentBellows == BellowsMode.push ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentBellows == BellowsMode.push
                                ? const Color(0xFFDC2626).withValues(alpha: 0.80)
                                : const Color(0xFF2563EB).withValues(alpha: 0.80),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        currentBellows == BellowsMode.push ? 'CIERRA' : 'ABRE',
                        style: const TextStyle(
                          fontSize: 4.0,
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

  Widget _buildBassButtonLabel(String pushName, String pullName, BellowsMode bellows, bool isPressed) {
    if (bellows == BellowsMode.push) {
      return Text(
        pushName,
        style: TextStyle(
          fontSize: 6.0,
          fontWeight: FontWeight.w900,
          color: isPressed ? Colors.white : const Color(0xFF991B1B),
          shadows: isPressed
              ? const [
                  Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 2.5),
                  Shadow(color: Colors.black87, blurRadius: 2),
                ]
              : const [
                  Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1),
                ],
        ),
      );
    }
    if (bellows == BellowsMode.pull) {
      return Text(
        pullName,
        style: TextStyle(
          fontSize: 6.0,
          fontWeight: FontWeight.w900,
          color: isPressed ? Colors.white : const Color(0xFF1E40AF),
          shadows: isPressed
              ? const [
                  Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 2.5),
                  Shadow(color: Colors.black87, blurRadius: 2),
                ]
              : const [
                  Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1),
                ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pushName,
          style: TextStyle(
            fontSize: 4.5,
            fontWeight: FontWeight.w900,
            color: isPressed ? const Color(0xFF7F1D1D) : const Color(0xFF991B1B),
            height: 1.0,
            shadows: const [Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1)],
          ),
        ),
        Container(
          width: 7,
          height: 1,
          color: isPressed ? Colors.black38 : const Color(0xFF64748B),
          margin: const EdgeInsets.symmetric(vertical: 0.8),
        ),
        Text(
          pullName,
          style: TextStyle(
            fontSize: 4.5,
            fontWeight: FontWeight.w900,
            color: isPressed ? const Color(0xFF1E3A8A) : const Color(0xFF1E40AF),
            height: 1.0,
            shadows: const [Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1)],
          ),
        ),
      ],
    );
  }

}
