/// Reloj musical inmutable (Value Object) que traduce tiempo de audio ↔ posición en la cuadrícula.
///
/// Centraliza en un solo lugar (Alta Cohesión / DRY) la aritmética que antes estaba
/// repetida en reproducción, búsqueda, marcador en vivo y generación de compases.
///
/// {I}: bpm > 0, offset >= 0, beatsPerBar > 0.
///      El Compás 1, tiempo 1 comienza exactamente en `offset` segundos.
class BeatClock {
  final double bpm;
  final double offset;
  final int beatsPerBar;

  const BeatClock._(this.bpm, this.offset, this.beatsPerBar);

  /// Fábrica que sanea las entradas para garantizar el invariante {I}.
  factory BeatClock({required num bpm, double offset = 0.0, int beatsPerBar = 4}) {
    final safeBpm = bpm > 0 ? bpm.toDouble() : 120.0;
    final safeOffset = offset.isFinite && offset > 0 ? offset : 0.0;
    final safeBeats = beatsPerBar > 0 ? beatsPerBar : 4;
    return BeatClock._(safeBpm, safeOffset, safeBeats);
  }

  double get secondsPerBeat => 60.0 / bpm;
  double get secondsPerBar => secondsPerBeat * beatsPerBar;

  /// {P}: t real. {Q}: índice de tiempo absoluto >= 0; los instantes previos a `offset` → 0.
  int totalBeatsAt(double t) {
    if (t <= offset) return 0;
    return ((t - offset) / secondsPerBeat).floor();
  }

  /// {P}: t real, barCount opcional > 0.
  /// {Q}: (bar, beat) con 0 <= beat < beatsPerBar; si se da barCount, 0 <= bar < barCount (cíclico).
  ({int bar, int beat}) positionAt(double t, {int? barCount}) {
    final total = totalBeatsAt(t);
    var bar = total ~/ beatsPerBar;
    if (barCount != null && barCount > 0) bar %= barCount;
    return (bar: bar, beat: total % beatsPerBar);
  }

  /// {P}: bar >= 0, 0 <= beat < beatsPerBar. {Q}: instante de inicio del tiempo, >= offset.
  double timeOf(int bar, [int beat = 0]) =>
      offset + (bar * beatsPerBar + beat) * secondsPerBeat;

  /// {Q}: cantidad de compases que cubren [offset, duration], acotada a [minBars, maxBars].
  int barsToCover(double duration, {int minBars = 8, int maxBars = 500}) {
    final span = (duration - offset).clamp(0.0, double.infinity);
    final beats = (span / secondsPerBeat).ceil();
    return ((beats + beatsPerBar - 1) ~/ beatsPerBar).clamp(minBars, maxBars);
  }

  /// Formato mm:ss para la etiqueta de cada tiempo.
  static String formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = ((seconds % 60).toInt()).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

