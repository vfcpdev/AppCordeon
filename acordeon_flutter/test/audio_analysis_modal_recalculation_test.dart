import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/domain/models/audio_analysis_models.dart';
import 'package:acordeon_flutter/domain/theory/chord_catalog.dart';
import 'package:acordeon_flutter/presentation/controllers/accordion_controller.dart';
import 'package:acordeon_flutter/presentation/widgets/audio_analysis_dialog.dart';
import 'package:acordeon_flutter/presentation/widgets/edit_audio_key_bpm_dialog.dart';

void main() {
  group('Recálculo de Acordes y Transposición Armónica', () {
    test('ChordCatalog.transposeChordSymbol transpone símbolos con precisión', () {
      expect(ChordCatalog.transposeChordSymbol('Bm', 1), equals('Cm'));
      expect(ChordCatalog.transposeChordSymbol('Esus4', 1), equals('Fsus4'));
      expect(ChordCatalog.transposeChordSymbol('Bsus4', 1), equals('Csus4'));
      expect(ChordCatalog.transposeChordSymbol('F#sus4', 1), equals('Gsus4'));
      expect(ChordCatalog.transposeChordSymbol('Em', 1), equals('Fm'));
      expect(ChordCatalog.transposeChordSymbol('C', 1), equals('C#'));
      expect(ChordCatalog.transposeChordSymbol('C', 1, preferFlats: true), equals('Db'));
      expect(ChordCatalog.transposeChordSymbol('Em7', 1), equals('Fm7'));
      expect(ChordCatalog.transposeChordSymbol('F#m7', 1), equals('Gm7'));
      expect(ChordCatalog.transposeChordSymbol('Bm7', 1), equals('Cm7'));
      expect(ChordCatalog.transposeChordSymbol('C/E', 2), equals('D/F#'));
    });

    test('ChordCatalog.transposeChordName transpone nombres descriptivos en español', () {
      expect(ChordCatalog.transposeChordName('Si Menor', 1), equals('Do Menor'));
      expect(ChordCatalog.transposeChordName('Mi Sus4', 1), equals('Fa Sus4'));
      expect(ChordCatalog.transposeChordName('Fa# Sus4', 1), equals('Sol Sus4'));
      expect(ChordCatalog.transposeChordName('Do Mayor', 2), equals('Re Mayor'));
      expect(ChordCatalog.transposeChordName('Mi Menor 7ma', 1), equals('Fa Menor 7ma'));
      expect(ChordCatalog.transposeChordName('Si Menor 7ma', 3), equals('Re Menor 7ma'));
    });
  });

  group('Pipeline de Recálculo en AccordionSimulatorNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('updateAudioKeyAndBpm recalcula reporte, acordes y compases de forma atómica', () {
      final notifier = container.read(accordionSimulatorProvider.notifier);

      final initialChords = [
        const DetectedChordSegment(
          startTime: 0.0,
          endTime: 0.5,
          rootMod: 11,
          quality: 'min',
          chordName: 'Si Menor',
          chordSymbol: 'Bm',
          noteMods: [11, 2, 6],
          playbackMidis: [59, 62, 66],
          confidence: 0.88,
        ),
        const DetectedChordSegment(
          startTime: 0.5,
          endTime: 1.0,
          rootMod: 4,
          quality: 'sus4',
          chordName: 'Mi Sus4',
          chordSymbol: 'Esus4',
          noteMods: [4, 9, 11],
          playbackMidis: [52, 57, 59],
          confidence: 0.88,
        ),
      ];

      final initialReport = AudioAnalysisReport(
        duration: 4.0,
        bpm: 176,
        mainKey: const KeyDetectionResult(
          rootMod: 11,
          mode: 'minor',
          keyNameLat: 'Si Menor',
          keyNameAle: 'B Minor',
          recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
          recommendedOffset: 10,
          recommendedRow: 'row3',
          correlation: 0.81,
        ),
        chords: initialChords,
      );

      // Inyectar reporte inicial
      notifier.state = container.read(accordionSimulatorProvider).copyWith(
            audioReport: initialReport,
          );

      // Cargar en compases
      notifier.applyChordsToMeasures(initialChords);
      expect(container.read(accordionSimulatorProvider).measures[0].beats[0].chord, equals('Bm'));

      // Modificar Tono a Do Menor (root: 0, +1 semitono) y BPM a 120
      notifier.updateAudioKeyAndBpm(rootMod: 0, mode: 'minor', bpm: 120);

      final state = container.read(accordionSimulatorProvider);
      final rep = state.audioReport!;

      // 1. Tonalidad y BPM actualizados
      expect(rep.mainKey.rootMod, equals(0));
      expect(rep.mainKey.keyNameLat, equals('Do Menor'));
      expect(rep.bpm, equals(120));

      // 2. Acordes en el timeline recalculados
      expect(rep.chords[0].chordSymbol, equals('Cm'));
      expect(rep.chords[0].chordName, equals('Do Menor'));
      expect(rep.chords[1].chordSymbol, equals('Fsus4'));
      expect(rep.chords[1].chordName, equals('Fa Sus4'));

      // 3. Cuadrícula de compases recalculada efectivamente con el nuevo acorde
      expect(state.measures[0].beats[0].chord, equals('Cm'));
    });
  });

  group('Pruebas de Interfaz del Modal de Análisis y Corregir Tono/BPM', () {
    testWidgets('AudioAnalysisDialog reacciona inmediatamente al recálculo de Tono y BPM',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialChords = [
        const DetectedChordSegment(
          startTime: 0.0,
          endTime: 0.5,
          rootMod: 11,
          quality: 'min',
          chordName: 'Si Menor',
          chordSymbol: 'Bm',
          noteMods: [11, 2, 6],
          playbackMidis: [59, 62, 66],
          confidence: 0.88,
        ),
        const DetectedChordSegment(
          startTime: 0.5,
          endTime: 1.0,
          rootMod: 4,
          quality: 'sus4',
          chordName: 'Mi Sus4',
          chordSymbol: 'Esus4',
          noteMods: [4, 9, 11],
          playbackMidis: [52, 57, 59],
          confidence: 0.88,
        ),
      ];

      final report = AudioAnalysisReport(
        duration: 304.6,
        bpm: 176,
        mainKey: const KeyDetectionResult(
          rootMod: 11,
          mode: 'minor',
          keyNameLat: 'Si Menor',
          keyNameAle: 'B Minor',
          recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
          recommendedOffset: 10,
          recommendedRow: 'row3',
          correlation: 0.81,
        ),
        chords: initialChords,
      );

      final container = ProviderContainer();
      container.read(accordionSimulatorProvider.notifier).state =
          container.read(accordionSimulatorProvider).copyWith(audioReport: report);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AudioAnalysisDialog(
                report: report,
                fileName: 'COMO ZAQUEO - HAZ UN MILAGRO EN MI.mp3',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar estado inicial visible en el modal
      expect(find.text('Si Menor'), findsOneWidget);
      expect(find.text('Bm'), findsOneWidget);
      expect(find.textContaining('176 BPM'), findsOneWidget);

      // Abrir diálogo de Corregir Tono/BPM
      final editBtn = find.text('Corregir Tono/BPM');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.byType(EditAudioKeyBpmDialog), findsOneWidget);

      // Simular selección de Do / C (root: 0) y guardar
      final notifier = container.read(accordionSimulatorProvider.notifier);
      notifier.updateAudioKeyAndBpm(rootMod: 0, mode: 'minor', bpm: 120);
      await tester.pumpAndSettle();

      // Cerrar el diálogo hijo si sigue abierto
      if (find.byType(EditAudioKeyBpmDialog).evaluate().isNotEmpty) {
        final closeBtn = find.text('Guardar Cambios');
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn);
        } else {
          Navigator.of(tester.element(find.byType(EditAudioKeyBpmDialog))).pop();
        }
        await tester.pumpAndSettle();
      }

      // Verificar que AudioAnalysisDialog se actualizó reactivamente con los acordes recalculados
      expect(find.text('Do Menor'), findsOneWidget);
      expect(find.text('Cm'), findsOneWidget);
      expect(find.textContaining('120 BPM'), findsOneWidget);

      // Probar pulsar "Cargar en Compases"
      final loadBtn = find.text('Cargar en Compases');
      expect(loadBtn, findsOneWidget);
      await tester.tap(loadBtn);
      await tester.pumpAndSettle();

      // Verificar que los compases tienen el acorde recalculado
      final st = container.read(accordionSimulatorProvider);
      expect(st.measures[0].beats[0].chord, equals('Cm'));
    });
  });
}

