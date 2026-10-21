import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/theory/music_theory.dart';
import '../controllers/accordion_controller.dart';

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
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del panel de bajos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(FontAwesomeIcons.drum, size: 12, color: Color(0xFF0284C7)),
                const SizedBox(width: 5),
                Text(
                  'Bajos A$accordionNumber (12)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
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

          // Cuerpo: Tablero de bajos + Barra de herramientas vertical a la derecha
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Diapasón de Bajos (2 columnas de 6 botones)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                      const SizedBox(width: 6),
                      _buildBassColumn(
                        title: 'Interior',
                        buttons: interiorButtons,
                        state: state,
                        notifier: notifier,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Barra de herramientas vertical apilada a la derecha
                _buildVerticalToolbar(state, notifier),
              ],
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
          width: 44,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        // 6 Botones
        ...buttons.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final btn = entry.value;
          final isPressed = state.activeButtons.contains(btn.id);
          final pushMidi = btn.pushNotes.isNotEmpty ? btn.pushNotes.first : 0;
          final pullMidi = btn.pullNotes.isNotEmpty ? btn.pullNotes.first : 0;

          final pushName = MusicTheory.midiToName(
            pushMidi,
            notation: state.notation,
            ignoreOctave: true,
            tuningOffset: currentTuning.offset,
          );
          final pullName = MusicTheory.midiToName(
            pullMidi,
            notation: state.notation,
            ignoreOctave: true,
            tuningOffset: currentTuning.offset,
          );

          final midiToPlay = pushMidi + currentTuning.offset;

          return Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Listener(
              onPointerDown: (_) => notifier.pressButton(btn.id, midiToPlay),
              onPointerUp: (_) => notifier.releaseButton(btn.id, midiToPlay),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: -14,
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 44,
                    height: 44,
                    transform: isPressed
                        ? Matrix4.diagonal3Values(1.12, 1.12, 1.0)
                        : Matrix4.identity(),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPressed ? const Color(0xFFFACC15) : const Color(0xFFF1F5F9),
                      border: Border.all(
                        color: btn.type == ButtonType.fundamental
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        width: 1.5,
                      ),
                      boxShadow: isPressed
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFACC15).withValues(alpha: 0.8),
                                blurRadius: 14,
                                spreadRadius: 3,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(1, 3),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pushName,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF991B1B),
                              height: 1.0,
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 1,
                            color: Colors.black26,
                            margin: const EdgeInsets.symmetric(vertical: 1),
                          ),
                          Text(
                            pullName,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E40AF),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVerticalToolbar(AccordionSimulatorState state, AccordionSimulatorNotifier notifier) {
    final isPrimary = accordionNumber == 1;
    final currentBellows = isPrimary ? state.bellows1 : state.bellows2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector de Fuelle Vertical
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToolbarIconButton(
                  icon: FontAwesomeIcons.arrowsLeftRight,
                  isActive: currentBellows == BellowsMode.both,
                  onTap: () {
                    if (isPrimary) {
                      notifier.setBellows1(BellowsMode.both);
                    } else {
                      notifier.setBellows2(BellowsMode.both);
                    }
                  },
                  tooltip: 'Ambos',
                ),
                const SizedBox(height: 2),
                _buildToolbarIconButton(
                  icon: FontAwesomeIcons.arrowLeft,
                  isActive: currentBellows == BellowsMode.pull,
                  onTap: () {
                    if (isPrimary) {
                      notifier.setBellows1(BellowsMode.pull);
                    } else {
                      notifier.setBellows2(BellowsMode.pull);
                    }
                  },
                  tooltip: 'Abre',
                ),
                const SizedBox(height: 2),
                _buildToolbarIconButton(
                  icon: FontAwesomeIcons.arrowRight,
                  isActive: currentBellows == BellowsMode.push,
                  onTap: () {
                    if (isPrimary) {
                      notifier.setBellows1(BellowsMode.push);
                    } else {
                      notifier.setBellows2(BellowsMode.push);
                    }
                  },
                  tooltip: 'Cierra',
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(width: 16, child: Divider(height: 1, color: Color(0xFFCBD5E1))),
          ),

          // Botones de Reproducción
          _buildToolbarIconButton(
            icon: FontAwesomeIcons.play,
            isActive: false,
            onTap: () {},
            tooltip: 'Reproducir ritmo',
          ),
          const SizedBox(height: 4),
          _buildToolbarIconButton(
            icon: FontAwesomeIcons.pause,
            isActive: false,
            onTap: () {},
            tooltip: 'Pausar',
          ),
          const SizedBox(height: 4),
          _buildToolbarIconButton(
            icon: FontAwesomeIcons.backwardStep,
            isActive: false,
            onTap: () {},
            tooltip: 'Reiniciar compás',
          ),

          const SizedBox(height: 4),

          // Píldora de Metrónomo Vertical
          Container(
            width: 24,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.stopwatch, size: 9, color: Color(0xFF64748B)),
                SizedBox(height: 1),
                Text(
                  '120',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(width: 16, child: Divider(height: 1, color: Color(0xFFCBD5E1))),
          ),

          _buildToolbarIconButton(
            icon: FontAwesomeIcons.fileImport,
            isActive: false,
            onTap: () {},
            tooltip: 'Cargar MusicXML',
          ),
          const SizedBox(height: 4),
          _buildToolbarIconButton(
            icon: FontAwesomeIcons.fileArrowDown,
            isActive: false,
            onTap: () {},
            tooltip: 'Exportar MIDI',
          ),
          const SizedBox(height: 4),
          _buildToolbarIconButton(
            icon: FontAwesomeIcons.arrowsRotate,
            isActive: false,
            onTap: () {},
            tooltip: 'Invertir columnas (Espejo)',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarIconButton({
    required FaIconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 22,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0284C7) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? const Color(0xFF0369A1) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 10,
              color: isActive ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
