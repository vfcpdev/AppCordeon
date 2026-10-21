import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';
import 'audio_analysis_dialog.dart';

class TrackInfoCardWidget extends ConsumerWidget {
  const TrackInfoCardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    final report = state.audioReport;
    if (report == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Sección izquierda: Título del archivo, Tono detectado, BPM y Motor
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de música
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(FontAwesomeIcons.music, size: 14, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),

              // Nombre de la canción
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  state.loadedAudioFileName ?? 'Canción Analizada',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 10),

              // Badge de Tonalidad detectada
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.key, size: 10, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 4),
                    Text(
                      'Tono: ${report.keyResult.keyNameLat}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Badge de BPM
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.drum, size: 10, color: Color(0xFF9333EA)),
                    const SizedBox(width: 4),
                    Text(
                      '${report.bpm.toStringAsFixed(0)} BPM',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Badge de Motor Rust
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    FaIcon(FontAwesomeIcons.microchip, size: 10, color: Color(0xFFEA580C)),
                    SizedBox(width: 4),
                    Text(
                      'Rust DSP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sección derecha: Botones de acción rápida
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Aplicar Afinación Sugerida
              ElevatedButton.icon(
                onPressed: () {
                  notifier.applyDetectedTuning(report.keyResult);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Afinación ${report.keyResult.recommendedTuning} aplicada a Acordeón 1'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.flash_on, size: 13),
                label: Text(
                  'Afinación: ${report.keyResult.recommendedTuning}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Cargar Acordes al Compás
              ElevatedButton.icon(
                onPressed: () {
                  notifier.applyChordsToMeasures(report.chords);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Acordes detectados cargados a la cuadrícula de compases'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const FaIcon(FontAwesomeIcons.tableColumns, size: 11),
                label: const Text(
                  'Cargar al Compás',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Ver Análisis Completo
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AudioAnalysisDialog(
                      report: report,
                      fileName: state.loadedAudioFileName ?? 'Audio',
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4338CA),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const FaIcon(FontAwesomeIcons.chartSimple, size: 11),
                label: const Text(
                  'Detalle Espectral',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Descartar
              IconButton(
                onPressed: notifier.clearAudioReport,
                icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                tooltip: 'Cerrar pista',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
