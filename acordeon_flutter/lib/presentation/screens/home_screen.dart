import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';
import '../widgets/accordion_keyboard_listener.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/bass_panel_widget.dart';
import '../widgets/chord_detector_widget.dart';
import '../widgets/diapason_widget.dart';
import '../widgets/free_chord_widget.dart';
import '../widgets/measure_grid_widget.dart';
import '../widgets/multi_beat_chord_dialog.dart';
import '../widgets/track_info_card_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Scaffold(
      backgroundColor: state.backgroundColor,
      body: AccordionKeyboardListener(
        child: SafeArea(
          left: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera superior completa
                  const AppHeaderWidget(),

                  // Cuerpo principal con scroll vertical y horizontal
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(0, 6, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tarjeta de pista de audio y análisis armónico (si hay audio cargado)
                            if (state.audioReport != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: state.isSongBarUndocked
                                    ? _buildSongBarPlaceholder(notifier)
                                    : const TrackInfoCardWidget(),
                              ),

                            // ================= FILA SUPERIOR: ESCENARIO DE DIAPASONES =================
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // DIAPASÓN 1 (Principal)
                                    if (state.showDiapason1) ...[
                                      _buildDiapasonColumn(
                                        accordionNumber: 1,
                                        currentTuning: state.tuning1,
                                        onTuningChanged: (t) => t != null ? notifier.setTuning1(t) : null,
                                        state: state,
                                      ),
                                      const SizedBox(width: 6),

                                      // Compás (185 px) + Constructor de Acorde (150 px)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!state.isCompas1Undocked)
                                            const MeasureGridWidget(accordionNumber: 1, width: 185)
                                          else
                                            _buildDockPlaceholder(1, notifier),
                                          const SizedBox(width: 6),
                                          const SizedBox(
                                            width: 150,
                                            child: FreeChordWidget(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                    ],

                                    // DIAPASÓN 2 (Comparativo / Equivalente)
                                    if (state.showDiapason2) ...[
                                      _buildDiapasonColumn(
                                        accordionNumber: 2,
                                        currentTuning: state.tuning2,
                                        onTuningChanged: (t) => t != null ? notifier.setTuning2(t) : null,
                                        state: state,
                                      ),
                                      const SizedBox(width: 6),

                                      // Cuadrícula de compases de Acordeón 2 con estructura y opciones completas
                                      if (!state.isCompas2Undocked)
                                        const MeasureGridWidget(accordionNumber: 2, width: 185)
                                      else
                                        _buildDockPlaceholder(2, notifier),
                                      const SizedBox(width: 10),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ================= FILA INFERIOR: TEORÍA ARMÓNICA =================
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  // Sección 3: Detector Inteligente de Acordes
                                  SizedBox(
                                    width: 818,
                                    child: ChordDetectorWidget(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Ventanas flotantes desacopladas y movibles de Compás
              if (state.isCompas1Undocked)
                _buildFloatingCompas(
                  context: context,
                  accordionNumber: 1,
                  position: state.compas1Position,
                  onPositionChanged: (pos) => notifier.setCompasPosition(1, pos),
                  onDock: () => notifier.toggleUndockCompas(1),
                ),
              if (state.isCompas2Undocked)
                _buildFloatingCompas(
                  context: context,
                  accordionNumber: 2,
                  position: state.compas2Position,
                  onPositionChanged: (pos) => notifier.setCompasPosition(2, pos),
                  onDock: () => notifier.toggleUndockCompas(2),
                ),
              if (state.isSongBarUndocked && state.audioReport != null)
                _buildFloatingSongBar(
                  context: context,
                  position: state.songBarPosition,
                  onPositionChanged: notifier.setSongBarPosition,
                  onDock: notifier.toggleUndockSongBar,
                ),
              if (state.showMultiBeatModal)
                const MultiBeatChordDialog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiapasonColumn({
    required int accordionNumber,
    required dynamic currentTuning,
    required dynamic onTuningChanged,
    required AccordionSimulatorState state,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cuerpo: Bajos (A1 o A2 según selección) + Diapasón 10-11-10
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accordionNumber == 1 || (!state.isBass2Collapsed && accordionNumber == 2))
                  BassPanelWidget(accordionNumber: accordionNumber),
                DiapasonWidget(
                  accordionNumber: accordionNumber,
                  currentTuning: currentTuning,
                  onTuningChanged: onTuningChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockPlaceholder(int accordionNumber, AccordionSimulatorNotifier notifier) {
    final isPrimary = accordionNumber == 1;
    return Container(
      width: 185,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? const Color(0xFFBAE6FD) : const Color(0xFFA7F3D0),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.arrowUpRightFromSquare,
            size: 18,
            color: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF059669),
          ),
          const SizedBox(height: 6),
          Text(
            isPrimary ? 'Compás flotante' : 'Compás A2 flotante',
            style: const TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Ventana móvil activa',
            style: TextStyle(fontSize: 8.0, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => notifier.toggleUndockCompas(accordionNumber),
            icon: const FaIcon(FontAwesomeIcons.compress, size: 9),
            label: const Text('Volver a acoplar', style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCompas({
    required BuildContext context,
    required int accordionNumber,
    required Offset position,
    required ValueChanged<Offset> onPositionChanged,
    required VoidCallback onDock,
  }) {
    final screen = MediaQuery.sizeOf(context);
    final isPrimary = accordionNumber == 1;
    final clampedX = position.dx.clamp(5.0, (screen.width - 200).clamp(5.0, double.infinity));
    final clampedY = position.dy.clamp(5.0, (screen.height - 350).clamp(5.0, double.infinity));

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 185,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior de arrastre / movimiento
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  onPositionChanged(Offset(position.dx + details.delta.dx, position.dy + details.delta.dy));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF059669),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.upDownLeftRight,
                            size: 9,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPrimary ? 'Compás (Móvil)' : 'Compás A2 (Móvil)',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Tooltip(
                        message: 'Volver a acoplar',
                        child: InkWell(
                          onTap: onDock,
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: FaIcon(
                              FontAwesomeIcons.compress,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              MeasureGridWidget(
                accordionNumber: accordionNumber,
                width: 185,
                isUndocked: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongBarPlaceholder(AccordionSimulatorNotifier notifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.music,
            size: 11,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          const Text(
            'Barra de canción desacoplada (flotante)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF15803D),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: notifier.toggleUndockSongBar,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.compress,
                    size: 9,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Volver a acoplar',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSongBar({
    required BuildContext context,
    required Offset position,
    required ValueChanged<Offset> onPositionChanged,
    required VoidCallback onDock,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    final clampedX = position.dx.clamp(0.0, (screenSize.width - 400).clamp(0.0, double.infinity));
    final clampedY = position.dy.clamp(0.0, (screenSize.height - 100).clamp(0.0, double.infinity));

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrastre superior
              GestureDetector(
                onPanUpdate: (details) {
                  onPositionChanged(Offset(clampedX + details.delta.dx, clampedY + details.delta.dy));
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.upDownLeftRight,
                          size: 9.5,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Barra de Canción (Móvil)',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Tooltip(
                          message: 'Volver a acoplar',
                          child: InkWell(
                            onTap: onDock,
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: FaIcon(
                                FontAwesomeIcons.compress,
                                size: 9.5,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Contenido interactivo (los botones responden de inmediato)
              const Padding(
                padding: EdgeInsets.all(4.0),
                child: TrackInfoCardWidget(isFloating: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
