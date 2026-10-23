import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'audio_file_loader_interface.dart';

AudioFileLoader getAudioFileLoader() => WebAudioFileLoader();

class WebAudioFileLoader implements AudioFileLoader {
  @override
  Future<PickedAudioData?> pickAudioFile() {
    final completer = Completer<PickedAudioData?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'audio/*,.mp3,.wav,.ogg,.m4a,.flac,.aac';
    input.style.position = 'fixed';
    input.style.top = '-1000px';
    input.style.left = '-1000px';
    input.style.opacity = '0';
    input.style.pointerEvents = 'none';
    web.document.body?.appendChild(input);

    input.onchange = ((web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0);
      if (file == null) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = web.FileReader();
      reader.onloadend = ((web.ProgressEvent e) {
        input.remove();
        final result = reader.result;
        if (result != null) {
          try {
            final jsArrayBuffer = result as JSArrayBuffer;
            final uint8List = jsArrayBuffer.toDart.asUint8List();
            if (!completer.isCompleted) {
              completer.complete(PickedAudioData(name: file.name, bytes: uint8List));
            }
          } catch (err) {
            if (!completer.isCompleted) completer.complete(null);
          }
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      }).toJS;

      reader.onerror = ((web.Event e) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;

      reader.readAsArrayBuffer(file);
    }).toJS;

    input.click();
    return completer.future;
  }
}
