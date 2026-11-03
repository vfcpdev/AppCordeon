import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('Pruebas de Acciones Unificadas: Limpiar Selecciones Armónicas, Reproducir Acorde Continuo y Selección de Compás', () {
    Future<ProviderContainer> pumpGrid(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MeasureGridWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('El botón Limpiar Selecciones restablece tónica, cualidad y extensiones sin alterar el diapasón físico', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Simular selecciones armónicas y un botón pulsado en el diapasón físico
      notifier.setFreeChordRoot(3);
      notifier.setFreeChordType('min');
      notifier.pressButton('row1_btn0', 60);
      await tester.pumpAndSettle();

      var state = container.read(accordionSimulatorProvider);
      expect(state.freeChordRoot, equals(3));
      expect(state.freeChordType, equals('min'));
      expect(state.activeButtons, contains('row1_btn0'));

      // Presionar el botón de limpiar selecciones armónicas en compás
      expect(find.byKey(const ValueKey('clear_harmonic_selections_btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clear_harmonic_selections_btn')));
      await tester.pumpAndSettle();

      state = container.read(accordionSimulatorProvider);
      // Selecciones armónicas reseteadas
      expect(state.freeChordRoot, equals(-1));
      expect(state.freeChordType, isEmpty);
      expect(state.freeChordFourth, equals('none'));
      // Diapasón físico conservado (no se borró)
      expect(state.activeButtons, contains('row1_btn0'));
    });

    testWidgets('El botón Reproducir Acorde activa y desactiva la reproducción continua según BPM', (tester) async {
      final container = await pumpGrid(tester);

      expect(container.read(accordionSimulatorProvider).isPlayingAudio, isFalse);
      expect(find.byKey(const ValueKey('play_chord_sequence_btn')), findsOneWidget);

      // Activar reproducción continua
      await tester.tap(find.byKey(const ValueKey('play_chord_sequence_btn')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(accordionSimulatorProvider).isPlayingAudio, isTrue);

      // Desactivar reproducción continua
      await tester.tap(find.byKey(const ValueKey('play_chord_sequence_btn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(accordionSimulatorProvider).isPlayingAudio, isFalse);
    });

    testWidgets('Sincronización de borrado: permite modo independiente o sincronizado con el botón de enlace', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // 1. Por defecto: sincronización inactiva (modo independiente)
      expect(container.read(accordionSimulatorProvider).isClearSynced, isFalse);

      notifier.setFreeChordRoot(2);
      notifier.setFreeChordType('min');
      notifier.pressButton('row1_btn1', 62);
      await tester.pumpAndSettle();

      // Borrado desde el diapasón en modo independiente: borra diapasón pero NO las selecciones armónicas
      notifier.clearDiapason();
      await tester.pumpAndSettle();

      var state = container.read(accordionSimulatorProvider);
      expect(state.activeButtons, isEmpty);
      expect(state.freeChordRoot, equals(2));
      expect(state.freeChordType, equals('min'));

      // 2. Activar sincronización con el botón de enlace tipo volumen
      expect(find.byKey(const ValueKey('sync_clear_toggle_btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sync_clear_toggle_btn')));
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).isClearSynced, isTrue);

      // Re-armar estado
      notifier.setFreeChordRoot(5);
      notifier.setFreeChordType('dim');
      notifier.pressButton('row1_btn2', 64);
      await tester.pumpAndSettle();

      // 3. Borrado sincronizado: al presionar limpiar selecciones en compás, borra AMBOS
      await tester.tap(find.byKey(const ValueKey('clear_harmonic_selections_btn')));
      await tester.pumpAndSettle();

      state = container.read(accordionSimulatorProvider);
      expect(state.freeChordRoot, equals(-1));
      expect(state.freeChordType, isEmpty);
      expect(state.activeButtons, isEmpty);
    });

    testWidgets('Borrado unificado: borra casillas seleccionadas por asignación masiva de cajas de texto', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.updateMeasureBeat(0, 1, 'Re');
      notifier.updateMeasureBeat(0, 2, 'Mi');

      // Activar modo de asignación múltiple y marcar casillas tocando cajas (0,0) y (0,2)
      notifier.toggleMultiBeatAssignmentMode();
      notifier.toggleMultiBeatAssignmentTarget(0, 0);
      notifier.toggleMultiBeatAssignmentTarget(0, 2);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).multiBeatAssignmentTargets, containsAll([0, 2]));

      // Tocar el botón de borrar
      await tester.tap(find.byKey(const ValueKey('delete_grid_chords_btn')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      // (0,0) y (0,2) borrados
      expect(state.measures[0].beats[0].chord, isEmpty);
      expect(state.measures[0].beats[2].chord, isEmpty);
      // (0,1) intacto
      expect(state.measures[0].beats[1].chord, equals('Re'));
      // Ambas selecciones limpiadas
      expect(state.multiBeatAssignmentTargets, isEmpty);
      expect(state.markedBeats, isEmpty);
    });

    testWidgets('Resolución de contradicciones: selectBeat preserva acorde en preparación en el constructor', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Usuario prepara acorde en el constructor (Fa# = 6, min)
      notifier.setFreeChordRoot(6);
      notifier.setFreeChordType('min');
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).freeChordRoot, equals(6));
      expect(container.read(accordionSimulatorProvider).freeChordType, equals('min'));
      expect(container.read(accordionSimulatorProvider).isFreeChordBeingEdited, isTrue);

      // Hace clic en una celda vacía para seleccionarla como destino
      notifier.selectBeat(1, 2);
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      // El foco se movió a la celda 1, 2 sin destruir el acorde que estaba armando
      expect(state.selectedBarIndex, equals(1));
      expect(state.selectedBeatIndex, equals(2));
      expect(state.freeChordRoot, equals(6));
      expect(state.freeChordType, equals('min'));
    });

    testWidgets('Resolución de contradicciones: updateMeasureBeat sincroniza bidireccionalmente con la matriz armónica', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Escribir acorde directamente en casilla
      notifier.updateMeasureBeat(0, 0, 'Solm');
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      // La matriz de tónica y cualidad refleja en tiempo real el acorde escrito
      expect(state.freeChordRoot, equals(7)); // Sol = 7
      expect(state.freeChordType, equals('min'));
    });
  });
}
