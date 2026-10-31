import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../controllers/accordion_controller.dart';

/// Captura eventos del teclado físico del PC para tocar los botones del acordeón
/// y alternar la dirección del fuelle con la tecla Escape.
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
  final Map<LogicalKeyboardKey, (String, int)> _pressedKeys = {};

  // Mapeo de teclas físicas a botones (Hilera 1, 2 y 3)
  // Hilera 1 (Afuera): Empieza en Z -> Z, X, C, V, B, N, M, Comma, Period, Minus/Slash
  static final List<LogicalKeyboardKey> _row1Keys = [
    LogicalKeyboardKey.keyZ,
    LogicalKeyboardKey.keyX,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyV,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyN,
    LogicalKeyboardKey.keyM,
    LogicalKeyboardKey.comma,
    LogicalKeyboardKey.period,
    LogicalKeyboardKey.minus,
    LogicalKeyboardKey.slash,
  ];

  // Hilera 2 (Central): Empieza en A -> A, S, D, F, G, H, J, K, L, Semicolon/Quote, BracketLeft
  static final List<LogicalKeyboardKey> _row2Keys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyG,
    LogicalKeyboardKey.keyH,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyL,
    LogicalKeyboardKey.semicolon,
    LogicalKeyboardKey.quote,
    LogicalKeyboardKey.bracketLeft,
  ];

  // Hilera 3 (Adentro): Empieza en W -> W, E, R, T, Y, U, I, O, P, BracketRight, Backslash
  static final List<LogicalKeyboardKey> _row3Keys = [
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.keyR,
    LogicalKeyboardKey.keyT,
    LogicalKeyboardKey.keyY,
    LogicalKeyboardKey.keyU,
    LogicalKeyboardKey.keyI,
    LogicalKeyboardKey.keyO,
    LogicalKeyboardKey.keyP,
    LogicalKeyboardKey.bracketRight,
    LogicalKeyboardKey.backslash,
  ];

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
    // 1. Detección prioritaria de la tecla Escape para cambiar el fuelle inmediatamente
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

    _handleKeyEvent(event);
    return false;
  }

  void _toggleBellows() {
    final state = ref.read(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    final current = state.bellows1;
    final next = (current == BellowsMode.push) ? BellowsMode.pull : BellowsMode.push;

    // Si hay teclas presionadas actualmente en el teclado físico:
    // en un acordeón real, al invertir el fuelle sin soltar el botón,
    // la nota cambia inmediatamente a la dirección opuesta (pull <-> push).
    if (_pressedKeys.isNotEmpty) {
      final entries = Map<LogicalKeyboardKey, (String, int)>.from(_pressedKeys);
      _pressedKeys.clear();

      // Apagar notas anteriores
      for (final entry in entries.entries) {
        notifier.releaseButton(entry.value.$1, entry.value.$2);
      }

      // Cambiar fuelle
      notifier.setBellows1(next);

      // Re-encender botones con el nuevo tono correspondiente al nuevo fuelle
      final nextState = ref.read(accordionSimulatorProvider);
      for (final entry in entries.entries) {
        final btnTarget = _findButtonForKey(entry.key);
        if (btnTarget != null) {
          final rowKey = btnTarget.$1;
          final btnIndex = btnTarget.$2;
          final buttons = nextState.trebleData1[rowKey];
          if (buttons != null && btnIndex < buttons.length) {
            final btnModel = buttons[btnIndex];
            // `trebleData1` ya está transpuesto según la afinación.
            final newMidi = (next == BellowsMode.pull)
                ? btnModel.pull
                : btnModel.push;
            final buttonId = '${rowKey}_$btnIndex';
            _pressedKeys[entry.key] = (buttonId, newMidi);
            notifier.pressButton(buttonId, newMidi);
          }
        }
      }
    } else {
      notifier.setBellows1(next);
    }
  }

  (String rowKey, int index)? _findButtonForKey(LogicalKeyboardKey key) {
    final idx1 = _row1Keys.indexOf(key);
    if (idx1 != -1 && idx1 < 10) return ('row1', idx1);

    final idx2 = _row2Keys.indexOf(key);
    if (idx2 != -1 && idx2 < 11) return ('row2', idx2);

    final idx3 = _row3Keys.indexOf(key);
    if (idx3 != -1 && idx3 < 10) return ('row3', idx3);

    return null;
  }

  void _handleKeyEvent(KeyEvent event) {
    final state = ref.read(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    final btnTarget = _findButtonForKey(event.logicalKey);
    if (btnTarget == null) return;

    final rowKey = btnTarget.$1;
    final btnIndex = btnTarget.$2; // 0-based
    final buttonId = '${rowKey}_$btnIndex';

    final buttons = state.trebleData1[rowKey];
    if (buttons == null || btnIndex >= buttons.length) return;
    final btnModel = buttons[btnIndex];

    final currentBellows = state.bellows1;
    // `trebleData1` ya está transpuesto según la afinación.
    final midiToPlay = (currentBellows == BellowsMode.pull)
        ? btnModel.pull
        : btnModel.push;

    if (event is KeyDownEvent) {
      if (!_pressedKeys.containsKey(event.logicalKey)) {
        _pressedKeys[event.logicalKey] = (buttonId, midiToPlay);
        if (state.detectorMode) {
          notifier.toggleDetectorButton(buttonId, midiToPlay);
        } else {
          notifier.pressButton(buttonId, midiToPlay);
        }
      }
    } else if (event is KeyUpEvent) {
      final active = _pressedKeys.remove(event.logicalKey);
      final idToRelease = active?.$1 ?? buttonId;
      final midiToRelease = active?.$2 ?? midiToPlay;

      if (!state.detectorMode) {
        notifier.releaseButton(idToRelease, midiToRelease);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
