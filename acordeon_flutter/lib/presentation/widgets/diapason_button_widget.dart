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
    this.size = 46.0,
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
          // Número ordinal fuera del botón (a la izquierda)
          Positioned(
            left: -16,
            child: Text(
              '$btnIndex',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          // Botón circular con relieve 3D y brillo reactivo
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: size,
            height: size,
            transform: isPressed
                ? Matrix4.diagonal3Values(1.12, 1.12, 1.0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPressed ? const Color(0xFFFACC15) : const Color(0xFFF1F5F9),
              gradient: isPressed
                  ? null
                  : const RadialGradient(
                      center: Alignment(-0.2, -0.3),
                      radius: 0.9,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFE2E8F0),
                        Color(0xFFCBD5E1),
                      ],
                    ),
              boxShadow: isPressed
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.85),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                      const BoxShadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 6,
                        offset: const Offset(2, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        blurRadius: 2,
                        offset: const Offset(-1, -1),
                      ),
                    ],
              border: Border.all(
                color: isPressed ? const Color(0xFFEAB308) : Colors.black26,
                width: 1.2,
              ),
            ),
            child: Center(
              child: _buildNoteContent(pushName, pullName),
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
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF991B1B),
        ),
      );
    }
    if (bellowsMode == BellowsMode.pull) {
      return Text(
        pullName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E40AF),
        ),
      );
    }

    // Modo Both (Push arriba, separador, Pull abajo)
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pushName,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF991B1B),
            height: 1.0,
          ),
        ),
        Container(
          width: 14,
          height: 1,
          color: Colors.black38,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
        ),
        Text(
          pullName,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E40AF),
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
