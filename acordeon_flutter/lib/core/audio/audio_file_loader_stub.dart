import 'dart:typed_data';

class PickedAudioData {
  final String name;
  final Uint8List bytes;

  PickedAudioData({required this.name, required this.bytes});
}

abstract class AudioFileLoader {
  factory AudioFileLoader() => getAudioFileLoader();
  Future<PickedAudioData?> pickAudioFile();
}

AudioFileLoader getAudioFileLoader() => throw UnsupportedError('Stub');
