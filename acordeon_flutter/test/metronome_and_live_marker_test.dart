import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('Metrónomo y Triplas de Hoare {P} C {Q}', () {
    test('PlayMetronomeTickCommand: {P: beatIndex >= 0} emite C6 en beat 0 y E5 en beats 1..3', () {
      int? playedNote;
      double? playedVel;

      final commandBeat0 = PlayMetronomeTickCommand(
        onNoteOn: (note, {velocity = 0.8}) {
          playedNote = note;
          playedVel = velocity;
        },
        onNoteOff: (_) {},
        beatIndex: 0,
        volume: 1.0,
      );

      expect(commandBeat0.canExecute(), isTrue);
      final note0 = commandBeat0.execute();
      expect(note0, equals(84)); // C6 acentuado
      expect(playedNote, equals(84));
      expect(playedVel, closeTo(0.95, 0.01));

      // Beat 1: pulso secundario E5
      final commandBeat1 = PlayMetronomeTickCommand(
        onNoteOn: (note, {velocity = 0.8}) {
          playedNote = note;
          playedVel = velocity;
        },
        onNoteOff: (_) {},
        beatIndex: 1,
        volume: 0.8,
      );

      final note1 = commandBeat1.execute();
      expect(note1, equals(76)); // E5
      expect(playedNote, equals(76));
      expect(playedVel, closeTo(0.65 * 0.8, 0.01));
    });

    test('PlayMetronomeTickCommand: Precondición {P} rechaza beatIndex negativo', () {
      final command = PlayMetronomeTickCommand(
        onNoteOn: (_, {velocity = 0.8}) {},
        onNoteOff: (_) {},
        beatIndex: -1,
      );

      expect(command.canExecute(), isFalse);
      expect(
        () => command.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });
  });

  group('Marcador en Vivo de Acordes con Barra Espaciadora {P} C {Q}', () {
    test('MarkLiveChordChangeCommand: Mapea currentAudioTime del slider exactamente a compás y tiempo', () {
      final measures = List.generate(
        8,
        (b) => MeasureRow(
          barNumber: b + 1,
          beats: List.generate(
            4,
            (t) => MeasureBeat(barIndex: b, beatIndex: t, chord: '', timeText: '00:00'),
          ),
        ),
      );

      // BPM = 120 -> cada tiempo dura 0.5s.
      // A los 3.25 segundos:
      // totalBeats = floor(3.25 / 0.5) = 6
      // targetBar = 6 ~/ 4 = 1 (Compás 2)
      // targetBeat = 6 % 4 = 2 (Tiempo 3)
      final command = MarkLiveChordChangeCommand(
        currentAudioTime: 3.25,
        bpm: 120.0,
        measures: measures,
        markedBeats: const {},
        activeChord: 'Fa#m',
      );

      expect(command.canExecute(), isTrue);
      final result = command.execute();

      expect(result.targetBar, equals(1));
      expect(result.targetBeat, equals(2));
      expect(result.updatedMeasures[1].beats[2].chord, equals('Fa#m'));
      expect(result.updatedMarkedBeats.contains(1 * 4 + 2), isTrue);
    });

    test('MarkLiveChordChangeCommand: Precondición {P} rechaza tiempo negativo o BPM nulo', () {
      const command = MarkLiveChordChangeCommand(
        currentAudioTime: -2.0,
        bpm: 120.0,
        measures: [],
        markedBeats: {},
      );

      expect(command.canExecute(), isFalse);
      expect(
        () => command.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });

    test('AccordionSimulatorNotifier ejecuta markLiveChordChange y actualiza selección', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Establecer posición de audio a 1.0s a 120 BPM -> Compás 0, Tiempo 2
      notifier.seekAudio(1.0);
      notifier.setFreeChordRoot(2); // Re Mayor

      final result = notifier.markLiveChordChange();
      expect(result, isNotNull);
      expect(result!.targetBar, equals(0));
      expect(result.targetBeat, equals(2));

      final state = container.read(accordionSimulatorProvider);
      expect(state.selectedBarIndex, equals(0));
      expect(state.selectedBeatIndex, equals(2));
      expect(state.measures[0].beats[2].chord, equals('Re'));
      expect(state.markedBeats.contains(2), isTrue);
    });
  });

  group('Pruebas de Interfaz del Metrónomo y Título de Compás Homólogo', () {
    testWidgets('Título de Compás está sobre los botones y se muestran controles de Metrónomo y Espacio', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MeasureGridWidget(accordionNumber: 1, width: 220),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Título "Compás" con icono de música presente en cabecera superior
      expect(find.text('Compás'), findsOneWidget);
      expect(find.byType(FaIcon), findsWidgets);

      // 2. Botón de Metrónomo (Click) presente inmediatamente junto a BPM
      final metronomeBtn = find.byKey(const ValueKey('metronome_toggle_btn_1'));
      expect(metronomeBtn, findsOneWidget);
      expect(find.text('Click'), findsOneWidget);

      // 3. Botón de Marcador en Vivo (Espacio) presente
      final liveMarkerBtn = find.byKey(const ValueKey('live_chord_marker_btn_1'));
      expect(liveMarkerBtn, findsOneWidget);
      expect(find.text('Espacio'), findsOneWidget);

      // 4. Activar metrónomo al pulsar el botón Click
      await tester.tap(metronomeBtn);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).isMetronomeActive, isTrue);

      // 5. Activar marcador en vivo al pulsar el botón Espacio
      await tester.tap(liveMarkerBtn);
      await tester.pumpAndSettle();

      expect(container.read(accordionSimulatorProvider).isLiveChordMarkerActive, isTrue);

      // 6. Apagar metrónomo para cancelar el temporizador periódico
      await tester.tap(metronomeBtn);
      await tester.pumpAndSettle();
      expect(container.read(accordionSimulatorProvider).isMetronomeActive, isFalse);
    });
  });
}
