import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'audio_file_player_interface.dart';

AudioFilePlayer getAudioFilePlayer() => WebAudioFilePlayer();

/// Reproduce el archivo cargado usando un elemento `<audio>` con un Blob URL.
/// No requiere plugins: funciona en cualquier navegador moderno.
class WebAudioFilePlayer implements AudioFilePlayer {
  web.HTMLAudioElement? _audio;
  String? _objectUrl;
  double _volume = 0.8;

  @override
  bool get isLoaded => _audio != null;

  @override
  double get positionSeconds => _audio?.currentTime ?? 0;

  @override
  double get durationSeconds {
    final d = _audio?.duration ?? 0;
    return d.isFinite && d > 0 ? d : 0;
  }

  @override
  void load(Uint8List bytes, String mimeType) {
    _release();
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      final url = web.URL.createObjectURL(blob);
      _objectUrl = url;
      final audio = web.HTMLAudioElement()
        ..src = url
        ..preload = 'auto'
        ..volume = _volume;
      _audio = audio;
    } catch (e) {
      // Si el navegador no puede crear el Blob, se deja sin reproducción.
      _audio = null;
      _objectUrl = null;
    }
  }

  @override
  void play() {
    final audio = _audio;
    if (audio == null) return;
    // El gesto del usuario (botón Play) permite iniciar la reproducción.
    unawaited(audio.play().toDart.catchError((Object _) => null));
  }

  @override
  void pause() {
    _audio?.pause();
  }

  @override
  void stop() {
    final audio = _audio;
    if (audio == null) return;
    audio.pause();
    audio.currentTime = 0;
  }

  @override
  void seek(double seconds) {
    final audio = _audio;
    if (audio == null) return;
    final duration = durationSeconds;
    final target = seconds.clamp(0.0, duration > 0 ? duration : seconds);
    audio.currentTime = target;
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    final audio = _audio;
    if (audio != null) {
      audio.volume = _volume;
    }
  }

  void _release() {
    final audio = _audio;
    if (audio != null) {
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
    }
    _audio = null;
    final url = _objectUrl;
    if (url != null) {
      web.URL.revokeObjectURL(url);
      _objectUrl = null;
    }
  }
}
