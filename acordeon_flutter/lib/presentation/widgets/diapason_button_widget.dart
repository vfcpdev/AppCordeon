import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/music_theory.dart';
import 'accordion_button_3d.dart';

class DiapasonButtonWidget extends StatelessWidget {
  final int btnIndex;
  final int pushMidi;
  final int pullMidi;
  final bool isPressed;
  final bool isDetectorSelected;
  final bool isChordPull;
  final bool isChordPush;
  final BellowsMode bellowsMode;
  final NotationMode notation;
  final int tuningOffset;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final double size;
  final String? shortcutLabel;

  const DiapasonButtonWidget({
    super.key,
    required this.btnIndex,
    required this.pushMidi,
    required this.pullMidi,
    required this.isPressed,
    this.isDetectorSelected = false,
    this.isChordPull = false,
    this.isChordPush = false,
    required this.bellowsMode,
    required this.notation,
    required this.tuningOffset,
    required this.onPointerDown,
    required this.onPointerUp,
    this.size = 50.0,
    this.shortcutLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pushName = MusicTheory.midiToName(
      pushMidi,
      notation: notation,
      ignoreOctave: true,
      tuningOffset: tuningOffset,
    );
    final pullName = MusicTheory.midiToName(
      pullMidi,
      notation: notation,
      ignoreOctave: true,
      tuningOffset: tuningOffset,
    );

    return Listener(
      onPointerDown: (_) => onPointerDown(),
      onPointerUp: (_) => onPointerUp(),
      onPointerCancel: (_) => onPointerUp(),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Número ordinal y tecla de PC ubicada fuera del botón a la izquierda con sombra
          Positioned(
            left: shortcutLabel != null ? -22 : -18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$btnIndex',
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
                if (shortcutLabel != null)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: Text(
                      shortcutLabel!,
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFDE047),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botón con Auténtico Efecto 3D Nácar/Perlado idéntico a CSS .btn-accordion
          AccordionButton3D(
            size: size,
            isPressed: isPressed,
            bellowsMode: bellowsMode,
            isDetectorSelected: isDetectorSelected,
            isChordPull: isChordPull,
            isChordPush: isChordPush,
            child: _buildNoteContent(pushName, pullName, isChordPull || isChordPush),
          ),

          // Insignia flotante de fuelle al presionar (CSS .bellows-action-pill: Abre / Cierra)
          if (isPressed && (bellowsMode == BellowsMode.push || bellowsMode == BellowsMode.pull))
            Positioned(
              top: -13,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: bellowsMode == BellowsMode.push ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: bellowsMode == BellowsMode.push ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bellowsMode == BellowsMode.push
                          ? const Color(0xFFDC2626).withValues(alpha: 0.85)
                          : const Color(0xFF2563EB).withValues(alpha: 0.85),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  bellowsMode == BellowsMode.push ? 'CIERRA' : 'ABRE',
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteContent(String pushName, String pullName, bool highlighted) {
    final useWhite = isPressed || highlighted;
    final labelShadows = useWhite
        ? const [
            Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 3),
            Shadow(color: Colors.black87, blurRadius: 2),
          ]
        : const [
            Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1),
          ];

    if (bellowsMode == BellowsMode.push) {
      return Text(
        pushName,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: useWhite ? Colors.white : const Color(0xFF991B1B),
          shadows: labelShadows,
        ),
      );
    }
    if (bellowsMode == BellowsMode.pull) {
      return Text(
        pullName,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: useWhite ? Colors.white : const Color(0xFF1E40AF),
          shadows: labelShadows,
        ),
      );
    }

    // Modo Both: cada mitad del botón muestra su nota.
    // Izquierda (azul) = Pull / Abre · Derecha (rojo) = Push / Cierra.
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pullName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: useWhite ? Colors.white : const Color(0xFF1E40AF),
                    height: 1.0,
                    shadows: labelShadows,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: size * 0.5,
            color: useWhite ? Colors.white54 : const Color(0xFF64748B),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pushName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: useWhite ? Colors.white : const Color(0xFF991B1B),
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
