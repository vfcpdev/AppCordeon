import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'file_storage_interface.dart';

FileStorageService getFileStorageService() => WebFileStorageService();

class WebFileStorageService implements FileStorageService {
  @override
  Future<void> saveFile({required String fileName, required String content}) async {
    final bytes = utf8.encode(content);
    final blobParts = [bytes.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'application/json'));
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  @override
  Future<String?> pickTextFile({List<String>? allowedExtensions}) {
    final completer = Completer<String?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = (allowedExtensions != null && allowedExtensions.isNotEmpty)
        ? allowedExtensions.map((ext) => '.$ext').join(',')
        : '.json,application/json';
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
            if (result.isA<JSString>()) {
              completer.complete((result as JSString).toDart);
            } else if (result.isA<JSArrayBuffer>()) {
              final uint8List = (result as JSArrayBuffer).toDart.asUint8List();
              completer.complete(utf8.decode(uint8List));
            } else {
              completer.complete(result.toString());
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

      reader.readAsText(file);
    }).toJS;

    input.click();
    return completer.future;
  }
}
