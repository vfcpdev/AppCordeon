import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';

/// Un widget que renderiza un botón de acordeón diatónico con un auténtico
/// efecto 3D perlado / nácar, biselado de luz, sombra interior convexa,
/// brillo especular y glow dinámico, idéntico al renderizado CSS del simulador web.
class AccordionButton3D extends StatelessWidget {
  final double size;
  final bool isPressed;
  final BellowsMode bellowsMode;
  final ButtonType? buttonType; // null para agudos (treble), fundamental o chord para bajos
  final bool isSelectedForRhythm;
  final bool isChordGlow;
  final bool isDetectorSelected;
  final Widget? child;
  final VoidCallback? onPointerDown;
  final VoidCallback? onPointerUp;

  const AccordionButton3D({
    super.key,
    this.size = 50.0,
    required this.isPressed,
    this.bellowsMode = BellowsMode.both,
    this.buttonType,
    this.isSelectedForRhythm = false,
    this.isChordGlow = false,
    this.isDetectorSelected = false,
    this.child,
    this.onPointerDown,
    this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onPointerDown?.call(),
      onPointerUp: (_) => onPointerUp?.call(),
      onPointerCancel: (_) => onPointerUp?.call(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        transform: isPressed
            ? (Matrix4.diagonal3Values(1.15, 1.15, 1.0)
              ..setTranslationRaw(0.0, 2.0, 0.0))
            : Matrix4.identity(),
        child: CustomPaint(
          size: Size(size, size),
          painter: _AccordionButton3DPainter(
            isPressed: isPressed,
            bellowsMode: bellowsMode,
            buttonType: buttonType,
            isSelectedForRhythm: isSelectedForRhythm,
            isChordGlow: isChordGlow,
            isDetectorSelected: isDetectorSelected,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AccordionButton3DPainter extends CustomPainter {
  final bool isPressed;
  final BellowsMode bellowsMode;
  final ButtonType? buttonType;
  final bool isSelectedForRhythm;
  final bool isChordGlow;
  final bool isDetectorSelected;

  _AccordionButton3DPainter({
    required this.isPressed,
    required this.bellowsMode,
    required this.buttonType,
    required this.isSelectedForRhythm,
    required this.isChordGlow,
    required this.isDetectorSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Sombras exteriores / Glows
    if (isPressed) {
      if (bellowsMode == BellowsMode.push) {
        // Glow Rojo Vibrante al Cerrar (Push)
        final glowPaint1 = Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
        canvas.drawCircle(center, radius + 6, glowPaint1);

        final glowPaint2 = Paint()
          ..color = const Color(0xFFDC2626).withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
        canvas.drawCircle(center, radius + 10, glowPaint2);
      } else if (bellowsMode == BellowsMode.pull) {
        // Glow Azul Vibrante al Abrir (Pull)
        final glowPaint1 = Paint()
          ..color = const Color(0xFF60A5FA).withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
        canvas.drawCircle(center, radius + 6, glowPaint1);

        final glowPaint2 = Paint()
          ..color = const Color(0xFF2563EB).withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
        canvas.drawCircle(center, radius + 10, glowPaint2);
      } else {
        // Glow dorado expansivo (CSS: 0 0 26px 8px #fde047, 0 0 48px rgba(250, 204, 21, 0.85))
        final glowPaint1 = Paint()
          ..color = const Color(0xFFFDE047).withValues(alpha: 0.90)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(center, radius + 4, glowPaint1);

        final glowPaint2 = Paint()
          ..color = const Color(0xFFFACC15).withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
        canvas.drawCircle(center, radius + 7, glowPaint2);
      }

      // Sombra de contacto inferior comprimida
      final pressShadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center + const Offset(0, 2), radius, pressShadow);
    } else if (isChordGlow) {
      // Glow verde vibrante para acordes
      final glowGreen = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, radius + 4, glowGreen);
    } else if (isDetectorSelected) {
      // Glow violeta para detector armónico
      final glowPurple = Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, radius + 4, glowPurple);
    } else if (isSelectedForRhythm) {
      // Glow azul para botón de bajos seleccionado para patrón rítmico
      final glowBlue = Paint()
        ..color = const Color(0xFF0284C7).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius + 3, glowBlue);
    } else {
      // Sombra 3D de profundidad y relieve hacia abajo a la derecha:
      // box-shadow: 2px 5px 8px rgba(0, 0, 0, 0.6)
      final dropShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(center + const Offset(2.0, 4.5), radius - 0.5, dropShadowPaint);
    }

    // 2. Base del Botón (Cuerpo del Domo 3D)
    final buttonPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.clipPath(buttonPath);

    // Gradiente del cuerpo
    final Paint bodyPaint = Paint();

    if (isPressed) {
      if (bellowsMode == BellowsMode.push) {
        // Presionado Cerrando: Rojo fuego vivo con gradiente 3D
        bodyPaint.shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.85,
          colors: const [
            Color(0xFFFCA5A5), // Brillo central
            Color(0xFFEF4444), // Rojo vivo
            Color(0xFFB91C1C), // Sombra rim
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      } else if (bellowsMode == BellowsMode.pull) {
        // Presionado Abriendo: Azul eléctrico vivo con gradiente 3D
        bodyPaint.shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.85,
          colors: const [
            Color(0xFFBFDBFE), // Brillo central
            Color(0xFF3B82F6), // Azul eléctrico
            Color(0xFF1D4ED8), // Sombra rim
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      } else {
        // Estado presionado Ambos: Dorado brillante con profundidad
        bodyPaint.shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          radius: 0.85,
          colors: const [
            Color(0xFFFEF08A),
            Color(0xFFEAB308),
            Color(0xFFCA8A04),
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      }
    } else {
      // Estado normal (sin presionar): Perlado Nácar auténtico de acordeón Hohner / Corona
      // CSS: radial-gradient(circle at 14px 14px, #ffffff, #d3cbbd 70%, #9e9587 100%)
      bodyPaint.shader = RadialGradient(
        center: const Alignment(-0.44, -0.44),
        radius: 0.88,
        colors: const [
          Color(0xFFFFFFFF), // Brillo especular superior
          Color(0xFFE5DFD4), // Nácar claro
          Color(0xFFD3CBBD), // Nácar medio
          Color(0xFF9E9587), // Reborde 3D biselado
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }

    canvas.drawCircle(center, radius, bodyPaint);

    // 3. Biselado Interior y Sombras Inset
    if (!isPressed) {
      // Inset Shadow inferior derecha: inset -1px -2px 4px rgba(0, 0, 0, 0.25)
      // Genera la sensación de curvatura descendente hacia la caja del acordeón
      final innerShadowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.30),
          ],
          stops: const [0.0, 0.70, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, innerShadowPaint);

      // Inset Highlight superior izquierda: inset 1px 1px 2px rgba(255, 255, 255, 0.85)
      // Genera el resalte de filo blanco pulido
      final innerHighlightPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.65, -0.65),
          radius: 0.50,
          colors: [
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, innerHighlightPaint);

      // 4. Glint / Brillo Especular de Laca en forma ovalada superior
      final specularCenter = Offset(size.width * 0.36, size.height * 0.28);
      canvas.save();
      canvas.translate(specularCenter.dx, specularCenter.dy);
      canvas.rotate(-math.pi / 8);
      final glintRect = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.34,
        height: size.height * 0.16,
      );
      final glintPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.60),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(glintRect);
      canvas.drawOval(glintRect, glintPaint);
      canvas.restore();
    } else {
      // Inset Shadow al estar presionado (hunde el botón en el orificio)
      final pressDepressionPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, pressDepressionPaint);
    }

    canvas.restore();

    // 5. Borde Físico / Bisel Perimetral
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isPressed ? 1.5 : 1.0;

    if (isPressed) {
      if (bellowsMode == BellowsMode.push) {
        borderPaint.color = const Color(0xFFFCA5A5);
        borderPaint.strokeWidth = 2.0;
      } else if (bellowsMode == BellowsMode.pull) {
        borderPaint.color = const Color(0xFFBFDBFE);
        borderPaint.strokeWidth = 2.0;
      } else {
        borderPaint.color = const Color(0xFFFDE047);
        borderPaint.strokeWidth = 1.8;
      }
    } else if (buttonType == ButtonType.fundamental) {
      // Bajos fundamentales: Borde sutil ámbar
      borderPaint.color = const Color(0xFFF59E0B).withValues(alpha: 0.70);
      borderPaint.strokeWidth = 1.4;
    } else if (buttonType == ButtonType.chord) {
      // Acordes de bajos: Borde sutil esmeralda
      borderPaint.color = const Color(0xFF10B981).withValues(alpha: 0.70);
      borderPaint.strokeWidth = 1.4;
    } else {
      // Borde estándar del botón de acordeón: rgba(0, 0, 0, 0.28)
      borderPaint.color = const Color(0x47000000);
    }

    canvas.drawCircle(center, radius - (borderPaint.strokeWidth / 2), borderPaint);

    // 6. Dot indicador de botón seleccionado para ritmo en bajos
    if (isSelectedForRhythm) {
      final dotCenter = Offset(size.width - 5, size.height - 5);
      final dotPaint = Paint()..color = const Color(0xFF0284C7);
      final dotBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white;

      canvas.drawCircle(dotCenter, 3.5, dotPaint);
      canvas.drawCircle(dotCenter, 3.5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _AccordionButton3DPainter oldDelegate) {
    return oldDelegate.isPressed != isPressed ||
        oldDelegate.bellowsMode != bellowsMode ||
        oldDelegate.buttonType != buttonType ||
        oldDelegate.isSelectedForRhythm != isSelectedForRhythm ||
        oldDelegate.isChordGlow != isChordGlow ||
        oldDelegate.isDetectorSelected != isDetectorSelected;
  }
}
