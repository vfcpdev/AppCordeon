import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/domain/models/bass_rhythm_pattern.dart';
import 'package:acordeon_flutter/domain/services/high_precision_rhythm_clock.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';

class _MockAudioEngineRecorder implements AudioEngine {
  final List<int> noteOnCalls = [];
  final List<int> noteOffCalls = [];
  int clickCalls = 0;

  @override
  Future<void> init({double sampleRate = 44100.0}) async {}

  @override
  void noteOn(int midiNote, {double velocity = 0.8}) {
    noteOnCalls.add(midiNote);
  }

  @override
  void noteOff(int midiNote) {
    noteOffCalls.add(midiNote);
  }

  @override
  void allNotesOff() {}

  @override
  void setVolume(double volume) {}

  @override
  void playPercussiveClick({bool isDownbeat = true, double volume = 0.8}) {
    clickCalls++;
  }

  void reset() {
    noteOnCalls.clear();
    noteOffCalls.clear();
    clickCalls = 0;
  }
}

void main() {
  group('Reproducción de Patrón de Bajo según Fuelle (Abierto, Cerrado o Ambos)', () {
    late _MockAudioEngineRecorder mockAudio;
    late ProviderContainer container;

    setUp(() {
      mockAudio = _MockAudioEngineRecorder();
      container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWithValue(mockAudio),
        ],
      );
    });

    tearDown(() {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.stopBassRhythm();
      container.dispose();
    });

    BassRhythmPattern createTestPattern() {
      return BassRhythmPattern(
        id: 'test_patron',
        name: 'Patrón Prueba',
        partName: 'Bajos',
        measureNumber: 1,
        beatsPerMeasure: 4,
        beatType: 4,
        durationQuarterBeats: 4.0,
        quarterNotesPerMinute: 120.0,
        hits: [
          // Golpe en el tiempo 0 en el botón 1 (bajo fundamental del par 1)
          const BassRhythmHit(
            onsetQuarterBeats: 0.0,
            durationQuarterBeats: 0.5,
            buttonIndex: 1,
            buttonType: BassRhythmButtonType.fundamental,
          ),
          // Golpe en el tiempo 1.0 en el botón 0 (acorde del par 1)
          const BassRhythmHit(
            onsetQuarterBeats: 1.0,
            durationQuarterBeats: 0.5,
            buttonIndex: 0,
            buttonType: BassRhythmButtonType.chord,
          ),
        ],
      );
    }

    test('Cuando el fuelle está en Ambos (both): SOLO ejecuta el patrón con un chasquido', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final pattern = createTestPattern();

      notifier.applyRawState(
        container.read(accordionSimulatorProvider).copyWith(
          bassRhythmPatterns: [pattern],
        ),
      );
      notifier.setBellows1(BellowsMode.both);
      notifier.selectBassRowTarget(AccordionRowTarget.externalRow);

      mockAudio.reset();

      // Reproducir el patrón de bajo
      notifier.playBassRhythmPattern(pattern.id);

      final state = container.read(accordionSimulatorProvider);
      expect(state.bellows1, equals(BellowsMode.both));
      expect(state.isBassMetronomeActive, isTrue);

      // {Q}: En Ambos, solo emite chasquido de metrónomo (click), NINGUNA nota MIDI de bajo
      expect(mockAudio.clickCalls, greaterThanOrEqualTo(1));
      expect(mockAudio.noteOnCalls, isEmpty);
    });

    test('Cuando el fuelle está Cerrado (push): ejecuta el patrón con las notas que contiene (pushNotes)', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final pattern = createTestPattern();

      notifier.applyRawState(
        container.read(accordionSimulatorProvider).copyWith(
          bassRhythmPatterns: [pattern],
        ),
      );
      notifier.setBellows1(BellowsMode.push);
      notifier.selectBassRowTarget(AccordionRowTarget.externalRow);

      mockAudio.reset();

      // Reproducir el patrón de bajo
      notifier.playBassRhythmPattern(pattern.id);

      final state = container.read(accordionSimulatorProvider);
      expect(state.bellows1, equals(BellowsMode.push));
      expect(state.isBassMetronomeActive, isTrue);

      // {Q}: Con fuelle Cerrado, ejecuta las notas que contiene para pushNotes
      // Botón 1 (bajo Bb/F) en push tiene nota MIDI 46 (Bb)
      expect(mockAudio.noteOnCalls, contains(46));
      // No debe sonar el chasquido del patrón
      expect(mockAudio.clickCalls, equals(0));
    });

    test('Cuando el fuelle está Abierto (pull): ejecuta el patrón con las notas que contiene (pullNotes)', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final pattern = createTestPattern();

      notifier.applyRawState(
        container.read(accordionSimulatorProvider).copyWith(
          bassRhythmPatterns: [pattern],
        ),
      );
      notifier.setBellows1(BellowsMode.pull);
      notifier.selectBassRowTarget(AccordionRowTarget.externalRow);

      mockAudio.reset();

      // Reproducir el patrón de bajo
      notifier.playBassRhythmPattern(pattern.id);

      final state = container.read(accordionSimulatorProvider);
      expect(state.bellows1, equals(BellowsMode.pull));
      expect(state.isBassMetronomeActive, isTrue);

      // {Q}: Con fuelle Abierto, ejecuta las notas que contiene para pullNotes
      // Botón 1 (bajo Bb/F) en pull tiene nota MIDI 41 (F)
      expect(mockAudio.noteOnCalls, contains(41));
      // No debe sonar el chasquido del patrón
      expect(mockAudio.clickCalls, equals(0));
    });

    test('Detener el patrón apaga las notas activas inmediatamente', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final pattern = createTestPattern();

      notifier.applyRawState(
        container.read(accordionSimulatorProvider).copyWith(
          bassRhythmPatterns: [pattern],
        ),
      );
      notifier.setBellows1(BellowsMode.push);
      notifier.selectBassRowTarget(AccordionRowTarget.externalRow);

      notifier.playBassRhythmPattern(pattern.id);
      expect(mockAudio.noteOnCalls, isNotEmpty);

      mockAudio.noteOffCalls.clear();
      notifier.stopBassRhythm();

      // {Q}: Las notas activas reciben noteOff
      expect(mockAudio.noteOffCalls, contains(46));
      expect(container.read(accordionSimulatorProvider).isBassMetronomeActive, isFalse);
    });

    test('Influencia directa del BPM de bajos: setBassBpm actualiza tempo efectivo y patrón activo', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);
      final pattern = createTestPattern();

      notifier.applyRawState(
        container.read(accordionSimulatorProvider).copyWith(
          bassRhythmPatterns: [pattern],
          selectedBassRhythmPatternId: pattern.id,
        ),
      );

      expect(container.read(accordionSimulatorProvider).effectiveBassBpm, equals(120.0));

      // Asignar nuevo BPM de bajos
      notifier.setBassBpm(145.0);

      final state = container.read(accordionSimulatorProvider);
      // {Q}: effectiveBassBpm refleja de inmediato el nuevo BPM
      expect(state.effectiveBassBpm, equals(145.0));
      expect(state.bassBpm, equals(145.0));
      // El patrón seleccionado sincroniza su tempo
      expect(state.selectedBassRhythmPattern?.quarterNotesPerMinute, equals(145.0));
    });

    test('HighPrecisionRhythmClock: cálculo temporal exacto con cero deriva rítmica (zero drift)', () {
      final clock = HighPrecisionRhythmClock(
        bpm: 120.0, // 2 negras por segundo (0.5 s por negra = 500,000 µs)
        durationQuarterBeats: 4.0,
      );

      // A 0 µs -> 0.0 negras
      expect(clock.positionAtMicroseconds(0), equals(0.0));

      // A 500,000 µs (0.5 s) -> 1.0 negras
      expect(clock.positionAtMicroseconds(500000), closeTo(1.0, 0.0001));

      // A 1,000,000 µs (1.0 s) -> 2.0 negras
      expect(clock.positionAtMicroseconds(1000000), closeTo(2.0, 0.0001));

      // A 2,000,000 µs (2.0 s = ciclo completo de 4 negras) -> vuelve a 0.0 por wrap modulo
      expect(clock.positionAtMicroseconds(2000000), closeTo(0.0, 0.0001));

      // Duración de nota física articulada y staccato
      final normalDuration = clock.noteDurationMs(1.0);
      final staccatoDuration = clock.noteDurationMs(1.0, isStaccato: true);
      expect(normalDuration, equals(450)); // 0.5 s * 0.9 = 450 ms
      expect(staccatoDuration, equals(225)); // 450 ms * 0.5 = 225 ms
    });
  });
}
