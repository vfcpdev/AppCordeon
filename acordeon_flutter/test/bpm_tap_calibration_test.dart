import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

const _sampleChords = [
  DetectedChordSegment(
    startTime: 0.0,
    endTime: 1.5,
    rootMod: 7,
    quality: 'maj',
    chordName: 'Sol Mayor',
    chordSymbol: 'G',
    noteMods: [7, 11, 2],
    playbackMidis: [55, 59, 62],
    confidence: 0.95,
  ),
  DetectedChordSegment(
    startTime: 1.5,
    endTime: 3.0,
    rootMod: 0,
    quality: 'maj',
    chordName: 'Do Mayor',
    chordSymbol: 'C',
    noteMods: [0, 4, 7],
    playbackMidis: [48, 52, 55],
    confidence: 0.92,
  ),
  DetectedChordSegment(
    startTime: 3.0,
    endTime: 4.5,
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
  bpm: 120,
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

List<MeasureRow> _generateEmptyMeasures(int count) {
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
  group('CalibrateBpmFromTapsCommand {P} C {Q}', () {
    test('{Q}: 4 tiempos en 2.0 s → 120 BPM', () {
      const c = CalibrateBpmFromTapsCommand(startTime: 1.0, endTime: 3.0);
      expect(c.canExecute(), isTrue);
      expect(c.execute(), 120);
    });

    test('{Q}: 4 tiempos en 2.4 s → 100 BPM', () {
      expect(
        const CalibrateBpmFromTapsCommand(
          startTime: 0.5,
          endTime: 2.9,
        ).execute(),
        100,
      );
    });

    test('{P} violada: orden invertido o BPM fuera de rango', () {
      const inverted = CalibrateBpmFromTapsCommand(
        startTime: 3.0,
        endTime: 1.0,
      );
      expect(inverted.canExecute(), isFalse);
      expect(
        () => inverted.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );

      const tooFast = CalibrateBpmFromTapsCommand(startTime: 1.0, endTime: 1.1);
      expect(tooFast.canExecute(), isFalse);
    });
  });

  group('MarkLiveChordChangeCommand con startOffset {P} C {Q}', () {
    test('{Q}: calcula compás y pulso relativo a startOffset', () {
      final measures = _generateEmptyMeasures(4);
      // Audio en 3.5s con startOffset = 2.0s -> tiempo relativo = 1.5s
      // A 120 BPM (0.5s/pulso), 1.5s = pulso 3 -> Compás 0, Pulso 3 (índice lineal 3)
      final cmd = MarkLiveChordChangeCommand(
        currentAudioTime: 3.5,
        bpm: 120,
        measures: measures,
        markedBeats: const {},
        startOffset: 2.0,
      );
      expect(cmd.canExecute(), isTrue);
      final result = cmd.execute();
      expect(result.targetBar, 0);
      expect(result.targetBeat, 3);
      expect(result.updatedMarkedBeats.contains(3), isTrue);
    });

    test('{Q}: tiempo anterior al startOffset se fija en compás 0 pulso 0', () {
      final measures = _generateEmptyMeasures(4);
      final cmd = MarkLiveChordChangeCommand(
        currentAudioTime: 0.5,
        bpm: 120,
        measures: measures,
        markedBeats: const {},
        startOffset: 1.5,
      );
      expect(cmd.canExecute(), isTrue);
      final result = cmd.execute();
      expect(result.targetBar, 0);
      expect(result.targetBeat, 0);
      expect(result.updatedMarkedBeats.contains(0), isTrue);
    });
  });

  group('ApplyMeasureChordsFromAudioCommand {P} C {Q}', () {
    test(
      '{Q}: asigna acordes sincronizados con pulsos y marca transiciones exactas',
      () {
        final measures = _generateEmptyMeasures(2);

        final cmd = ApplyMeasureChordsFromAudioCommand(
          measures: measures,
          chords: _sampleChords,
          bpm: 120.0,
          startOffset: 0.0,
          notation: NotationMode.latina,
        );

        expect(cmd.canExecute(), isTrue);
        final result = cmd.execute();

        expect(result.updatedMeasures.length, 2);
        expect(result.totalChordChanges, 3);

        // Compás 0:
        // Beat 0 (mid: 0.25s): Sol Mayor (Cambio inicial)
        expect(result.updatedMeasures[0].beats[0].chord, 'Sol Mayor');
        expect(result.updatedMeasures[0].beats[0].isContinue, isFalse);
        // Beat 1 (mid: 0.75s): Sol Mayor (Continuación)
        expect(result.updatedMeasures[0].beats[1].chord, 'Sol Mayor');
        expect(result.updatedMeasures[0].beats[1].isContinue, isTrue);
        // Beat 2 (mid: 1.25s): Sol Mayor (Continuación)
        expect(result.updatedMeasures[0].beats[2].chord, 'Sol Mayor');
        expect(result.updatedMeasures[0].beats[2].isContinue, isTrue);
        // Beat 3 (mid: 1.75s): Do Mayor (Transición)
        expect(result.updatedMeasures[0].beats[3].chord, 'Do Mayor');
        expect(result.updatedMeasures[0].beats[3].isContinue, isFalse);

        // Compás 1:
        // Beat 0 (mid: 2.25s): Do Mayor (Continuación)
        expect(result.updatedMeasures[1].beats[0].chord, 'Do Mayor');
        expect(result.updatedMeasures[1].beats[0].isContinue, isTrue);
        // Beat 2 (mid: 3.25s): Re Mayor (Transición)
        expect(result.updatedMeasures[1].beats[2].chord, 'Re Mayor');
        expect(result.updatedMeasures[1].beats[2].isContinue, isFalse);

        // Verificación de pulsos marcados con cambio armónico:
        // Beat 0 (0*4+0 = 0), Beat 3 (0*4+3 = 3), Beat 6 (1*4+2 = 6)
        expect(result.updatedMarkedBeats.contains(0), isTrue);
        expect(result.updatedMarkedBeats.contains(3), isTrue);
        expect(result.updatedMarkedBeats.contains(6), isTrue);
        expect(result.updatedMarkedBeats.contains(1), isFalse);
        expect(result.updatedMarkedBeats.contains(4), isFalse);
      },
    );

    test('{P} violada: precondición falla si no hay acordes o compases', () {
      final emptyCmd = ApplyMeasureChordsFromAudioCommand(
        measures: const [],
        chords: _sampleChords,
        bpm: 120.0,
      );
      expect(emptyCmd.canExecute(), isFalse);
      expect(
        () => emptyCmd.execute(),
        throwsA(isA<PreconditionViolationException>()),
      );
    });
  });

  group('tapBpmCalibration (tecla Control)', () {
    test(
      '1er toque fija audioStartOffset; 2º toque calibra BPM y aplica acordes automáticamente',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(accordionSimulatorProvider.notifier);
        notifier.setAudioReport(_report);

        // 1er toque en 1.5s (fija inicio de Compás 1)
        notifier.seekAudio(1.5);
        expect(notifier.tapBpmCalibration(), isNull);
        var state = container.read(accordionSimulatorProvider);
        expect(state.isCalibratingBpm, isTrue);
        expect(state.audioStartOffset, 1.5);

        // 2º toque en 3.5s (4 pulsos en 2.0s → 120 BPM)
        notifier.seekAudio(3.5);
        final calibratedBpm = notifier.tapBpmCalibration();
        expect(calibratedBpm, 120);

        state = container.read(accordionSimulatorProvider);
        expect(state.isCalibratingBpm, isFalse);
        expect(state.audioStartOffset, 1.5);
        expect(state.audioReport!.bpm, 120);

        // Verifica que los acordes por compás se sincronizaron con el nuevo inicio
        expect(state.measures.isNotEmpty, isTrue);
        // El compás 0 inicia en 1.5s, por lo que el pulso 0 (1.5 + 0.25 = 1.75s) tiene 'Do Mayor'
        expect(state.measures[0].beats[0].chord, 'Do Mayor');
        expect(state.markedBeats.isNotEmpty, isTrue);
      },
    );

    test('sin audio cargado no hace nada', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);
      expect(notifier.tapBpmCalibration(), isNull);
      expect(
        container.read(accordionSimulatorProvider).isCalibratingBpm,
        isFalse,
      );
    });
  });
}
