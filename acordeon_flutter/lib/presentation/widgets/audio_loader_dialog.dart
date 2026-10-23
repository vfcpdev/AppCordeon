import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';
import 'audio_load_feedback.dart';
import 'audio_analysis_dialog.dart';

class AudioLoaderDialog extends ConsumerWidget {
  const AudioLoaderDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del diálogo
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: FaIcon(FontAwesomeIcons.compactDisc, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cargar Pista de Audio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Análisis armónico, tonalidad, BPM y acordes con Rust DSP',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (state.isAnalyzingAudio) ...[
                // Estado de análisis activo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    children: const [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Analizando espectro de audio con Rust DSP...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Extrayendo cromagrama por bandas (45-2400 Hz) y correlación de Krumhansl-Kessler',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Opción 1: Seleccionar archivo del dispositivo
                InkWell(
                  onTap: () {
                    // Síncrono dentro del gesto: el selector se abre antes de cerrar el diálogo.
                    final navContext = Navigator.of(context).context;
                    notifier.pickAndAnalyzeAudio().then((r) {
                      if (navContext.mounted) presentAudioLoadResult(navContext, r);
                    });
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: FaIcon(FontAwesomeIcons.folderOpen, color: Color(0xFF0284C7), size: 22),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Explorar archivo local',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Soporta MP3, WAV, OGG, M4A, FLAC o AAC desde tu computadora.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Opción 2: Cargar demo instantáneo de Vallenato
                InkWell(
                  onTap: () async {
                    final navContext = Navigator.of(context).context;
                    Navigator.of(context).pop();
                    final r = await notifier.loadDemoAudioTrack();
                    if (navContext.mounted) presentAudioLoadResult(navContext, r);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFEFF6FF),
                          const Color(0xFFEEF2FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: FaIcon(FontAwesomeIcons.wandMagicSparkles, color: Color(0xFF2563EB), size: 22),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Text(
                                    'Pista Demo Vallenato',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  ContainerBadge(text: '1 Clic', color: Color(0xFF2563EB)),
                                ],
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Paseo Vallenato tradicional en Do Mayor (Cinco Letras: Do-Fa-Sol).',
                                style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),

                // Si ya hay un reporte cargado, mostrar tarjeta de estado actual
                if (state.audioReport != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.circleCheck, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.loadedAudioFileName ?? 'Pista Cargada',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Tono: ${state.audioReport!.keyResult.keyNameLat} | ${state.audioReport!.bpm.toStringAsFixed(0)} BPM | ${state.audioReport!.keyResult.recommendedTuning}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (_) => AudioAnalysisDialog(
                                report: state.audioReport!,
                                fileName: state.loadedAudioFileName ?? 'Audio',
                              ),
                            );
                          },
                          child: const Text('Ver Reporte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ContainerBadge extends StatelessWidget {
  final String text;
  final Color color;

  const ContainerBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
