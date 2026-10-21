import 'web_audio_decoder_interface.dart';
import 'web_audio_decoder_stub.dart'
    if (dart.library.js_interop) 'web_audio_decoder_web.dart';

export 'web_audio_decoder_interface.dart';

AudioDecoder createAudioDecoder() => getAudioDecoder();
