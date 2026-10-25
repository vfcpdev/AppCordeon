import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'file_storage_interface.dart';

FileStorageService getFileStorageService() => FileStorageStub();

class FileStorageStub implements FileStorageService {
  @override
  Future<void> saveFile({required String fileName, required String content}) async {
    // En escritorio/móvil se puede usar FilePicker para guardar
    try {
      final bytes = utf8.encode(content);
      await FilePicker.saveFile(
        dialogTitle: 'Guardar compases en JSON',
        fileName: fileName,
        bytes: bytes,
      );
    } catch (_) {
      // Ignorar si el usuario cancela o no está soportado en la plataforma actual
    }
  }

  @override
  Future<String?> pickTextFile({List<String>? allowedExtensions}) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? ['json'],
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
