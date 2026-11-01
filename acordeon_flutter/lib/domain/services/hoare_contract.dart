import '../commands/accordion_commands.dart' as contracts;

/// Mixin de contratos formales (Triplas de Hoare) para controllers y servicios.
///
/// El dominio ya verifica precondiciones vía `AccordionCommand.assertPreconditions`.
/// Este mixin extiende la disciplina al resto de la capa de aplicación con
/// helpers `require` (precondición {P}) y `ensure` (poscondición {Q}).
///
/// Uso típico en un método mutador de estado:
/// ```dart
/// void updateAudioKeyAndBpm({required int bpm}) {
///   require('updateAudioKeyAndBpm', 'bpm ∈ [30,300]', bpm >= 30 && bpm <= 300);
///   ...
///   ensure('updateAudioKeyAndBpm', 'measures no vacía', state.measures.isNotEmpty);
/// }
/// ```
///
/// En producción una violación lanza [PreconditionViolationException] (fallo
/// temprano y explícito); en pruebas sirve como aserción formal ejecutable.
mixin HoareContract {
  /// Verifica la precondición {P}: lanza si `condition` es falsa.
  ///
  /// {P} del propio helper: `name` y `reason` no vacíos.
  /// {Q}: retorna normalmente sólo si la condición se cumple.
  void require(String name, String reason, bool condition) {
    if (!condition) {
      throw contracts.PreconditionViolationException(
          name, 'Precondición {P}: $reason');
    }
  }

  /// Verifica la poscondición {Q}: lanza si `condition` es falsa.
  ///
  /// Se invoca justo antes de retornar del método mutador, con el estado ya
  /// actualizado, para atrapar mutaciones inconsistentes.
  void ensure(String name, String reason, bool condition) {
    if (!condition) {
      throw contracts.PreconditionViolationException(
          name, 'Poscondición {Q}: $reason');
    }
  }

  /// Verifica un invariante que debe mantenerse en todo momento.
  void invariant(String name, String reason, bool condition) {
    if (!condition) {
      throw contracts.PreconditionViolationException(
          name, 'Invariante {I}: $reason');
    }
  }
}
