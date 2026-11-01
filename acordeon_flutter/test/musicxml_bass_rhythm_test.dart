import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/core/storage/file_storage_interface.dart';
import 'package:acordeon_flutter/domain/services/musicxml_rhythm_importer.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/accordion_button_3d.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';

const _musicXml = '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Acordeón</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <direction>
        <direction-type>
          <words>Paseo</words>
          <metronome>
            <beat-unit>quarter</beat-unit>
            <beat-unit-dot/>
            <per-minute>80</per-minute>
          </metronome>
        </direction-type>
        <sound tempo="120"/>
      </direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration></note>
      <note><rest/><duration>2</duration></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <attributes><time><beats>6</beats><beat-type>8</beat-type></time></attributes>
      <direction><direction-type><words>Merengue</words></direction-type></direction>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration></note>
    </measure>
  </part>
</score-partwise>
''';

void main() {
  group('MusicXML bass rhythm import', () {
    test('preserves meter, tempo, rests, timing, and button order', () {
      final result = MusicXmlRhythmImporter().importPatterns(_musicXml);
      final paseo = result.patterns.first;
      final merengue = result.patterns.last;

      expect(result.patterns, hasLength(2));
      expect(result.recoveredMalformedEvents, 0);
      expect(paseo.name, 'Paseo');
      expect(paseo.partName, 'Acordeón');
      expect(paseo.beatsPerMeasure, 4);
      expect(paseo.durationQuarterBeats, 4);
      expect(paseo.quarterNotesPerMinute, 120);
      expect(paseo.hits, hasLength(2));
      expect(paseo.hits[0].onsetQuarterBeats, 0);
      expect(paseo.hits[1].onsetQuarterBeats, 2);
      expect(paseo.hits.map((hit) => hit.buttonIndex), [0, 1]);
      expect(merengue.beatsPerMeasure, 6);
      expect(merengue.beatType, 8);
      expect(merengue.durationQuarterBeats, 3);
      expect(merengue.hits.map((hit) => hit.buttonIndex), [0, 1]);
    });

    test('recovers only the known malformed event as a pause', () {
      const malformedEvent =
          '<note><pitch><step>G</node><rest><duration>2</duration>'
          '<voice>1</voice><type>quarter</type></rest>';
      final xml = _musicXml.replaceFirst(
        '<note><pitch><step>E</step><octave>4</octave></pitch>'
            '<duration>4</duration></note>',
        '$malformedEvent',
      );

      final result = MusicXmlRhythmImporter().importPatterns(xml);
      final paseo = result.patterns.first;

      expect(result.recoveredMalformedEvents, 1);
      expect(paseo.hits, hasLength(1));
      expect(paseo.hits.single.onsetQuarterBeats, 0);
      expect(paseo.durationQuarterBeats, 4);
    });

    test('cycles sequential hits across all twelve physical bass buttons', () {
      final notes = List.generate(
        13,
        (_) =>
            '<note><pitch><step>C</step><octave>4</octave></pitch>'
            '<duration>1</duration></note>',
      ).join();
      final xml = '''
<score-partwise>
  <part-list><score-part id="P1"><part-name>Bajos</part-name></score-part></part-list>
  <part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>$notes</measure></part>
</score-partwise>
''';

      final result = MusicXmlRhythmImporter().importPatterns(xml);

      expect(
        result.patterns.single.hits.map((hit) => hit.buttonIndex),
        [...List<int>.generate(12, (index) => index), 0],
      );
    });

    test('rejects malformed XML outside the documented recovery case', () {
      const invalidXml =
          '<score-partwise><part id="P1"><measure><note></node></measure>'
          '</part></score-partwise>';

      expect(
        () => MusicXmlRhythmImporter().importPatterns(invalidXml),
        throwsA(isA<FormatException>()),
      );
    });

    testWidgets(
      'imports and selects patterns, highlights basses, and reuses the metronome',
      (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetPhysicalSize());

        final audioEngine = _RecordingAudioEngine();
        final container = ProviderContainer(
          overrides: [
            fileStorageProvider.overrideWithValue(
              _MemoryFileStorage(_musicXml),
            ),
            audioEngineProvider.overrideWithValue(audioEngine),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: BassPanelWidget())),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('bass_rhythm_import_btn_1')),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(accordionSimulatorProvider).bassRhythmPatterns,
          hasLength(2),
        );

        final patternPicker = find.byKey(
          const ValueKey('bass_rhythm_pattern_picker_1'),
        );
        await tester.tap(patternPicker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Merengue · Acordeón · C2'));
        await tester.pumpAndSettle();

        var state = container.read(accordionSimulatorProvider);
        expect(state.selectedBassRhythmPattern?.name, 'Merengue');
        expect(state.activeBassRhythmButtonIndexes, contains(0));

        await tester.tap(
          find.byKey(const ValueKey('bass_metronome_toggle_btn_1')),
        );
        await tester.pump();
        expect(state.isBassMetronomeActive, isFalse);
        expect(
          container.read(accordionSimulatorProvider).isBassMetronomeActive,
          isTrue,
        );
        expect(audioEngine.clickCount, 1);

        await tester.pump(const Duration(seconds: 1));
        state = container.read(accordionSimulatorProvider);
        expect(state.bassRhythmElapsedSeconds, greaterThan(0));
        expect(state.activeBassRhythmButtonIndexes, contains(1));
        final renderedButtons = tester
            .widgetList<AccordionButton3D>(find.byType(AccordionButton3D))
            .toList();
        expect(renderedButtons, hasLength(12));
        expect(renderedButtons[1].isSelectedForRhythm, isTrue);

        await tester.tap(
          find.byKey(const ValueKey('bass_metronome_toggle_btn_1')),
        );
        await tester.pump();
        expect(
          container.read(accordionSimulatorProvider).isBassMetronomeActive,
          isFalse,
        );
      },
    );
  });
}

class _MemoryFileStorage implements FileStorageService {
  final String content;

  const _MemoryFileStorage(this.content);

  @override
  Future<String?> pickTextFile({List<String>? allowedExtensions}) async =>
      content;

  @override
  Future<void> saveFile({
    required String fileName,
    required String content,
  }) async {}
}

class _RecordingAudioEngine implements AudioEngine {
  int clickCount = 0;

  @override
  Future<void> init({double sampleRate = 44100}) async {}

  @override
  void allNotesOff() {}

  @override
  void noteOff(int midiNote) {}

  @override
  void noteOn(int midiNote, {double velocity = 0.8}) {}

  @override
  void playPercussiveClick({bool isDownbeat = true, double volume = 0.8}) {
    clickCount++;
  }

  @override
  void setVolume(double volume) {}
}
