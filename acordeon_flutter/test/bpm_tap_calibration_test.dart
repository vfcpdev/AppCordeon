import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

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
  chords: [],
);

void main() {
  group('CalibrateBpmFromTapsCommand {P} C {Q}', () {
    test('{Q}: 4 tiempos en 2.0 s → 120 BPM', () {
      const c = CalibrateBpmFromTapsCommand(startTime: 1.0, endTime: 3.0);
      expect(c.canExecute(), isTrue);
      expect(c.execute(), 120);
    });

    test('{Q}: 4 tiempos en 2.4 s → 100 BPM', () {
      expect(const CalibrateBpmFromTapsCommand(startTime: 0.5, endTime: 2.9).execute(), 100);
    });

    test('{P} violada: orden invertido o BPM fuera de rango', () {
      const inverted = CalibrateBpmFromTapsCommand(startTime: 3.0, endTime: 1.0);
      expect(inverted.canExecute(), isFalse);
      expect(() => inverted.execute(), throwsA(isA<PreconditionViolationException>()));

      const tooFast = CalibrateBpmFromTapsCommand(startTime: 1.0, endTime: 1.1);
      expect(tooFast.canExecute(), isFalse);
    });
  });

  group('tapBpmCalibration (tecla Control)', () {
    test('1er toque marca Compás 1; 2º toque aplica BPM y conserva la tonalidad', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setAudioReport(_report);

      notifier.seekAudio(2.0);
      expect(notifier.tapBpmCalibration(), isNull);
      expect(container.read(accordionSimulatorProvider).isCalibratingBpm, isTrue);

      notifier.seekAudio(4.5); // 4 tiempos en 2.5 s → 96 BPM
      expect(notifier.tapBpmCalibration(), 96);

      final s = container.read(accordionSimulatorProvider);
      expect(s.isCalibratingBpm, isFalse);
      expect(s.audioReport!.bpm, 96);
      expect(s.audioReport!.mainKey.rootMod, 7);
    });

    test('sin audio cargado no hace nada', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(accordionSimulatorProvider.notifier);
      expect(notifier.tapBpmCalibration(), isNull);
      expect(container.read(accordionSimulatorProvider).isCalibratingBpm, isFalse);
    });
  });
}
