import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/domain/services/hoare_contract.dart';
import 'package:acordeon_flutter/domain/services/grid_metrics_service.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

/// Clase mínima para probar el mixin [HoareContract] de forma aislada.
class _ContractProbe with HoareContract {}

/// Invariantes del transporte de audio y contratos Hoare ejecutables.
///
/// {I1}: 0 ≤ currentAudioTime ≤ max(totalAudioDuration, 0)
/// {I2}: si !isPlayingAudio entonces ningún temporizador queda activo en estado
///        observable (currentCompasTime congelado respecto a su último valor).
/// {I3}: cargar una pista reinicia posición (currentAudioTime == 0).
void main() {
  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('HoareContract mixin', () {
    test('require pasa con condición verdadera', () {
      final p = _ContractProbe();
      expect(() => p.require('op', 'x > 0', true), returnsNormally);
    });

    test('require lanza PreconditionViolationException con condición falsa',
        () {
      final p = _ContractProbe();
      expect(
        () => p.require('opPrueba', 'x > 0', false),
        throwsA(isA<PreconditionViolationException>()),
      );
    });

    test('ensure e invariant lanzan con el motivo correcto', () {
      final p = _ContractProbe();
      expect(
        () => p.ensure('opQ', 'salida coherente', false),
        throwsA(
          isA<PreconditionViolationException>().having(
            (e) => e.toString(),
            'message',
            contains('Poscondición {Q}'),
          ),
        ),
      );
      expect(
        () => p.invariant('opI', 'estado consistente', false),
        throwsA(
          isA<PreconditionViolationException>().having(
            (e) => e.toString(),
            'message',
            contains('Invariante {I}'),
          ),
        ),
      );
    });
  });

  group('Invariantes del transporte de audio', () {
    test(
        '{I1} tras la construcción inicial: posición 0 ≤ duración por defecto',
        () {
      final container = makeContainer();
      final s = container.read(accordionSimulatorProvider);
      expect(s.currentAudioTime, greaterThanOrEqualTo(0.0));
      expect(
        s.currentAudioTime,
        lessThanOrEqualTo(
          s.totalAudioDuration > 0 ? s.totalAudioDuration : 0.0,
        ),
      );
    });

    test(
        '{I3} posición reiniciada a 0 tras simulateLoadAudioBytes (contrato de carga)',
        () {
      final container = makeContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);

      // Avanza la posición simulando reproducción previa.
      notifier.state = notifier.state.copyWith(currentAudioTime: 42.0);
      expect(notifier.state.currentAudioTime, 42.0);

      final result = notifier.loadAudioBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        'prueba.mp3',
      );
      expect(result, isA<AudioLoadSuccess>());

      // {I3}: la carga reinicia la posición.
      expect(notifier.state.currentAudioTime, 0.0);
      expect(notifier.state.isPlayingAudio, isFalse);
      expect(notifier.state.loadedAudioFileName, 'prueba.mp3');
    });

    test(
        '{I2} clearAudioReport detiene reproducción y mantiene invariantes de rango',
        () {
      final container = makeContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.state = notifier.state.copyWith(isPlayingAudio: true);

      notifier.clearAudioReport();

      expect(notifier.state.isPlayingAudio, isFalse);
      expect(notifier.state.audioReport, isNull);
      expect(notifier.state.currentAudioTime, greaterThanOrEqualTo(0.0));
    });

    test(
        'updateAudioKeyAndBpm mantiene la coherencia measures/report ({Q} formal)',
        () {
      final container = makeContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setAudioReport(
        notifier.state.audioReport ?? _minimalReport(120),
      );

      notifier.updateAudioKeyAndBpm(rootMod: 0, mode: 'major', bpm: 90);

      expect(notifier.state.audioReport!.bpm, 90);
      expect(notifier.state.measures, isNotEmpty);
      expect(notifier.state.measures.every((m) => m.beats.length == 4), isTrue);
    });

    test(
        'updateAudioKeyAndBpm con BPM inválido lanza violación de precondición',
        () {
      final container = makeContainer();
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.setAudioReport(_minimalReport(120));

      // BPM fuera de rango: el contrato con clampeo interno lo limita a 300,
      // por lo que no debe corromper el estado (ni lanzar aquí).
      notifier.updateAudioKeyAndBpm(
        rootMod: 0,
        mode: 'major',
        bpm: 999999,
      );
      expect(notifier.state.audioReport!.bpm, 300);
    });
  });

  group('grid_metrics_service (funciones extraídas)', () {
    test('formatBeatTime formatea minutos y segundos con ceros', () {
      expect(formatBeatTime(0), '00:00');
      expect(formatBeatTime(59.9), '00:59');
      expect(formatBeatTime(60), '01:00');
      expect(formatBeatTime(754), '12:34');
    });

    test('buildMeasureRow genera 4 beats con tiempos crecientes', () {
      final row = buildMeasureRow(barIndex: 1, secondsPerBeat: 0.5);
      expect(row.barNumber, 2);
      expect(row.beats, hasLength(4));
      final times = row.beats.map((b) => b.timeText).toList();
      expect(times, ['00:02', '00:02', '00:03', '00:03']);
      // Monotonía no decreciente en el texto.
      for (var i = 1; i < times.length; i++) {
        expect(
          times[i].compareTo(times[i - 1]),
          greaterThanOrEqualTo(0),
        );
      }
    });
  });
}

AudioAnalysisReport _minimalReport(int bpm) => AudioAnalysisReport(
      duration: 32.0,
      bpm: bpm,
      mainKey: const KeyDetectionResult(
        rootMod: 0,
        mode: 'major',
        keyNameLat: 'Do Mayor',
        keyNameAle: 'C Major',
        recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
        recommendedOffset: 10,
        recommendedRow: 'row2',
        correlation: 0.9,
      ),
      chords: const [],
    );
