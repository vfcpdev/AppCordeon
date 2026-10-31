import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/commands/accordion_commands.dart';
import '../controllers/accordion_controller.dart';

/// Captura atajos globales del teclado físico del PC para funciones de control y transporte:
/// - Tecla [Escape]: Alterna la dirección del fuelle mediante [ToggleBellowsCommand].
/// - Tecla [Espacio]: Marca cambio armónico en vivo con [markLiveChordChange].
/// - Tecla [Control]: Calibra el BPM a partir de toques al inicio de compás.
/// - Teclas [Alt + Flechas / B / A]: Micro-ajustes de desfase de pulso y auto-detección.
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Gestión exclusiva de atajos de control y transporte.
/// - Bajo acoplamiento: Se elimina la relación directa entre el teclado QWERTY y los botones melódicos
///   del diapasón, evitando interferencias o activaciones de notas indeseadas al escribir o interactuar.
/// - Enfoque formal con Triplas de Hoare mediante [ToggleBellowsCommand].
class AccordionKeyboardListener extends ConsumerStatefulWidget {
  final Widget child;

  const AccordionKeyboardListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AccordionKeyboardListener> createState() => _AccordionKeyboardListenerState();
}

class _AccordionKeyboardListenerState extends ConsumerState<AccordionKeyboardListener> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    // 1. Detección prioritaria de la tecla Escape para alternar el fuelle inmediatamente
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _toggleBellows();
      }
      return true; // Consumir el evento Escape para evitar que el navegador o modales pierdan foco
    }

    // 2. Barra espaciadora para aplicar el acorde detectado en el audio al compás y diapasón
    if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
      final isAnyEditing = FocusManager.instance.primaryFocus?.context?.widget is EditableText;
      if (!isAnyEditing) {
        final res = ref.read(accordionSimulatorProvider.notifier).markLiveChordChange();
        if (res != null) {
          return true;
        }
      }
    }

    // 3. Tecla Control: calibración del BPM (1er toque = Compás 1, 2º toque = compás siguiente)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.controlRight)) {
      final notifier = ref.read(accordionSimulatorProvider.notifier);
      final bpm = notifier.tapBpmCalibration();
      if (mounted) {
        final calibrating = ref.read(accordionSimulatorProvider).isCalibratingBpm;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        if (bpm != null) {
          final state = ref.read(accordionSimulatorProvider);
          final mins = (state.audioStartOffset ~/ 60).toString().padLeft(2, '0');
          final secs = (state.audioStartOffset % 60).toStringAsFixed(1).padLeft(4, '0');
          messenger?.showSnackBar(SnackBar(
            content: Text('BPM ajustado a $bpm (Compás 1 en $mins:$secs). Cambios de acorde aplicados.'),
            duration: const Duration(seconds: 3),
          ));
        } else if (calibrating) {
          final state = ref.read(accordionSimulatorProvider);
          final mins = (state.audioStartOffset ~/ 60).toString().padLeft(2, '0');
          final secs = (state.audioStartOffset % 60).toStringAsFixed(1).padLeft(4, '0');
          messenger?.showSnackBar(SnackBar(
            content: Text('Compás 1 fijado en $mins:$secs. Presiona Control al inicio del siguiente compás.'),
            duration: const Duration(seconds: 3),
          ));
        }
      }
      return false;
    }

    // 4. Ajustes del beat y auto-detección con tecla Alt
    if (event is KeyDownEvent && HardwareKeyboard.instance.isAltPressed) {
      final isAnyEditing = FocusManager.instance.primaryFocus?.context?.widget is EditableText;
      if (!isAnyEditing) {
        final notifier = ref.read(accordionSimulatorProvider.notifier);
        final messenger = ScaffoldMessenger.maybeOf(context);

        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          notifier.adjustBeatOffset(-0.025);
          if (mounted) {
            final ms = (ref.read(accordionSimulatorProvider).beatNudgeOffset * 1000).round();
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(SnackBar(
              content: Text('Beat atrasado -25 ms (Desfase: ${ms >= 0 ? "+" : ""}$ms ms)'),
              duration: const Duration(seconds: 1),
            ));
          }
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          notifier.adjustBeatOffset(0.025);
          if (mounted) {
            final ms = (ref.read(accordionSimulatorProvider).beatNudgeOffset * 1000).round();
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(SnackBar(
              content: Text('Beat adelantado +25 ms (Desfase: ${ms >= 0 ? "+" : ""}$ms ms)'),
              duration: const Duration(seconds: 1),
            ));
          }
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyB) {
          notifier.syncBeatToCurrentAudioTime();
          if (mounted) {
            final ms = (ref.read(accordionSimulatorProvider).beatNudgeOffset * 1000).round();
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(SnackBar(
              content: Text('Beat sincronizado con el audio (Desfase: ${ms >= 0 ? "+" : ""}$ms ms)'),
              duration: const Duration(seconds: 2),
            ));
          }
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyA) {
          notifier.togglePlaybackAutoChordDetect();
          if (mounted) {
            final active = ref.read(accordionSimulatorProvider).isPlaybackAutoChordDetectEnabled;
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(SnackBar(
              content: Text(active
                  ? 'Detección Automática en Reproducción Activada (solo en cambios de acorde).'
                  : 'Detección Automática en Reproducción Desactivada.'),
              duration: const Duration(seconds: 2),
            ));
          }
          return true;
        }
      }
    }

    return false;
  }

  void _toggleBellows() {
    final state = ref.read(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    // Alterna fuelle usando el comando desacoplado formalizado con Triplas de Hoare
    final command = ToggleBellowsCommand(currentMode: state.bellows1);
    final nextBellows = command.execute();
    notifier.setBellows1(nextBellows);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
