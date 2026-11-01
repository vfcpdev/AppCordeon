import 'package:flutter/material.dart';
import '../controllers/accordion_controller.dart';
import 'audio_analysis_dialog.dart';

/// Presenta en la UI el resultado de una carga de audio.
/// Mantiene `BuildContext`, `SnackBar` y diálogos fuera del controlador.
void presentAudioLoadResult(BuildContext context, AudioLoadResult result) {
  if (!context.mounted) return;
  switch (result) {
    case AudioLoadSuccess(:final fileName):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio cargado: $fileName. Analízalo cuando quieras.'),
        ),
      );
    case AudioAnalysisSuccess(:final report, :final fileName):
      showDialog(
        context: context,
        builder: (_) => AudioAnalysisDialog(report: report, fileName: fileName),
      );
    case AudioLoadFailure(:final message):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    case AudioLoadCancelled():
      break;
  }
}
