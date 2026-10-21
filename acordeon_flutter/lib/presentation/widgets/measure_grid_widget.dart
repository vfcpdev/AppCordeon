import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';

class MeasureGridWidget extends ConsumerWidget {
  const MeasureGridWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de Acciones de la Cuadrícula
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconBtn(
                    icon: FontAwesomeIcons.listOl,
                    isActive: state.sequenceMode,
                    tooltip: 'Modo Secuencia',
                    onTap: notifier.toggleSequenceMode,
                  ),
                  _buildIconBtn(
                    icon: FontAwesomeIcons.checkDouble,
                    tooltip: 'Seleccionar Todos',
                    onTap: () {},
                  ),
                  _buildIconBtn(
                    icon: FontAwesomeIcons.keyboard,
                    tooltip: 'Digitar Progresión Manual',
                    onTap: () {},
                  ),
                  _buildIconBtn(
                    icon: FontAwesomeIcons.plus,
                    tooltip: 'Agregar Compás',
                    onTap: notifier.addMeasure,
                  ),
                  _buildIconBtn(
                    icon: FontAwesomeIcons.trashCan,
                    tooltip: 'Borrar Todos los Acordes',
                    color: Colors.redAccent,
                    onTap: notifier.clearAllGridChords,
                  ),
                ],
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.upRightAndDownLeftFromCenter, size: 10, color: Color(0xFF38BDF8)),
                ],
              ),
            ],
          ),
          const Divider(height: 12, color: Color(0xFF1E293B)),

          // Bloque Central: Transporte Vertical + Seeker + Lista de Compases
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transporte y Seeker Vertical
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTransportBtn(
                    icon: FontAwesomeIcons.backwardStep,
                    onTap: () {},
                    tooltip: 'Compás Anterior',
                  ),
                  const SizedBox(height: 4),
                  _buildTransportBtn(
                    icon: state.isPlayingAudio ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                    isPrimary: true,
                    onTap: notifier.togglePlayAudio,
                    tooltip: 'Reproducir / Pausa',
                  ),
                  const SizedBox(height: 4),
                  _buildTransportBtn(
                    icon: FontAwesomeIcons.forwardStep,
                    onTap: () {},
                    tooltip: 'Siguiente Compás',
                  ),
                  const SizedBox(height: 4),
                  _buildTransportBtn(
                    icon: FontAwesomeIcons.stop,
                    onTap: notifier.stopAudio,
                    tooltip: 'Detener',
                  ),
                  const SizedBox(height: 4),
                  _buildTransportBtn(
                    icon: FontAwesomeIcons.arrowsRotate,
                    isActive: state.syncDiapason,
                    onTap: notifier.toggleSyncDiapason,
                    tooltip: 'Sincronizar Diapasón',
                  ),
                  const SizedBox(height: 8),

                  // Tiempo actual
                  const Text(
                    '00:00',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                  ),
                  SizedBox(
                    height: 140,
                    width: 20,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: state.currentAudioTime,
                        min: 0.0,
                        max: state.totalAudioDuration,
                        activeColor: const Color(0xFF0284C7),
                        inactiveColor: const Color(0xFF334155),
                        onChanged: (v) => notifier.seekAudio(v),
                      ),
                    ),
                  ),
                  const Text(
                    '-03:00',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Lista de Compases con 4 Tiempos por fila
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.measures.length,
                    itemBuilder: (context, mIdx) {
                      final measure = state.measures[mIdx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            // Número de compás
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  '${measure.barNumber}',
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // 4 Pulsos / Beats
                            Expanded(
                              child: Row(
                                children: measure.beats.map((beat) {
                                  final isSelected = state.selectedBarIndex == beat.barIndex &&
                                      state.selectedBeatIndex == beat.beatIndex;
                                  final hasChord = beat.chord.isNotEmpty;

                                  return Expanded(
                                    child: InkWell(
                                      onTap: () => notifier.selectBeat(beat.barIndex, beat.beatIndex),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF0369A1)
                                              : (hasChord ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF38BDF8)
                                                : (hasChord ? const Color(0xFF0284C7) : const Color(0xFF334155)),
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              beat.chord.isNotEmpty ? beat.chord : '-',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: hasChord ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              beat.timeText,
                                              style: const TextStyle(
                                                fontSize: 6.5,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn({
    required FaIconData icon,
    bool isActive = false,
    Color? color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: FaIcon(
        icon,
        size: 10,
        color: color ?? (isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      onPressed: onTap,
    );
  }

  Widget _buildTransportBtn({
    required FaIconData icon,
    bool isPrimary = false,
    bool isActive = false,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF0284C7)
              : (isActive ? const Color(0xFF0369A1) : const Color(0xFF1E293B)),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: FaIcon(
            icon,
            size: 9,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
