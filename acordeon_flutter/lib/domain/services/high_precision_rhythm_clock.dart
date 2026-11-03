/// Servicio de dominio para el cálculo temporal y secuenciación rítmica de alta precisión.
///
/// Principios aplicados:
/// - **Single Responsibility Principle (SRP)**: Encapsula exclusivamente el cómputo
///   matemático del tiempo musical y la duración de notas, aislando la lógica de jitter
///   y drift del ciclo de vida del controlador y la UI.
/// - **Open/Closed Principle (OCP)**: Permite evaluar cualquier origen monotónico de tiempo
///   sin requerir dependencias de hardware ni timers del sistema operativo.
/// - **Triplas de Hoare**:
///   - Precondición {P}: `bpm >= 30.0 && bpm <= 300.0 && durationQuarterBeats > 0.0`.
///   - Comando {C}: Cómputo de posición en negra mediante microsegundos absolutos:
///       $$\text{position} = \left(\frac{\text{elapsedMicroseconds}}{1\,000\,000.0} \times \frac{\text{bpm}}{60.0}\right) \bmod \text{durationQuarterBeats}$$
///   - Poscondición {Q}: `0.0 <= position < durationQuarterBeats`.
///   - Invariante {I}: La posición rítmica es estrictamente proporcional al tiempo real
///     transcurrido y no acumula error por retrasos de callbacks (*zero clock drift*).
class HighPrecisionRhythmClock {
  final double bpm;
  final double durationQuarterBeats;

  const HighPrecisionRhythmClock({
    required this.bpm,
    required this.durationQuarterBeats,
  });

  /// Determina la posición rítmica exacta (en tiempos de negra) para un tiempo transcurrido dado.
  double positionAtMicroseconds(int elapsedMicroseconds) {
    if (durationQuarterBeats <= 0.0 || bpm <= 0.0 || elapsedMicroseconds <= 0) {
      return 0.0;
    }
    final elapsedSeconds = elapsedMicroseconds / 1000000.0;
    final totalQuarterBeats = elapsedSeconds * (bpm / 60.0);
    return totalQuarterBeats % durationQuarterBeats;
  }

  /// Calcula los tiempos absolutos (en tiempos de negra) acumulados desde el inicio.
  double totalQuarterBeatsAtMicroseconds(int elapsedMicroseconds) {
    if (bpm <= 0.0 || elapsedMicroseconds <= 0) return 0.0;
    return (elapsedMicroseconds / 1000000.0) * (bpm / 60.0);
  }

  /// Calcula la duración física en milisegundos de un golpe de bajo según el tempo y articulación.
  int noteDurationMs(double hitDurationQuarterBeats, {bool isStaccato = false}) {
    if (bpm <= 0.0 || hitDurationQuarterBeats <= 0.0) return 80;
    var durationSec = hitDurationQuarterBeats * 60.0 / bpm;
    if (isStaccato) {
      durationSec *= 0.5;
    }
    return (durationSec * 1000 * 0.9).round().clamp(50, 1500);
  }
}

