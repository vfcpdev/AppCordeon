import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'audio_file_player_interface.dart';
import 'audio_file_player_stub.dart';

typedef _MciSendStringNative = Uint32 Function(
  Pointer<Utf16> lpstrCommand,
  Pointer<Utf16> lpstrReturnString,
  Uint32 uReturnLength,
  IntPtr hwndCallback,
);
typedef _MciSendStringDart = int Function(
  Pointer<Utf16> lpstrCommand,
  Pointer<Utf16> lpstrReturnString,
  int uReturnLength,
  int hwndCallback,
);

AudioFilePlayer getAudioFilePlayer() {
  if (Platform.isWindows) {
    try {
      return WindowsMciAudioPlayer();
    } catch (e) {
      debugPrint('[AudioFilePlayer] Fallback a stub en Windows: $e');
      return AudioFilePlayerStub();
    }
  }
  return AudioFilePlayerStub();
}

/// Reproductor nativo de archivos de audio para Windows utilizando MCI (Media Control Interface).
///
/// Principios aplicados:
/// - **SRP**: se enfoca exclusivamente en la reproducción del archivo de audio nativo.
/// - **Alta cohesión y bajo acoplamiento**: implementa la interfaz [AudioFilePlayer]
///   sin dependencias de Riverpod ni de UI.
/// - **Tripla de Hoare**:
///   - {P}: bytes válidos en [load].
///   - {Q}: archivo cargado, duración disponible inmediatamente y reproducción con hardware.
///   - {I}: recursos temporales y alias MCI siempre liberados al cerrar.
class WindowsMciAudioPlayer implements AudioFilePlayer {
  static const String _alias = 'appcordeon_track';
  static DynamicLibrary? _winmm;
  static _MciSendStringDart? _mciSendString;
  static bool _initAttempted = false;

  File? _tempFile;
  bool _isLoaded = false;
  bool _isPlaying = false;
  double _durationSeconds = 0.0;
  double _volume = 0.8;

  WindowsMciAudioPlayer() {
    _ensureInitialized();
  }

  static void _ensureInitialized() {
    if (_initAttempted) return;
    _initAttempted = true;
    try {
      _winmm = DynamicLibrary.open('winmm.dll');
      _mciSendString = _winmm!
          .lookup<NativeFunction<_MciSendStringNative>>('mciSendStringW')
          .asFunction<_MciSendStringDart>();
    } catch (e) {
      debugPrint('[WindowsMciAudioPlayer] Error al cargar winmm.dll: $e');
      _mciSendString = null;
    }
  }

  (int code, String text) _executeMci(String command) {
    final fn = _mciSendString;
    if (fn == null) return (-1, '');
    final cmdPtr = command.toNativeUtf16();
    final returnBuf = calloc<Uint16>(256).cast<Utf16>();
    try {
      final code = fn(cmdPtr, returnBuf, 256, 0);
      final text = returnBuf.toDartString();
      return (code, text);
    } catch (e) {
      debugPrint('[WindowsMciAudioPlayer] Excepción en comando "$command": $e');
      return (-1, '');
    } finally {
      calloc.free(cmdPtr);
      calloc.free(returnBuf);
    }
  }

  @override
  bool get isLoaded => _isLoaded;

  @override
  double get durationSeconds => _durationSeconds;

  @override
  double get positionSeconds {
    if (!_isLoaded) return 0.0;
    final res = _executeMci('status $_alias position');
    if (res.$1 == 0) {
      final ms = int.tryParse(res.$2.trim()) ?? 0;
      return (ms / 1000.0).clamp(0.0, _durationSeconds);
    }
    return 0.0;
  }

  @override
  Future<double> waitForDuration({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return _durationSeconds;
  }

  @override
  void load(Uint8List bytes, String mimeType) {
    _release();
    if (bytes.isEmpty) return;

    try {
      final ext = _extensionForMime(mimeType);
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}\\appcordeon_track_${DateTime.now().millisecondsSinceEpoch}$ext';
      final file = File(tempPath);
      file.writeAsBytesSync(bytes, flush: true);
      _tempFile = file;

      // Cerrar cualquier sesión previa de MCI
      _executeMci('close $_alias');

      // Abrir archivo con alias
      var openRes = _executeMci('open "${file.path}" alias $_alias');
      if (openRes.$1 != 0) {
        // Reintento con tipo explícito mpegvideo
        openRes = _executeMci('open "${file.path}" type mpegvideo alias $_alias');
      }

      if (openRes.$1 == 0) {
        _executeMci('set $_alias time format milliseconds');
        final lenRes = _executeMci('status $_alias length');
        final ms = int.tryParse(lenRes.$2.trim()) ?? 0;
        _durationSeconds = ms > 0 ? (ms / 1000.0) : 0.0;
        _isLoaded = _durationSeconds > 0;
        _isPlaying = false;
        setVolume(_volume);
      } else {
        debugPrint('[WindowsMciAudioPlayer] Error al abrir audio MCI: código ${openRes.$1}');
        _release();
      }
    } catch (e) {
      debugPrint('[WindowsMciAudioPlayer] Error en load: $e');
      _release();
    }
  }

  @override
  void play() {
    if (!_isLoaded) return;
    final res = _executeMci('play $_alias');
    if (res.$1 == 0) {
      _isPlaying = true;
    }
  }

  @override
  void pause() {
    if (!_isLoaded) return;
    final res = _executeMci('pause $_alias');
    if (res.$1 == 0) {
      _isPlaying = false;
    }
  }

  @override
  void stop() {
    if (!_isLoaded) return;
    _executeMci('stop $_alias');
    _executeMci('seek $_alias to 0');
    _isPlaying = false;
  }

  @override
  void seek(double seconds) {
    if (!_isLoaded) return;
    final clampedSec = seconds.clamp(0.0, _durationSeconds);
    final ms = (clampedSec * 1000).round();
    if (_isPlaying) {
      _executeMci('play $_alias from $ms');
    } else {
      _executeMci('seek $_alias to $ms');
    }
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (!_isLoaded) return;
    final mciVol = (_volume * 1000).round();
    _executeMci('setaudio $_alias volume to $mciVol');
  }

  void _release() {
    if (_isLoaded) {
      _executeMci('stop $_alias');
      _executeMci('close $_alias');
    }
    _isLoaded = false;
    _isPlaying = false;
    _durationSeconds = 0.0;

    final file = _tempFile;
    if (file != null) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
      _tempFile = null;
    }
  }

  static String _extensionForMime(String mimeType) {
    final lower = mimeType.toLowerCase();
    if (lower.contains('wav')) return '.wav';
    if (lower.contains('ogg')) return '.ogg';
    if (lower.contains('mp4') || lower.contains('m4a')) return '.m4a';
    if (lower.contains('flac')) return '.flac';
    if (lower.contains('aac')) return '.aac';
    return '.mp3';
  }
}
