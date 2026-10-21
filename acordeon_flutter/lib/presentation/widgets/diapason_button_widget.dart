import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/music_theory.dart';

class DiapasonButtonWidget extends StatelessWidget {
  final int btnIndex;
  final int pushMidi;
  final int pullMidi;
  final bool isPressed;
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

          // Botón con Efecto 3D Nácar/Perlado idéntico a CSS .btn-accordion
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            transform: isPressed
                ? (Matrix4.identity()
                  ..translate(0.0, 2.0)
                  ..scale(1.15, 1.15, 1.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isPressed
                    ? const Color(0xFFFDE047)
                    : const Color(0x47000000), // rgba(0, 0, 0, 0.28)
                width: isPressed ? 1.5 : 1.0,
              ),
              gradient: isPressed
                  ? const RadialGradient(
                      center: Alignment(-0.2, -0.3),
                      radius: 0.85,
                      colors: [
                        Color(0xFFFEF08A),
                        Color(0xFFEAB308),
                        Color(0xFFCA8A04),
                      ],
                    )
                  : const RadialGradient(
                      center: Alignment(-0.44, -0.44), // circle at 14px 14px en 50px
                      radius: 0.85,
                      colors: [
                        Color(0xFFFFFFFF), // Brillo especular superior
                        Color(0xFFD3CBBD), // Nácar medio
                        Color(0xFF9E9587), // Reborde 3D inferior
                      ],
                      stops: [0.0, 0.70, 1.0],
                    ),
              boxShadow: isPressed
                  ? [
                      // Glow dorado expansivo idéntico al CSS :active
                      BoxShadow(
                        color: const Color(0xFFFDE047).withValues(alpha: 0.9),
                        blurRadius: 26,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.85),
                        blurRadius: 48,
                        spreadRadius: 2,
                      ),
                      const BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ]
                  : [
                      // Sombra 3D de profundidad y relieve
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.60),
                        offset: const Offset(2, 5),
                        blurRadius: 8,
                      ),
                      // Bisel de luz superior
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.85),
                        offset: const Offset(-1, -1),
                        blurRadius: 2,
                      ),
                    ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Brillo especular sutil en la parte superior izquierda
                Positioned(
                  top: 4,
                  left: 6,
                  child: Container(
                    width: 14,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: isPressed ? 0.0 : 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Contenido de las notas
                Center(
                  child: _buildNoteContent(pushName, pullName),
                ),
              ],
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
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: isPressed ? const Color(0xFF0F172A) : const Color(0xFF991B1B),
          shadows: isPressed
              ? const [Shadow(color: Colors.white, blurRadius: 1)]
              : const [Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1)],
        ),
      );
    }
    if (bellowsMode == BellowsMode.pull) {
      return Text(
        pullName,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: isPressed ? const Color(0xFF0F172A) : const Color(0xFF1E40AF),
          shadows: isPressed
              ? const [Shadow(color: Colors.white, blurRadius: 1)]
              : const [Shadow(color: Colors.white70, offset: Offset(0, 0.5), blurRadius: 1)],
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
