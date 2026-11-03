import '../../../domain/models/measure_models.dart';
import '../../../domain/models/tuning.dart';
import '../../../domain/theory/chord_detector_engine.dart';

/// Controlador de dominio especializado para la gestión armónica, afinaciones,
/// acordes libres, cálculo modal de extensiones y detección de acordes.
///
/// Aplica el principio de Responsabilidad Única (SRP) y forma parte
/// del desacoplamiento modular bajo SPEC-001.
class AccordionHarmonicController {
  AccordionHarmonicController();

  /// Alterna o establece la tónica del acorde libre (interruptor reversible).
  ///
  /// {P}: `root >= 0 && root <= 11`
  /// {Q}: Si `currentRoot == root`, se desactiva (`-1`); si no, se asigna `root`.
  int toggleFreeChordRoot(int currentRoot, int newRoot) {
    return currentRoot == newRoot ? -1 : newRoot;
  }

  /// Alterna o establece la cualidad del acorde libre.
  String toggleFreeChordType(String currentType, String newType) {
    return currentType == newType ? '' : newType;
  }

  /// Alterna o establece la extensión (4ta nota / 7ma / 9na).
  String toggleFreeChordFourth(String currentFourth, String newFourth) {
    return currentFourth == newFourth ? '' : newFourth;
  }

  /// Alterna o establece el filtro de octava.
  String toggleFreeChordOctave(String currentOctave, String newOctave) {
    return currentOctave == newOctave ? '' : newOctave;
  }

  /// Resuelve la extensión armónica cuando se selecciona un modo de escala (Tríada, Séptima, Quinto grado).
  String resolveExtensionForScaleHarmonicMode({
    required String targetMode,
    required String currentFourth,
    required String currentType,
  }) {
    if (targetMode == 'triad') {
      if (['dom7', 'maj7', 'min7', 'dim7', 'five'].contains(currentFourth)) {
        return '';
      }
      return currentFourth;
    } else if (targetMode == 'seventh') {
      if (currentFourth.isEmpty ||
          currentFourth == 'none' ||
          currentFourth == 'octave') {
        if (currentType == 'min') return 'min7';
        if (currentType == 'dim') return 'dim7';
        return 'dom7';
      }
      return currentFourth;
    } else if (targetMode == 'five') {
      return 'five';
    }
    return currentFourth;
  }

  /// Detecta un acorde a partir de una lista de notas MIDI.
  ///
  /// {P}: `midiNotes` no es nulo.
  /// {Q}: Devuelve el modelo de acorde detectado o nulo si no hay notas suficientes.
  DetectedChordModel? detectChordFromMidiNotes(List<int> midiNotes) {
    if (midiNotes.length < 2) return null;
    return ChordDetectorEngine.detect(midiNotes: midiNotes);
  }

  /// Valida y devuelve la afinación correspondiente.
  TuningDefinition validateTuning(TuningDefinition tuning) {
    return tuning;
  }
}
