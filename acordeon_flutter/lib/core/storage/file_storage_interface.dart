import 'dart:async';

abstract class FileStorageService {
  /// Guarda o descarga un archivo de texto en el dispositivo o navegador.
  Future<void> saveFile({required String fileName, required String content});

  /// Abre un selector de archivos y retorna el contenido de texto seleccionado.
  Future<String?> pickTextFile({List<String>? allowedExtensions});
}
