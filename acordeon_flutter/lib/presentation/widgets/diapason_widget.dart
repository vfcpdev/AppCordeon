import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/accordion_data.dart';
import '../controllers/accordion_controller.dart';
import 'diapason_button_widget.dart';

class DiapasonWidget extends ConsumerWidget {
  final int accordionNumber;
  final String title;

  const DiapasonWidget({
    super.key,
    this.accordionNumber = 1,
    this.title = 'Diapasón Principal',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final isPrimary = accordionNumber == 1;
    final trebleData = isPrimary ? state.trebleData1 : state.trebleData2;
    final isMirror = isPrimary ? state.mirror1 : state.mirror2;

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
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 38),
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
      child: Row(
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
          final midiToPlay = btn.push + currentTuning.offset;
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
