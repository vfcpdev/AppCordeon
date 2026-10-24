import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/tuning.dart';
import '../controllers/accordion_controller.dart';
import 'diapason_button_widget.dart';
import 'tuning_picker_dialog.dart';

class DiapasonWidget extends ConsumerWidget {
  final int accordionNumber;
  final String title;
  final TuningDefinition? currentTuning;
  final ValueChanged<TuningDefinition?>? onTuningChanged;

  const DiapasonWidget({
    super.key,
    this.accordionNumber = 1,
    this.title = 'Diapasón Principal',
    this.currentTuning,
    this.onTuningChanged,
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
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 38),
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
        children: [
          // ── Botones de Fuelle (⇄  ←  →) ──────────────────────────────
          _BellowsToggle(
            bellowsMode: bellowsMode,
            onBellowsChanged: onBellowsChanged,
          ),
          const SizedBox(height: 18),

          // ── Hileras de botones + selector acordeón + bajos ──────────────
          Stack(
            clipBehavior: Clip.none,
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
                    ),
                  );
                }).toList(),
              ),
              // Botón selector acordeón y botón bajos a la derecha, arriba
              if (currentTuning != null && onTuningChanged != null)
                Positioned(
                  left: -36,
                  top: 0,
                  child: Tooltip(
                    message: 'Seleccionar acordeón',
                    child: IconButton(
                      onPressed: () => showTuningPickerDialog(
                        context: context,
                        currentTuning: currentTuning!,
                        onTuningChanged: onTuningChanged!,
                      ),
                      icon: const FaIcon(
                        FontAwesomeIcons.music,
                        size: 16,
                        color: Colors.white,
                      ),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.07),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                      ),
                    ),
                  ),
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
        // Botones de la hilera con espaciado natural de 12px
        ...buttons.map((btn) {
          final isPressed = state.activeButtons.contains(btn.id);
          final isDetector = state.detectorSelectedButtons.contains(btn.id);
          final midiToPlay = currentBellows == BellowsMode.pull
              ? btn.pull + currentTuning.offset
              : btn.push + currentTuning.offset;

          String? shortcut;
          if (isPrimary) {
            const row1Keys = ['Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '-'];
            const row2Keys = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ', '{'];
            const row3Keys = ['W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '´'];

            final idx = btn.btnIndex - 1;
            if (btn.rowKey == 'row1' && idx < row1Keys.length) shortcut = row1Keys[idx];
            if (btn.rowKey == 'row2' && idx < row2Keys.length) shortcut = row2Keys[idx];
            if (btn.rowKey == 'row3' && idx < row3Keys.length) shortcut = row3Keys[idx];
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: DiapasonButtonWidget(
              btnIndex: btn.btnIndex,
              pushMidi: btn.push,
              pullMidi: btn.pull,
              isPressed: isPressed,
              isDetectorSelected: isDetector,
              bellowsMode: currentBellows,
              notation: state.notation,
              tuningOffset: currentTuning.offset,
              shortcutLabel: shortcut,
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
      child: InkWell(
        onTap: () => onTap(mode),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
