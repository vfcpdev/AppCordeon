import 'audio_file_loader_stub.dart'
    if (dart.library.js_interop) 'audio_file_loader_web.dart';

export 'audio_file_loader_stub.dart';

AudioFileLoader createAudioFileLoader() => getAudioFileLoader();
