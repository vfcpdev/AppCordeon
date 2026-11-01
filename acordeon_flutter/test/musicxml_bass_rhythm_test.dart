import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/audio/audio_engine_bridge.dart';
import 'package:acordeon_flutter/core/di/providers.dart';
import 'package:acordeon_flutter/core/storage/file_storage_interface.dart';
import 'package:acordeon_flutter/domain/models/bass_rhythm_pattern.dart';
import 'package:acordeon_flutter/domain/services/musicxml_rhythm_importer.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/accordion_button_3d.dart';
import 'package:acordeon_flutter/presentation/widgets/bass_panel_widget.dart';

const _musicXml = '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1">
      <part-name>Acordeón</part-name>
      <score-instrument id="P1-BASS"><instrument-name>Bajo Principal</instrument-name></score-instrument>
      <score-instrument id="P1-CHORD"><instrument-name>Acorde Acompañante</instrument-name></score-instrument>
    </score-part>
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
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><instrument id="P1-BASS"/></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration><instrument id="P1-BASS"/><notations><articulations><accent/></articulations></notations></note>
    </measure>
  </part>
</score-partwise>
''';

const _rhythmFiles = <(String, String)>[
  ('paseo.musicxml', 'I. PASEO VALLENATO'),
  ('merengue.musicxml', 'II. MERENGUE VALLENATO'),
  ('puya.musicxml', 'III. PUYA VALLENATA'),
  ('son.musicxml', 'IV. SON VALLENATO (Bajo Arrastrado)'),
  ('chande.musicxml', 'V. CHANDÉ'),
  ('cumbia.musicxml', 'VI. CUMBIA COLOMBIANA'),
];

BassRhythmPattern _patternFromFile(String fileName, String patternName) {
  final score = File('../$fileName').readAsStringSync();
  return MusicXmlRhythmImporter()
      .importPatterns(score)
      .patterns
      .firstWhere((pattern) => pattern.name == patternName);
}

void main() {
  group('MusicXML bass rhythm import', () {
    test('imports the five Paseo Vallenato events from its own file', () {
      final paseo = _patternFromFile('paseo.musicxml', 'I. PASEO VALLENATO');

      expect(paseo.beatsPerMeasure, 4);
      expect(paseo.beatType, 4);
      expect(paseo.quarterNotesPerMinute, 130);
      expect(paseo.hits, hasLength(5));
      expect(paseo.hits.map((hit) => hit.buttonType), [
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.chord,
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.chord,
      ]);
      expect(paseo.hits.map((hit) => hit.buttonIndex), [1, 7, 3, 9, 5]);
      expect(paseo.hits.map((hit) => hit.pairedButtonIndex), [0, 6, 2, 8, 4]);
      expect(paseo.hits.map((hit) => hit.fingerNumber), [2, 2, 2, 2, 2]);
      expect(paseo.hits.map((hit) => hit.pairedFingerNumber), [3, 3, 3, 3, 3]);
      expect(paseo.hits.map((hit) => hit.onsetQuarterBeats), [
        0,
        1 / 3,
        2 / 3,
        1,
        1.5,
      ]);
    });

    test('lists each named rhythm once, excluding repeat measures', () {
      final names = <String>[];
      for (final (file, expectedName) in _rhythmFiles) {
        final score = File('../$file').readAsStringSync();
        final patterns = MusicXmlRhythmImporter()
            .importPatterns(score)
            .patterns;
        final named = patterns
            .where((pattern) => pattern.name == expectedName)
            .toList();

        expect(
          named,
          hasLength(1),
          reason: '$file debe contener un solo "$expectedName"',
        );
        names.add(named.single.name);
      }

      expect(names, [
        'I. PASEO VALLENATO',
        'II. MERENGUE VALLENATO',
        'III. PUYA VALLENATA',
        'IV. SON VALLENATO (Bajo Arrastrado)',
        'V. CHANDÉ',
        'VI. CUMBIA COLOMBIANA',
      ]);
    });

    test('imports Vallenato grooves with row fingering and articulations', () {
      BassRhythmPattern patternFrom(String fileName, String name) =>
          _patternFromFile(fileName, name);

      final merengue = patternFrom(
        'merengue.musicxml',
        'II. MERENGUE VALLENATO',
      );
      expect(merengue.hits, hasLength(4));
      expect(merengue.hits.map((hit) => hit.buttonType), [
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.chord,
        BassRhythmButtonType.fundamental,
      ]);
      expect(merengue.hits.map((hit) => hit.onsetQuarterBeats), [
        0,
        0.75,
        1.5,
        2.25,
      ]);
      expect(merengue.hits.map((hit) => hit.buttonIndex), [1, 7, 3, 9]);
      expect(merengue.hits.map((hit) => hit.pairedButtonIndex), [0, 6, 2, 8]);
      expect(merengue.hits.map((hit) => hit.fingerNumber), [2, 2, 2, 2]);
      expect(merengue.hits.map((hit) => hit.pairedFingerNumber), [3, 3, 3, 3]);
      expect(merengue.hits.map((hit) => hit.isAccented), [
        false,
        false,
        true,
        false,
      ]);

      final puya = patternFrom('puya.musicxml', 'III. PUYA VALLENATA');
      expect(puya.hits, hasLength(4));
      expect(puya.hits.every((hit) => hit.isStaccato), isTrue);
      expect(puya.hits.map((hit) => hit.onsetQuarterBeats), [
        0,
        0.75,
        1.5,
        2.25,
      ]);

      final chande = patternFrom('chande.musicxml', 'V. CHANDÉ');
      expect(chande.hits, hasLength(4));
      expect(chande.hits.map((hit) => hit.onsetQuarterBeats), [
        0,
        0.75,
        2,
        2.75,
      ]);

      final cumbia = patternFrom('cumbia.musicxml', 'VI. CUMBIA COLOMBIANA');
      expect(cumbia.hits, hasLength(4));
      expect(cumbia.hits.map((hit) => hit.buttonType), [
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.chord,
        BassRhythmButtonType.fundamental,
        BassRhythmButtonType.chord,
      ]);
      expect(cumbia.hits.map((hit) => hit.fingerNumber), [2, 2, 2, 2]);
      expect(cumbia.hits.map((hit) => hit.pairedFingerNumber), [3, 3, 3, 3]);
      expect(cumbia.hits.map((hit) => hit.buttonIndex), [1, 7, 3, 9]);
      expect(cumbia.hits.map((hit) => hit.pairedButtonIndex), [0, 6, 2, 8]);
    });

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
      expect(paseo.hits.map((hit) => hit.buttonIndex), [1, 7]);
      expect(paseo.hits.map((hit) => hit.pairedButtonIndex), [0, 6]);
      expect(merengue.beatsPerMeasure, 6);
      expect(merengue.beatType, 8);
      expect(merengue.durationQuarterBeats, 3);
      expect(merengue.hits.map((hit) => hit.buttonIndex), [1, 7]);
      expect(merengue.hits.map((hit) => hit.pairedButtonIndex), [0, 6]);
    });

    test('recovers only the known malformed event as a pause', () {
      const malformedEvent =
          '<note><pitch><step>G</node><rest><duration>2</duration>'
          '<voice>1</voice><type>quarter</type></rest>';
      final xml = _musicXml.replaceFirst(
        '<note><pitch><step>E</step><octave>4</octave></pitch>'
        '<duration>4</duration></note>',
        malformedEvent,
      );

      final result = MusicXmlRhythmImporter().importPatterns(xml);
      final paseo = result.patterns.first;

      expect(result.recoveredMalformedEvents, 1);
      expect(paseo.hits, hasLength(1));
      expect(paseo.hits.single.onsetQuarterBeats, 0);
      expect(paseo.durationQuarterBeats, 4);
    });

    test('cycles sequential hits across the six bass pairs', () {
      final notes = List.generate(
        13,
        (_) =>
            '<note><pitch><step>C</step><octave>4</octave></pitch>'
            '<duration>1</duration></note>',
      ).join();
      final xml =
          '''
<score-partwise>
  <part-list><score-part id="P1"><part-name>Bajos</part-name></score-part></part-list>
  <part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>$notes</measure></part>
</score-partwise>
''';

      final result = MusicXmlRhythmImporter().importPatterns(xml);
      final hits = result.patterns.single.hits;

      // Parejas alternas: exterior 1-2, interior 1-2, exterior 3-4, ...
      expect(hits.map((hit) => hit.buttonIndex), [
        1,
        7,
        3,
        9,
        5,
        11,
        1,
        7,
        3,
        9,
        5,
        11,
        1,
      ]);
      expect(hits.map((hit) => hit.pairedButtonIndex), [
        0,
        6,
        2,
        8,
        4,
        10,
        0,
        6,
        2,
        8,
        4,
        10,
        0,
      ]);
      expect(hits.every((hit) => hit.fingerNumber == 2), isTrue);
      expect(hits.every((hit) => hit.pairedFingerNumber == 3), isTrue);
      expect(hits.map((hit) => hit.buttonIndexes), everyElement(hasLength(2)));
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
      'captura un patrón desde la matriz 2×2 de bajos (7, 8, 4, 5)',
      (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetPhysicalSize());

        final audioEngine = _RecordingAudioEngine();
        final container = ProviderContainer(
          overrides: [
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

        // El panel ya no expone combobox ni modal de listado de ritmos.
        expect(
          find.byKey(const ValueKey('bass_rhythm_pattern_picker_1')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('bass_rhythm_import_btn_1')),
          findsNothing,
        );

        final patternCountBefore = container
            .read(accordionSimulatorProvider)
            .bassRhythmPatterns
            .length;

        await tester.tap(
          find.byKey(const ValueKey('bass_rhythm_capture_btn_1')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Capturar patrón rítmico'), findsOneWidget);

        // La matriz relaciona las cuatro cajas con los botones 7, 8, 4, 5.
        for (final n in const [7, 8, 4, 5]) {
          expect(
            find.byKey(ValueKey('bass_matrix_cell_$n')),
            findsOneWidget,
          );
        }
        expect(find.text('Bajos externos'), findsOneWidget);
        expect(find.text('Bajos internos'), findsOneWidget);

        // Nombre del patrón y arranque de la captura.
        await tester.enterText(
          find.byKey(const ValueKey('bass_capture_name_field')),
          'Mi Paseo',
        );
        await tester.tap(
          find.byKey(const ValueKey('bass_capture_start_btn')),
        );
        await tester.pumpAndSettle();

        var state = container.read(accordionSimulatorProvider);
        expect(state.isBassCaptureActive, isTrue);

        // Tocar el bajo 7 registra un golpe.
        container
            .read(accordionSimulatorProvider.notifier)
            .captureBassMatrixHit(7);
        await tester.pump();
        state = container.read(accordionSimulatorProvider);
        expect(state.bassRhythmRecorder?.hits, hasLength(1));
        expect(state.bassRhythmRecorder!.hits.first.buttonIndex, 7);

        // Detener la captura registra el patrón con el nombre indicado.
        await tester.tap(
          find.byKey(const ValueKey('bass_capture_stop_btn')),
        );
        await tester.pumpAndSettle();

        state = container.read(accordionSimulatorProvider);
        expect(state.isBassCaptureActive, isFalse);
        expect(
          state.bassRhythmPatterns.length,
          patternCountBefore + 1,
        );
        expect(state.bassRhythmPatterns.first.name, 'Mi Paseo');
        expect(state.bassRhythmPatterns.first.hits, hasLength(1));
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
  final List<bool> clickAccents = [];

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
    clickAccents.add(isDownbeat);
  }

  @override
  void setVolume(double volume) {}
}
