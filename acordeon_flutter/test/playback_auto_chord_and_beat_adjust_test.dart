import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

const _sampleChords = [
  DetectedChordSegment(
    startTime: 0.0,
    endTime: 2.0,
    rootMod: 7,
    quality: 'maj',
    chordName: 'Sol Mayor',
    chordSymbol: 'G',
    noteMods: [7, 11, 2],
    playbackMidis: [55, 59, 62],
    confidence: 0.95,
  ),
  DetectedChordSegment(
    startTime: 2.0,
    endTime: 4.0,
    rootMod: 0,
    quality: 'maj',
    chordName: 'Do Mayor',
    chordSymbol: 'C',
    noteMods: [0, 4, 7],
    playbackMidis: [48, 52, 55],
    confidence: 0.92,
  ),
  DetectedChordSegment(
    startTime: 4.0,
    endTime: 6.0,
    rootMod: 2,
    quality: 'maj',
    chordName: 'Re Mayor',
    chordSymbol: 'D',
    noteMods: [2, 6, 9],
    playbackMidis: [50, 54, 57],
    confidence: 0.90,
  ),
];

const _report = AudioAnalysisReport(
  duration: 60.0,
  bpm: 120, // 0.5s por pulso, 2.0s por compás
  mainKey: KeyDetectionResult(
    rootMod: 7,
    mode: 'major',
    keyNameLat: 'Sol Mayor',
    keyNameAle: 'G Major',
    recommendedTuning: 'Tres Coronas (G-C-F)',
    recommendedOffset: 7,
    recommendedRow: 'row2',
    correlation: 0.9,
  ),
  chords: _sampleChords,
);

List<MeasureRow> _generateMeasures(int count) {
  return List.generate(
    count,
    (bar) => MeasureRow(
      barNumber: bar + 1,
      beats: List.generate(
        4,
        (beat) => MeasureBeat(barIndex: bar, beatIndex: beat),
      ),
    ),
  );
}

void main() {
  group('AdjustBeatOffsetCommand {P} C {Q}', () {
    test(
      '{Q}: micro-ajuste de beat positivo y negativo con precisión a ms',
      () {
        const cmdFwd = AdjustBeatOffsetCommand(
          currentOffset: 0.050,
          deltaSeconds: 0.025,
        );
        expect(cmdFwd.canExecute(), isTrue);
        expect(cmdFwd.execute(), 0.075);

        const cmdBwd = AdjustBeatOffsetCommand(
          currentOffset: 0.050,
          deltaSeconds: -0.050,
        );
        expect(cmdBwd.execute(), 0.0);
      },
    );

    test('{Q}: acotamiento estricto a los límites minLimit y maxLimit', () {
      const cmdLimit = AdjustBeatOffsetCommand(
        currentOffset: 4.980,
        deltaSeconds: 0.100,
        minLimit: -5.0,
        maxLimit: 5.0,
      );
      expect(cmdLimit.execute(), 5.0);
    });

    test('{P} violada: parámetros numéricos no finitos o min > max', () {
      const invalid = AdjustBeatOffsetCommand(
        currentOffset: double.infinity,
        deltaSeconds: 0.05,
      );
      expect(invalid.canExecute(), isFalse);
      expect(
        () => invalid.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });
  });

  group('SyncBeatToAudioCommand {P} C {Q}', () {
    test('{Q}: calcula discrepancia delta al pulso más cercano', () {
      // 120 BPM -> 0.5s por pulso.
      // Audio en 1.12s con offset 0.0s -> el pulso más cercano es pulso 2 (1.0s).
      // Discrepancia = 1.12 - 1.00 = +0.12s
      const cmd = SyncBeatToAudioCommand(
        currentAudioTime: 1.12,
        audioStartOffset: 0.0,
        bpm: 120.0,
      );
      expect(cmd.canExecute(), isTrue);
      expect(cmd.execute(), 0.12);
    });
  });

  group(
    'DetectPlaybackChordTransitionCommand (Solo en cambios de acorde) {P} C {Q}',
    () {
      test('{Q}: detecta transición inicial cuando no hay acorde previo', () {
        final measures = _generateMeasures(4);
        final cmd = DetectPlaybackChordTransitionCommand(
          currentAudioTime: 0.5, // Dentro de Sol Mayor (0.0 - 2.0s)
          bpm: 120.0,
          startOffset: 0.0,
          measures: measures,
          markedBeats: const {},
          chords: _sampleChords,
          lastDetectedChordText: null, // Primer acorde
          notation: NotationMode.latina,
        );

        expect(cmd.canExecute(), isTrue);
        final result = cmd.execute();

        expect(result.hasTransition, isTrue);
        expect(result.detectedChordText, 'Sol Mayor');
        expect(result.targetBar, 0);
        expect(result.targetBeat, 1); // 0.5s / 0.5s = beat 1
        expect(result.updatedMeasures[0].beats[1].chord, 'Sol Mayor');
        expect(result.updatedMarkedBeats.contains(1), isTrue);
      });

      test(
        '{Q}: NO se activa si el acorde es el mismo que el anterior (Inmutabilidad)',
        () {
          final measures = _generateMeasures(4);
          final marked = <int>{1};
          final cmd = DetectPlaybackChordTransitionCommand(
            currentAudioTime: 1.2, // Todavía en Sol Mayor (0.0 - 2.0s)
            bpm: 120.0,
            startOffset: 0.0,
            measures: measures,
            markedBeats: marked,
            chords: _sampleChords,
            lastDetectedChordText: 'Sol Mayor', // Ya registrado
            notation: NotationMode.latina,
          );

          final result = cmd.execute();

          // ESTRICTO: No hay transición, no altera cuadrícula ni marcaciones
          expect(result.hasTransition, isFalse);
          expect(result.detectedChordText, 'Sol Mayor');
          expect(identical(result.updatedMeasures, measures), isTrue);
          expect(identical(result.updatedMarkedBeats, marked), isTrue);
        },
      );

      test(
        '{Q}: detecta transición cuando el audio cambia de acorde (Do Mayor a 2.1s)',
        () {
          final measures = _generateMeasures(4);
          final marked = <int>{0};
          final cmd = DetectPlaybackChordTransitionCommand(
            currentAudioTime: 2.1, // Entró en Do Mayor (2.0 - 4.0s)
            bpm: 120.0,
            startOffset: 0.0,
            measures: measures,
            markedBeats: marked,
            chords: _sampleChords,
            lastDetectedChordText: 'Sol Mayor', // Acorde previo era Sol Mayor
            notation: NotationMode.latina,
          );

          final result = cmd.execute();

          expect(result.hasTransition, isTrue);
          expect(result.detectedChordText, 'Do Mayor');
          expect(result.targetBar, 1); // 2.1s -> beat 4 -> Compás 1
          expect(result.targetBeat, 0); // Pulso 0 de Compás 1
          expect(result.updatedMeasures[1].beats[0].chord, 'Do Mayor');
          expect(result.updatedMarkedBeats.contains(4), isTrue);
        },
      );
    },
  );

  group('Integración en AccordionSimulatorNotifier', () {
    test('togglePlaybackAutoChordDetect conmuta la opción', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);

      expect(
        container
            .read(accordionSimulatorProvider)
            .isPlaybackAutoChordDetectEnabled,
        isFalse,
      );
      notifier.togglePlaybackAutoChordDetect();
      expect(
        container
            .read(accordionSimulatorProvider)
            .isPlaybackAutoChordDetectEnabled,
        isTrue,
      );
      notifier.togglePlaybackAutoChordDetect();
      expect(
        container
            .read(accordionSimulatorProvider)
            .isPlaybackAutoChordDetectEnabled,
        isFalse,
      );
    });

    test(
      'adjustBeatOffset actualiza el desfase del pulso y recalcula timeCodes',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(accordionSimulatorProvider.notifier);
        notifier.setAudioReport(_report);

        expect(container.read(accordionSimulatorProvider).beatNudgeOffset, 0.0);
        notifier.adjustBeatOffset(0.050); // +50ms
        expect(
          container.read(accordionSimulatorProvider).beatNudgeOffset,
          0.050,
        );
        expect(
          container.read(accordionSimulatorProvider).effectiveAudioStartOffset,
          0.050,
        );

        notifier.resetBeatOffset();
        expect(container.read(accordionSimulatorProvider).beatNudgeOffset, 0.0);
      },
    );

    test(
      'syncBeatToCurrentAudioTime ajusta el beat al cursor de reproducción',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(accordionSimulatorProvider.notifier);
        notifier.setAudioReport(_report);

        notifier.seekAudio(
          1.15,
        ); // Discrepancia +0.15s respecto al beat 2 (1.0s)
        notifier.syncBeatToCurrentAudioTime();

        expect(
          container.read(accordionSimulatorProvider).beatNudgeOffset,
          0.15,
        );
      },
    );
  });
}
