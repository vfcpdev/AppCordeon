import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/bass_capture_key_mapper.dart';
import '../controllers/accordion_controller.dart';

/// Captura los eventos del teclado físico del PC para el capturador de
/// patrones rítmicos de bajos.
///
/// Mapeo activo (solo mientras `isBassCaptureActive == true`):
/// - [7] / [NumPad 7] → botón 7 (externo, fila 1)
/// - [8] / [NumPad 8] → botón 8 (externo, fila 2)
/// - [4] / [NumPad 4] → botón 4 (interno, fila 1)
/// - [5] / [NumPad 5] → botón 5 (interno, fila 2)
///
/// Las acciones previas sobre Escape, Espacio, Ctrl (BPM) y Alt+Flechas/B/A
/// fueron anuladas: ya no se registran atajos globales fuera de la captura.
///
/// Principios aplicados:
/// - **SRP**: este widget sólo traduce eventos de teclado a acciones del
///   capturador; no conoce la UI de la matriz ni el motor de audio.
/// - **OCP**: el mapeo tecla → botón vive en [BassCaptureKeyMapper]; añadir
///   teclas no requiere tocar este listener.
/// - **DIP**: depende de la abstracción del mapeador y del notifier, no de
///   widgets concretos.
/// - **Bajo acoplamiento**: usa `select`-free reads puntuales; no escucha el
///   estado completo ni reconstruye la UI.
/// - **Triplas de Hoare**: la precondición (captura activa y sin foco de
///   edición) se verifica antes de invocar al notifier.
class AccordionKeyboardListener extends ConsumerStatefulWidget {
  final Widget child;

  const AccordionKeyboardListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AccordionKeyboardListener> createState() =>
      _AccordionKeyboardListenerState();
}

class _AccordionKeyboardListenerState
    extends ConsumerState<AccordionKeyboardListener> {
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

  /// {P}: `event` es un evento de teclado físico del sistema.
  /// {Q}: retorna `true` si el evento fue consumido por el capturador
  ///      rítmico; `false` en cualquier otro caso (el evento sigue su curso).
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // No interferir con campos de texto (por ejemplo, el nombre del patrón).
    final isEditing =
        FocusManager.instance.primaryFocus?.context?.widget is EditableText;
    if (isEditing) return false;

    final state = ref.read(accordionSimulatorProvider);
    if (!state.isBassCaptureActive) return false;

    final buttonNumber = BassCaptureKeyMapper.map(event.logicalKey);
    if (buttonNumber == null) return false;

    // Consumir siempre las teclas mapeadas mientras se captura para evitar
    // que otros atajos o el sistema las procesen.
    final recorder = state.bassRhythmRecorder;
    if (recorder != null &&
        BassCaptureKeyMapper.isValid(buttonNumber) &&
        recorder.selectedButtons.contains(buttonNumber)) {
      ref
          .read(accordionSimulatorProvider.notifier)
          .captureBassMatrixHit(buttonNumber);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
