import 'dart:math' as math;
import '../../core/constants/enums.dart';
import '../models/tuning.dart';

class MusicTheory {
  static const List<String> notesAlemanaSharp = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static const List<String> notesLatinaSharp = [
    'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'
  ];

  static const List<String> notesAlemanaFlat = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  static const List<String> notesLatinaFlat = [
    'Do', 'Re♭', 'Re', 'Mi♭', 'Mi', 'Fa', 'Sol♭', 'Sol', 'La♭', 'La', 'Si♭', 'Si'
  ];

  /// Retorna la clase de tono normalizada (0 a 11, donde 0 = C / Do).
  static int getPitchClass(int midi) {
    return ((midi % 12) + 12) % 12;
  }

  /// Retorna la octava científica de una nota MIDI (ej: 60 -> 4 para C4).
  static int getOctave(int midi) {
    return (midi ~/ 12) - 1;
  }

  /// Convierte una nota MIDI en frecuencia en Hz (A4 = 69 = 440 Hz).
  static double midiToFrequency(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  /// Convierte un número MIDI en su nombre textual (ej: 'Si♭4', 'Do#3').
  static String midiToName(
    int midi, {
    NotationMode notation = NotationMode.latina,
    bool ignoreOctave = false,
    int tuningOffset = 0,
  }) {
    final pitchClass = getPitchClass(midi);
    final octave = getOctave(midi);
    final useFlat = TuningRegistry.usesFlats(tuningOffset);

    final List<String> noteArray;
    if (notation == NotationMode.latina) {
      noteArray = useFlat ? notesLatinaFlat : notesLatinaSharp;
    } else {
      noteArray = useFlat ? notesAlemanaFlat : notesAlemanaSharp;
    }

    final name = noteArray[pitchClass];
    return ignoreOctave ? name : '$name$octave';
  }
}
