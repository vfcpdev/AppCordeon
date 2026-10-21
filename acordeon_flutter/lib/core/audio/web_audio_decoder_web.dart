import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'web_audio_decoder_interface.dart';

AudioDecoder getAudioDecoder() => WebAudioDecoder();

class WebAudioDecoder implements AudioDecoder {
  @override
  Future<DecodedAudioData?> decode(Uint8List bytes) async {
    try {
      final ctx = web.AudioContext();
      final jsArrayBuffer = bytes.buffer.toJS;
      final audioBuffer = await ctx.decodeAudioData(jsArrayBuffer).toDart;
      final channel0 = audioBuffer.getChannelData(0);
      final samples = channel0.toDart;
      return DecodedAudioData(
        samples: samples,
        sampleRate: audioBuffer.sampleRate.toDouble(),
        duration: audioBuffer.duration.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
