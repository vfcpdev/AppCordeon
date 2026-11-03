import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/diapason_button_widget.dart';
import 'package:acordeon_flutter/domain/models/tuning.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';

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

    testWidgets('Guardar e Importar compás están ubicados a la derecha del BPM', (tester) async {
      await pumpGrid(tester);

      expect(find.byTooltip('Guardar compases en JSON (Exportar)'), findsOneWidget);
      expect(find.byTooltip('Importar compases desde archivo JSON'), findsOneWidget);

      // Verificamos que el control de metrónomo también está presente en la cabecera
      expect(find.byTooltip('Activar Metrónomo (Click sincronizado con compás)'), findsOneWidget);
    });

    testWidgets('Opción de borrar acorde resetea el cuadro de texto enfocado a silencio sin marcas previas', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Escribir acorde en el compás 0, tiempo 1
      notifier.updateMeasureBeat(0, 1, 'Lam');
      notifier.selectBeat(0, 1);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).measures[0].beats[1].chord, equals('Lam'));
      expect(container.read(accordionSimulatorProvider).markedBeats, isEmpty);

      // Tocar el botón de borrar acorde
      await tester.tap(find.byKey(const ValueKey('delete_grid_chords_btn')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      // {Q}: El cuadro de texto quedó reseteado a silencio ('') para no ejecutar acorde
      expect(state.measures[0].beats[1].chord, isEmpty);
      // Invariante de Memento: se puede revertir con undo si el usuario lo desea
      expect(state.canUndoGrid, isTrue);
    });

    testWidgets('Opción de borrar acorde borra múltiples cuadros seleccionados', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.updateMeasureBeat(0, 1, 'Sol');
      notifier.updateMeasureBeat(0, 2, 'Fa');

      // Marcar casillas (0,0) y (0,2)
      notifier.toggleBeatMark(0, 0);
      notifier.toggleBeatMark(0, 2);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).markedBeats.length, equals(2));

      // Tocar el botón de borrar acorde
      await tester.tap(find.byKey(const ValueKey('delete_grid_chords_btn')));
      await tester.pumpAndSettle();

      final state = container.read(accordionSimulatorProvider);
      // Los cuadros seleccionados fueron borrados
      expect(state.measures[0].beats[0].chord, isEmpty);
      expect(state.measures[0].beats[2].chord, isEmpty);
      // El cuadro no seleccionado permanece intacto
      expect(state.measures[0].beats[1].chord, equals('Sol'));
      // Las marcas quedan limpias
      expect(state.markedBeats, isEmpty);
    });

    testWidgets('Botones de cabecera del compás (Metrónomo, Guardar, Importar) tienen tamaño homogéneo de 29x29', (tester) async {
      await pumpGrid(tester);

      final metronomeFinder = find.byKey(const ValueKey('metronome_toggle_btn_1'));
      expect(metronomeFinder, findsOneWidget);
      final metronomeSize = tester.getSize(metronomeFinder);
      expect(metronomeSize.width, equals(29.0));
      expect(metronomeSize.height, equals(29.0));

      final saveFinder = find.byTooltip('Guardar compases en JSON (Exportar)');
      expect(saveFinder, findsOneWidget);
      final saveSize = tester.getSize(saveFinder);
      expect(saveSize.width, equals(29.0));
      expect(saveSize.height, equals(29.0));

      final importFinder = find.byTooltip('Importar compases desde archivo JSON');
      expect(importFinder, findsOneWidget);
      final importSize = tester.getSize(importFinder);
      expect(importSize.width, equals(29.0));
      expect(importSize.height, equals(29.0));
    });

    testWidgets('Flechas de fuelle para compás colorizan todo el fondo del botón (Verde si abre, Rojo si cierra)', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.selectBeat(0, 0);
      notifier.setBeatBellows(0, 0, BellowsMode.pull);
      await tester.pumpAndSettle();

      // Flecha abre seleccionada -> fondo verde completo
      final pullContainer = tester.widget<Container>(
        find.descendant(
          of: find.byTooltip('Abre (Fuelle abriendo)'),
          matching: find.byType(Container),
        ).first,
      );
      final pullDeco = pullContainer.decoration as BoxDecoration;
      expect(pullDeco.color, equals(const Color(0xFF16A34A)));

      // Cambiar a cierra -> fondo rojo completo
      notifier.setBeatBellows(0, 0, BellowsMode.push);
      await tester.pumpAndSettle();

      final pushContainer = tester.widget<Container>(
        find.descendant(
          of: find.byTooltip('Cierra (Fuelle cerrando)'),
          matching: find.byType(Container),
        ).first,
      );
      final pushDeco = pushContainer.decoration as BoxDecoration;
      expect(pushDeco.color, equals(const Color(0xFFDC2626)));
    });

    testWidgets('Color permanente del cuadro: Verde si abre, Rojo si cierra, y Amarillo si abre o cierra por definir', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Compás 0.0: con acorde pero fuelle BellowsMode.both (abrir o cerrar por definir)
      notifier.updateMeasureBeat(0, 0, 'Do');
      await tester.pumpAndSettle();

      final beat0Pending = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('beat_cell_0_0')),
      );
      final beat0PendingDeco = beat0Pending.decoration as BoxDecoration;
      // Fondo amarillo cálido de decisión
      expect(beat0PendingDeco.color, equals(const Color(0xFFFEF08A)));

      // Definir fuelle a Abre (pull) -> Color queda asignado en Verde permanente sin reproducir
      notifier.setBeatBellows(0, 0, BellowsMode.pull);
      await tester.pumpAndSettle();

      final beat0Pull = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('beat_cell_0_0')),
      );
      final beat0PullDeco = beat0Pull.decoration as BoxDecoration;
      expect(beat0PullDeco.color, equals(const Color(0xFF16A34A))); // Verde permanente

      // Compás 0.1: con acorde y fuelle definido a Cierra (push) -> Rojo permanente
      notifier.updateMeasureBeat(0, 1, 'Sol');
      notifier.setBeatBellows(0, 1, BellowsMode.push);
      await tester.pumpAndSettle();

      final beat1Push = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('beat_cell_0_1')),
      );
      final beat1PushDeco = beat1Push.decoration as BoxDecoration;
      expect(beat1PushDeco.color, equals(const Color(0xFFDC2626))); // Rojo permanente

      // El estado no está reproduciendo y los colores permanecen
      expect(container.read(accordionSimulatorProvider).isPlayingAudio, isFalse);
    });

    testWidgets('Al reproducir compás, la asignación de fuelle mantiene el cuadro en Verde si abre y Rojo si cierra con borde activo', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      notifier.updateMeasureBeat(0, 0, 'Do');
      notifier.setBeatBellows(0, 0, BellowsMode.pull);
      notifier.updateMeasureBeat(0, 1, 'Sol');
      notifier.setBeatBellows(0, 1, BellowsMode.push);

      // Simular reproducción en el compás 0, pulso 0 (pull)
      container.read(accordionSimulatorProvider.notifier).state =
          container.read(accordionSimulatorProvider).copyWith(
                isPlayingAudio: true,
                selectedBarIndex: 0,
                selectedBeatIndex: 0,
              );
      await tester.pumpAndSettle();

      final beat0Container = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('beat_cell_0_0')),
      );
      final beat0Deco = beat0Container.decoration as BoxDecoration;
      expect(beat0Deco.color, equals(const Color(0xFF16A34A))); // Verde al abrir

      // Simular avance al pulso 1 (push)
      container.read(accordionSimulatorProvider.notifier).state =
          container.read(accordionSimulatorProvider).copyWith(
                isPlayingAudio: true,
                selectedBarIndex: 0,
                selectedBeatIndex: 1,
              );
      await tester.pumpAndSettle();

      final beat1Container = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('beat_cell_0_1')),
      );
      final beat1Deco = beat1Container.decoration as BoxDecoration;
      expect(beat1Deco.color, equals(const Color(0xFFDC2626))); // Rojo al cerrar
    });

    testWidgets('Borde de cuadros de compás: tenue gris claro en reposo y resaltado en azul al seleccionar', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // En reposo (sin seleccionar), el cuadro tiene borde tenue en gris claro
      final cell0 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('beat_cell_0_0')));
      final cell0Deco = cell0.decoration as BoxDecoration;
      final cell0Border = cell0Deco.border as Border;
      expect(cell0Border.top.color, equals(const Color(0xFFCBD5E1)));
      expect(cell0Border.top.width, equals(1.0));

      // Al seleccionar el cuadro, se resalta con borde Azul
      notifier.selectBeat(0, 0);
      await tester.pumpAndSettle();

      final cell0Selected = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('beat_cell_0_0')));
      final cell0SelectedDeco = cell0Selected.decoration as BoxDecoration;
      final cell0SelectedBorder = cell0SelectedDeco.border as Border;
      expect(cell0SelectedBorder.top.color, equals(const Color(0xFF2563EB)));
      expect(cell0SelectedBorder.top.width, equals(2.0));
    });

    testWidgets('Etiqueta del acorde y notas que lo conforman sobre los botones de tónica reutiliza el banner sin botones 3, 4 y 5', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Verificar que la etiqueta reutilizada sobre las tónicas existe
      final tonicBannerFinder = find.byKey(const ValueKey('tonic_chord_header_banner'));
      expect(tonicBannerFinder, findsOneWidget);

      // Los botones de estructura 3, 4 y 5 no deben existir en el banner de tónicas
      expect(find.descendant(of: tonicBannerFinder, matching: find.byKey(const ValueKey('diapason_structure_triad'))), findsNothing);
      expect(find.descendant(of: tonicBannerFinder, matching: find.byKey(const ValueKey('diapason_structure_seventh'))), findsNothing);
      expect(find.descendant(of: tonicBannerFinder, matching: find.byKey(const ValueKey('diapason_structure_five'))), findsNothing);

      // Seleccionar tónica Sol (7) y cualidad menor ('min')
      notifier.setFreeChordRoot(7);
      notifier.setFreeChordType('min');
      await tester.pumpAndSettle();

      // Debe mostrar el acorde y sus notas conformantes
      final bannerText = tester.widget<Text>(tonicBannerFinder).textSpan?.toPlainText();
      expect(bannerText, contains('Solm'));
      expect(bannerText, contains('Sol - Si♭ - Re'));
    });

    testWidgets('Estado del Acorde no muestra nada cuando no hay notas ni acorde y se actualiza al definir tónica o compás', (tester) async {
      final container = await pumpGrid(tester);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // En reposo limpio (sin notas en diapasón, ni compás, ni edición en constructor), Estado del Acorde no debe mostrar nada
      expect(find.text('Estado del Acorde'), findsNothing);

      // Al definir una tónica en el constructor, se muestra inmediatamente la información actualizada
      notifier.setFreeChordRoot(7); // Sol
      await tester.pumpAndSettle();
      expect(find.text('Estado del Acorde'), findsOneWidget);
      expect(find.textContaining('Constructor'), findsOneWidget);

      // Al limpiar las selecciones armónicas, vuelve a ocultarse
      notifier.clearHarmonicSelections();
      await tester.pumpAndSettle();
      expect(find.text('Estado del Acorde'), findsNothing);

      // Al asignar un acorde en el compás, aparece de nuevo reflejando la casilla
      notifier.updateMeasureBeat(0, 0, 'Fa');
      notifier.selectBeat(0, 0);
      await tester.pumpAndSettle();
      expect(find.text('Estado del Acorde'), findsOneWidget);
      expect(find.textContaining('C1.1'), findsOneWidget);
    });

    testWidgets('Los botones que abren en el diapasón se colorean de verde', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiapasonWidget(
                  currentTuning: TuningRegistry.defaultTunings[0],
                  onTuningChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Cambiar fuelle a Abre (pull) y limpiar selecciones armónicas para verificar notas en reposo
      notifier.setBellows1(BellowsMode.pull);
      notifier.clearHarmonicSelections();
      await tester.pumpAndSettle();

      // 1. En reposo abriendo (sin acorde tintando el cuerpo), la etiqueta de la nota del botón es verde
      final diapasonButtons = find.byType(DiapasonButtonWidget);
      expect(diapasonButtons, findsWidgets);

      final firstButton = tester.widget<DiapasonButtonWidget>(diapasonButtons.first);
      expect(firstButton.bellowsMode, BellowsMode.pull);

      final noteTextFinder = find.descendant(of: diapasonButtons.first, matching: find.byType(Text)).last;
      final noteText = tester.widget<Text>(noteTextFinder);
      expect(noteText.style?.color, equals(const Color(0xFF15803D)));

      // 2. Al activar un acorde en Abre (ej. Do Mayor), los botones que abren se marcan como acorde en Abre (isChordPull == true)
      notifier.setFreeChordRoot(0); // Do
      notifier.setFreeChordType('maj');
      await tester.pumpAndSettle();

      final activePullBtns = find.byWidgetPredicate(
        (w) => w is DiapasonButtonWidget && w.isChordPull,
      );
      expect(activePullBtns, findsWidgets);

      // 3. Al presionar un botón abriendo, la insignia flotante 'ABRE' tiene fondo verde
      final firstBtnModel = container.read(accordionSimulatorProvider).trebleData1['row3']!.first;
      notifier.pressButton(firstBtnModel.id, firstButton.pullMidi);
      await tester.pumpAndSettle();

      final abrePillFinder = find.text('ABRE');
      expect(abrePillFinder, findsOneWidget);

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: abrePillFinder, matching: find.byType(AnimatedContainer)).first,
      );
      final deco = animatedContainer.decoration as BoxDecoration;
      expect(deco.color, equals(const Color(0xFF16A34A)));
    });
  });
}
