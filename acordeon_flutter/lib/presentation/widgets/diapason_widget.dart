import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/tuning.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';
import 'diapason_button_widget.dart';
import 'tonic_bar_widget.dart';
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
    final isPrimary = accordionNumber == 1;
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final trebleData = ref.watch(accordionSimulatorProvider.select(
      (s) => isPrimary ? s.trebleData1 : s.trebleData2,
    ));
    final isMirror = ref.watch(accordionSimulatorProvider.select(
      (s) => isPrimary ? s.mirror1 : s.mirror2,
    ));
    final bellowsMode = ref.watch(accordionSimulatorProvider.select(
      (s) => isPrimary ? s.bellows1 : s.bellows2,
    ));
    final onBellowsChanged = isPrimary ? notifier.setBellows1 : notifier.setBellows2;
    final onToggleMirror = isPrimary ? notifier.toggleMirror1 : notifier.toggleMirror2;

    // Selector memoizado para no recalcular acordes en cada frame ni provocar rebuilds innecesarios
    final activeChordPitchClasses = ref.watch(activeChordPitchClassesProvider(accordionNumber));

    // Nombre del acorde del constructor en la notación activa (Latina/Alemana).
    final freeChordRoot = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordRoot));
    final freeChordType = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordType));
    final freeChordFourth = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordFourth));
    final notation = ref.watch(accordionSimulatorProvider.select((s) => s.notation));
    final isFreeChordFixed = ref.watch(accordionSimulatorProvider.select((s) => s.isFreeChordFixed));

    // Acorde activo en el Compás (seleccionado o reproduciéndose)
    final compasChord = ref.watch(accordionSimulatorProvider.select((s) => s.activeCompasChord));
    final formattedCompasChord = compasChord.isNotEmpty
        ? ChordCatalog.formatChordForNotation(compasChord, notation)
        : '';

    final rowList = [
      _RowDef(
        rowKey: 'row3',
        title: 'Hilera 3\nAdentro',
        buttons: trebleData['row3'] ?? [],
        topOffset: 31.0,
      ),
      _RowDef(
        rowKey: 'row2',
        title: 'Hilera 2\nMedio',
        buttons: trebleData['row2'] ?? [],
        topOffset: 0.0,
      ),
      _RowDef(
        rowKey: 'row1',
        title: 'Hilera 1\nAfuera',
        buttons: trebleData['row1'] ?? [],
        topOffset: 31.0,
      ),
    ];

    final effectiveRows = isMirror ? rowList.reversed.toList() : rowList;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Contenedor principal del Diapasón
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
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
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Barra unificada: Fuelle (Ambos / Abrir / Cerrar) + Intercambiar Hileras ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155), width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ⇄ Ambos
                        _BellowsBtn(
                          icon: FontAwesomeIcons.arrowsLeftRight,
                          mode: BellowsMode.both,
                          current: bellowsMode,
                          activeColor: const Color(0xFFEAB308),
                          onTap: onBellowsChanged,
                          tooltip: 'Ambos (Abrir y Cerrar)',
                        ),
                        const SizedBox(width: 3),

                        // ← Abre / Pull
                        _BellowsBtn(
                          icon: FontAwesomeIcons.arrowLeft,
                          mode: BellowsMode.pull,
                          current: bellowsMode,
                          activeColor: const Color(0xFF0284C7),
                          onTap: onBellowsChanged,
                          tooltip: 'Abre (Pull)',
                        ),
                        const SizedBox(width: 3),

                        // → Cierra / Push
                        _BellowsBtn(
                          icon: FontAwesomeIcons.arrowRight,
                          mode: BellowsMode.push,
                          current: bellowsMode,
                          activeColor: const Color(0xFFEF4444),
                          onTap: onBellowsChanged,
                          tooltip: 'Cierra (Push)',
                        ),

                        // Separador vertical sutil
                        Container(
                          width: 1,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: const Color(0xFF334155),
                        ),

                        // ⇄ Intercambiar Hileras
                        _BarActionBtn(
                          icon: FontAwesomeIcons.arrowsRotate,
                          isActive: isMirror,
                          activeColor: const Color(0xFF0284C7),
                          onTap: onToggleMirror,
                          tooltip: 'Intercambiar hileras',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // ── Etiqueta que ocupa todo el ancho del diapasón ──
                Container(
                  height: 24,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      (!isFreeChordFixed && formattedCompasChord.isNotEmpty)
                          ? ChordCatalog.buildChordLabelSpans(
                              chord: compasChord,
                              notation: notation,
                              fontSize: 9.5,
                            )
                          : TonicBarWidget.buildChordNameSpans(
                              root: freeChordRoot,
                              type: freeChordType,
                              extension: freeChordFourth,
                              latin: notation != NotationMode.alemana,
                              fontSize: 9.5,
                            ),
                      key: ValueKey('diapason_chord_label_$accordionNumber'),
                      maxLines: 1,
                    ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _buildRow(
                            context: context,
                            ref: ref,
                            buttons: rDef.buttons,
                            topOffset: rDef.topOffset,
                            activeChordPitchClasses: activeChordPitchClasses,
                            compasChord: compasChord,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 4),
                    _VerticalVolumeControl(
                      volume: ref.watch(accordionSimulatorProvider.select(
                        (s) => isPrimary ? s.volume1 : s.volume2,
                      )),
                      isMuted: ref.watch(accordionSimulatorProvider.select(
                        (s) => isPrimary ? s.isMuted1 : s.isMuted2,
                      )),
                      onVolumeChanged: isPrimary ? notifier.setVolume1 : notifier.setVolume2,
                      onToggleMute: isPrimary ? notifier.toggleMute1 : notifier.toggleMute2,
                      syncVolume: isPrimary
                          ? ref.watch(accordionSimulatorProvider.select((s) => s.syncVolume))
                          : null,
                      onToggleSyncVolume: isPrimary ? notifier.toggleSyncVolume : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Botón de Tonalidad en el borde superior (50% sobre el borde, 50% dentro del diapasón) ──
        Positioned(
          top: 0,
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Seleccionar acordeón / tonalidad',
              child: InkWell(
                key: ValueKey('diapason_tuning_btn_$accordionNumber'),
                onTap: () => showTuningPickerDialog(
                  context: context,
                  currentTuning: currentTuning,
                  onTuningChanged: onTuningChanged,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Ink(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      currentTuning.name,
                      key: ValueKey('diapason_tuning_pill_$accordionNumber'),
                      style: const TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required WidgetRef ref,
    required List<TrebleButtonModel> buttons,
    required double topOffset,
    required Set<int> activeChordPitchClasses,
    required String compasChord,
  }) {
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;
    final currentTuning = ref.watch(accordionSimulatorProvider.select(
      (s) => isPrimary ? s.tuning1 : s.tuning2,
    ));
    final currentBellows = ref.watch(accordionSimulatorProvider.select(
      (s) => isPrimary ? s.bellows1 : s.bellows2,
    ));
    final activeButtons = ref.watch(accordionSimulatorProvider.select((s) => s.activeButtons));
    final detectorSelectedButtons = ref.watch(accordionSimulatorProvider.select((s) => s.detectorSelectedButtons));
    final notation = ref.watch(accordionSimulatorProvider.select((s) => s.notation));
    final detectorMode = ref.watch(accordionSimulatorProvider.select((s) => s.detectorMode));
    final freeChordOctave = ref.watch(accordionSimulatorProvider.select((s) => s.freeChordOctave));
    final isFreeChordFixed = ref.watch(accordionSimulatorProvider.select((s) => s.isFreeChordFixed));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topOffset > 0) SizedBox(height: topOffset),
        // Todos los botones permanecen visibles. En Abrir/Cerrar solo se
        // colorean los que producen una nota del acorde vigente.
        ...buttons.map((btn) {
          final isPressed = activeButtons.contains('a${accordionNumber}_${btn.id}') ||
              activeButtons.contains(btn.id);
          final isDetector = detectorSelectedButtons.contains(btn.id);
          final midiToPlay = currentBellows == BellowsMode.pull
              ? btn.pull
              : btn.push;

          // `btn.pull`/`btn.push` ya incluyen la transposición de la afinación.
          bool matchesOctave(int midi) {
            if (!isFreeChordFixed && compasChord.isNotEmpty) return true;
            if (freeChordOctave == 'all' || freeChordOctave.isEmpty) return true;
            // Octava 3: 48 a 59, Octava 4: 60 a 71, Octava 5: 72 a 83
            final oct = (midi / 12).floor() - 1;
            return '$oct' == freeChordOctave;
          }

          final isChordPull = activeChordPitchClasses.contains(btn.pull % 12) && matchesOctave(btn.pull);
          final isChordPush = activeChordPitchClasses.contains(btn.push % 12) && matchesOctave(btn.push);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
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
              notation: notation,
              tuningOffset: currentTuning.offset,
              size: _buttonSize,
              onPointerDown: () {
                if (detectorMode) {
                  notifier.toggleDetectorButton(btn.id, midiToPlay);
                } else {
                  notifier.pressButton(btn.id, midiToPlay);
                }
              },
              onPointerUp: () {
                if (!detectorMode) {
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

// ─── Botones de la barra unificada de fuelle y control ──────────────────────
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FaIcon(
            icon,
            size: 12,
            color: isActive
                ? (activeColor.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white)
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _BarActionBtn extends StatelessWidget {
  final FaIconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final String tooltip;

  const _BarActionBtn({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FaIcon(
            icon,
            size: 11,
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
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
        borderRadius: BorderRadius.zero,
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
                  trackShape: const RectangularSliderTrackShape(),
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
              borderRadius: BorderRadius.zero,
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
                borderRadius: BorderRadius.zero,
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
