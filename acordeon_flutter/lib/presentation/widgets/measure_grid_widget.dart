import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';

class MeasureGridWidget extends ConsumerWidget {
  final int accordionNumber;

  const MeasureGridWidget({
    super.key,
    this.accordionNumber = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;

    return Container(
      width: isPrimary ? 340 : 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera para Acordeón 2 (Badge verde esmeralda con enlace sincronizado)
          if (!isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: Color(0xFFA7F3D0))),
              ),
              child: const Row(
                children: [
                  FaIcon(FontAwesomeIcons.link, size: 10, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text(
                    'Acordeón 2',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Transporte y Seeker de Tiempo (Solo en Diapasón 1)
                if (isPrimary) ...[
                  _buildTransportAndSeeker(state, notifier),
                  const SizedBox(width: 8),
                ],

                // Columna Central: Cuadrícula de Compases con 4 Tiempos por fila
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 330),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.measures.length,
                      itemBuilder: (context, mIdx) {
                        final measure = state.measures[mIdx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              // Número de compás
                              Container(
                                width: 24,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
                                  border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                child: Center(
                                  child: Text(
                                    '${measure.barNumber}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),

                              // 4 Beats / Tiempos del compás
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: measure.beats.asMap().entries.map((entry) {
                                    final beatIdx = entry.key;
                                    final beat = entry.value;
                                    final hasChord = beat.chord.isNotEmpty;

                                    return InkWell(
                                      onTap: () => _showEditChordDialog(context, notifier, mIdx, beatIdx, beat.chord),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: beatIdx < measure.beats.length - 1
                                                ? const BorderSide(color: Color(0xFFE2E8F0), width: 0.8)
                                                : BorderSide.none,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              hasChord ? beat.chord : '-',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: hasChord ? FontWeight.w900 : FontWeight.w500,
                                                color: hasChord ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                            Text(
                                              beat.timeText,
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
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

                // Columna Derecha: Barra de Herramientas Vertical (Solo en Diapasón 1)
                if (isPrimary) ...[
                  const SizedBox(width: 6),
                  _buildVerticalActionToolbar(context, state, notifier),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportAndSeeker(AccordionSimulatorState state, AccordionSimulatorNotifier notifier) {
    return Column(
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
          tooltip: 'Reproducir / Pausar',
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

        // Tiempo actual y Seeker Vertical
        const Text(
          '00:00',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
        ),
        SizedBox(
          height: 140,
          width: 22,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3.5,
                activeTrackColor: const Color(0xFF0284C7),
                inactiveTrackColor: const Color(0xFFCBD5E1),
                thumbColor: const Color(0xFF0284C7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: state.currentAudioTime,
                min: 0.0,
                max: state.totalAudioDuration > 0 ? state.totalAudioDuration : 1.0,
                onChanged: (v) => notifier.seekAudio(v),
              ),
            ),
          ),
        ),
        const Text(
          '-03:00',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildVerticalActionToolbar(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionBtn(
          icon: FontAwesomeIcons.listOl,
          isActive: state.sequenceMode,
          tooltip: 'Modo Secuencia',
          onTap: notifier.toggleSequenceMode,
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.checkDouble,
          tooltip: 'Seleccionar Todos (Ctrl+A)',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.fileArrowDown,
          tooltip: 'Guardar / Exportar acordes a CSV',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.fileArrowUp,
          tooltip: 'Cargar / Importar acordes desde CSV',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.keyboard,
          tooltip: 'Digitar Progresión Manualmente',
          onTap: () => _showManualProgressionDialog(context, notifier),
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.plus,
          tooltip: 'Agregar un compás vacío al final',
          onTap: notifier.addMeasure,
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.trashCan,
          tooltip: 'Borrar todos los acordes de la cuadrícula',
          color: const Color(0xFFDC2626),
          onTap: notifier.clearAllGridChords,
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.gear,
          tooltip: 'Configurar cantidad de filas visibles',
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _buildActionBtn(
          icon: FontAwesomeIcons.upRightAndDownLeftFromCenter,
          tooltip: 'Desacoplar a ventana completa',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildTransportBtn({
    required FaIconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isPrimary = false,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF0284C7)
                : (isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF0369A1)
                  : (isActive ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 11,
              color: isPrimary
                  ? Colors.white
                  : (isActive ? const Color(0xFF0284C7) : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required FaIconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isActive ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 10,
              color: color ?? (isActive ? const Color(0xFF0284C7) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditChordDialog(
    BuildContext context,
    AccordionSimulatorNotifier notifier,
    int measureIndex,
    int beatIndex,
    String currentChord,
  ) {
    final controller = TextEditingController(text: currentChord);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Acorde (Compás ${measureIndex + 1}, Beat ${beatIndex + 1})'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Acorde',
            hintText: 'ej. Bb, Eb, F7, Gm',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.updateMeasureBeat(measureIndex, beatIndex, '');
              Navigator.pop(ctx);
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.updateMeasureBeat(measureIndex, beatIndex, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showManualProgressionDialog(BuildContext context, AccordionSimulatorNotifier notifier) {
    final controller = TextEditingController(text: 'Bb | Eb | F7 | Bb');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digitar Progresión Manualmente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe los acordes separados por barra (|), espacio o coma. Ej: Sol | Re | Mim | Do',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'ej: Bb | Eb | F7 | Bb',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = controller.text;
              final parts = raw.split(RegExp(r'[|, \n]+')).where((s) => s.isNotEmpty).toList();
              for (int i = 0; i < parts.length; i++) {
                final mIdx = i ~/ 4;
                final bIdx = i % 4;
                notifier.updateMeasureBeat(mIdx, bIdx, parts[i]);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Cargar a Cuadrícula'),
          ),
        ],
      ),
    );
  }
}
