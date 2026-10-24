import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/accordion_controller.dart';
import '../widgets/accordion_keyboard_listener.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/bass_panel_widget.dart';
import '../widgets/chord_detector_widget.dart';
import '../widgets/diapason_card_header.dart';
import '../widgets/diapason_widget.dart';
import '../widgets/free_chord_widget.dart';
import '../widgets/measure_grid_widget.dart';
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
          child: Column(
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
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: TrackInfoCardWidget(),
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
                                    bellowsMode: state.bellows1,
                                    onBellowsChanged: notifier.setBellows1,
                                    isBassCollapsed: state.isBass1Collapsed,
                                    onToggleBass: notifier.toggleBass1,
                                    isMirror: state.mirror1,
                                    onToggleMirror: notifier.toggleMirror1,
                                    volume: state.volume1,
                                    onVolumeChanged: notifier.setVolume1,
                                    isMuted: state.isMuted1,
                                    onToggleMute: notifier.toggleMute1,
                                    syncVolume: state.syncVolume,
                                    onToggleSyncVolume: notifier.toggleSyncVolume,
                                  ),
                                  const SizedBox(width: 8),

                                  // Cuadrícula de compases y transporte vertical
                                  const MeasureGridWidget(),
                                  const SizedBox(width: 14),
                                ],

                                // DIAPASÓN 2 (Comparativo / Equivalente)
                                if (state.showDiapason2) ...[
                                  _buildDiapasonColumn(
                                    accordionNumber: 2,
                                    currentTuning: state.tuning2,
                                    onTuningChanged: (t) => t != null ? notifier.setTuning2(t) : null,
                                    bellowsMode: state.bellows2,
                                    onBellowsChanged: notifier.setBellows2,
                                    isBassCollapsed: state.isBass2Collapsed,
                                    onToggleBass: notifier.toggleBass2,
                                    isMirror: state.mirror2,
                                    onToggleMirror: notifier.toggleMirror2,
                                    volume: state.volume2,
                                    onVolumeChanged: notifier.setVolume2,
                                    isMuted: state.isMuted2,
                                    onToggleMute: notifier.toggleMute2,
                                  ),
                                  const SizedBox(width: 8),

                                  // Cuadrícula de compases de Acordeón 2
                                  const MeasureGridWidget(accordionNumber: 2),
                                  const SizedBox(width: 14),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ================= FILA INFERIOR: TEORÍA ARMÓNICA =================
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              // Sección 5: Acorde Libre y Escalas
                              SizedBox(
                                width: 540,
                                child: FreeChordWidget(),
                              ),

                              SizedBox(width: 14),

                              // Sección 3: Detector Inteligente de Acordes
                              SizedBox(
                                width: 520,
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
        ),
      ),
    );
  }

  Widget _buildDiapasonColumn({
    required int accordionNumber,
    required dynamic currentTuning,
    required dynamic onTuningChanged,
    required dynamic bellowsMode,
    required dynamic onBellowsChanged,
    required bool isBassCollapsed,
    required VoidCallback onToggleBass,
    required bool isMirror,
    required VoidCallback onToggleMirror,
    required double volume,
    required ValueChanged<double> onVolumeChanged,
    required bool isMuted,
    required VoidCallback onToggleMute,
    bool syncVolume = false,
    VoidCallback? onToggleSyncVolume,
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
          // Cabecera del diapasón
          DiapasonCardHeader(
            accordionNumber: accordionNumber,
            currentTuning: currentTuning,
            onTuningChanged: onTuningChanged,
            bellowsMode: bellowsMode,
            onBellowsChanged: onBellowsChanged,
            isBassCollapsed: isBassCollapsed,
            onToggleBass: onToggleBass,
            isMirror: isMirror,
            onToggleMirror: onToggleMirror,
            volume: volume,
            onVolumeChanged: onVolumeChanged,
            isMuted: isMuted,
            onToggleMute: onToggleMute,
            syncVolume: syncVolume,
            onToggleSyncVolume: onToggleSyncVolume,
          ),

          // Cuerpo: Bajos + Diapasón 10-11-10
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BassPanelWidget(accordionNumber: accordionNumber),
                DiapasonWidget(
                  accordionNumber: accordionNumber,
                  isBassCollapsed: isBassCollapsed,
                  onToggleBass: onToggleBass,
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
}
