import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/multi_beat_chord_dialog.dart';
import 'package:acordeon_flutter/presentation/widgets/tonic_bar_widget.dart';

void main() {
  group('AccordionSimulatorNotifier - Asignación Múltiple de Acordes', () {
    test('parseMultiBeatPositions interpreta correctamente formato Compás.Cuadro separado por comas', () {
      final positions = AccordionSimulatorNotifier.parseMultiBeatPositions('1.1, 2.3, 5.2');
      expect(positions.length, 3);
      expect(positions[0].barNumber, 1);
      expect(positions[0].beatNumber, 1);
      expect(positions[1].barNumber, 2);
      expect(positions[1].beatNumber, 3);
      expect(positions[2].barNumber, 5);
      expect(positions[2].beatNumber, 2);
    });

    test('applyMultiBeatChord asigna el acorde en los cuadros especificados y expande compases si es necesario', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Inicialmente hay 8 compases
      var state = container.read(accordionSimulatorProvider);
      expect(state.measures.length, 8);

      // Asignar Sol7 en 1.1, 2.3, 10.2
      final count = notifier.applyMultiBeatChord(chord: 'Sol7', pattern: '1.1, 2.3, 10.2');
      expect(count, 3);

      state = container.read(accordionSimulatorProvider);
      // Debe haberse expandido automáticamente a 10 compases
      expect(state.measures.length, greaterThanOrEqualTo(10));

      // Verificar que los cuadros específicos recibieron el acorde
      expect(state.measures[0].beats[0].chord, 'Sol7'); // Compás 1 cuadro 1
      expect(state.measures[1].beats[2].chord, 'Sol7'); // Compás 2 cuadro 3
      expect(state.measures[9].beats[1].chord, 'Sol7'); // Compás 10 cuadro 2

      // Otros cuadros deben permanecer vacíos
      expect(state.measures[0].beats[1].chord, '');
      expect(state.measures[1].beats[0].chord, '');

      expect(state.multiBeatChord, 'Sol7');
      expect(state.multiBeatPattern, '1.1, 2.3, 10.2');

      // Los cuadros registrados deben quedar seleccionados en markedBeats
      expect(state.markedBeats, containsAll([
        AccordionSimulatorNotifier.beatKey(0, 0),
        AccordionSimulatorNotifier.beatKey(1, 2),
        AccordionSimulatorNotifier.beatKey(9, 1),
      ]));
    });
  });

  group('TonicBarWidget - Checkbox a la derecha de Agregar a Compás', () {
    testWidgets('Checkbox a la derecha de agregar a compás abre y cierra el modal movible',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 150,
                child: TonicBarWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe encontrarse el botón de agregar a compás y el checkbox a su derecha
      expect(find.byKey(const ValueKey('insert_chord_to_compas_btn')), findsOneWidget);
      final checkboxFinder = find.byKey(const ValueKey('multi_beat_modal_checkbox'));
      expect(checkboxFinder, findsOneWidget);

      // Inicialmente no está seleccionado
      expect(container.read(accordionSimulatorProvider).showMultiBeatModal, isFalse);

      // Al tocar el checkbox, se activa el modal en el estado
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).showMultiBeatModal, isTrue);

      // Al volver a tocar, se desactiva
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).showMultiBeatModal, isFalse);
    });
  });

  group('MultiBeatChordDialog - Modal Movible', () {
    testWidgets('Permite escribir posiciones 1.1, 2.3, 5.2 y confirmar para aplicar acorde',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.openMultiBeatModalForChord('Do');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  MultiBeatChordDialog(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el título del modal
      expect(find.text('Asignar a Múltiples Compases'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);

      // Escribir 1.1, 2.3, 5.2 en el campo de texto
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      await tester.enterText(textFieldFinder, '1.1, 2.3, 5.2');
      await tester.pumpAndSettle();

      // Pulsar Confirmar
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      expect(state.showMultiBeatModal, isFalse);
      expect(state.measures[0].beats[0].chord, 'Do');
      expect(state.measures[1].beats[2].chord, 'Do');
      expect(state.measures[4].beats[1].chord, 'Do');
    });
  });

  group('MeasureGridWidget - Botón de edición y tamaño 50% mayor', () {
    testWidgets('Botón de edición a la derecha de importar se activa al seleccionar el acorde en cualquier compás',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Asignar acorde 'Sol7' en el compás
      notifier.applyMultiBeatChord(chord: 'Sol7', pattern: '1.1, 2.3');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MeasureGridWidget(width: 150),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editBtnFinder = find.byKey(const ValueKey('edit_multi_beat_chord_btn'));
      expect(editBtnFinder, findsOneWidget);

      // Al seleccionar el compás 1 cuadro 1 (que tiene Sol7), el botón de edición está activo
      notifier.selectBeat(0, 0);
      await tester.pumpAndSettle();

      // Pulsar el botón de edición debe abrir el modal para ese acorde y precargar la cadena de texto
      await tester.tap(editBtnFinder);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).showMultiBeatModal, isTrue);
      expect(container.read(accordionSimulatorProvider).multiBeatChord, 'Sol7');
      expect(container.read(accordionSimulatorProvider).multiBeatPattern, '1.1, 2.3');
    });

    testWidgets('Al editar la cadena de texto en el modal, se muestran todas las posiciones y se actualiza la asignación',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Asignar Sol7 en 1.1 y 2.3
      notifier.applyMultiBeatChord(chord: 'Sol7', pattern: '1.1, 2.3');

      // Abrir modal de edición para Sol7 (debe recolectar '1.1, 2.3')
      notifier.openMultiBeatModalForChord('Sol7');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  MultiBeatChordDialog(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El campo de texto debe mostrar la cadena de texto separada por comas de todos los compases y cuadros
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '1.1, 2.3');

      // Editar la cadena de texto a 1.1, 2.4
      await tester.enterText(find.byType(TextField), '1.1, 2.4');
      await tester.pumpAndSettle();

      // Confirmar edición
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      expect(state.measures[0].beats[0].chord, 'Sol7'); // 1.1 sigue teniendo Sol7
      expect(state.measures[1].beats[2].chord, '');     // 2.3 se limpió porque se editó
      expect(state.measures[1].beats[3].chord, 'Sol7'); // 2.4 ahora tiene Sol7

      // Los cuadros registrados al editar deben quedar seleccionados
      expect(state.markedBeats, containsAll([
        AccordionSimulatorNotifier.beatKey(0, 0),
        AccordionSimulatorNotifier.beatKey(1, 3),
      ]));
      expect(state.markedBeats, isNot(contains(AccordionSimulatorNotifier.beatKey(1, 2))));
    });
  });
}
