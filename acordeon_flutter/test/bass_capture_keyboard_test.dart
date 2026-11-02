import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/domain/models/accordion_data.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/services/bass_capture_key_mapper.dart';
import 'package:acordeon_flutter/domain/services/bass_capture_matrix_mapper.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/accordion_keyboard_listener.dart';

/// Verifica el capturador de patrones rítmicos por teclado (Windows).
///
/// {I}: los botones de la matriz 2×2 son siempre {7, 8, 4, 5} y el mapeo
///      tecla → botón es puro y determinista.
void main() {
  group('BassCaptureKeyMapper', () {
    test('mapea los dígitos de la fila principal', () {
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.digit7), 7);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.digit8), 8);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.digit4), 4);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.digit5), 5);
    });

    test('mapea el teclado numérico', () {
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.numpad7), 7);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.numpad8), 8);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.numpad4), 4);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.numpad5), 5);
    });

    test('ignora teclas fuera del mapeo', () {
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.keyA), isNull);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.space), isNull);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.escape), isNull);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.digit1), isNull);
      expect(BassCaptureKeyMapper.map(LogicalKeyboardKey.numpad9), isNull);
    });

    test('solo acepta botones de la matriz 2×2', () {
      for (final button in BassCaptureKeyMapper.validButtons) {
        expect(BassCaptureKeyMapper.isValid(button), isTrue);
      }
      expect(BassCaptureKeyMapper.isValid(1), isFalse);
      expect(BassCaptureKeyMapper.isValid(6), isFalse);
      expect(BassCaptureKeyMapper.isValid(9), isFalse);
    });
  });

  group('BassCaptureMatrixMapper', () {
    test('columna exterior mapea fila 1 → 7 y fila 2 → 8', () {
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 0,
          btnIndex: 1,
          type: ButtonType.fundamental,
        ),
        7,
      );
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 0,
          btnIndex: 3,
          type: ButtonType.fundamental,
        ),
        8,
      );
    });

    test('columna interior mapea fila 1 → 4 y fila 2 → 5', () {
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 1,
          btnIndex: 2,
          type: ButtonType.fundamental,
        ),
        4,
      );
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 1,
          btnIndex: 4,
          type: ButtonType.fundamental,
        ),
        5,
      );
    });

    test('el bajo grave y los acordes quedan fuera de la matriz', () {
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 0,
          btnIndex: 5,
          type: ButtonType.fundamental,
        ),
        isNull,
      );
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 1,
          btnIndex: 6,
          type: ButtonType.fundamental,
        ),
        isNull,
      );
      expect(
        BassCaptureMatrixMapper.fromPhysical(
          rhythmButtonOffset: 0,
          btnIndex: 1,
          type: ButtonType.chord,
        ),
        isNull,
      );
    });
  });

  group('Captura por teclado end-to-end', () {
    testWidgets('las teclas 4/5/7/8 registran golpes durante la captura',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(accordionSimulatorProvider.notifier);
      notifier.startBassRhythmCapture(
        name: 'Prueba teclado',
        selectedButtons: const {4, 5, 7, 8},
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AccordionKeyboardListener(
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(key);
        await tester.sendKeyUpEvent(key);
        // Avanza el reloj de captura (40 ms por tick) para que cada golpe
        // tenga un onset distinto y no sea descartado por duplicado.
        await tester.pump(const Duration(milliseconds: 200));
      }

      await press(LogicalKeyboardKey.digit7);
      await press(LogicalKeyboardKey.numpad8);
      await press(LogicalKeyboardKey.digit4);
      await press(LogicalKeyboardKey.numpad5);

      final recorder =
          container.read(accordionSimulatorProvider).bassRhythmRecorder;
      expect(recorder, isNotNull);
      expect(recorder!.hits.map((hit) => hit.buttonIndex), [7, 8, 4, 5]);

      notifier.cancelBassRhythmCapture();
    });

    testWidgets('las teclas no mapeadas no registran golpes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(accordionSimulatorProvider.notifier);
      notifier.startBassRhythmCapture(
        name: 'Prueba sin teclas',
        selectedButtons: const {7},
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AccordionKeyboardListener(
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 200));

      final recorder =
          container.read(accordionSimulatorProvider).bassRhythmRecorder;
      expect(recorder!.hits, isEmpty);

      notifier.cancelBassRhythmCapture();
    });

    testWidgets('sin captura activa las teclas no registran golpes',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AccordionKeyboardListener(
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit7);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit7);
      await tester.pump();

      final state = container.read(accordionSimulatorProvider);
      expect(state.isBassCaptureActive, isFalse);
      expect(state.bassRhythmRecorder, isNull);
    });
  });
}
