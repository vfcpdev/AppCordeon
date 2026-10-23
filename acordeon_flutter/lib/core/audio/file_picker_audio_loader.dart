import 'package:file_picker/file_picker.dart';
import 'audio_file_loader_interface.dart';

/// Cargador basado en `file_picker` (escritorio / móvil).
class FilePickerAudioLoader implements AudioFileLoader {
  const FilePickerAudioLoader();

  @override
  Future<PickedAudioData?> pickAudioFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedAudioData(name: file.name, bytes: bytes);
  }
}

/// Intenta cada cargador en orden hasta obtener un archivo (Chain of Responsibility).
/// En Web el primero es el `<input type=file>` nativo, que debe invocarse
/// sin `await` previo para conservar el gesto del usuario.
class FallbackAudioLoader implements AudioFileLoader {
  final List<AudioFileLoader> loaders;
  const FallbackAudioLoader(this.loaders);

  @override
  Future<PickedAudioData?> pickAudioFile() async {
    for (final loader in loaders) {
      final picked = await loader.pickAudioFile();
      if (picked != null) return picked;
    }
    return null;
  }
}
