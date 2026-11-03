import '../../../domain/models/bass_rhythm_pattern.dart';

/// Controlador de dominio especializado para la gestión y selección de
/// patrones rítmicos de bajos, filtros de hilera y visualización de columnas.
///
/// Aplica el principio de Responsabilidad Única (SRP) y forma parte
/// del desacoplamiento modular bajo SPEC-001.
class AccordionBassRhythmController {
  AccordionBassRhythmController();

  /// Valida y selecciona un patrón rítmico por su identificador único.
  ///
  /// {P}: `availablePatterns` no es nulo; si `patternId != null`, debe existir en la lista.
  /// {Q}: Devuelve el `patternId` validado.
  String? validateAndSelectPatternId(
    String? patternId,
    List<BassRhythmPattern> availablePatterns,
  ) {
    if (patternId != null &&
        !availablePatterns.any((pattern) => pattern.id == patternId)) {
      throw ArgumentError.value(
        patternId,
        'patternId',
        'No corresponde a un patrón rítmico disponible.',
      );
    }
    return patternId;
  }

  /// Calcula el incremento temporal de un golpe dentro de los límites de un compás.
  ///
  /// {P}: `0.0 <= currentOnset <= maxDurationQuarterBeats`
  /// {Q}: `0.0 <= resultado <= maxDurationQuarterBeats`
  double nudgeBeatOnset(
    double currentOnset,
    double delta, {
    double maxDurationQuarterBeats = 4.0,
  }) {
    final next = currentOnset + delta;
    return next.clamp(0.0, maxDurationQuarterBeats);
  }

  /// Cuantiza la posición de un golpe al múltiplo más cercano de la rejilla temporal.
  ///
  /// {P}: `gridStep > 0`
  /// {Q}: El resultado es un múltiplo exacto de `gridStep`.
  double quantizeBeatOnset(double currentOnset, double gridStep) {
    if (gridStep <= 0) return currentOnset;
    return (currentOnset / gridStep).round() * gridStep;
  }
}
