import 'audio_file_player_interface.dart';
import 'audio_file_player_stub.dart'
    if (dart.library.js_interop) 'audio_file_player_web.dart';

export 'audio_file_player_interface.dart';

AudioFilePlayer createAudioFilePlayer() => getAudioFilePlayer();
