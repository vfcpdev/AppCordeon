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
  final bool isChordGlow;
  final BellowsMode bellowsMode;
  final NotationMode notation;
  final int tuningOffset;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerUp;
  final double size;

  const DiapasonButtonWidget({
    super.key,
    required this.btnIndex,
    required this.pushMidi,
    required this.pullMidi,
    required this.isPressed,
    this.isDetectorSelected = false,
    this.isChordGlow = false,
    required this.bellowsMode,
    required this.notation,
    required this.tuningOffset,
    required this.onPointerDown,
    required this.onPointerUp,
    this.size = 50.0,
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
          // Número ordinal ubicado fuera del botón a la izquierda con sombra
          Positioned(
            left: -18,
            child: Text(
              '$btnIndex',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.95),
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
                  Shadow(color: Colors.black87, blurRadius: 2),
                ],
              ),
            ),
          ),

          // Botón con Auténtico Efecto 3D Nácar/Perlado idéntico a CSS .btn-accordion
          AccordionButton3D(
            size: size,
            isPressed: isPressed,
            bellowsMode: bellowsMode,
            isDetectorSelected: isDetectorSelected,
            isChordGlow: isChordGlow,
            child: _buildNoteContent(pushName, pullName),
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

  Widget _buildNoteContent(String pushName, String pullName) {
    if (bellowsMode == BellowsMode.push) {
      return Text(
        pushName,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 3),
            Shadow(color: Colors.black87, blurRadius: 2),
          ],
        ),
      );
    }
    if (bellowsMode == BellowsMode.pull) {
      return Text(
        pullName,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 3),
            Shadow(color: Colors.black87, blurRadius: 2),
          ],
        ),
      );
    }

    // Modo Both (Push arriba en rojo, separador, Pull abajo en azul)
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pushName,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isPressed ? const Color(0xFF7F1D1D) : const Color(0xFF991B1B),
            height: 1.0,
            shadows: const [Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1)],
          ),
        ),
        Container(
          width: 15,
          height: 1,
          color: isPressed ? Colors.black38 : const Color(0xFF64748B),
          margin: const EdgeInsets.symmetric(vertical: 2.0),
        ),
        Text(
          pullName,
          style: TextStyle(
            fontSize: 10,
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
