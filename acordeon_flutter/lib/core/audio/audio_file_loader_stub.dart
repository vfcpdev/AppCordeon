import 'audio_file_loader_interface.dart';

AudioFileLoader getAudioFileLoader() => AudioFileLoaderStub();

class AudioFileLoaderStub implements AudioFileLoader {
  @override
  Future<PickedAudioData?> pickAudioFile() async => null;
}
