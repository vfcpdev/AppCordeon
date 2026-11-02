import 'audio_file_player_interface.dart';
import 'audio_file_player_stub.dart'
    if (dart.library.js_interop) 'audio_file_player_web.dart'
    if (dart.library.io) 'audio_file_player_io.dart';

export 'audio_file_player_interface.dart';

AudioFilePlayer createAudioFilePlayer() => getAudioFilePlayer();
