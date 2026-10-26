import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/audio_analysis_models.dart';
import '../controllers/accordion_controller.dart';
import 'edit_audio_key_bpm_dialog.dart';

/// Barra de la canción analizada.
///
/// Contiene:
/// 1. Título de la pista con animación de Marquesina continua.
/// 2. Botones de reproducción horizontales y reducidos (Atrás, Play/Pausa, Adelante, Stop, tiempo).
/// 3. Bloque contiguo de opciones: Tono, BPM y Cargar Acordes juntos.
/// 4. Desacople eficaz hacia ventana flotante y re-acople inmediato.
class TrackInfoCardWidget extends ConsumerWidget {
  final bool isFloating;

  const TrackInfoCardWidget({
    super.key,
    this.isFloating = false,
  });

  static String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '00:00';
    final totalSec = seconds.toInt();
    final mins = (totalSec ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final AudioAnalysisReport? report = state.audioReport;

    if (report == null) return const SizedBox.shrink();

    final isPlaying = state.isPlayingAudio;
    final totalDur = state.totalAudioDuration > 0
        ? state.totalAudioDuration
        : report.duration;

    return Container(
      margin: isFloating ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFloating ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1),
          width: isFloating ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFloating ? 0.16 : 0.05),
            blurRadius: isFloating ? 14 : 6,
            offset: Offset(0, isFloating ? 6 : 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Ícono musical indicador ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(5.5),
            decoration: BoxDecoration(
              color: isPlaying ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isPlaying ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: FaIcon(
              isPlaying ? FontAwesomeIcons.music : FontAwesomeIcons.compactDisc,
              size: 11,
              color: isPlaying ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),

          // ─── Título de la pista con Marquesina ──────────────────────────
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
              child: SizedBox(
                height: 20,
                child: _MarqueeText(
                  text: state.loadedAudioFileName ?? 'Canción Analizada',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ─── Botones de reproducción horizontales y reducidos ───────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón Atrás (compás anterior)
                _PlaybackMiniBtn(
                  icon: FontAwesomeIcons.backwardStep,
                  tooltip: 'Compás Anterior',
                  onTap: notifier.previousBar,
                ),
                const SizedBox(width: 4),

                // Botón Play / Pausa (reducido y destacado)
                _PlaybackMiniBtn(
                  icon: isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                  tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                  isPrimary: true,
                  isPlaying: isPlaying,
                  onTap: notifier.togglePlayAudio,
                ),
                const SizedBox(width: 4),

                // Botón Adelante (siguiente compás)
                _PlaybackMiniBtn(
                  icon: FontAwesomeIcons.forwardStep,
                  tooltip: 'Siguiente Compás',
                  onTap: notifier.nextBar,
                ),
                const SizedBox(width: 4),

                // Botón Detener
                _PlaybackMiniBtn(
                  icon: FontAwesomeIcons.stop,
                  tooltip: 'Detener',
                  onTap: notifier.stopAudio,
                ),
                const SizedBox(width: 6),

                // Contador de Tiempo actual / total
                Text(
                  '${_formatTime(state.currentAudioTime)} / ${_formatTime(totalDur)}',
                  style: const TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ─── Opciones juntas: Tono, BPM y Cargar Acordes ────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Tono detectado
                _GroupedOptionBadge(
                  icon: FontAwesomeIcons.key,
                  label: 'Tono: ${report.keyResult.keyNameLat}',
                  tooltip: 'Tono detectado (clic para editar o corregir)',
                  background: const Color(0xFFEEF2FF),
                  border: const Color(0xFFC7D2FE),
                  foreground: const Color(0xFF4338CA),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => EditAudioKeyBpmDialog(report: report),
                  ),
                ),
                const SizedBox(width: 4),

                // 2. BPM
                _GroupedOptionBadge(
                  icon: FontAwesomeIcons.drum,
                  label: '${report.bpm.toStringAsFixed(0)} BPM',
                  tooltip: 'Tempo de la pista (clic para editar BPM)',
                  background: const Color(0xFFFAF5FF),
                  border: const Color(0xFFE9D5FF),
                  foreground: const Color(0xFF7E22CE),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => EditAudioKeyBpmDialog(report: report),
                  ),
                ),
                const SizedBox(width: 4),

                // 3. Cargar Acordes a la cuadrícula de compases
                _GroupedOptionBadge(
                  icon: FontAwesomeIcons.tableCells,
                  label: 'Cargar Acordes',
                  tooltip: 'Cargar acordes analizados a los compases',
                  background: const Color(0xFFECFDF5),
                  border: const Color(0xFFA7F3D0),
                  foreground: const Color(0xFF059669),
                  onTap: () {
                    notifier.applyChordsToMeasures(report.chords);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Acordes detectados cargados en la cuadrícula de compases.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ─── Botón de Desacople / Acople Eficaz ──────────────────────────
          Tooltip(
            message: state.isSongBarUndocked
                ? 'Volver a acoplar la barra de la canción'
                : 'Desacoplar barra de la canción (mover libremente)',
            child: InkWell(
              onTap: notifier.toggleUndockSongBar,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: state.isSongBarUndocked
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: state.isSongBarUndocked
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: FaIcon(
                  state.isSongBarUndocked
                      ? FontAwesomeIcons.compress
                      : FontAwesomeIcons.arrowUpRightFromSquare,
                  size: 9.5,
                  color: state.isSongBarUndocked
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // ─── Botón de Cerrar Pista ──────────────────────────────────────
          Tooltip(
            message: 'Cerrar pista',
            child: InkWell(
              onTap: notifier.clearAudioReport,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 9.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de Marquesina suave para texto en desplazamiento continuo o rebote.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _scrollingForward = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;

      final current = _scrollController.offset;
      if (_scrollingForward) {
        final next = current + 1.2;
        if (next >= max) {
          _scrollingForward = false;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) _startAnimation();
          });
        } else {
          _scrollController.jumpTo(next);
        }
      } else {
        final next = current - 2.2;
        if (next <= 0) {
          _scrollingForward = true;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) _startAnimation();
          });
        } else {
          _scrollController.jumpTo(next);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _scrollingForward = true;
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}

/// Botón pequeño y elegante de transporte para la barra horizontal.
class _PlaybackMiniBtn extends StatelessWidget {
  final dynamic icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isPlaying;

  const _PlaybackMiniBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isPrimary = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? (isPlaying ? const Color(0xFFEF4444) : const Color(0xFF0284C7))
        : Colors.white;
    final iconColor = isPrimary ? Colors.white : const Color(0xFF475569);
    final borderColor = isPrimary ? bgColor : const Color(0xFFCBD5E1);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 8.5,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge clickeable agrupado para opciones conjuntas (Tono, BPM, Cargar Acordes).
class _GroupedOptionBadge extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String tooltip;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback onTap;

  const _GroupedOptionBadge({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.background,
    required this.border,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(icon, size: 8.5, color: foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
