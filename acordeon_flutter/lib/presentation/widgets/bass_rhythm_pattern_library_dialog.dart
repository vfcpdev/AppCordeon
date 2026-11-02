import 'package:flutter/material.dart';

import 'bass_rhythm_pattern_library_widget.dart';

/// Diálogo con la biblioteca de patrones rítmicos de bajos.
///
/// Se abre desde el panel de bajos para reproducir, seleccionar o eliminar
/// patrones guardados sin ocupar espacio permanente en el layout.
class BassRhythmPatternLibraryDialog extends StatelessWidget {
  final int accordionNumber;

  const BassRhythmPatternLibraryDialog({
    super.key,
    this.accordionNumber = 1,
  });

  /// Muestra el diálogo como modal.
  static Future<void> show(
    BuildContext context, {
    int accordionNumber = 1,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BassRhythmPatternLibraryDialog(
        accordionNumber: accordionNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('bass_rhythm_library_dialog'),
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: const Row(
        children: [
          Icon(Icons.library_music_outlined, size: 18),
          SizedBox(width: 6),
          Text('Patrones de bajos', style: TextStyle(fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 380,
        child: SingleChildScrollView(
          child: BassRhythmPatternLibraryWidget(
            accordionNumber: accordionNumber,
            width: 380,
            maxHeight: 360,
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bass_rhythm_library_close_btn'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
