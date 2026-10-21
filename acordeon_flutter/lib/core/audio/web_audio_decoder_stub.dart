import 'dart:typed_data';
import 'web_audio_decoder_interface.dart';

AudioDecoder getAudioDecoder() => AudioDecoderStub();

class AudioDecoderStub implements AudioDecoder {
  @override
  Future<DecodedAudioData?> decode(Uint8List bytes) async => null;
}
