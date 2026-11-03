import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/bass_rhythm_pattern.dart';
import '../../domain/services/bass_capture_matrix_mapper.dart';
import '../../domain/theory/chord_catalog.dart';
import '../../domain/theory/music_theory.dart';
import '../controllers/accordion_controller.dart';
import 'accordion_button_3d.dart';
import 'bass_rhythm_capture_dialog.dart';
import 'bass_rhythm_pattern_library_dialog.dart';

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
    final rhythmHits = state.activeBassRhythmHits;

    return Container(
      key: ValueKey('bass_panel_container_$accordionNumber'),
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
      child: IntrinsicWidth(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Cabecera del panel de bajos (compacta en dos micro-filas para ajustar al ancho de los botones)
            Container(
              key: ValueKey('bass_panel_header_$accordionNumber'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
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
                      const SizedBox(width: 4),
                      // Selector compacto de Hilera objetivo (Ext | Med | Int)
                      _buildRowTargetSelector(state, notifier),
                      const Spacer(),
                      IconButton(
                        key: ValueKey('bass_panel_collapse_btn_$accordionNumber'),
                        tooltip: 'Ocultar bajos',
                        onPressed: () => _toggleCollapsed(notifier, isPrimary),
                        constraints: const BoxConstraints.tightFor(
                          width: 22,
                          height: 22,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 12,
                        icon: const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Selector de Columnas: [Todos | Externos | Internos]
                  _buildColumnFilterSelector(state, notifier),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Combobox / Selector rápido de patrón
                      Expanded(
                        child: _buildPatternQuickSelector(context, state, notifier),
                      ),
                      const SizedBox(width: 2),
                      // Botón de acceso directo a la biblioteca de patrones
                      IconButton(
                        key: ValueKey('bass_rhythm_library_btn_$accordionNumber'),
                        tooltip: 'Biblioteca de patrones',
                        onPressed: () => BassRhythmPatternLibraryDialog.show(
                          context,
                          accordionNumber: accordionNumber,
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 14,
                        icon: const Icon(
                          Icons.library_music_outlined,
                          size: 15,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _buildRhythmControls(context, state, notifier),

            // Panel inline de captura (no modal): permite tocar los bajos
            // mientras el reloj de captura corre.
            if (state.isBassCapturePanelOpen)
              BassRhythmCapturePanel(
                key: ValueKey('bass_capture_panel_$accordionNumber'),
                accordionNumber: accordionNumber,
                onClose: notifier.toggleBassCapturePanel,
              ),

            // Cuerpo: Tablero de bajos - Ancho estrictamente ajustado a los botones sin espacio vacío lateral
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Container(
                key: ValueKey('bass_panel_board_$accordionNumber'),
                padding: const EdgeInsets.only(left: 14.0, right: 8.0, top: 8.0, bottom: 8.0),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: state.bassColumnFilter == BassColumnFilter.internalOnly ? 0.28 : 1.0,
                      child: IgnorePointer(
                        ignoring: state.bassColumnFilter == BassColumnFilter.internalOnly,
                        child: _buildBassColumn(
                          title: 'Exterior',
                          buttons: exteriorButtons,
                          state: state,
                          notifier: notifier,
                          activeChordPitchClasses: activeChordPitchClasses,
                          rhythmHits: rhythmHits,
                          rhythmButtonIndexes: rhythmButtonIndexes,
                          rhythmButtonOffset: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: state.bassColumnFilter == BassColumnFilter.externalOnly ? 0.28 : 1.0,
                      child: IgnorePointer(
                        ignoring: state.bassColumnFilter == BassColumnFilter.externalOnly,
                        child: _buildBassColumn(
                          title: 'Interior',
                          buttons: interiorButtons,
                          state: state,
                          notifier: notifier,
                          activeChordPitchClasses: activeChordPitchClasses,
                          rhythmHits: rhythmHits,
                          rhythmButtonIndexes: rhythmButtonIndexes,
                          rhythmButtonOffset: 6,
                        ),
                      ),
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
                ],
              ),
            ),
          ],
        ),
        ),
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
    required Map<int, BassRhythmHit> rhythmHits,
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
          final rhythmHit = rhythmHits[rhythmButtonOffset + entry.key];
          final fingerNumber = rhythmHit?.fingerNumberFor(
            rhythmButtonOffset + entry.key,
          );

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
          if (fingerNumber != null) {
            final fingerName = switch (fingerNumber) {
              2 => 'índice',
              3 => 'medio',
              4 => 'anular',
              _ => 'dedo $fingerNumber',
            };
            tooltipMsg = '$tooltipMsg · Dedo $fingerNumber ($fingerName)';
          }
          if (rhythmHit?.isStaccato ?? false) {
            tooltipMsg = '$tooltipMsg · Staccato';
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
                    onPointerDown: () {
                      notifier.pressButton(btn.id, midiToPlay);
                      if (state.isBassCaptureActive) {
                        // La regla de mapeo vive en el dominio
                        // (BassCaptureMatrixMapper) para mantener alta
                        // cohesión y evitar duplicidad con la ruta de teclado.
                        final matrixButton = BassCaptureMatrixMapper.fromPhysical(
                          rhythmButtonOffset: rhythmButtonOffset,
                          btnIndex: btn.btnIndex,
                          type: btn.type,
                        );
                        if (matrixButton != null) {
                          notifier.captureBassMatrixHit(matrixButton);
                        }
                      }
                    },
                    onPointerUp: () =>
                        notifier.releaseButton(btn.id, midiToPlay),
                    child: _buildBassButtonLabel(
                      pushName,
                      pullName,
                      currentBellows,
                    ),
                  ),
                  if (fingerNumber != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 21,
                        height: 21,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E7490),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.4),
                        ),
                        child: Text(
                          '$fingerNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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

  /// Controles de captura de patrón rítmico.
  ///
  /// Reemplaza al antiguo combobox de selección y al modal de listado: el
  /// botón abre el diálogo con la matriz 2×2 (bajos 7, 8, 4 y 5).
  Widget _buildRhythmControls(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    final isCapturing = state.isBassCaptureActive;
    final patternCount = state.bassRhythmPatterns.length;
    final hasPatterns = state.bassRhythmPatterns.isNotEmpty;
    final isPatternPlaying =
        state.isBassMetronomeActive && state.selectedBassRhythmPattern != null;

    return Container(
      key: ValueKey('bass_rhythm_controls_$accordionNumber'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
            key: ValueKey('bass_rhythm_play_btn_$accordionNumber'),
            tooltip: !hasPatterns
                ? 'Sin patrones para reproducir'
                : isPatternPlaying
                    ? 'Detener patrón de bajos'
                    : 'Reproducir patrón de bajos',
            onPressed:
                hasPatterns ? notifier.toggleSelectedBassRhythmPlayback : null,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            splashRadius: 14,
            icon: Icon(
              isPatternPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              size: 20,
              color: !hasPatterns
                  ? const Color(0xFF94A3B8)
                  : isPatternPlaying
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            key: ValueKey('bass_rhythm_capture_btn_$accordionNumber'),
            tooltip: isCapturing
                ? 'Capturando patrón… ($patternCount)'
                : 'Capturar patrón rítmico de bajos',
            onPressed: () => notifier.toggleBassCapturePanel(),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            splashRadius: 14,
            icon: Icon(
              isCapturing ? Icons.fiber_manual_record : Icons.grid_view_rounded,
              size: 18,
              color: isCapturing
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF334155),
            ),
          ),
          if (isCapturing) ...[
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Capturando… ($patternCount)',
                key: ValueKey('bass_rhythm_capture_label_$accordionNumber'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            IconButton(
              key: ValueKey('bass_rhythm_quick_stop_btn_$accordionNumber'),
              tooltip: 'Detener captura',
              onPressed: notifier.stopBassRhythmCapture,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              splashRadius: 13,
              icon: const Icon(
                Icons.stop_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
            ),
          ] else ...[
            const Spacer(),
            _buildBpmSpeedControl(context, state, notifier),
          ],
        ],
      ),
    );
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

  Widget _buildColumnFilterSelector(
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    return Container(
      height: 22,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Row(
        children: BassColumnFilter.values.map((filter) {
          final isSelected = state.bassColumnFilter == filter;
          return Expanded(
            child: InkWell(
              key: ValueKey('bass_column_filter_${filter.name}_$accordionNumber'),
              onTap: () => notifier.selectBassColumnFilter(filter),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRowTargetSelector(
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AccordionRowTarget.values.map((target) {
          final isSelected = state.selectedBassRowTarget == target;
          return InkWell(
            key: ValueKey('bass_row_target_${target.name}_$accordionNumber'),
            onTap: () => notifier.selectBassRowTarget(target),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF059669) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                target.label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPatternQuickSelector(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    final selectedPattern = state.selectedBassRhythmPattern;
    final patterns = state.bassRhythmPatterns;
    final label = selectedPattern != null ? selectedPattern.name : 'Elegir ritmo…';

    return PopupMenuButton<String>(
      key: ValueKey('bass_pattern_quick_selector_$accordionNumber'),
      tooltip: 'Cambiar patrón activo',
      onSelected: (val) {
        if (val == '__open_library__') {
          BassRhythmPatternLibraryDialog.show(
            context,
            accordionNumber: accordionNumber,
          );
        } else {
          notifier.selectBassRhythmPattern(val);
        }
      },
      itemBuilder: (context) {
        return [
          ...patterns.map((p) {
            final isCurrent = p.id == state.selectedBassRhythmPatternId;
            return PopupMenuItem<String>(
              value: p.id,
              height: 32,
              child: Row(
                children: [
                  Icon(
                    isCurrent ? Icons.check_circle : Icons.circle_outlined,
                    size: 14,
                    color: isCurrent ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            key: ValueKey('bass_rhythm_library_btn_$accordionNumber'),
            value: '__open_library__',
            height: 34,
            child: Row(
              children: const [
                Icon(
                  Icons.library_music_outlined,
                  size: 15,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 6),
                Text(
                  'Biblioteca de patrones…',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              key: ValueKey('bass_rhythm_quick_label_$accordionNumber'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Icon(
            Icons.arrow_drop_down,
            size: 14,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmSpeedControl(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
    final currentBpm = state.effectiveBassBpm;

    return Tooltip(
      message: 'Velocidad del patrón / Metrónomo (BPM)',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                final newBpm = (currentBpm - 5).clamp(30.0, 300.0);
                notifier.setBassBpm(newBpm);
              },
              borderRadius: BorderRadius.circular(3),
              child: const Icon(Icons.remove, size: 12, color: Color(0xFF1E293B)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _showBpmInputDialog(context, currentBpm, notifier),
                child: Text(
                  '${currentBpm.round()} BPM',
                  key: ValueKey('bass_bpm_control_$accordionNumber'),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                final newBpm = (currentBpm + 5).clamp(30.0, 300.0);
                notifier.setBassBpm(newBpm);
              },
              borderRadius: BorderRadius.circular(3),
              child: const Icon(Icons.add, size: 12, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBpmInputDialog(
    BuildContext context,
    double initialBpm,
    AccordionSimulatorNotifier notifier,
  ) {
    final ctrl = TextEditingController(text: initialBpm.round().toString());
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ajustar BPM / Tempo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tempo (30 - 300 BPM)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim());
              if (parsed != null && parsed >= 30 && parsed <= 300) {
                notifier.setBassBpm(parsed);
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}
