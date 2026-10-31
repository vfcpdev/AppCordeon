import '../../core/constants/enums.dart';
import '../models/accordion_data.dart';
import '../models/measure_models.dart';
import '../theory/chord_detector_engine.dart';

/// Contrato base para comandos ejecutables en el simulador (Command Pattern + SRP).
abstract class AccordionCommand<T> {
  T execute();
}

/// Comando para limpiar completamente el diapasón dejando 0 botones presionados o resaltados.
class ClearDiapasonCommand implements AccordionCommand<void> {
  final void Function({
    required int freeChordRoot,
    required bool isFreeChordFixed,
    required Set<String> activeButtons,
    required List<String> detectorSelectedButtons,
    required DetectedChordModel? detectedChord,
    required Set<int> playingChordNotes,
  }) stateUpdater;

  const ClearDiapasonCommand(this.stateUpdater);

  @override
  void execute() {
    stateUpdater(
      freeChordRoot: -1,
      isFreeChordFixed: false,
      activeButtons: const {},
      detectorSelectedButtons: const [],
      detectedChord: null,
      playingChordNotes: const {},
    );
  }
}

/// Comando para asignar un acorde detectado a una celda de compás con fuelle óptimo.
class AssignDetectedChordCommand implements AccordionCommand<bool> {
  final DetectedChordModel? chord;
  final int barIndex;
  final int beatIndex;
  final NotationMode notation;
  final Map<String, List<TrebleButtonModel>> trebleData;
  final void Function(int bar, int beat, String chordSymbol) onUpdateBeat;
  final void Function(int bar, int beat, BellowsMode bellows) onSetBellows;

  const AssignDetectedChordCommand({
    required this.chord,
    required this.barIndex,
    required this.beatIndex,
    required this.notation,
    required this.trebleData,
    required this.onUpdateBeat,
    required this.onSetBellows,
  });

  @override
  bool execute() {
    if (chord == null) return false;

    final symbol = chord!.formattedSymbol(notation);
    onUpdateBeat(barIndex, beatIndex, symbol);

    final availability = ChordDetectorEngine.evaluateDiapasonBellows(
      chordPitchClasses: chord!.pitchClasses,
      trebleData: trebleData,
    );

    if (availability.isCompletePush && !availability.isCompletePull) {
      onSetBellows(barIndex, beatIndex, BellowsMode.push);
    } else if (!availability.isCompletePush && availability.isCompletePull) {
      onSetBellows(barIndex, beatIndex, BellowsMode.pull);
    }

    return true;
  }
}
