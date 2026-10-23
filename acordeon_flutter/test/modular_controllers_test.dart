import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/presentation/controllers/audio_analysis_controller.dart';
import 'package:acordeon_flutter/presentation/controllers/chord_detector_controller.dart';
import 'package:acordeon_flutter/presentation/controllers/diapason_controller.dart';
import 'package:acordeon_flutter/presentation/controllers/free_chord_controller.dart';
import 'package:acordeon_flutter/presentation/controllers/measure_grid_controller.dart';
import 'package:acordeon_flutter/presentation/controllers/playback_controller.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart'; // AudioLoadResult

void main() {
  group('Phase 3 Modular Controllers Test Suite (SRP & ISP)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('DiapasonNotifier (Family) maintains isolated state for Diapasón 1 and 2', () {
      final d1 = container.read(diapasonFamilyProvider(1).notifier);
      final d2 = container.read(diapasonFamilyProvider(2).notifier);
      expect(d2.accordionId, 2);
      expect(container.read(diapasonFamilyProvider(2)).id, 2);

      // Mutar solo D1
      d1.setVolume(0.42);
      d1.setBellows(BellowsMode.push);
      d1.toggleMirror();

      expect(container.read(diapasonFamilyProvider(1)).volume, 0.42);
      expect(container.read(diapasonFamilyProvider(1)).bellows, BellowsMode.push);
      expect(container.read(diapasonFamilyProvider(1)).mirror, isTrue);

      // D2 permanece inalterado (aislado)
      expect(container.read(diapasonFamilyProvider(2)).volume, 0.8);
      expect(container.read(diapasonFamilyProvider(2)).bellows, BellowsMode.both);
      expect(container.read(diapasonFamilyProvider(2)).mirror, isFalse);
    });

    test('MeasureGridNotifier manages rows, beats, and chord assignment', () {
      final grid = container.read(measureGridProvider.notifier);
      expect(container.read(measureGridProvider).length, 8);

      grid.addMeasure();
      expect(container.read(measureGridProvider).length, 9);

      grid.updateMeasureBeat(0, 1, 'Eb');
      expect(container.read(measureGridProvider)[0].beats[1].chord, 'Eb');

      grid.clearAllGridChords();
      final beats = container.read(measureGridProvider).expand((m) => m.beats);
      expect(beats.every((b) => b.chord.isEmpty), isTrue);
    });

    test('FreeChordNotifier updates root, extensions and calculates chord notes', () {
      final fc = container.read(freeChordProvider.notifier);
      fc.setRoot(3); // Eb
      fc.setType('min');
      fc.setFourth('dom7');

      final notes = container.read(freeChordProvider).calculateNotes();
      // 60 + 3 = 63 (Eb), +3 = 66, +7 = 70, +10 = 73
      expect(notes, [63, 66, 70, 73]);
    });

    test('ChordDetectorNotifier toggles buttons and detects chords', () {
      final cd = container.read(chordDetectorProvider.notifier);
      cd.toggleMode();
      expect(container.read(chordDetectorProvider).isEnabled, isTrue);

      cd.toggleButton('btn_row1_1');
      cd.toggleButton('btn_row1_2');
      expect(container.read(chordDetectorProvider).selectedButtons.length, 2);
      expect(container.read(chordDetectorProvider).detectedChord, isNotNull);

      cd.clear();
      expect(container.read(chordDetectorProvider).selectedButtons, isEmpty);
      expect(container.read(chordDetectorProvider).detectedChord, isNull);
    });

    test('PlaybackNotifier manages playback timeline, tempo and seek', () {
      final pb = container.read(playbackProvider.notifier);
      expect(container.read(playbackProvider).isPlaying, isFalse);

      pb.seek(15.5);
      expect(container.read(playbackProvider).currentTime, 15.5);

      pb.selectBeat(2, 3);
      expect(container.read(playbackProvider).selectedBarIndex, 2);
      expect(container.read(playbackProvider).selectedBeatIndex, 3);

      pb.stop();
      expect(container.read(playbackProvider).currentTime, 0.0);
    });

    test('AudioAnalysisNotifier processes demo audio track successfully', () async {
      final aa = container.read(audioAnalysisProvider.notifier);
      expect(container.read(audioAnalysisProvider).report, isNull);

      final result = await aa.loadDemo();
      expect(result, isA<AudioLoadSuccess>());
      expect(container.read(audioAnalysisProvider).report, isNotNull);
      expect(container.read(audioAnalysisProvider).loadedFileName, contains('Demo'));

      aa.clear();
      expect(container.read(audioAnalysisProvider).report, isNull);
    });
  });
}
