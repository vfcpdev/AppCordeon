import 'dart:typed_data';

class DecodedAudioData {
  final Float32List samples;
  final double sampleRate;
  final double duration;

  DecodedAudioData({
    required this.samples,
    required this.sampleRate,
    required this.duration,
  });
}

abstract class AudioDecoder {
  Future<DecodedAudioData?> decode(Uint8List bytes);
}
