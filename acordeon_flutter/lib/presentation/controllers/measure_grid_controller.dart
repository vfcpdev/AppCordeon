import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/measure_models.dart';

class MeasureGridNotifier extends Notifier<List<MeasureRow>> {
  @override
  List<MeasureRow> build() {
    return List.generate(8, (bIdx) {
      return MeasureRow(
        barNumber: bIdx + 1,
        beats: List.generate(4, (beatIdx) {
          final timeSec = (bIdx * 4 + beatIdx) * 0.5;
          final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
          final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
          return MeasureBeat(
            barIndex: bIdx,
            beatIndex: beatIdx,
            chord: (bIdx == 0 && beatIdx == 0) ? 'Bb' : '',
            timeText: '$mins:$secs',
            isContinue: (bIdx == 0 && beatIdx > 0),
          );
        }),
      );
    });
  }

  void addMeasure() {
    final nextBar = state.length + 1;
    final newRow = MeasureRow(
      barNumber: nextBar,
      beats: List.generate(4, (beatIdx) {
        final timeSec = ((nextBar - 1) * 4 + beatIdx) * 0.5;
        final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
        final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
        return MeasureBeat(
          barIndex: nextBar - 1,
          beatIndex: beatIdx,
          chord: '',
          timeText: '$mins:$secs',
        );
      }),
    );
    state = [...state, newRow];
  }

  void updateMeasureBeat(int barIndex, int beatIndex, String chord) {
    if (barIndex < 0 || barIndex >= state.length) return;
    final row = state[barIndex];
    if (beatIndex < 0 || beatIndex >= row.beats.length) return;

    final updatedBeats = List<MeasureBeat>.from(row.beats);
    updatedBeats[beatIndex] = updatedBeats[beatIndex].copyWith(chord: chord);

    final updatedMeasures = List<MeasureRow>.from(state);
    updatedMeasures[barIndex] =
        MeasureRow(barNumber: row.barNumber, beats: updatedBeats);

    state = updatedMeasures;
  }

  void setBeatChord(int barIdx, int beatIdx, String chord) {
    state = state.map((m) {
      if (m.barNumber - 1 != barIdx) return m;
      final newBeats = m.beats.map((b) {
        if (b.beatIndex != beatIdx) return b;
        return b.copyWith(chord: chord);
      }).toList();
      return MeasureRow(barNumber: m.barNumber, beats: newBeats);
    }).toList();
  }

  void clearAllGridChords() {
    state = state.map((m) {
      return MeasureRow(
        barNumber: m.barNumber,
        beats: m.beats.map((b) => b.copyWith(chord: '')).toList(),
      );
    }).toList();
  }

  void populateFromChords(List<String> chordSymbols) {
    if (chordSymbols.isEmpty) return;
    final updatedMeasures = <MeasureRow>[];
    int chordIdx = 0;

    for (int bar = 1; bar <= 8; bar++) {
      final beats = <MeasureBeat>[];
      for (int b = 1; b <= 4; b++) {
        final ch = chordSymbols[chordIdx % chordSymbols.length];
        beats.add(MeasureBeat(
          barIndex: bar,
          beatIndex: b,
          chord: ch,
          timeText: '${((bar - 1) * 2.0 + (b - 1) * 0.5).toStringAsFixed(1)}s',
        ));
        if (b % 2 == 0) {
          chordIdx++;
        }
      }
      updatedMeasures.add(MeasureRow(barNumber: bar, beats: beats));
    }

    state = updatedMeasures;
  }
}

final measureGridProvider =
    NotifierProvider<MeasureGridNotifier, List<MeasureRow>>(() {
  return MeasureGridNotifier();
});
