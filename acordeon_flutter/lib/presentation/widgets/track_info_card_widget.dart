import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/audio_analysis_models.dart';
import '../controllers/accordion_controller.dart';
import 'edit_audio_key_bpm_dialog.dart';

/// Barra de información de la pista cargada.
///
/// Muestra únicamente el nombre del archivo, el tono detectado y el BPM.
/// Puede desacoplarse de la página (arrastrando el asa) y moverse libremente
/// como una ventana flotante; el botón de pin la vuelve a acoplar.
class TrackInfoCardWidget extends ConsumerStatefulWidget {
  const TrackInfoCardWidget({super.key});

  @override
  ConsumerState<TrackInfoCardWidget> createState() =>
      _TrackInfoCardWidgetState();
}

class _TrackInfoCardWidgetState extends ConsumerState<TrackInfoCardWidget> {
  static const double _floatingWidth = 360;

  OverlayEntry? _overlayEntry;
  Offset? _floatingPosition;

  bool get _isFloating => _floatingPosition != null;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accordionSimulatorProvider);
    final report = state.audioReport;
    if (report == null) return const SizedBox.shrink();

    // Mientras flota, el hueco original desaparece; la ventana vive en el Overlay.
    if (_isFloating) return const SizedBox.shrink();

    return _buildCard(
      context,
      state,
      report,
      floating: false,
      showDragHandle: true,
      showClose: true,
    );
  }

  // ─── Ventana flotante ─────────────────────────────────────────────────────

  void _detach(Offset globalTopLeft) {
    final screen = MediaQuery.sizeOf(context);
    final maxX = (screen.width - _floatingWidth).clamp(0.0, double.infinity);
    final maxY = (screen.height - 70).clamp(0.0, double.infinity);

    _floatingPosition = Offset(
      globalTopLeft.dx.clamp(0.0, maxX),
      globalTopLeft.dy.clamp(0.0, maxY),
    );
    _insertOverlay();
    setState(() {});
  }

  void _insertOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(accordionSimulatorProvider);
          final report = state.audioReport;
          final position = _floatingPosition;

          if (report == null || position == null) {
            if (report == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _isFloating) _dock();
              });
            }
            return const SizedBox.shrink();
          }

          return Positioned(
            left: position.dx,
            top: position.dy,
            child: GestureDetector(
              onPanUpdate: (details) => _moveFloating(details.delta),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: _floatingWidth,
                  child: _buildCard(
                    context,
                    state,
                    report,
                    floating: true,
                    showDock: true,
                    showClose: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _moveFloating(Offset delta) {
    final position = _floatingPosition;
    if (position == null) return;

    final screen = MediaQuery.sizeOf(context);
    final maxX = (screen.width - _floatingWidth).clamp(0.0, double.infinity);
    final maxY = (screen.height - 70).clamp(0.0, double.infinity);

    _floatingPosition = Offset(
      (position.dx + delta.dx).clamp(0.0, maxX),
      (position.dy + delta.dy).clamp(0.0, maxY),
    );
    _overlayEntry?.markNeedsBuild();
  }

  void _dock() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!mounted) return;
    setState(() => _floatingPosition = null);
  }

  // ─── Contenido ────────────────────────────────────────────────────────────

  Widget _buildCard(
    BuildContext context,
    AccordionSimulatorState state,
    AudioAnalysisReport report, {
    required bool floating,
    bool showDragHandle = false,
    bool showDock = false,
    bool showClose = false,
  }) {
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Container(
      margin: floating ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: floating ? 0.18 : 0.04),
            blurRadius: floating ? 18 : 8,
            offset: Offset(0, floating ? 8 : 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre del archivo
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const FaIcon(
              FontAwesomeIcons.music,
              size: 12,
              color: Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.loadedAudioFileName ?? 'Canción Analizada',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 10),

          // Tono detectado (click para corregir)
          _InfoBadge(
            icon: FontAwesomeIcons.key,
            label: 'Tono: ${report.keyResult.keyNameLat}',
            background: const Color(0xFFEEF2FF),
            border: const Color(0xFFC7D2FE),
            foreground: const Color(0xFF4338CA),
            onTap: () => showDialog(
              context: context,
              builder: (_) => EditAudioKeyBpmDialog(report: report),
            ),
          ),
          const SizedBox(width: 6),

          // BPM (click para corregir)
          _InfoBadge(
            icon: FontAwesomeIcons.drum,
            label: '${report.bpm.toStringAsFixed(0)} BPM',
            background: const Color(0xFFFAF5FF),
            border: const Color(0xFFE9D5FF),
            foreground: const Color(0xFF7E22CE),
            onTap: () => showDialog(
              context: context,
              builder: (_) => EditAudioKeyBpmDialog(report: report),
            ),
          ),

          if (showDock) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Volver a acoplar la barra',
              child: IconButton(
                onPressed: _dock,
                icon: const FaIcon(
                  FontAwesomeIcons.thumbtack,
                  size: 11,
                  color: Color(0xFF0284C7),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
          ],

          if (showClose) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: 'Cerrar pista',
              child: IconButton(
                onPressed: notifier.clearAudioReport,
                icon: const Icon(
                  Icons.close,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
          ],

          if (showDragHandle) ...[
            const SizedBox(width: 2),
            Draggable<int>(
              data: 0,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: _floatingWidth,
                  child: _buildCard(
                    context,
                    state,
                    report,
                    floating: true,
                  ),
                ),
              ),
              childWhenDragging: const SizedBox(width: 22, height: 22),
              onDragEnd: (details) => _detach(details.offset),
              child: Tooltip(
                message: 'Arrastrar para desacoplar y mover',
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: FaIcon(
                      FontAwesomeIcons.gripVertical,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback onTap;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 9, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.edit, size: 9, color: foreground.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
