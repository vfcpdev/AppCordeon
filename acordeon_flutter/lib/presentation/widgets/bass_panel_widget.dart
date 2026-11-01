import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/theory/chord_catalog.dart';
import '../../domain/theory/music_theory.dart';
import '../controllers/accordion_controller.dart';
import 'accordion_button_3d.dart';

class BassPanelWidget extends ConsumerWidget {
  final int accordionNumber;

  static const double _buttonSize = 50.0;

  const BassPanelWidget({super.key, this.accordionNumber = 1});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = accordionNumber == 1;
    final isCollapsed = isPrimary
        ? state.isBass1Collapsed
        : state.isBass2Collapsed;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Tooltip(
          message: 'Mostrar bajos',
          child: InkWell(
            key: ValueKey('bass_panel_restore_btn_$accordionNumber'),
            onTap: () => _toggleCollapsed(notifier, isPrimary),
            borderRadius: BorderRadius.circular(8),
            child: RotatedBox(
              quarterTurns: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'Bajos',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final basses = isPrimary ? state.bassData1 : state.bassData2;
    final funds = basses
        .where((b) => b.type == ButtonType.fundamental)
        .toList();
    final chords = basses.where((b) => b.type == ButtonType.chord).toList();

    // Columna Exterior: pares 1, 3, 5 (Acorde, Bajo, Acorde, Bajo, Acorde, Bajo)
    final List<BassButtonModel> exteriorButtons = [
      chords[0],
      funds[0],
      chords[2],
      funds[2],
      chords[4],
      funds[4],
    ];

    // Columna Interior: pares 2, 4, 6
    final List<BassButtonModel> interiorButtons = [
      chords[1],
      funds[1],
      chords[3],
      funds[3],
      chords[5],
      funds[5],
    ];

    final activeChordPitchClasses = ref.watch(
      activeChordPitchClassesProvider(accordionNumber),
    );
    final rhythmButtonIndexes = state.activeBassRhythmButtonIndexes;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del panel de bajos
          Container(
            key: ValueKey('bass_panel_header_$accordionNumber'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bajos',
                  key: ValueKey('bass_panel_title_$accordionNumber'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  key: ValueKey('bass_panel_collapse_btn_$accordionNumber'),
                  onTap: () {
                    _toggleCollapsed(notifier, isPrimary);
                  },
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Cuerpo: Tablero de bajos
          Padding(
            padding: const EdgeInsets.fromLTRB(2.2, 4.4, 6.5, 4.4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(19.6, 8.7, 6.5, 8.7),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBassColumn(
                    title: 'Exterior',
                    buttons: exteriorButtons,
                    state: state,
                    notifier: notifier,
                    activeChordPitchClasses: activeChordPitchClasses,
                    rhythmButtonIndexes: rhythmButtonIndexes,
                    rhythmButtonOffset: 0,
                  ),
                  // Espacio suficiente para los números de la columna interior.
                  const SizedBox(width: 18.0),
                  _buildBassColumn(
                    title: 'Interior',
                    buttons: interiorButtons,
                    state: state,
                    notifier: notifier,
                    activeChordPitchClasses: activeChordPitchClasses,
                    rhythmButtonIndexes: rhythmButtonIndexes,
                    rhythmButtonOffset: 6,
                  ),
                ],
              ),
            ),
          ),

          // Leyenda inferior de acompañamiento de bajos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                const Text(
                  'Exacto',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                const Text(
                  'Cercano',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
                _buildRhythmControls(context, state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCollapsed(AccordionSimulatorNotifier notifier, bool isPrimary) {
    if (isPrimary) {
      notifier.toggleBass1();
    } else {
      notifier.toggleBass2();
    }
  }

  Widget _buildBassColumn({
    required String title,
    required List<BassButtonModel> buttons,
    required AccordionSimulatorState state,
    required AccordionSimulatorNotifier notifier,
    required Set<int> activeChordPitchClasses,
    required Set<int> rhythmButtonIndexes,
    required int rhythmButtonOffset,
  }) {
    final isPrimary = accordionNumber == 1;
    final currentTuning = isPrimary ? state.tuning1 : state.tuning2;

    final int activeChordRoot;
    if (state.detectedChord != null) {
      activeChordRoot = state.detectedChord!.rootPitchClass;
    } else if (!state.isFreeChordFixed &&
        !state.isFreeChordBeingEdited &&
        state.activeCompasChord.isNotEmpty) {
      activeChordRoot =
          ChordCatalog.rootPitchClassForChordSymbol(state.activeCompasChord) ??
          state.freeChordRoot;
    } else {
      activeChordRoot = state.freeChordRoot;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabecera de columna
        Container(
          width: _buttonSize,
          height: 25.4,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(5.4),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6.5),
        // 6 Botones
        ...buttons.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final btn = entry.value;
          final isPressed = state.activeButtons.contains(btn.id);
          final pushMidi = btn.pushNotes.isNotEmpty ? btn.pushNotes.first : 0;
          final pullMidi = btn.pullNotes.isNotEmpty ? btn.pullNotes.first : 0;

          final isMinorPush = btn.namePush.toLowerCase().contains('min');
          final isMinorPull = btn.namePull.toLowerCase().contains('min');
          final rawPush = MusicTheory.midiToName(
            pushMidi,
            notation: state.notation,
            ignoreOctave: true,
            tuningOffset: currentTuning.offset,
          );
          final rawPull = MusicTheory.midiToName(
            pullMidi,
            notation: state.notation,
            ignoreOctave: true,
            tuningOffset: currentTuning.offset,
          );
          final pushName = btn.type == ButtonType.chord
              ? '$rawPush${isMinorPush ? "m" : ""}'
              : rawPush;
          final pullName = btn.type == ButtonType.chord
              ? '$rawPull${isMinorPull ? "m" : ""}'
              : rawPull;

          final currentBellows = isPrimary ? state.bellows1 : state.bellows2;
          // `bassData` ya está transpuesto según la afinación.
          final midiToPlay = currentBellows == BellowsMode.pull
              ? pullMidi
              : pushMidi;

          final pushMatch = ChordCatalog.evaluateBassMatch(
            notes: btn.pushNotes,
            type: btn.type,
            chordRoot: activeChordRoot,
            chordPitchClasses: activeChordPitchClasses,
            btnIndex: btn.btnIndex,
          );
          final pullMatch = ChordCatalog.evaluateBassMatch(
            notes: btn.pullNotes,
            type: btn.type,
            chordRoot: activeChordRoot,
            chordPitchClasses: activeChordPitchClasses,
            btnIndex: btn.btnIndex,
          );

          final isChordPull = pullMatch.isMatch;
          final isChordPush = pushMatch.isMatch;

          String tooltipMsg;
          if (currentBellows == BellowsMode.push) {
            final desc = pushMatch == BassMatchType.exact
                ? 'Coincidencia exacta'
                : (pushMatch == BassMatchType.close
                      ? 'Acompañamiento cercano'
                      : '');
            tooltipMsg = desc.isNotEmpty ? '${btn.label} ($desc)' : btn.label;
          } else if (currentBellows == BellowsMode.pull) {
            final desc = pullMatch == BassMatchType.exact
                ? 'Coincidencia exacta'
                : (pullMatch == BassMatchType.close
                      ? 'Acompañamiento cercano'
                      : '');
            tooltipMsg = desc.isNotEmpty ? '${btn.label} ($desc)' : btn.label;
          } else {
            final parts = <String>[];
            if (pullMatch == BassMatchType.exact) {
              parts.add('Abre: Exacto');
            } else if (pullMatch == BassMatchType.close) {
              parts.add('Abre: Cercano');
            }
            if (pushMatch == BassMatchType.exact) {
              parts.add('Cierra: Exacto');
            } else if (pushMatch == BassMatchType.close) {
              parts.add('Cierra: Cercano');
            }
            tooltipMsg = parts.isNotEmpty
                ? '${btn.label} (${parts.join(' · ')})'
                : btn.label;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.5),
            child: Tooltip(
              message: tooltipMsg,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    // Alineado a la derecha contra el borde izquierdo del botón:
                    // los números de 1 y 2 dígitos quedan en la misma columna.
                    right: _buttonSize + 4.8,
                    child: Text(
                      '$index',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.95),
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                          Shadow(color: Colors.black87, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                  AccordionButton3D(
                    size: _buttonSize,
                    isPressed: isPressed,
                    bellowsMode: currentBellows,
                    buttonType: btn.type,
                    isChordPull: isChordPull,
                    isChordPush: isChordPush,
                    bassMatchPush: pushMatch,
                    bassMatchPull: pullMatch,
                    isSelectedForRhythm: rhythmButtonIndexes.contains(
                      rhythmButtonOffset + entry.key,
                    ),
                    onPointerDown: () =>
                        notifier.pressButton(btn.id, midiToPlay),
                    onPointerUp: () =>
                        notifier.releaseButton(btn.id, midiToPlay),
                    child: _buildBassButtonLabel(
                      pushName,
                      pullName,
                      currentBellows,
                    ),
                  ),

                  // Insignia flotante Abre / Cierra al presionar bajo
                  if (isPressed &&
                      (currentBellows == BellowsMode.push ||
                          currentBellows == BellowsMode.pull))
                    Positioned(
                      top: -13.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.5,
                          vertical: 1.1,
                        ),
                        decoration: BoxDecoration(
                          color: currentBellows == BellowsMode.push
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: currentBellows == BellowsMode.push
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF93C5FD),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: currentBellows == BellowsMode.push
                                  ? const Color(
                                      0xFFDC2626,
                                    ).withValues(alpha: 0.80)
                                  : const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.80),
                              blurRadius: 14.5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          currentBellows == BellowsMode.push
                              ? 'CIERRA'
                              : 'ABRE',
                          style: const TextStyle(
                            fontSize: 8.7,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRhythmControls(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    final selectedPattern = state.selectedBassRhythmPattern;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(13),
          bottomRight: Radius.circular(13),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('bass_rhythm_import_btn_$accordionNumber'),
            tooltip: 'Importar patrón MusicXML',
            onPressed: () => _importRhythmPatterns(context, notifier),
            constraints: const BoxConstraints.tightFor(width: 26, height: 28),
            padding: EdgeInsets.zero,
            splashRadius: 14,
            icon: const Icon(
              Icons.file_upload_outlined,
              size: 15,
              color: Color(0xFF334155),
            ),
          ),
          SizedBox(
            width: 84,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: ValueKey('bass_rhythm_pattern_picker_$accordionNumber'),
                value: selectedPattern?.id,
                isDense: true,
                isExpanded: true,
                itemHeight: 34,
                hint: const Text(
                  'Patrón',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Color(0xFF475569)),
                ),
                selectedItemBuilder: (context) => state.bassRhythmPatterns
                    .map(
                      (pattern) => Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message:
                              '${pattern.name} · ${pattern.partName} · Compás ${pattern.measureNumber}',
                          child: Text(
                            pattern.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                items: state.bassRhythmPatterns
                    .map(
                      (pattern) => DropdownMenuItem(
                        value: pattern.id,
                        child: Text(
                          '${pattern.name} · ${pattern.partName} · C${pattern.measureNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: state.bassRhythmPatterns.isEmpty
                    ? null
                    : notifier.selectBassRhythmPattern,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('bass_metronome_toggle_btn_$accordionNumber'),
            tooltip: state.isBassMetronomeActive
                ? 'Detener metrónomo de bajos'
                : 'Iniciar metrónomo de bajos',
            onPressed: notifier.toggleBassMetronome,
            constraints: const BoxConstraints.tightFor(width: 26, height: 28),
            padding: EdgeInsets.zero,
            splashRadius: 14,
            icon: Icon(
              state.isBassMetronomeActive
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 16,
              color: state.isBassMetronomeActive
                  ? const Color(0xFF059669)
                  : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importRhythmPatterns(
    BuildContext context,
    AccordionSimulatorNotifier notifier,
  ) async {
    try {
      final result = await notifier.importBassRhythmPatterns();
      if (!context.mounted || result == null) return;
      final recoveryMessage = result.recoveredMalformedEvents == 0
          ? ''
          : ' Se recuperó ${result.recoveredMalformedEvents} evento(s) malformado(s) como pausa.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron ${result.patterns.length} patrones.$recoveryMessage',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('No se pudo importar el MusicXML: $error')),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Error al leer el archivo: $error')),
      );
    }
  }

  Widget _buildBassButtonLabel(
    String pushName,
    String pullName,
    BellowsMode bellows,
  ) {
    // Fuelle seleccionado: solo se muestra la nota que suena en esa
    // dirección. El cuerpo del botón ya está teñido de azul (Abre) o
    // rojo (Cierra), por eso el texto va en blanco.
    const labelShadows = [
      Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 2.5),
      Shadow(color: Colors.black87, blurRadius: 2),
    ];
    if (bellows == BellowsMode.push) {
      return Text(
        pushName,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: labelShadows,
        ),
      );
    }
    if (bellows == BellowsMode.pull) {
      return Text(
        pullName,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: labelShadows,
        ),
      );
    }

    // Modo Both: cada mitad del botón está teñida (azul/rojo), así que el
    // texto de ambas notas va en blanco para mantener el contraste.
    // Izquierda (azul) = Pull / Abre · Derecha (rojo) = Push / Cierra.
    return SizedBox(
      width: _buttonSize,
      height: _buttonSize,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pullName,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                    shadows: labelShadows,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 2.2,
            height: _buttonSize * 0.5,
            color: Colors.white54,
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pushName,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                    shadows: labelShadows,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
