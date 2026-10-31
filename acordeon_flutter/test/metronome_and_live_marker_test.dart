import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/core/audio/analysis/bpm_detector.dart';
import 'package:acordeon_flutter/core/audio/analysis/key_detector.dart';
import 'package:acordeon_flutter/core/audio/analysis/chord_segmenter.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/measure_grid_widget.dart';

void main() {
  group('Metrónomo y Chasquido Percusivo con Triplas de Hoare {P} C {Q}', () {
    test('PlayMetronomeTickCommand: {P: beatIndex >= 0} emite chasquido percusivo onPercussiveClick con acento', () {
      bool? capturedDownbeat;
      double? capturedVolume;

      final commandBeat0 = PlayMetronomeTickCommand(
        onPercussiveClick: ({bool isDownbeat = true, double volume = 0.8}) {
          capturedDownbeat = isDownbeat;
          capturedVolume = volume;
        },
        beatIndex: 0,
        volume: 0.9,
      );

      expect(commandBeat0.canExecute(), isTrue);
      commandBeat0.execute();
      expect(capturedDownbeat, isTrue); // Beat 0 es acento
      expect(capturedVolume, equals(0.9));

      // Beat 2: pulso secundario
      final commandBeat2 = PlayMetronomeTickCommand(
        onPercussiveClick: ({bool isDownbeat = true, double volume = 0.8}) {
          capturedDownbeat = isDownbeat;
          capturedVolume = volume;
        },
        beatIndex: 2,
        volume: 0.8,
      );

      commandBeat2.execute();
      expect(capturedDownbeat, isFalse); // Beat 2 no es downbeat
      expect(capturedVolume, equals(0.8));
    });

    test('PlayMetronomeTickCommand: fallback a onNoteOn si onPercussiveClick es nulo', () {
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
    });

    test('PlayMetronomeTickCommand: Precondición {P} rechaza beatIndex negativo', () {
      final command = PlayMetronomeTickCommand(
        onPercussiveClick: ({bool isDownbeat = true, double volume = 0.8}) {},
        beatIndex: -1,
      );

      expect(command.canExecute(), isFalse);
      expect(
        () => command.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });
  });

  group('Marcador en Vivo de Acordes con Barra Espaciadora y Detección de Audio {P} C {Q}', () {
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

      // BPM = 120 -> cada tiempo dura 0.5s. A los 3.25 segundos:
      // totalBeats = floor(3.25 / 0.5) = 6 -> Compás 1 (segundo compás), tiempo 2 (tercer tiempo)
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

    test('markLiveChordChange aplica con prioridad el acorde detectado en el archivo de audio para el tiempo actual', () {
      final container = ProviderContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Configurar un reporte de análisis de audio con segmentos detectados
      final fakeReport = AudioAnalysisReport(
        duration: 30.0,
        bpm: 120,
        mainKey: const KeyDetectionResult(
          rootMod: 0,
          mode: 'major',
          keyNameLat: 'Do Mayor',
          keyNameAle: 'C Major',
          recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
          recommendedOffset: 10,
          recommendedRow: 'row2',
          correlation: 0.95,
        ),
        chords: const [
          DetectedChordSegment(
            startTime: 0.0,
            endTime: 2.0,
            rootMod: 0,
            quality: 'maj',
            chordName: 'Do Mayor',
            chordSymbol: 'C',
            noteMods: [0, 4, 7],
            playbackMidis: [48, 52, 55],
            confidence: 0.9,
          ),
          DetectedChordSegment(
            startTime: 2.0,
            endTime: 5.0,
            rootMod: 7,
            quality: 'dom7',
            chordName: 'Sol 7ma',
            chordSymbol: 'G7',
            noteMods: [7, 11, 2, 5],
            playbackMidis: [55, 59, 62, 65],
            confidence: 0.95,
          ),
        ],
      );

      notifier.setAudioReport(fakeReport);

      // Posicionar el audio en 2.5s (dentro del segmento Sol 7ma)
      notifier.seekAudio(2.5);

      // Al presionar la barra espaciadora (markLiveChordChange),
      // debe aplicar el acorde detectado en el audio ("Sol 7ma" / "G7") y no requerir construcción manual
      final result = notifier.markLiveChordChange();
      expect(result, isNotNull);
      expect(result!.assignedChord, equals('Sol 7ma'));

      final state = container.read(accordionSimulatorProvider);
      expect(state.measures[result.targetBar].beats[result.targetBeat].chord, equals('Sol 7ma'));
      expect(state.activeCompasChord, equals('Sol 7ma'));
    });
  });

  group('Optimización de Análisis de Audio Espectral {P} C {Q}', () {
    test('AutocorrelationBpmDetector: Invariante {Q: 60 <= bpm <= 200}', () {
      const detector = AutocorrelationBpmDetector();
      final syntheticSamples = Float32List(44100 * 2); // 2 segundos
      final bpm = detector.detectBpm(syntheticSamples, 44100.0);
      expect(bpm, inInclusiveRange(60, 200));
    });

    test('KrumhanslTemperleyKeyDetector: Invariante {Q: 0 <= rootMod <= 11}', () {
      const detector = KrumhanslTemperleyKeyDetector();
      // Vector cromático con energía predominante en Do (0), Mi (4), Sol (7)
      final chromaC = List<double>.generate(12, (i) => (i == 0 || i == 4 || i == 7) ? 1.0 : 0.05);
      final key = detector.detectKey(chromaC);

      expect(key.rootMod, equals(0)); // Do
      expect(key.mode, equals('major'));
      expect(key.correlation, greaterThanOrEqualTo(0.65));
    });

    test('HarmonicChordSegmenter: Asigna noteMods y playbackMidis precisos según la cualidad (Menor vs Mayor)', () {
      const segmenter = HarmonicChordSegmenter();
      final chromagram = [
        List<double>.generate(12, (i) => (i == 9 || i == 0 || i == 4) ? 1.0 : 0.0), // La Menor: La(9), Do(0), Mi(4)
      ];

      final segments = segmenter.segmentChords(
        chromagram,
        chromagram,
        chromagram,
        2048,
        44100.0,
        const KeyDetectionResult(
          rootMod: 9,
          mode: 'minor',
          keyNameLat: 'La Menor',
          keyNameAle: 'A Minor',
          recommendedTuning: 'Cinco Letras',
          recommendedOffset: 10,
          recommendedRow: 'row2',
          correlation: 0.9,
        ),
      );

      expect(segments.isNotEmpty, isTrue);
      final seg = segments.first;
      expect(seg.rootMod, equals(9));
      expect(seg.quality, equals('min'));
      // noteMods de La menor: [9, 0, 4] -> (9 + 3)%12 = 0 (Do), (9 + 7)%12 = 4 (Mi)
      expect(seg.noteMods, equals([9, 0, 4]));
      expect(seg.playbackMidis, equals([48 + 9, 48 + 9 + 3, 48 + 9 + 7]));
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
