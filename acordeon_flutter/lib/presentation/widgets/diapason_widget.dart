import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/tuning.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';
import 'diapason_button_widget.dart';
import 'tuning_picker_dialog.dart';

class DiapasonWidget extends ConsumerWidget {
  static const double _buttonSize = 50.0;

  final int accordionNumber;
  final String title;
  final TuningDefinition currentTuning;
  final ValueChanged<TuningDefinition?> onTuningChanged;

  const DiapasonWidget({
    super.key,
    this.accordionNumber = 1,
    this.title = 'Diapasón Principal',
    required this.currentTuning,
    required this.onTuningChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;
    final trebleData = isPrimary ? state.trebleData1 : state.trebleData2;
    final isMirror = isPrimary ? state.mirror1 : state.mirror2;
    final bellowsMode = isPrimary ? state.bellows1 : state.bellows2;
    final onBellowsChanged = isPrimary ? notifier.setBellows1 : notifier.setBellows2;
    final onToggleMirror = isPrimary ? notifier.toggleMirror1 : notifier.toggleMirror2;

    // Acorde vigente: generado en el constructor + activo en el Compás +
    // seleccionado en el detector. Sus clases de altura deciden qué botones
    // se muestran al elegir Abrir o Cerrar con las flechas del fuelle.
    final generatedChordNotes = ChordCatalog.notesFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
    );
    final selectedChordNotes = <int>[];
    if (state.detectorSelectedButtons.isNotEmpty) {
      final selectedIds = state.detectorSelectedButtons.toSet();
      for (final row in trebleData.values) {
        for (final btn in row) {
          if (selectedIds.contains(btn.id)) {
            // `trebleData` ya está transpuesto: no se suma el offset otra vez.
            selectedChordNotes
              ..add(btn.pull)
              ..add(btn.push);
          }
        }
      }
    }
    final activeChordPitchClasses = ChordCatalog.activePitchClasses(
      generated: generatedChordNotes,
      playing: state.syncDiapason && state.isPlayingAudio
          ? state.playingChordNotes
          : const <int>[],
      selected: selectedChordNotes,
    );

    // Nombre del acorde del constructor en la notación activa (Latina/Alemana).
    final chordLabel = ChordCatalog.symbolFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      latin: state.notation != NotationMode.alemana,
      display: true,
    );

    final rowList = [
      _RowDef(
        rowKey: 'row1',
        title: 'Hilera 1\nAfuera',
        buttons: trebleData['row1'] ?? [],
        topOffset: 31.0,
      ),
      _RowDef(
        rowKey: 'row2',
        title: 'Hilera 2\nMedio',
        buttons: trebleData['row2'] ?? [],
        topOffset: 0.0,
      ),
      _RowDef(
        rowKey: 'row3',
        title: 'Hilera 3\nAdentro',
        buttons: trebleData['row3'] ?? [],
        topOffset: 31.0,
      ),
    ];

    final effectiveRows = isMirror ? rowList.reversed.toList() : rowList;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF334155), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra superior: selector de acordeón + fuelle ──────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF475569), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Seleccionar acordeón',
                      child: IconButton(
                        onPressed: () => showTuningPickerDialog(
                          context: context,
                          currentTuning: currentTuning,
                          onTuningChanged: onTuningChanged,
                        ),
                        icon: const FaIcon(
                          FontAwesomeIcons.music,
                          size: 16,
                          color: Colors.white,
                        ),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Nombre del acorde en la notación seleccionada.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chordLabel.isEmpty ? '—' : chordLabel,
                        key: ValueKey('diapason_chord_label_$accordionNumber'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 26,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 6),
                _BellowsToggle(
                  bellowsMode: bellowsMode,
                  onBellowsChanged: onBellowsChanged,
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 26,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Intercambiar hileras',
                  child: IconButton(
                    onPressed: onToggleMirror,
                    icon: FaIcon(
                      FontAwesomeIcons.arrowsRotate,
                      size: 14,
                      color: isMirror ? Colors.white : Colors.white70,
                    ),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: isMirror
                          ? const Color(0xFF0284C7)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isMirror
                              ? const Color(0xFF38BDF8)
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Hileras de botones + volumen vertical al borde derecho ──
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: effectiveRows.map((rDef) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildRow(
                      context: context,
                      ref: ref,
                      buttons: rDef.buttons,
                      topOffset: rDef.topOffset,
                      activeChordPitchClasses: activeChordPitchClasses,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 6),
              _VerticalVolumeControl(
                volume: isPrimary ? state.volume1 : state.volume2,
                isMuted: isPrimary ? state.isMuted1 : state.isMuted2,
                onVolumeChanged: isPrimary ? notifier.setVolume1 : notifier.setVolume2,
                onToggleMute: isPrimary ? notifier.toggleMute1 : notifier.toggleMute2,
                syncVolume: isPrimary ? state.syncVolume : null,
                onToggleSyncVolume: isPrimary ? notifier.toggleSyncVolume : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required WidgetRef ref,
    required List<TrebleButtonModel> buttons,
    required double topOffset,
    required Set<int> activeChordPitchClasses,
  }) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;
    final currentTuning = isPrimary ? state.tuning1 : state.tuning2;
    final currentBellows = isPrimary ? state.bellows1 : state.bellows2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topOffset > 0) SizedBox(height: topOffset),
        // Todos los botones permanecen visibles. En Abrir/Cerrar solo se
        // colorean los que producen una nota del acorde vigente.
        ...buttons.map((btn) {
          final isPressed = state.activeButtons.contains(btn.id);
          final isDetector = state.detectorSelectedButtons.contains(btn.id);
          final midiToPlay = currentBellows == BellowsMode.pull
              ? btn.pull
              : btn.push;

          // `btn.pull`/`btn.push` ya incluyen la transposición de la afinación.
          final isChordPull = activeChordPitchClasses.contains(btn.pull % 12);
          final isChordPush = activeChordPitchClasses.contains(btn.push % 12);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: DiapasonButtonWidget(
              btnIndex: btn.btnIndex,
              pushMidi: btn.push,
              pullMidi: btn.pull,
              isPressed: isPressed,
              isDetectorSelected: isDetector,
              isChordPull: isChordPull,
              isChordPush: isChordPush,
              showGloss: !isPrimary,
              bellowsMode: currentBellows,
              notation: state.notation,
              tuningOffset: currentTuning.offset,
              size: _buttonSize,
              onPointerDown: () {
                if (state.detectorMode) {
                  notifier.toggleDetectorButton(btn.id, midiToPlay);
                } else {
                  notifier.pressButton(btn.id, midiToPlay);
                }
              },
              onPointerUp: () {
                if (!state.detectorMode) {
                  notifier.releaseButton(btn.id, midiToPlay);
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

// ─── Widget interno: los 3 botones de fuelle ─────────────────────────────────
class _BellowsToggle extends StatelessWidget {
  final BellowsMode bellowsMode;
  final ValueChanged<BellowsMode> onBellowsChanged;

  const _BellowsToggle({
    required this.bellowsMode,
    required this.onBellowsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⇄  Ambos
          _BellowsBtn(
            icon: FontAwesomeIcons.arrowsLeftRight,
            mode: BellowsMode.both,
            current: bellowsMode,
            activeColor: const Color(0xFF818CF8),
            onTap: onBellowsChanged,
            tooltip: 'Ambos (Abrir y Cerrar)',
          ),
          const SizedBox(width: 3),

          // ←  Abre / Pull
          _BellowsBtn(
            icon: FontAwesomeIcons.arrowLeft,
            mode: BellowsMode.pull,
            current: bellowsMode,
            activeColor: const Color(0xFF3B82F6),
            onTap: onBellowsChanged,
            tooltip: 'Abre (Pull)',
          ),
          const SizedBox(width: 3),

          // →  Cierra / Push
          _BellowsBtn(
            icon: FontAwesomeIcons.arrowRight,
            mode: BellowsMode.push,
            current: bellowsMode,
            activeColor: const Color(0xFFEF4444),
            onTap: onBellowsChanged,
            tooltip: 'Cierra (Push)',
          ),
        ],
      ),
    );
  }
}

class _BellowsBtn extends StatelessWidget {
  final FaIconData icon;
  final BellowsMode mode;
  final BellowsMode current;
  final Color activeColor;
  final ValueChanged<BellowsMode> onTap;
  final String tooltip;

  const _BellowsBtn({
    required this.icon,
    required this.mode,
    required this.current,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == mode;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => onTap(mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isActive
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: FaIcon(
            icon,
            size: 13,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _VerticalVolumeControl extends StatelessWidget {
  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final bool? syncVolume;
  final VoidCallback? onToggleSyncVolume;

  const _VerticalVolumeControl({
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onToggleMute,
    this.syncVolume,
    this.onToggleSyncVolume,
  });

  @override
  Widget build(BuildContext context) {
    final effective = isMuted ? 0.0 : volume;

    return Container(
      width: 30,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(effective * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 20,
            height: 300,
            child: RotatedBox(
              // 270°: 100% arriba y 0% abajo, como un fader vertical.
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 9),
                  activeTrackColor: const Color(0xFF38BDF8),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: const Color(0xFF38BDF8),
                ),
                child: Slider(
                  value: effective,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    if (isMuted) onToggleMute();
                    onVolumeChanged(value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: isMuted ? 'Activar sonido' : 'Silenciar',
            child: InkWell(
              onTap: onToggleMute,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: FaIcon(
                  isMuted ? FontAwesomeIcons.volumeXmark : FontAwesomeIcons.volumeHigh,
                  size: 10,
                  color: isMuted ? const Color(0xFFF87171) : Colors.white70,
                ),
              ),
            ),
          ),
          if (onToggleSyncVolume != null) ...[
            const SizedBox(height: 4),
            Tooltip(
              message: 'Sincronizar volumen',
              child: InkWell(
                onTap: onToggleSyncVolume,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: FaIcon(
                    FontAwesomeIcons.link,
                    size: 9,
                    color: (syncVolume ?? false)
                        ? const Color(0xFF38BDF8)
                        : Colors.white38,
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

class _RowDef {
  final String rowKey;
  final String title;
  final List<TrebleButtonModel> buttons;
  final double topOffset;

  const _RowDef({
    required this.rowKey,
    required this.title,
    required this.buttons,
    required this.topOffset,
  });
}
