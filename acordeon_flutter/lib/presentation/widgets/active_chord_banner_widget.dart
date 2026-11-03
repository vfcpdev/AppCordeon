import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';

/// Widget unificado y reutilizable que muestra la etiqueta del acorde activo
/// y las notas que lo conforman (SRP + OCP + DRY).
///
/// Se utiliza en:
/// 1. El Diapasón (con selector de estructura de acordes 3, 4, 5).
/// 2. La cabecera sobre los botones de la tónica (sin los botones 3, 4, 5).
///
/// Triplas de Hoare:
/// - Precondición {P}: Estado del simulador con o sin acorde activo definido.
/// - Ejecución {C}: Renderiza la etiqueta del acorde y notas entre paréntesis o '—' si no hay acorde.
/// - Poscondición {Q}: Interfaz homogénea, legible y sincronizada en tiempo real.
class ActiveChordBannerWidget extends ConsumerWidget {
  final int accordionNumber;
  final bool showStructureSelector;
  final String? customChord;
  final double height;
  final Key? labelKey;

  const ActiveChordBannerWidget({
    super.key,
    required this.accordionNumber,
    this.showStructureSelector = false,
    this.customChord,
    this.height = 28.0,
    this.labelKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notation = state.notation;
    final isLatin = notation != NotationMode.alemana;

    String chordLabel = customChord ?? '';
    if (chordLabel.isEmpty) {
      // 1. Acorde activo en el Compás (seleccionado o reproduciéndose)
      final compasChord = state.activeCompasChord;
      final formattedCompasChord = compasChord.isNotEmpty
          ? ChordCatalog.formatChordForNotation(compasChord, notation)
          : '';

      // 2. Acorde del constructor armónico si la tónica está definida (root >= 0)
      final formattedFreeChord = state.freeChordRoot >= 0
          ? ChordCatalog.symbolFor(
              root: state.freeChordRoot,
              type: state.freeChordType.isNotEmpty ? state.freeChordType : 'maj',
              extension: state.freeChordFourth,
              bass: state.freeChordBass,
              latin: isLatin,
              display: true,
            )
          : '';

      // 3. Acorde detectado en el diapasón físico
      final detectedChord = state.detectedChord;
      final formattedDetectedChord = detectedChord != null
          ? detectedChord.formattedSymbol(notation)
          : '';

      if (!state.isFreeChordFixed &&
          !state.isFreeChordBeingEdited &&
          formattedCompasChord.isNotEmpty) {
        chordLabel = formattedCompasChord;
      } else if (formattedFreeChord.isNotEmpty) {
        chordLabel = formattedFreeChord;
      } else if (formattedDetectedChord.isNotEmpty) {
        chordLabel = formattedDetectedChord;
      } else if (formattedCompasChord.isNotEmpty) {
        chordLabel = formattedCompasChord;
      }
    }

    final chordNoteCount = chordLabel.isNotEmpty
        ? ChordCatalog.pitchClassesForChordSymbol(chordLabel).length
        : 0;
    final displayedChordStructure = switch (chordNoteCount) {
      3 => 'triad',
      4 => 'seventh',
      5 => 'five',
      _ => state.freeChordScaleHarmonicMode,
    };

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  chordLabel.isEmpty
                      ? const TextSpan(
                          text: '—',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      : ChordCatalog.buildChordLabelSpans(
                          chord: chordLabel,
                          notation: notation,
                          fontSize: 9.5,
                        ),
                  key: labelKey ?? ValueKey('diapason_chord_label_$accordionNumber'),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          if (showStructureSelector) ...[
            const SizedBox(width: 6),
            ChordStructureSelectorWidget(
              selectedStructure: displayedChordStructure,
            ),
          ],
        ],
      ),
    );
  }
}

/// Selector de estructura armónica (3: Tríada, 4: Cuatríada, 5: Cinco notas)
class ChordStructureSelectorWidget extends ConsumerWidget {
  final String selectedStructure;

  const ChordStructureSelectorWidget({
    super.key,
    required this.selectedStructure,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Row(
      key: const ValueKey('diapason_structure_selector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          label: '3',
          tooltip: 'Tríada: 3 notas',
          key: 'diapason_structure_triad',
          isSelected: selectedStructure == 'triad',
          onTap: () => notifier.setFreeChordScaleHarmonicMode('triad'),
        ),
        const SizedBox(width: 2),
        _buildButton(
          label: '4',
          tooltip: 'Cuatríada: 4 notas',
          key: 'diapason_structure_seventh',
          isSelected: selectedStructure == 'seventh',
          onTap: () => notifier.setFreeChordScaleHarmonicMode('seventh'),
        ),
        const SizedBox(width: 2),
        _buildButton(
          label: '5',
          tooltip: 'Acorde de cinco notas: 1, 3, 5, 7 y 9',
          key: 'diapason_structure_five',
          isSelected: selectedStructure == 'five',
          onTap: () => notifier.setFreeChordScaleHarmonicMode('five'),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required String tooltip,
    required String key,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 25,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEA580C) : Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC2410C)
                  : const Color(0xFFFDBA74),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF9A3412),
            ),
          ),
        ),
      ),
    );
  }
}

