import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_engine_bridge.dart';
import '../../core/di/providers.dart';

class PlaybackState {
  final bool isPlaying;
  final double currentTime;
  final double totalDuration;
  final int selectedBarIndex;
  final int selectedBeatIndex;
  final bool syncDiapason;
  final bool sequenceMode;
  final int visibleGridRows;

  const PlaybackState({
    required this.isPlaying,
    required this.currentTime,
    required this.totalDuration,
    required this.selectedBarIndex,
    required this.selectedBeatIndex,
    required this.syncDiapason,
    required this.sequenceMode,
    required this.visibleGridRows,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    double? currentTime,
    double? totalDuration,
    int? selectedBarIndex,
    int? selectedBeatIndex,
    bool? syncDiapason,
    bool? sequenceMode,
    int? visibleGridRows,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentTime: currentTime ?? this.currentTime,
      totalDuration: totalDuration ?? this.totalDuration,
      selectedBarIndex: selectedBarIndex ?? this.selectedBarIndex,
      selectedBeatIndex: selectedBeatIndex ?? this.selectedBeatIndex,
      syncDiapason: syncDiapason ?? this.syncDiapason,
      sequenceMode: sequenceMode ?? this.sequenceMode,
      visibleGridRows: visibleGridRows ?? this.visibleGridRows,
    );
  }
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  Timer? _playbackTimer;
  late AudioEngine _audioBridge;

  @override
  PlaybackState build() {
    _audioBridge = ref.read(audioEngineProvider);
    ref.onDispose(() => _playbackTimer?.cancel());
    return const PlaybackState(
      isPlaying: false,
      currentTime: 0.0,
      totalDuration: 180.0,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
      syncDiapason: true,
      sequenceMode: true,
      visibleGridRows: 4,
    );
  }

  void togglePlay({double bpm = 120.0, int measureCount = 8}) {
    final nextPlaying = !state.isPlaying;
    state = state.copyWith(isPlaying: nextPlaying);
    _playbackTimer?.cancel();

    if (nextPlaying) {
      final safeBpm = bpm > 0 ? bpm : 120.0;
      final intervalMs = ((60.0 / safeBpm / 2.0) * 1000).toInt().clamp(50, 1000);

      _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
        if (!state.isPlaying) {
          timer.cancel();
          return;
        }

        final nextTime = state.currentTime + (intervalMs / 1000.0);
        final totalDur = state.totalDuration > 0 ? state.totalDuration : 16.0;
        final wrappedTime = nextTime >= totalDur ? 0.0 : nextTime;

        final beatDuration = 60.0 / safeBpm;
        final totalBeats = (wrappedTime / beatDuration).floor();
        final currentBar = (totalBeats ~/ 4) % (measureCount > 0 ? measureCount : 8);
        final currentBeat = totalBeats % 4;

        state = state.copyWith(
          currentTime: wrappedTime,
          selectedBarIndex: currentBar,
          selectedBeatIndex: currentBeat,
        );
      });
    }
  }

  void stop() {
    _playbackTimer?.cancel();
    state = state.copyWith(
      isPlaying: false,
      currentTime: 0.0,
      selectedBarIndex: 0,
      selectedBeatIndex: 0,
    );
    _audioBridge.allNotesOff();
  }

  void seek(double time) {
    state = state.copyWith(currentTime: time);
  }

  void selectBeat(int barIdx, int beatIdx) {
    state = state.copyWith(
      selectedBarIndex: barIdx,
      selectedBeatIndex: beatIdx,
    );
  }

  void setDuration(double duration) {
    state = state.copyWith(totalDuration: duration);
  }

  void toggleSyncDiapason() =>
      state = state.copyWith(syncDiapason: !state.syncDiapason);

  void toggleSequenceMode() =>
      state = state.copyWith(sequenceMode: !state.sequenceMode);
}

final playbackProvider =
    NotifierProvider<PlaybackNotifier, PlaybackState>(() {
  return PlaybackNotifier();
});
