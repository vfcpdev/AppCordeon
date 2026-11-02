import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'audio_file_player_interface.dart';

AudioFilePlayer getAudioFilePlayer() => WebAudioFilePlayer();

/// Reproduce el archivo cargado usando un elemento `<audio>` con un Blob URL.
/// No requiere plugins: funciona en cualquier navegador moderno.
///
/// Principios aplicados: SRP (solo reproducción), alta cohesión, bajo acoplamiento.
/// Usa eventos `loadedmetadata`/`durationchange` para garantizar la duración
/// completa antes de usarla en el transporte.
class WebAudioFilePlayer implements AudioFilePlayer {
  web.HTMLAudioElement? _audio;
  String? _objectUrl;
  double _volume = 0.8;

  Completer<double>? _durationCompleter;
  JSFunction? _loadedMetadataHandler;
  JSFunction? _durationChangeHandler;
  JSFunction? _errorHandler;

  @override
  bool get isLoaded => _audio != null;

  @override
  double get positionSeconds => _audio?.currentTime ?? 0;

  @override
  double get durationSeconds {
    final d = _audio?.duration ?? 0;
    if (d.isFinite && d > 0) {
      return d;
    }
    return 0;
  }

  /// Espera a que el navegador resuelva la duración real del archivo.
  /// Devuelve la duración en segundos o 0 si no está disponible.
  @override
  Future<double> waitForDuration({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = _durationCompleter;
    if (completer == null) {
      final d = durationSeconds;
      if (d > 0) return d;
      return 0;
    }
    try {
      final d = await completer.future.timeout(timeout);
      return d.isFinite && d > 0 ? d : durationSeconds;
    } catch (_) {
      return durationSeconds;
    }
  }

  void _attachDurationListeners(web.HTMLAudioElement audio) {
    _detachDurationListeners(audio);
    _durationCompleter = Completer<double>();

    _loadedMetadataHandler = ((web.Event _) {
      final d = audio.duration;
      if (d.isFinite && d > 0) {
        if (!(_durationCompleter?.isCompleted ?? true)) {
          _durationCompleter?.complete(d);
        }
      }
    }).toJS;

    _durationChangeHandler = ((web.Event _) {
      final d = audio.duration;
      if (d.isFinite && d > 0) {
        if (!(_durationCompleter?.isCompleted ?? true)) {
          _durationCompleter?.complete(d);
        }
      }
    }).toJS;

    // Si el navegador no puede decodificar el archivo, se libera la espera de
    // inmediato (duración 0) para que la carga se reporte como fallida.
    _errorHandler = ((web.Event _) {
      if (!(_durationCompleter?.isCompleted ?? true)) {
        _durationCompleter?.complete(0);
      }
    }).toJS;

    audio.addEventListener('loadedmetadata', _loadedMetadataHandler!);
    audio.addEventListener('durationchange', _durationChangeHandler!);
    audio.addEventListener('error', _errorHandler!);
  }

  void _detachDurationListeners(web.HTMLAudioElement audio) {
    final lm = _loadedMetadataHandler;
    if (lm != null) {
      audio.removeEventListener('loadedmetadata', lm);
    }
    final dc = _durationChangeHandler;
    if (dc != null) {
      audio.removeEventListener('durationchange', dc);
    }
    final err = _errorHandler;
    if (err != null) {
      audio.removeEventListener('error', err);
    }
    _loadedMetadataHandler = null;
    _durationChangeHandler = null;
    _errorHandler = null;
    if (!(_durationCompleter?.isCompleted ?? true)) {
      _durationCompleter?.complete(durationSeconds);
    }
    _durationCompleter = null;
  }

  @override
  void load(Uint8List bytes, String mimeType) {
    _release();
    try {
      final safeMime = mimeType.trim().isNotEmpty ? mimeType : 'audio/mpeg';
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: safeMime),
      );
      final url = web.URL.createObjectURL(blob);
      _objectUrl = url;
      final audio = web.HTMLAudioElement()
        ..src = url
        ..preload = 'auto'
        ..volume = _volume;
      audio.style.display = 'none';
      web.document.body?.appendChild(audio);
      _attachDurationListeners(audio);
      audio.load();
      _audio = audio;
    } catch (e) {
      // Si el navegador no puede crear el Blob, se deja sin reproducción.
      debugPrint('WebAudioFilePlayer.load falló: $e');
      _release();
    }
  }

  @override
  void play() {
    final audio = _audio;
    if (audio == null) return;
    try {
      final promise = audio.play();
      unawaited(promise.toDart.catchError((Object e) {
        debugPrint('WebAudioFilePlayer.play error: $e');
        return null;
      }));
    } catch (e) {
      debugPrint('WebAudioFilePlayer.play sincrónico falló: $e');
    }
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
      _detachDurationListeners(audio);
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
      audio.remove();
    }
    _audio = null;
    final url = _objectUrl;
    if (url != null) {
      web.URL.revokeObjectURL(url);
      _objectUrl = null;
    }
  }
}
