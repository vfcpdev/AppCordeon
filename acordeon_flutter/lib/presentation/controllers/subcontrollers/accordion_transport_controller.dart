import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/services/high_precision_rhythm_clock.dart';

/// Controlador de dominio especializado para la gestión del transporte,
/// reproducción de compás, tempo (BPM) y secuenciación rítmica.
///
/// Cumple con el principio de Responsabilidad Única (SRP) y forma parte
/// del desacoplamiento modular del controlador principal bajo el patrón Facade.
class AccordionTransportController {
  Timer? _playbackTimer;
  VoidCallback? _onStateChanged;

  AccordionTransportController();

  void attach({required VoidCallback onStateChanged}) {
    _onStateChanged = onStateChanged;
  }

  void dispose() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  /// Crea un reloj de alta precisión para un cálculo rítmico específico.
  HighPrecisionRhythmClock createClock({
    required double bpm,
    required double durationQuarterBeats,
  }) {
    return HighPrecisionRhythmClock(
      bpm: bpm,
      durationQuarterBeats: durationQuarterBeats,
    );
  }

  /// Inicia el temporizador de reproducción para iterar sobre los beats del compás.
  void startLoop({
    required double bpm,
    required int totalBeats,
    required void Function(int nextBeatIndex) onTick,
  }) {
    _playbackTimer?.cancel();
    final intervalMs = (60000.0 / bpm).round().clamp(100, 3000);
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      onTick(timer.tick % (totalBeats > 0 ? totalBeats : 1));
      _onStateChanged?.call();
    });
  }

  /// Detiene la reproducción en curso.
  void stopLoop() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _onStateChanged?.call();
  }

  bool get isPlaying => _playbackTimer != null && _playbackTimer!.isActive;
}
