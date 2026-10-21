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
        topOffset: 24,
      ),
      _RowDef(
        rowKey: 'row2',
        title: 'Hilera 2\nMedio',
        buttons: trebleData['row2'] ?? [],
        topOffset: 0,
      ),
      _RowDef(
        rowKey: 'row3',
        title: 'Hilera 3\nAdentro',
        buttons: trebleData['row3'] ?? [],
        topOffset: 24,
      ),
    ];

    final effectiveRows = isMirror ? rowList.reversed.toList() : rowList;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: effectiveRows.map((rDef) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildRow(
              context: context,
              ref: ref,
              title: rDef.title,
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
    required String title,
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
        // Cabecera de la hilera
        Container(
          width: 58,
          height: 34,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
                height: 1.1,
              ),
            ),
          ),
        ),
        SizedBox(height: topOffset + 8),
        // Botones de la hilera
        ...buttons.map((btn) {
          final isPressed = state.activeButtons.contains(btn.id);
          final midiToPlay = btn.push + currentTuning.offset;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: DiapasonButtonWidget(
              btnIndex: btn.btnIndex,
              pushMidi: btn.push,
              pullMidi: btn.pull,
              isPressed: isPressed,
              bellowsMode: currentBellows,
              notation: state.notation,
              tuningOffset: currentTuning.offset,
              onPointerDown: () => notifier.pressButton(btn.id, midiToPlay),
              onPointerUp: () => notifier.releaseButton(btn.id, midiToPlay),
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
