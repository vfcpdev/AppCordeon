import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/diapason_state.dart';
import '../../domain/models/tuning.dart';

/// Notifier para un diapasón particular (Family: 1 o 2).
/// Open/Closed: Añadir un tercer o cuarto acordeón en el futuro no requiere cambios aquí.
class DiapasonNotifier extends Notifier<DiapasonState> {
  final int accordionId;

  DiapasonNotifier(this.accordionId);

  @override
  DiapasonState build() {
    final isFirst = accordionId == 1;
    return DiapasonState(
      id: accordionId,
      isVisible: true,
      tuning: isFirst
          ? TuningRegistry.defaultTunings[0] // Cinco Letras
          : TuningRegistry.defaultTunings[1], // Rey Vallenato
      bellows: BellowsMode.push,
      isBassCollapsed: !isFirst,
      mirror: false,
      volume: 0.8,
      isMuted: false,
    );
  }

  void toggleVisibility() => state = state.copyWith(isVisible: !state.isVisible);
  void setTuning(TuningDefinition t) => state = state.copyWith(tuning: t);
  void setBellows(BellowsMode m) => state = state.copyWith(bellows: m);
  void toggleBass() => state = state.copyWith(isBassCollapsed: !state.isBassCollapsed);
  void toggleMirror() => state = state.copyWith(mirror: !state.mirror);
  void setVolume(double vol) => state = state.copyWith(volume: vol);
  void toggleMute() => state = state.copyWith(isMuted: !state.isMuted);
}

final diapasonFamilyProvider =
    NotifierProvider.family<DiapasonNotifier, DiapasonState, int>((arg) {
  return DiapasonNotifier(arg);
});
