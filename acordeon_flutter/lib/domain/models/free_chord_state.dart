import '../../core/constants/enums.dart';
import '../theory/chord_catalog.dart';

/// Configuración de la Sección 5: Acorde Libre y Escalas.
///
/// Fuente única de verdad compartida por [FreeChordNotifier] (audio libre)
/// y el estado global del simulador (cuadrícula y diapasón). Consolidada en
/// `domain/models/` para eliminar la duplicación que existía entre
/// `accordion_controller.dart` y `free_chord_controller.dart`.
class FreeChordState {
  final int root; // 0=Do, 1=Do#, etc.
  final String type; // maj, min, dim, aug, sus2, sus4
  final String fourth; // none, octave, dom7, maj7, maj6, add9
  final String octave; // all, 3, 4, 5
  final String mode; // harmonic, melodic
  final bool isFixed;
  final bool isBeingEdited;
  final BellowsMode bellows;
  final String scaleHarmonicMode; // triad, seventh, five
  final String bass; // Bajo alterado / slash chord ('' = ninguno)

  const FreeChordState({
    this.root = -1,
    this.type = '',
    this.fourth = 'none',
    this.octave = 'all',
    this.mode = 'harmonic',
    this.isFixed = false,
    this.isBeingEdited = false,
    this.bellows = BellowsMode.both,
    this.scaleHarmonicMode = 'triad',
    this.bass = '',
  });

  FreeChordState copyWith({
    int? root,
    String? type,
    String? fourth,
    String? octave,
    String? mode,
    bool? isFixed,
    bool? isBeingEdited,
    BellowsMode? bellows,
    String? scaleHarmonicMode,
    String? bass,
  }) {
    return FreeChordState(
      root: root ?? this.root,
      type: type ?? this.type,
      fourth: fourth ?? this.fourth,
      octave: octave ?? this.octave,
      mode: mode ?? this.mode,
      isFixed: isFixed ?? this.isFixed,
      isBeingEdited: isBeingEdited ?? this.isBeingEdited,
      bellows: bellows ?? this.bellows,
      scaleHarmonicMode: scaleHarmonicMode ?? this.scaleHarmonicMode,
      bass: bass ?? this.bass,
    );
  }

  /// Notas MIDI del acorde configurado, vía el catálogo teórico.
  List<int> calculateNotes() => ChordCatalog.notesFor(
        root: root,
        type: type,
        extension: fourth,
      );
}
