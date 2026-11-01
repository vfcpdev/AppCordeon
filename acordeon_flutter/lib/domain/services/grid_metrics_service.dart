import '../models/audio_analysis_models.dart';
import '../models/measure_models.dart';

/// Encuentra el símbolo de acorde vigente en un instante dado usando búsqueda
/// binaria sobre segmentos ordenados por tiempo.
///
/// # Triplas de Hoare:
/// - {P}: `chords` no vacío (si está vacío devuelve ''). Los segmentos pueden
///        estar desordenados entre segmentos contiguos pero cada segmento
///        cumple `startTime <= endTime`.
/// - {Q}: retorna el símbolo del segmento que contiene `timeSeconds`, o el del
///        segmento contiguo más próximo cuando el instante cae en un hueco.
String findChordForTime(
  List<DetectedChordSegment> chords,
  double timeSeconds,
) {
  if (chords.isEmpty) return '';
  var low = 0;
  var high = chords.length - 1;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final segment = chords[mid];
    if (segment.startTime <= timeSeconds && timeSeconds < segment.endTime) {
      return segment.chordSymbol;
    }
    if (timeSeconds < segment.startTime) {
      high = mid - 1;
    } else {
      low = mid + 1;
    }
  }
  if (low >= chords.length) return chords.last.chordSymbol;
  if (high < 0) return chords.first.chordSymbol;
  final distanceToNext = (chords[low].startTime - timeSeconds).abs();
  final distanceToPrevious = (timeSeconds - chords[high].endTime).abs();
  return distanceToNext < distanceToPrevious
      ? chords[low].chordSymbol
      : chords[high].chordSymbol;
}

/// Formatea un instante (s) como texto `mm:ss` para la cuadrícula.
/// Único punto de verdad del formato de tiempos de la cuadrícula.
String formatBeatTime(double seconds) {
  final mins = (seconds ~/ 60).toString().padLeft(2, '0');
  final secs = ((seconds % 60).toInt()).toString().padLeft(2, '0');
  return '$mins:$secs';
}

/// Construye un compás de 4 tiempos con su texto de tiempo derivado de
/// `secondsPerBeat` y (opcionalmente) el acorde del timeline en cada beat.
/// Único punto de verdad para generar filas de compases en la cuadrícula.
///
/// # Triplas de Hoare:
/// - {P}: `secondsPerBeat > 0 && barIndex >= 0`.
/// - {Q}: retorna una [MeasureRow] con 4 beats, `barNumber == barIndex + 1` y
///        `timeText` estrictamente creciente dentro del compás.
MeasureRow buildMeasureRow({
  required int barIndex,
  required double secondsPerBeat,
  double startOffset = 0.0,
  List<DetectedChordSegment> chords = const [],
  double chordProbeBias = 0.0,
  bool isContinue = false,
}) {
  return MeasureRow(
    barNumber: barIndex + 1,
    beats: List.generate(4, (beatIdx) {
      final beatTime = startOffset + (barIndex * 4 + beatIdx) * secondsPerBeat;
      final ch = chords.isEmpty
          ? ''
          : findChordForTime(chords, beatTime + chordProbeBias);
      return MeasureBeat(
        barIndex: barIndex,
        beatIndex: beatIdx,
        chord: ch,
        timeText: formatBeatTime(beatTime),
        isContinue: isContinue,
      );
    }),
  );
}
