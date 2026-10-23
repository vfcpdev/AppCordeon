import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/tuning.dart';

/// Estado independiente de un diapasón de acordeón (Family: id 1 o 2).
/// Elimina la duplicación de 10 métodos y 10 campos entre Accordion 1 y Accordion 2.
class DiapasonState {
  final int id;
  final bool isVisible;
  final TuningDefinition tuning;
  final BellowsMode bellows;
  final bool isBassCollapsed;
  final bool mirror;
  final double volume;
  final bool isMuted;

  const DiapasonState({
    required this.id,
    required this.isVisible,
    required this.tuning,
    required this.bellows,
    required this.isBassCollapsed,
    required this.mirror,
    required this.volume,
    required this.isMuted,
  });

  DiapasonState copyWith({
    bool? isVisible,
    TuningDefinition? tuning,
    BellowsMode? bellows,
    bool? isBassCollapsed,
    bool? mirror,
    double? volume,
    bool? isMuted,
  }) {
    return DiapasonState(
      id: id,
      isVisible: isVisible ?? this.isVisible,
      tuning: tuning ?? this.tuning,
      bellows: bellows ?? this.bellows,
      isBassCollapsed: isBassCollapsed ?? this.isBassCollapsed,
      mirror: mirror ?? this.mirror,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, List<TrebleButtonModel>> get trebleData =>
      AccordionData.getTransposedTreble(tuning.offset);

  List<BassButtonModel> get bassData =>
      AccordionData.getTransposedBasses(tuning.offset);
}
