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
  final bool showGloss;
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
    this.isChordPull = false,
    this.isChordPush = false,
    this.showGloss = true,
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

    // El cuerpo se tiñe solo cuando el botón está presionado, seleccionado
    // en el detector o pertenece al acorde en la dirección Abrir/Cerrar.
    // En "Ambos" el cuerpo queda en blanco y solo se colorean las notas.
    final bool chordBodyTint = !isPressed &&
        !isDetectorSelected &&
        ((bellowsMode == BellowsMode.pull && isChordPull) ||
            (bellowsMode == BellowsMode.push && isChordPush) ||
            (bellowsMode == BellowsMode.both && (isChordPull || isChordPush)));
    final bool bodyTinted = isPressed || isDetectorSelected || chordBodyTint;

    return Listener(
      onPointerDown: (_) => onPointerDown(),
      onPointerUp: (_) => onPointerUp(),
      onPointerCancel: (_) => onPointerUp(),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Número ordinal fuera del botón a la izquierda con sombra
          Positioned(
            left: -12,
            child: Text(
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
          ),

          // Botón con Auténtico Efecto 3D Nácar/Perlado idéntico a CSS .btn-accordion
          AccordionButton3D(
            size: size,
            isPressed: isPressed,
            bellowsMode: bellowsMode,
            isDetectorSelected: isDetectorSelected,
            isChordPull: isChordPull,
            isChordPush: isChordPush,
            showGloss: showGloss,
            child: _buildNoteContent(pushName, pullName, bodyTinted),
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

  Widget _buildNoteContent(String pushName, String pullName, bool bodyTinted) {
    final useWhite = bodyTinted;
    final labelShadows = useWhite
        ? const [
            Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 3),
            Shadow(color: Colors.black87, blurRadius: 2),
          ]
        : const [
            Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1),
          ];

    // Fuelle abriendo: solo muestra la nota de abrir (pull).
    if (bellowsMode == BellowsMode.pull) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pullName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: useWhite ? Colors.white : const Color(0xFF1E40AF),
                height: 1.0,
                shadows: labelShadows,
              ),
            ),
          ),
        ),
      );
    }

    // Fuelle cerrando: solo muestra la nota de cerrar (push).
    if (bellowsMode == BellowsMode.push) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pushName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: useWhite ? Colors.white : const Color(0xFF991B1B),
                height: 1.0,
                shadows: labelShadows,
              ),
            ),
          ),
        ),
      );
    }

    // Fuelle en Ambos: muestra ambas notas (Abre a la izquierda en azul, Cierra a la derecha en rojo).
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
