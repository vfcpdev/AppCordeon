import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_audio_decoder_interface.dart';

AudioDecoder getAudioDecoder() => WebAudioDecoder();

class WebAudioDecoder implements AudioDecoder {
  @override
  Future<DecodedAudioData?> decode(Uint8List bytes) async {
    web.AudioContext? ctx;
    try {
      // IMPORTANTE: `decodeAudioData` desacopla (detach) el ArrayBuffer que
      // recibe, incluso cuando falla. Si se le pasara el buffer original, los
      // bytes quedarían inservibles para el reproductor (Blob) y para el
      // decodificador PCM de respaldo, que es lo que rompía la carga de MP3.
      // Se decodifica siempre sobre una copia propia.
      final copy = Uint8List.fromList(bytes);
      ctx = web.AudioContext();
      final audioBuffer = await ctx.decodeAudioData(copy.buffer.toJS).toDart;
      return DecodedAudioData(
        samples: _toMono(audioBuffer),
        sampleRate: audioBuffer.sampleRate.toDouble(),
        duration: audioBuffer.duration.toDouble(),
      );
    } catch (e) {
      debugPrint('WebAudioDecoder.decode falló: $e');
      return null;
    } finally {
      // Un AudioContext por análisis agota el límite del navegador (~6).
      try {
        await ctx?.close().toDart;
      } catch (_) {
        // El contexto pudo cerrarse solo o no haberse creado.
      }
    }
  }

  /// Mezcla todos los canales a mono para el análisis espectral.
  Float32List _toMono(web.AudioBuffer buffer) {
    final channels = buffer.numberOfChannels;
    final length = buffer.length;
    if (channels <= 1) return buffer.getChannelData(0).toDart;

    final mixed = Float32List(length);
    for (var channel = 0; channel < channels; channel++) {
      final data = buffer.getChannelData(channel).toDart;
      final limit = data.length < length ? data.length : length;
      for (var i = 0; i < limit; i++) {
        mixed[i] += data[i];
      }
    }
    final scale = 1.0 / channels;
    for (var i = 0; i < length; i++) {
      mixed[i] *= scale;
    }
    return mixed;
  }
}
