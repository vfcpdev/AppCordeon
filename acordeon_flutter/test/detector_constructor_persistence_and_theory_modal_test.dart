import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/domain/theory/music_theory_topics.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/app_header_widget.dart';
import 'package:acordeon_flutter/presentation/widgets/music_theory_dialog.dart';

void main() {
  group('Auditoría y Persistencia entre Detector de Acordes y Constructor Libre', () {
    test('Persistencia: toggleDetectorMode() conserva botones seleccionados y acorde detectado', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // 1. Activar detector
      notifier.toggleDetectorMode();
      expect(container.read(accordionSimulatorProvider).detectorMode, isTrue);

      // 2. Simular selección de botones en el detector
      notifier.toggleDetectorButton('row1_1', 60);
      notifier.toggleDetectorButton('row1_3', 64);
      notifier.toggleDetectorButton('row1_5', 67);

      expect(container.read(accordionSimulatorProvider).detectorSelectedButtons.length, 3);
      final detected = container.read(accordionSimulatorProvider).detectedChord;
      expect(detected, isNotNull);

      // 3. Conmutar a modo Constructor (desactivar detector)
      notifier.toggleDetectorMode();
      expect(container.read(accordionSimulatorProvider).detectorMode, isFalse);

      // Verificamos que NO se pierda la selección del detector
      expect(container.read(accordionSimulatorProvider).detectorSelectedButtons.length, 3);
      expect(container.read(accordionSimulatorProvider).detectedChord, isNotNull);

      // 4. Volver a activar detector: la selección sigue presente
      notifier.toggleDetectorMode();
      expect(container.read(accordionSimulatorProvider).detectorMode, isTrue);
      expect(container.read(accordionSimulatorProvider).detectorSelectedButtons.length, 3);
      expect(container.read(accordionSimulatorProvider).detectedChord, isNotNull);
    });

    test('Transferencia fiel: transferDetectedChordToConstructor transfiere raíz, cualidad menor y séptima', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Simulamos un acorde detectado complejo: Sol menor 7ma con bajo en Re (Gm7/D)
      const detectedGm7 = DetectedChordModel(
        name: 'Sol menor 7ma/Re',
        root: 'Sol',
        bass: 'Re',
        formula: '1 - ♭3 - 5 - ♭7',
        type: 'Séptima Menor',
        inversion: '2ª Inversión (Bajo en 5ta)',
        chordSymbol: 'Gm7/D',
        pitchClasses: {7, 10, 2, 5},
        rootPitchClass: 7, // Sol
        bassPitchClass: 2, // Re (5ta)
      );

      // Forzar acorde detectado en el estado
      container.read(accordionSimulatorProvider.notifier).state =
          container.read(accordionSimulatorProvider).copyWith(detectedChord: detectedGm7);

      // Ejecutar transferencia
      notifier.transferDetectedChordToConstructor();

      final state = container.read(accordionSimulatorProvider);
      expect(state.freeChordRoot, 7); // Sol
      expect(state.freeChordType, 'min'); // Cualidad menor
      expect(state.freeChordFourth, 'dom7'); // Séptima
      expect(state.freeChordBass, '5'); // Bajo en 5ta (/D)
      expect(state.isFreeChordFixed, isTrue);
    });
  });

  group('Modal de Teoría Musical para Acordeón', () {
    test('El catálogo de teoría contiene 7 módulos progresivos (Básico a Avanzado)', () {
      final topics = MusicTheoryCatalog.topics;
      expect(topics.length, 7);
      expect(topics[0].level, 'Básico');
      expect(topics[1].level, 'Básico');
      expect(topics[2].level, 'Intermedio');
      expect(topics[3].level, 'Intermedio');
      expect(topics[4].level, 'Intermedio - Avanzado');
      expect(topics[5].level, 'Avanzado');
      expect(topics[6].level, 'Avanzado');
    });

    testWidgets('AppHeaderWidget muestra botón de Teoría Musical y abre el modal interactivo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppHeaderWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buscamos el botón de Teoría Musical en el encabezado
      final theoryBtn = find.byKey(const ValueKey('music_theory_modal_btn'));
      expect(theoryBtn, findsOneWidget);
      expect(find.text('Fondo:'), findsNothing);
      expect(find.byTooltip('Cambiar color de fondo'), findsNothing);

      // Hacemos clic para abrir el modal
      await tester.tap(theoryBtn);
      await tester.pumpAndSettle();

      // Verificamos que el modal se muestre
      expect(find.byType(MusicTheoryDialog), findsOneWidget);
      expect(find.text('Teoría Musical del Acordeón Diatónico'), findsOneWidget);

      // Verificamos el menú lateral izquierdo con los módulos
      expect(find.text('1. El Pentagrama y las Claves'), findsWidgets);
      expect(find.text('2. Simbología y Fuelle'), findsOneWidget);
      expect(find.text('3. Círculo de Quintas y Hileras'), findsOneWidget);

      // Cambiamos de módulo en el menú lateral
      final module3 = find.byKey(const ValueKey('theory_topic_item_2'));
      await tester.tap(module3);
      await tester.pumpAndSettle();

      expect(find.text('El Círculo de Quintas: La Brújula Armónica'), findsOneWidget);

      // Cerramos el modal
      final closeBtn = find.byTooltip('Cerrar ventana');
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MusicTheoryDialog), findsNothing);
    });
  });
}
