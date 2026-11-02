import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/di/providers.dart';
import '../../core/text/chord_text_fitter.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';
import 'chord_detector_widget.dart';
import 'tonic_notes_matrix_widget.dart';

class MeasureGridWidget extends ConsumerStatefulWidget {
  final int accordionNumber;
  final double? width;
  final bool isUndocked;
  final LayerLink? chordQualityLink;

  const MeasureGridWidget({
    super.key,
    this.accordionNumber = 1,
    this.width,
    this.isUndocked = false,
    this.chordQualityLink,
  });

  @override
  ConsumerState<MeasureGridWidget> createState() => _MeasureGridWidgetState();
}

class _MeasureGridWidgetState extends ConsumerState<MeasureGridWidget> {
  late final ScrollController _compasScrollController;
  int? _autoScrollTargetBar;

  @override
  void initState() {
    super.initState();
    _compasScrollController = ScrollController();
  }

  @override
  void dispose() {
    _compasScrollController.dispose();
    super.dispose();
  }

  void _scrollToBar(int barIndex) {
    if (_compasScrollController.hasClients) {
      final target = (barIndex * CompasCardMetrics.measureRowHeight).clamp(
        0.0,
        _compasScrollController.position.maxScrollExtent,
      );
      _compasScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Cuando el compás activo llega al 80 % del viewport, desplaza lentamente
  /// para dejar el siguiente compás alineado en la parte superior.
  void _handlePlaybackAutoScroll(int currentBar) {
    if (!_compasScrollController.hasClients) return;
    final state = ref.read(accordionSimulatorProvider);
    if (!state.isPlayingAudio) return;

    const itemHeight = CompasCardMetrics.measureRowHeight;
    final currentOffset = _compasScrollController.offset;
    final maxScroll = _compasScrollController.position.maxScrollExtent;

    if (currentBar == 0) {
      if (currentOffset > 0) {
        _animatePlaybackScroll(
          targetBar: 0,
          targetOffset: 0.0,
          duration: _playbackScrollDuration(state),
        );
      }
      return;
    }

    final viewportHeight = _compasScrollController.position.viewportDimension;
    final effectiveViewport = viewportHeight > 100 ? viewportHeight : 330.0;
    final activeBarBottom = ((currentBar + 1) * itemHeight) - currentOffset;
    if (activeBarBottom < effectiveViewport * 0.8) return;

    final nextBar = currentBar + 1;
    final target = (nextBar * itemHeight).clamp(0.0, maxScroll);
    if ((target - currentOffset).abs() <= 4.0 ||
        _autoScrollTargetBar != null ||
        nextBar >= state.measures.length) {
      return;
    }
    _animatePlaybackScroll(
      targetBar: nextBar,
      targetOffset: target,
      duration: _playbackScrollDuration(state),
    );
  }

  Duration _playbackScrollDuration(AccordionSimulatorState state) {
    final bpm = state.audioReport?.bpm ?? 120;
    final durationMs = (4 * 60 / bpm * 1000).round().clamp(800, 3000);
    return Duration(milliseconds: durationMs);
  }

  Future<void> _animatePlaybackScroll({
    required int targetBar,
    required double targetOffset,
    required Duration duration,
  }) async {
    if (!_compasScrollController.hasClients || _autoScrollTargetBar != null) {
      return;
    }
    _autoScrollTargetBar = targetBar;
    try {
      await _compasScrollController.animateTo(
        targetOffset,
        duration: duration,
        curve: Curves.linear,
      );
    } finally {
      if (mounted) _autoScrollTargetBar = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = widget.accordionNumber == 1;

    // Al cargar un nuevo archivo de audio, reiniciar el scroll vertical al compás 0 (inicio de la sección)
    ref.listen<String?>(
      accordionSimulatorProvider.select((s) => s.loadedAudioFileName),
      (prevFile, currentFile) {
        if (currentFile != null && currentFile != prevFile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBar(0);
          });
        }
      },
    );

    // Escucha cambios de compás durante reproducción/audio para scroll automático
    ref.listen<
      int?
    >(accordionSimulatorProvider.select((s) => s.selectedBarIndex), (
      prevBar,
      currentBar,
    ) {
      if (currentBar != null && currentBar != prevBar) {
        // Deja que termine el desplazamiento de edición antes del de reproducción.
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!mounted ||
              ref.read(accordionSimulatorProvider).selectedBarIndex !=
                  currentBar) {
            return;
          }
          _handlePlaybackAutoScroll(currentBar);
        });
      }
    });

    final bpm = state.audioReport?.bpm ?? 120;
    final totalBeats = state.measures.length * 4;
    final allMarked = totalBeats > 0 && state.markedBeats.length == totalBeats;
    final hasMarks = state.markedBeats.isNotEmpty;
    final effectiveWidth = widget.width ?? CompasCardMetrics.gridWidth;
    final isUndocked =
        widget.isUndocked ||
        (widget.accordionNumber == 1
            ? state.isCompas1Undocked
            : state.isCompas2Undocked);

    // Detectar si hay un acorde seleccionado en algún cuadro del compás o en el constructor
    final selectedBar = state.selectedBarIndex;
    final selectedBeat = state.selectedBeatIndex;
    String? selectedChord;
    if (selectedBar != null &&
        selectedBeat != null &&
        selectedBar >= 0 &&
        selectedBar < state.measures.length) {
      final row = state.measures[selectedBar];
      if (selectedBeat >= 0 && selectedBeat < row.beats.length) {
        final c = row.beats[selectedBeat].chord.trim();
        if (c.isNotEmpty) selectedChord = c;
      }
    }

    final constructorChord = ChordCatalog.symbolFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      bass: state.freeChordBass,
      latin: state.notation != NotationMode.alemana,
    );
    final hasSelectedCell =
        selectedBar != null &&
        selectedBeat != null &&
        selectedBar >= 0 &&
        selectedBar < state.measures.length &&
        selectedBeat >= 0 &&
        selectedBeat < state.measures[selectedBar].beats.length;
    final assignmentTargetCount = state.multiBeatAssignmentTargets.length;
    final insertTargetLabel = hasSelectedCell
        ? 'Compás ${selectedBar + 1} · Tiempo ${selectedBeat + 1}'
        : 'sin casilla seleccionada';
    final canInsertChord =
        constructorChord.isNotEmpty &&
        (state.isMultiBeatAssignmentMode
            ? assignmentTargetCount > 0
            : hasSelectedCell);
    final canToggleMultiBeatAssignment =
        constructorChord.isNotEmpty || state.isMultiBeatAssignmentMode;

    final chordToEdit =
        selectedChord ??
        ((state.multiBeatChord != null && state.multiBeatChord!.isNotEmpty)
            ? state.multiBeatChord
            : (constructorChord.isNotEmpty ? constructorChord : null));

    final hasOccurrences =
        chordToEdit != null &&
        state.measures.any(
          (m) => m.beats.any((b) => b.chord.trim() == chordToEdit),
        );
    final isEditActive = selectedChord != null || hasOccurrences;

    return SizedBox(
      width: effectiveWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            autofocus: false,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.space) {
                final isAnyEditing =
                    FocusManager.instance.primaryFocus?.context?.widget
                        is EditableText;
                if (!isAnyEditing) {
                  final res = notifier.markLiveChordChange();
                  if (res != null) {
                    return KeyEventResult.handled;
                  }
                }
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              key: const ValueKey('measure_grid_section_card'),
              width: effectiveWidth,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Cabecera superior: título del Compás, con la misma tipografía que Acorde.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFFECFDF5),
                      border: Border(
                        bottom: BorderSide(
                          color: isPrimary
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFA7F3D0),
                        ),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final naturalWidth = constraints.maxWidth > 230.0
                            ? constraints.maxWidth
                            : 230.0;
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: naturalWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isPrimary ? 'Compás' : 'Compás A2',
                                      key: ValueKey(
                                        'compas_title_${widget.accordionNumber}',
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    _BpmInputControl(
                                      bpm: bpm,
                                      compact: true,
                                      onChanged: (newVal) =>
                                          notifier.updateAudioBpm(newVal),
                                    ),
                                    const SizedBox(width: 3),
                                    _MetronomeButton(
                                      accordionNumber: widget.accordionNumber,
                                      isActive: state.isMetronomeActive,
                                      onTap: notifier.toggleMetronome,
                                    ),
                                  ],
                                ),
                                // Botón de acoplar / desacoplar y hacer movible el Compás
                                Tooltip(
                                  message: isUndocked
                                      ? 'Acoplar ventana de Compás'
                                      : 'Desacoplar ventana de Compás (mover libremente)',
                                  child: InkWell(
                                    key: ValueKey(
                                      'undock_compas_${widget.accordionNumber}',
                                    ),
                                    onTap: () => notifier.toggleUndockCompas(
                                      widget.accordionNumber,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3.0),
                                      decoration: BoxDecoration(
                                        color: isUndocked
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isUndocked
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFFCBD5E1),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: FaIcon(
                                        isUndocked
                                            ? FontAwesomeIcons.compress
                                            : FontAwesomeIcons
                                                  .arrowUpRightFromSquare,
                                        size: 8.5,
                                        color: isUndocked
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Fila de controles rítmicos: BPM + Metrónomo + Marcador Espacio + Acordes Completos
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFD1FAE5),
                      border: Border(
                        bottom: BorderSide(
                          color: isPrimary
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFA7F3D0),
                        ),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LiveMarkerButton(
                                accordionNumber: widget.accordionNumber,
                                isActive: state.isLiveChordMarkerActive,
                                isPlaying: state.isPlayingAudio,
                                onTap: notifier.toggleLiveChordMarker,
                              ),
                              const SizedBox(width: 3),
                              _AutoChordDetectButton(
                                accordionNumber: widget.accordionNumber,
                                isActive:
                                    state.isPlaybackAutoChordDetectEnabled,
                                onTap: notifier.togglePlaybackAutoChordDetect,
                              ),
                              const SizedBox(width: 3),
                              _BeatAdjustButton(
                                accordionNumber: widget.accordionNumber,
                                nudgeOffsetSeconds: state.beatNudgeOffset,
                                onNudge: notifier.adjustBeatOffset,
                                onSync: notifier.syncBeatToCurrentAudioTime,
                                onReset: notifier.resetBeatOffset,
                              ),
                              const SizedBox(width: 3),
                              _CompleteChordsButton(
                                accordionNumber: widget.accordionNumber,
                                hasYellowDecisions:
                                    state.yellowDecisionBeats.isNotEmpty,
                                yellowDecisionsCount:
                                    state.yellowDecisionBeats.length,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // 3. Minibarra superior: selección masiva de checkboxes y borrado de acordes
                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: effectiveWidth > 150 ? effectiveWidth : 180,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Botones de Guardar (JSON), Importar (JSON) y Editar — aumentados 50%
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message:
                                      'Guardar compases en JSON (Exportar)',
                                  child: InkWell(
                                    onTap: () async {
                                      final jsonStr = notifier
                                          .exportMeasuresToJson();
                                      final storage = ref.read(
                                        fileStorageProvider,
                                      );
                                      final timestamp =
                                          DateTime.now().millisecondsSinceEpoch;
                                      await storage.saveFile(
                                        fileName: 'compases_$timestamp.json',
                                        content: jsonStr,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Compases guardados en formato JSON.',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const FaIcon(
                                        FontAwesomeIcons.floppyDisk,
                                        size: 13.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Tooltip(
                                  message:
                                      'Importar compases desde archivo JSON',
                                  child: InkWell(
                                    onTap: () async {
                                      final storage = ref.read(
                                        fileStorageProvider,
                                      );
                                      final content = await storage
                                          .pickTextFile(
                                            allowedExtensions: ['json'],
                                          );
                                      if (content != null &&
                                          content.isNotEmpty) {
                                        final success = notifier
                                            .loadMeasuresFromJson(content);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                success
                                                    ? 'Compases restaurados exitosamente desde JSON.'
                                                    : 'Error al importar: archivo JSON no válido.',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const FaIcon(
                                        FontAwesomeIcons.upload,
                                        size: 13.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                // Botón de edición a la derecha de importar compás
                                Tooltip(
                                  message: isEditActive
                                      ? 'Editar asignación múltiple de $chordToEdit'
                                      : 'Selecciona un acorde en el compás para editarlo',
                                  child: InkWell(
                                    key: const ValueKey(
                                      'edit_multi_beat_chord_btn',
                                    ),
                                    onTap: isEditActive
                                        ? () {
                                            final targetChord = chordToEdit;
                                            if (targetChord == null ||
                                                targetChord.isEmpty) {
                                              return;
                                            }
                                            final positions = <String>[];
                                            for (
                                              var m = 0;
                                              m < state.measures.length;
                                              m++
                                            ) {
                                              for (
                                                var b = 0;
                                                b <
                                                    state
                                                        .measures[m]
                                                        .beats
                                                        .length;
                                                b++
                                              ) {
                                                if (state
                                                        .measures[m]
                                                        .beats[b]
                                                        .chord
                                                        .trim() ==
                                                    targetChord) {
                                                  positions.add(
                                                    '${m + 1}.${b + 1}',
                                                  );
                                                }
                                              }
                                            }
                                            notifier.openMultiBeatModalForChord(
                                              targetChord,
                                              pattern: positions.join(', '),
                                            );
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isEditActive
                                            ? const Color(0xFF8B5CF6)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: isEditActive
                                              ? const Color(0xFF7C3AED)
                                              : const Color(0xFFCBD5E1),
                                          width: 1,
                                        ),
                                      ),
                                      child: FaIcon(
                                        FontAwesomeIcons.penToSquare,
                                        size: 13.5,
                                        color: isEditActive
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Tooltip(
                                  message: state.isMultiBeatAssignmentMode
                                      ? canInsertChord
                                            ? 'Asignar $constructorChord a $assignmentTargetCount caja${assignmentTargetCount == 1 ? '' : 's'}'
                                            : 'Selecciona las cajas de destino para asignar $constructorChord'
                                      : canInsertChord
                                      ? 'Agregar $constructorChord a $insertTargetLabel'
                                      : 'Selecciona un acorde y una casilla del Compás',
                                  child: InkWell(
                                    key: const ValueKey(
                                      'insert_chord_to_compas_btn',
                                    ),
                                    onTap: canInsertChord
                                        ? () {
                                            final symbol =
                                                state.isMultiBeatAssignmentMode
                                                ? notifier
                                                      .assignFreeChordToMultiBeatTargets()
                                                : notifier
                                                      .insertFreeChordIntoSelectedCell();
                                            if (symbol == null) return;
                                            ScaffoldMessenger.of(context)
                                              ..hideCurrentSnackBar()
                                              ..showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    state.isMultiBeatAssignmentMode
                                                        ? '$symbol asignado a $assignmentTargetCount caja${assignmentTargetCount == 1 ? '' : 's'}'
                                                        : '$symbol → $insertTargetLabel',
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 1400,
                                                  ),
                                                ),
                                              );
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: canInsertChord
                                            ? state.isMultiBeatAssignmentMode
                                                  ? const Color(0xFF7C3AED)
                                                  : const Color(0xFF16A34A)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: canInsertChord
                                              ? state.isMultiBeatAssignmentMode
                                                    ? const Color(0xFF6D28D9)
                                                    : const Color(0xFF16A34A)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: FaIcon(
                                        FontAwesomeIcons.plus,
                                        size: 13.5,
                                        color: canInsertChord
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Tooltip(
                                  message: state.isMultiBeatAssignmentMode
                                      ? 'Cancelar selección de cajas ($assignmentTargetCount seleccionada${assignmentTargetCount == 1 ? '' : 's'})'
                                      : 'Activar asignación múltiple de $constructorChord tocando sus cajas',
                                  child: InkWell(
                                    key: const ValueKey(
                                      'multi_beat_assignment_mode_btn',
                                    ),
                                    onTap: canToggleMultiBeatAssignment
                                        ? notifier.toggleMultiBeatAssignmentMode
                                        : null,
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: state.isMultiBeatAssignmentMode
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: state.isMultiBeatAssignmentMode
                                              ? const Color(0xFF6D28D9)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: FaIcon(
                                        FontAwesomeIcons.squareCheck,
                                        size: 13.5,
                                        color: canToggleMultiBeatAssignment
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Botón de borrado, casilla de selección masiva contigua y desmarcado.
                            // Si la casilla está marcada, borrar elimina todos los acordes;
                            // en caso contrario, solo los de las casillas marcadas.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasMarks) ...[
                                  _DeleteAllChordsButton(
                                    tooltip: allMarked
                                        ? 'Borrar todos los acordes (casilla marcada)'
                                        : 'Borrar acordes de las casillas marcadas',
                                    onTap: () {
                                      final deleted = allMarked
                                          ? notifier.deleteAllGridChords()
                                          : notifier.deleteMarkedGridChords();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            allMarked
                                                ? (deleted > 0
                                                      ? 'Acordes borrados de la cuadrícula.'
                                                      : 'La cuadrícula ya está vacía.')
                                                : (deleted > 0
                                                      ? 'Se borraron $deleted acordes de las casillas marcadas.'
                                                      : 'No hay casillas marcadas para borrar.'),
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                // Casilla al lado del botón borrar: marcada => borrar todo
                                _SelectAllBeatsButton(
                                  key: const ValueKey('select_all_beats_btn'),
                                  allMarked: allMarked,
                                  onTap: notifier.toggleAllBeatMarks,
                                ),
                                if (hasMarks) ...[
                                  const SizedBox(width: 3),
                                  // Desmarcar todas las casillas seleccionadas
                                  _ClearMarksButton(
                                    onTap: notifier.clearBeatMarks,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Matriz de botones de Tónica: 2 filas por 6 columnas (debajo de guardar / importar compás)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: widget.chordQualityLink == null
                            ? const TonicNotesMatrixWidget()
                            : CompositedTransformTarget(
                                link: widget.chordQualityLink!,
                                child: const TonicNotesMatrixWidget(),
                              ),
                      ),
                    ],
                  ),

                  if (state.yellowDecisionBeats.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF9C3),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFFDE047)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 11,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${state.yellowDecisionBeats.length} acordes abren o cierran',
                              style: const TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF92400E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            key: ValueKey(
                              'apply_yellow_pull_quick_${widget.accordionNumber}',
                            ),
                            onTap: () {
                              final n = notifier.applyYellowDecision(
                                BellowsMode.pull,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$n acordes asignados a Abre (←)',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Abre',
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          InkWell(
                            key: ValueKey(
                              'apply_yellow_push_quick_${widget.accordionNumber}',
                            ),
                            onTap: () {
                              final n = notifier.applyYellowDecision(
                                BellowsMode.push,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$n acordes asignados a Cierra (→)',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFFEF4444),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Cierra',
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3.0,
                      vertical: 4.0,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: CompasCardMetrics.gridMaxHeight,
                      ),
                      child: RawScrollbar(
                        controller: _compasScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        thickness:
                            8.0, // Aumentado ~30% sobre el grosor estándar (6.0px -> 8.0px)
                        radius: const Radius.circular(4),
                        thumbColor: const Color(0xFF94A3B8),
                        trackColor: const Color(0xFFF1F5F9),
                        trackBorderColor: const Color(0xFFE2E8F0),
                        padding: EdgeInsets.zero,
                        child: ListView.builder(
                          controller: _compasScrollController,
                          padding: const EdgeInsets.only(right: 12),
                          shrinkWrap: true,
                          itemCount: state.measures.length,
                          itemBuilder: (context, mIdx) {
                            final measure = state.measures[mIdx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Checkbox de marcado del compás, a la izquierda del
                                  // número: marca o desmarca los 4 tiempos del compás.
                                  Container(
                                    width: 15,
                                    height: CompasCardMetrics.beatCellHeight,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      border: Border(
                                        right: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: _BeatMarkCheckbox(
                                        key: ValueKey('measure_checkbox_$mIdx'),
                                        isChecked: notifier.isMeasureMarked(
                                          mIdx,
                                        ),
                                        onTap: () =>
                                            notifier.toggleMeasureMark(mIdx),
                                      ),
                                    ),
                                  ),

                                  // Número de compás
                                  Container(
                                    width: 18,
                                    height: CompasCardMetrics.beatCellHeight,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      border: Border(
                                        right: BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${measure.barNumber}',
                                        style: const TextStyle(
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 4 Cuadros del compás en fila horizontal, uno al lado
                                  // del otro; separados por un hueco que deja ver el
                                  // fondo del compás como divisor entre cuadros.
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (final entry
                                            in measure.beats
                                                .asMap()
                                                .entries) ...[
                                          if (entry.key > 0)
                                            const SizedBox(width: 1),
                                          Expanded(
                                            child: _InlineBeatChordEditor(
                                              accordionId:
                                                  widget.accordionNumber,
                                              measureIndex: mIdx,
                                              beatIndex: entry.key,
                                              totalMeasures:
                                                  state.measures.length,
                                              chord: entry.value.chord,
                                              timeText: entry.value.timeText,
                                              startTime: entry.value.startTime,
                                              endTime: entry.value.endTime,
                                              bellows: entry.value.bellows,
                                              isCurrentPlayhead:
                                                  state.isPlayingAudio &&
                                                  state.selectedBarIndex ==
                                                      mIdx &&
                                                  state.selectedBeatIndex ==
                                                      entry.key,
                                              isMarked: notifier.isBeatMarked(
                                                mIdx,
                                                entry.key,
                                              ),
                                              isMultiBeatAssignmentMode: state
                                                  .isMultiBeatAssignmentMode,
                                              isMultiBeatAssignmentTarget: state
                                                  .multiBeatAssignmentTargets
                                                  .contains(
                                                    AccordionSimulatorNotifier.beatKey(
                                                      mIdx,
                                                      entry.key,
                                                    ),
                                                  ),
                                              onToggleMultiBeatAssignmentTarget:
                                                  () => notifier
                                                      .toggleMultiBeatAssignmentTarget(
                                                        mIdx,
                                                        entry.key,
                                                      ),
                                              isYellowDecision: state
                                                  .yellowDecisionBeats
                                                  .contains(
                                                    mIdx * 4 + entry.key,
                                                  ),
                                              isSelected:
                                                  state.selectedBarIndex ==
                                                      mIdx &&
                                                  state.selectedBeatIndex ==
                                                      entry.key,
                                              notation: state.notation,
                                              onChanged: (newChord) {
                                                notifier.updateMeasureBeat(
                                                  mIdx,
                                                  entry.key,
                                                  newChord,
                                                );
                                              },
                                              onCopy: () =>
                                                  notifier.copyChordFromBeat(
                                                    mIdx,
                                                    entry.key,
                                                  ),
                                              onPaste: () =>
                                                  notifier.copiedChord,
                                              onSelected: () {
                                                notifier.selectBeat(
                                                  mIdx,
                                                  entry.key,
                                                );
                                              },
                                              onNavigate: (bar, beat) {
                                                notifier.selectBeat(bar, beat);
                                                _scrollToBar(bar);
                                              },
                                              onBellowsChanged: (bellows) {
                                                notifier.setBeatBellows(
                                                  mIdx,
                                                  entry.key,
                                                  bellows,
                                                );
                                              },
                                              onLiveMarker: () => notifier
                                                  .markLiveChordChange(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Volumen propio del Compás (pista + acordes marcados)
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 1, 6, 4),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.volumeLow,
                          size: 9,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: SizedBox(
                            height: 20,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 8,
                                ),
                                activeTrackColor: const Color(0xFF0284C7),
                                inactiveTrackColor: const Color(0xFFCBD5E1),
                                thumbColor: const Color(0xFF0284C7),
                              ),
                              child: Slider(
                                value: state.compasVolume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: notifier.setCompasVolume,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${(state.compasVolume * 100).toInt()}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Sección de Información debajo de la ventana de Compás:
          // Informa si el acorde está completo o incompleto según el fuelle (Abre y Cierra)
          _buildChordBellowsInfoCard(context, state, effectiveWidth),

          if (isPrimary) ...[
            const SizedBox(height: 6),
            // Sección de Detector de Acordes debajo de Estado del Acorde (desacoplable)
            if (!state.isChordDetectorUndocked)
              ChordDetectorWidget(width: effectiveWidth)
            else
              _buildDetectorDockPlaceholder(context, effectiveWidth, notifier),
          ],
        ],
      ),
    );
  }

  /// Marcador de posición cuando el Detector de Acordes está desacoplado (flotante).
  Widget _buildDetectorDockPlaceholder(
    BuildContext context,
    double effectiveWidth,
    AccordionSimulatorNotifier notifier,
  ) {
    return Container(
      width: effectiveWidth,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.microchip,
                  size: 9,
                  color: Color(0xFF7C3AED),
                ),
                SizedBox(width: 4),
                Text(
                  'Detector (Móvil)',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            InkWell(
              key: const ValueKey('re_dock_detector_btn'),
              onTap: notifier.toggleUndockChordDetector,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFC4B5FD),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Acoplar',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sección informativa que reporta si el acorde está completo o incompleto según el fuelle.
  Widget _buildChordBellowsInfoCard(
    BuildContext context,
    AccordionSimulatorState state,
    double cardWidth,
  ) {
    final isPrimary = widget.accordionNumber == 1;
    final treble = isPrimary ? state.trebleData1 : state.trebleData2;
    final notation = state.notation;
    final isLatin = notation != NotationMode.alemana;

    // Determinar qué acorde inspeccionar:
    // 1) Tiempo seleccionado en el Compás
    // 2) Acorde activo del constructor libre
    final selectedBar = state.selectedBarIndex;
    final selectedBeat = state.selectedBeatIndex;
    MeasureBeat? activeBeat;
    if (selectedBar != null &&
        selectedBeat != null &&
        selectedBar >= 0 &&
        selectedBar < state.measures.length) {
      final row = state.measures[selectedBar];
      if (selectedBeat >= 0 && selectedBeat < row.beats.length) {
        activeBeat = row.beats[selectedBeat];
      }
    }

    String targetChord = '';
    BellowsMode targetBellows = isPrimary ? state.bellows1 : state.bellows2;
    String contextLabel = '';

    if (activeBeat != null && activeBeat.chord.trim().isNotEmpty) {
      targetChord = activeBeat.chord.trim();
      targetBellows = activeBeat.bellows != BellowsMode.both
          ? activeBeat.bellows
          : targetBellows;
      contextLabel = 'C${activeBeat.barIndex + 1}.${activeBeat.beatIndex + 1}';
    } else {
      targetChord = ChordCatalog.symbolFor(
        root: state.freeChordRoot,
        type: state.freeChordType,
        extension: state.freeChordFourth,
        bass: state.freeChordBass,
        latin: isLatin,
        display: true,
      );
      contextLabel = 'Constructor';
    }

    // Clases de altura disponibles físicamente en el diapasón según el fuelle
    final pullPcs = <int>{};
    final pushPcs = <int>{};
    for (final row in treble.values) {
      for (final btn in row) {
        pullPcs.add(btn.pull % 12);
        pushPcs.add(btn.push % 12);
      }
    }

    final chordPcs = ChordCatalog.pitchClassesForChordSymbol(targetChord);
    final hasTarget = targetChord.isNotEmpty && chordPcs.isNotEmpty;

    final missingPush = chordPcs.difference(pushPcs);
    final missingPull = chordPcs.difference(pullPcs);
    final isCompletePush = hasTarget && missingPush.isEmpty;
    final isCompletePull = hasTarget && missingPull.isEmpty;

    final namesList = isLatin
        ? ChordCatalog.latinRootNames
        : ChordCatalog.germanRootNames;
    final chordNoteNames = chordPcs.map((pc) => namesList[pc]).toList();
    final missingPushNames = missingPush.map((pc) => namesList[pc]).toList();
    final missingPullNames = missingPull.map((pc) => namesList[pc]).toList();

    final isSelectedPull = targetBellows == BellowsMode.pull;
    final isSelectedPush = targetBellows == BellowsMode.push;
    final currentIsComplete = isSelectedPull
        ? isCompletePull
        : (isSelectedPush
              ? isCompletePush
              : (isCompletePush || isCompletePull));

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: !hasTarget
              ? const Color(0xFFCBD5E1)
              : (currentIsComplete
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFCA5A5)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.circleInfo,
                  size: 9.5,
                  color: !hasTarget
                      ? const Color(0xFF64748B)
                      : (currentIsComplete
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626)),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Estado del Acorde',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (contextLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      contextLabel,
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (!hasTarget)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Selecciona un compás o acorde para ver disponibilidad por fuelle.',
                style: TextStyle(
                  fontSize: 8.0,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Acorde: $targetChord',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${chordNoteNames.join('·')})',
                    style: const TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            _buildBellowsCompletenessRow(
              label: 'Cierra',
              isPush: true,
              isComplete: isCompletePush,
              isTargetBellows: isSelectedPush,
              missingNames: missingPushNames,
              totalNotes: chordPcs.length,
            ),
            const SizedBox(height: 3),
            _buildBellowsCompletenessRow(
              label: 'Abre',
              isPush: false,
              isComplete: isCompletePull,
              isTargetBellows: isSelectedPull,
              missingNames: missingPullNames,
              totalNotes: chordPcs.length,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBellowsCompletenessRow({
    required String label,
    required bool isPush,
    required bool isComplete,
    required bool isTargetBellows,
    required List<String> missingNames,
    required int totalNotes,
  }) {
    final accentColor = isPush
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);
    final badgeBg = isComplete
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);
    final badgeFg = isComplete
        ? const Color(0xFF15803D)
        : const Color(0xFFB91C1C);
    final presentCount = totalNotes - missingNames.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: isTargetBellows
            ? (isPush ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF))
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isTargetBellows ? accentColor : const Color(0xFFE2E8F0),
          width: isTargetBellows ? 1.2 : 0.8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              isPush ? FontAwesomeIcons.arrowRight : FontAwesomeIcons.arrowLeft,
              size: 7.5,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    isComplete
                        ? FontAwesomeIcons.check
                        : FontAwesomeIcons.xmark,
                    size: 6.5,
                    color: badgeFg,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isComplete
                        ? 'Completo'
                        : 'Incompleto ($presentCount/$totalNotes)',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: badgeFg,
                    ),
                  ),
                ],
              ),
            ),
            if (!isComplete && missingNames.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                'Falta: ${missingNames.join(',')}',
                style: const TextStyle(
                  fontSize: 7.0,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Control de BPM compacto y editable con cuadro de texto y botones de subir / bajar
class _BpmInputControl extends StatefulWidget {
  final int bpm;
  final ValueChanged<int> onChanged;
  final bool compact;

  const _BpmInputControl({
    required this.bpm,
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<_BpmInputControl> createState() => _BpmInputControlState();
}

class _BpmInputControlState extends State<_BpmInputControl> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.bpm.toString());
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _commitValue();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _BpmInputControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm && !_focusNode.hasFocus) {
      _controller.text = widget.bpm.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitValue() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed >= 30 && parsed <= 300) {
      widget.onChanged(parsed);
    } else {
      _controller.text = widget.bpm.toString();
    }
  }

  void _step(int delta) {
    final current = int.tryParse(_controller.text.trim()) ?? widget.bpm;
    final next = (current + delta).clamp(30, 300);
    _controller.text = next.toString();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.9),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.compact) ...[
            const Text(
              'BPM',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 2),
          ],
          // Cuadro de texto editable
          SizedBox(
            width: 32,
            height: 18,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _commitValue(),
            ),
          ),
          // Flechas subir / bajar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _step(1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: FaIcon(
                    FontAwesomeIcons.caretUp,
                    size: 8,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _step(-1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1),
                  child: FaIcon(
                    FontAwesomeIcons.caretDown,
                    size: 8,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modificadores de cualidad y extensión armónica para digitación rápida
enum _ChordModKey {
  mayor, // '0'
  menor, // '.' o ','
  septima, // '/'
  aumentada, // '+'
  disminuida, // '-'
  sus, // '8'
  cuarta, // '9'
}

class _ChordTools {
  static const roots = [
    'Do#',
    'Dob',
    'Do♭',
    'Do',
    'Re#',
    'Reb',
    'Re♭',
    'Re',
    'Mi#',
    'Mib',
    'Mi♭',
    'Mi',
    'Fa#',
    'Fab',
    'Fa♭',
    'Fa',
    'Sol#',
    'Solb',
    'Sol♭',
    'Sol',
    'La#',
    'Lab',
    'La♭',
    'La',
    'Si#',
    'Sib',
    'Si♭',
    'Si',
    'C#',
    'Db',
    'C♭',
    'C',
    'D#',
    'Eb',
    'D♭',
    'D',
    'E#',
    'Eb',
    'E♭',
    'E',
    'F#',
    'Fb',
    'F♭',
    'F',
    'G#',
    'Gb',
    'G♭',
    'G',
    'A#',
    'Ab',
    'A♭',
    'A',
    'B#',
    'Bb',
    'B♭',
    'B',
  ];

  static (String, String) splitChord(String chord) {
    final trimmed = chord.trim();
    for (final r in roots) {
      if (trimmed.startsWith(r)) {
        return (r, trimmed.substring(r.length));
      }
    }
    return ('', trimmed);
  }

  static _ChordModKey? parseModifierKey(KeyEvent event) {
    final char = event.character;
    if (char == '.' || char == ',') return _ChordModKey.menor;
    if (char == '/') return _ChordModKey.septima;
    if (char == '+') return _ChordModKey.aumentada;
    if (char == '-') return _ChordModKey.disminuida;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.comma) {
      return _ChordModKey.menor;
    }
    if (key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide) {
      return _ChordModKey.septima;
    }
    if (key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
      return _ChordModKey.aumentada;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      return _ChordModKey.disminuida;
    }
    return null;
  }

  static String applyModifier(
    String chord,
    _ChordModKey mod,
    NotationMode notation,
  ) {
    var (root, rest) = splitChord(chord);
    if (root.isEmpty) {
      root = notation == NotationMode.alemana ? 'C' : 'Do';
    }

    final has7 = rest.contains('7');

    switch (mod) {
      case _ChordModKey.mayor:
        // Cero para Mayor: limpia menor (m), dim, aug, sus y deja la tríada mayor
        return has7 ? '${root}7' : root;

      case _ChordModKey.menor:
        // Punto para menor: 'm'
        return has7 ? '${root}m7' : '${root}m';

      case _ChordModKey.septima:
        // Barra diagonal con la 7ma: conmuta la séptima
        if (has7) {
          return root + rest.replaceAll('7', '');
        } else {
          return '$root$rest 7'.replaceAll(' ', '');
        }

      case _ChordModKey.aumentada:
        // Más para Aumentada: 'aug'
        if (rest.contains('aug')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}aug7' : '${root}aug';

      case _ChordModKey.disminuida:
        // Menos para Disminuida: 'dim'
        if (rest.contains('dim')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}dim7' : '${root}dim';

      case _ChordModKey.sus:
        // 8 para Sus: 'sus'
        if (rest.contains('sus')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}sus7' : '${root}sus';

      case _ChordModKey.cuarta:
        // 9 para la Cuarta: '4' o 'sus4'
        if (rest.contains('sus')) {
          return has7 ? '${root}sus47' : '${root}sus4';
        }
        if (rest.contains('4')) {
          return root + (has7 ? '7' : '');
        }
        return has7 ? '${root}47' : '${root}4';
    }
  }
}

/// Celda de tiempo/acorde editable en línea: al hacer clic recibe foco directamente
/// sin abrir ningún diálogo modal.
class _InlineBeatChordEditor extends StatefulWidget {
  final int accordionId;
  final int measureIndex;
  final int beatIndex;
  final int totalMeasures;
  final String chord;
  final String timeText;
  final double? startTime;
  final double? endTime;
  final BellowsMode bellows;
  final bool isMultiBeatAssignmentMode;
  final bool isMultiBeatAssignmentTarget;
  final bool isCurrentPlayhead;
  final bool isMarked;
  final bool isYellowDecision;
  final bool isSelected;
  final NotationMode notation;
  final ValueChanged<String> onChanged;
  final VoidCallback? onToggleMultiBeatAssignmentTarget;
  final String? Function()? onCopy;
  final String? Function()? onPaste;
  final VoidCallback? onSelected;
  final void Function(int bar, int beat)? onNavigate;
  final ValueChanged<BellowsMode>? onBellowsChanged;
  final VoidCallback? onLiveMarker;

  const _InlineBeatChordEditor({
    required this.accordionId,
    required this.measureIndex,
    required this.beatIndex,
    required this.totalMeasures,
    required this.chord,
    required this.timeText,
    this.startTime,
    this.endTime,
    this.bellows = BellowsMode.both,
    this.isMultiBeatAssignmentMode = false,
    this.isMultiBeatAssignmentTarget = false,
    required this.isCurrentPlayhead,
    required this.isMarked,
    this.isYellowDecision = false,
    this.isSelected = false,
    this.notation = NotationMode.latina,
    required this.onChanged,
    this.onToggleMultiBeatAssignmentTarget,
    this.onCopy,
    this.onPaste,
    this.onSelected,
    this.onNavigate,
    this.onBellowsChanged,
    this.onLiveMarker,
  });

  @override
  State<_InlineBeatChordEditor> createState() => _InlineBeatChordEditorState();
}

class _InlineBeatChordEditorState extends State<_InlineBeatChordEditor> {
  // Registro separado por accordionId para evitar interferencia entre acordeones
  static final Map<int, Map<String, _InlineBeatChordEditorState>> _registries =
      {};
  static final Map<int, String?> _selectedKeys = {};

  Map<String, _InlineBeatChordEditorState> get _registry =>
      _registries.putIfAbsent(widget.accordionId, () => {});

  String? get _selectedKey => _selectedKeys[widget.accordionId];
  set _selectedKey(String? val) => _selectedKeys[widget.accordionId] = val;

  late TextEditingController _controller;
  late final FocusNode _focusNode;
  late final FocusNode _cellFocusNode;
  bool _isEditing = false;

  String get _nodeKey => '${widget.measureIndex}_${widget.beatIndex}';
  bool get _isSelected => widget.isSelected;
  bool get _isCellHighlighted => _isSelected && !_isEditing;

  /// Deselecciona de forma exclusiva todos los demás cuadros y textboxes del acordeón.
  /// Garantiza que al seleccionar un textbox u otro cuadro, el anterior quede totalmente deseleccionado.
  void _deselectOtherCells() {
    for (final entry in _registry.entries) {
      if (entry.key != _nodeKey) {
        entry.value._setIdle();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _registry[_nodeKey] = this;
    final initialChord = ChordCatalog.formatChordForNotation(
      widget.chord,
      widget.notation,
    );
    _controller = TextEditingController(text: initialChord);

    _cellFocusNode = FocusNode(debugLabel: 'beat_cell_$_nodeKey');
    _cellFocusNode.onKeyEvent = _handleCellKeyEvent;

    _focusNode = FocusNode(debugLabel: 'beat_text_$_nodeKey');
    _focusNode.onKeyEvent = _handleTextFieldKeyEvent;

    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      if (hasFocus) {
        if (widget.isMultiBeatAssignmentMode) {
          _focusNode.unfocus();
          return;
        }
        _selectedKey = _nodeKey;
        _deselectOtherCells();
        if (!_isEditing) {
          _isEditing = true;
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
        _update();
      } else {
        if (_isEditing) {
          _isEditing = false;
          _controller.selection = const TextSelection.collapsed(offset: -1);
          _commit();
          _update();
        }
      }
    });

    _cellFocusNode.addListener(() {
      if (_cellFocusNode.hasFocus) {
        if (widget.isMultiBeatAssignmentMode) {
          _cellFocusNode.unfocus();
          return;
        }
        if (_selectedKey != _nodeKey) {
          _selectedKey = _nodeKey;
          _deselectOtherCells();
          _update();
        }
      } else {
        _update();
      }
    });

    if (widget.isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activateEdit();
      });
    }
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _InlineBeatChordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measureIndex != widget.measureIndex ||
        oldWidget.beatIndex != widget.beatIndex) {
      _registry.remove('${oldWidget.measureIndex}_${oldWidget.beatIndex}');
      _registry[_nodeKey] = this;
    }
    if (!oldWidget.isMultiBeatAssignmentMode &&
        widget.isMultiBeatAssignmentMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isMultiBeatAssignmentMode) _setIdle();
      });
    }
    final formattedChord = ChordCatalog.formatChordForNotation(
      widget.chord,
      widget.notation,
    );
    if ((oldWidget.chord != widget.chord ||
            oldWidget.notation != widget.notation) &&
        !_isEditing) {
      _controller.value = TextEditingValue(
        text: formattedChord,
        selection: const TextSelection.collapsed(offset: -1),
      );
    }
    if (widget.isSelected && !oldWidget.isSelected && !_isEditing) {
      _selectedKey = _nodeKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isSelected && !_isEditing) {
          _activateEdit(notifySelection: false);
        }
      });
    } else if (!widget.isSelected && oldWidget.isSelected) {
      if (_selectedKey == _nodeKey) {
        _selectedKey = null;
      }
      _setIdle();
    }
  }

  @override
  void dispose() {
    _registry.remove(_nodeKey);
    if (_selectedKey == _nodeKey) {
      _selectedKey = null;
    }
    _controller.dispose();
    _focusNode.dispose();
    _cellFocusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final trimmed = _controller.text.trim();
    final formatted = ChordCatalog.formatChordForNotation(
      trimmed,
      widget.notation,
    );
    if (formatted != widget.chord) {
      widget.onChanged(formatted);
    }
  }

  void _moveSelection(int delta) {
    _commit();
    final currentIndex = widget.measureIndex * 4 + widget.beatIndex;
    final totalSlots = widget.totalMeasures * 4;
    final nextIndex = currentIndex + delta;

    if (nextIndex >= 0 && nextIndex < totalSlots) {
      final nextM = nextIndex ~/ 4;
      final nextB = nextIndex % 4;
      final targetKey = '${nextM}_$nextB';

      _selectedKey = targetKey;
      _deselectOtherCells();

      widget.onNavigate?.call(nextM, nextB);

      final targetState = _registry[targetKey];
      if (targetState != null) {
        targetState._activateEdit();
      }
    }
  }

  void _setSelected() {
    _commit();
    _selectedKey = _nodeKey;
    _deselectOtherCells();
    _isEditing = false;
    _controller.selection = const TextSelection.collapsed(offset: -1);
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _cellFocusNode.requestFocus();
    widget.onSelected?.call();
    if (mounted) {
      setState(() {});
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
      );
    }
  }

  void _setIdle() {
    _isEditing = false;
    _controller.selection = const TextSelection.collapsed(offset: -1);
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    if (_cellFocusNode.hasFocus) {
      _cellFocusNode.unfocus();
    }
    if (mounted) setState(() {});
  }

  void _activateEdit({bool notifySelection = true}) {
    if (widget.isMultiBeatAssignmentMode) return;
    _selectedKey = _nodeKey;
    _deselectOtherCells();
    if (notifySelection) widget.onSelected?.call();
    _isEditing = true;
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    if (mounted) {
      setState(() {});
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
      );
    }
  }

  void _applyChord(String chord) {
    final formatted = ChordCatalog.formatChordForNotation(
      chord,
      widget.notation,
    );
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged(formatted);
    if (mounted) setState(() {});
  }

  KeyEventResult _handleChordClipboardKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        !(HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final copied = widget.onCopy?.call();
      return copied == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      final chord = widget.onPaste?.call();
      if (chord == null) return KeyEventResult.ignored;
      _applyChord(chord);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCellKeyEvent(FocusNode node, KeyEvent event) {
    final clipboardResult = _handleChordClipboardKeyEvent(event);
    if (clipboardResult == KeyEventResult.handled) return clipboardResult;
    if (_isEditing) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      // Modificadores armónicos: . Menor, / 7ma, + Aumentada, - Disminuida
      final mod = _ChordTools.parseModifierKey(event);
      if (mod != null) {
        final updated = _ChordTools.applyModifier(
          _controller.text,
          mod,
          widget.notation,
        );
        _applyChord(updated);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        widget.onLiveMarker?.call();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        _applyChord('');
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Flecha izquierda: pone en foco el cuadro seleccionado para edición
        _activateEdit();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Flecha derecha: permanece el cuadro seleccionado con su foco activo
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Flecha abajo: navega al compás/cuadro siguiente
        _moveSelection(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Flecha arriba: sube al compás/cuadro anterior
        _moveSelection(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        // Tab / Shift+Tab para navegar adelante / atrás
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        _moveSelection(isShift ? -1 : 1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _activateEdit();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTextFieldKeyEvent(FocusNode node, KeyEvent event) {
    final clipboardResult = _handleChordClipboardKeyEvent(event);
    if (clipboardResult == KeyEventResult.handled) return clipboardResult;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Flecha derecha: saca de foco de edición, pero permanece el cuadro seleccionado
        _commit();
        _setSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Flecha abajo: sube/baja y cambia al compás/cuadro siguiente
        _moveSelection(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Flecha arriba: sube al compás/cuadro anterior
        _moveSelection(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        // Tab / Shift+Tab para navegar adelante / atrás
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        _commit();
        _moveSelection(isShift ? -1 : 1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Escape: saca de foco de edición pero mantiene cuadro seleccionado
        _commit();
        _setSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _commit();
        _moveSelection(1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasChord = widget.chord.isNotEmpty;
    final isPlaying = widget.isCurrentPlayhead;
    final isCellSelected = _isCellHighlighted;
    final isFocusedOrSelected = _isEditing || isCellSelected;
    final isAssignmentTarget = widget.isMultiBeatAssignmentTarget;
    final isMarked = widget.isMarked;

    return Focus(
      focusNode: _cellFocusNode,
      child: GestureDetector(
        onTap: () {
          if (widget.isMultiBeatAssignmentMode) {
            widget.onToggleMultiBeatAssignmentTarget?.call();
          } else {
            _activateEdit();
          }
        },
        child: AnimatedContainer(
          key: ValueKey('beat_cell_${widget.measureIndex}_${widget.beatIndex}'),
          duration: const Duration(milliseconds: 120),
          // Altura mínima un 5% mayor; se permite crecer si el contenido interno
          // (ej. flechas de fuelle en modo compacto) supera el mínimo. {P} C {Q}
          constraints: const BoxConstraints(
            minHeight: CompasCardMetrics.beatCellHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            // Radio condicional: bordes "Stateful" no ocasionan problemas; el
            // divisor entre cuadros es un hueco (no un borde), así que el
            // radio siempre se admite sobre bordes uniformes.
            borderRadius: BorderRadius.circular(4),
            color: isAssignmentTarget
                ? const Color(0xFFF3E8FF)
                : (isCellSelected
                      ? const Color(
                          0xFFDBEAFE,
                        ) // Resaltado azul suave y vivo para cuadro seleccionado
                      : (_isEditing
                            ? Colors
                                  .white // Fondo blanco limpio al editar
                            : (isPlaying
                                  ? const Color(0xFFFEF3C7)
                                  : (widget.isYellowDecision
                                        ? const Color(
                                            0xFFFEF08A,
                                          ) // Resaltado amarillo para decidir fuelle
                                        : (isMarked
                                              ? const Color(
                                                  0xFFF0FDF4,
                                                ) // Tiempo marcado con el checkbox
                                              : Colors.white))))),
            border: isAssignmentTarget
                ? Border.all(color: const Color(0xFF7C3AED), width: 1.8)
                : (isCellSelected
                      ? Border.all(
                          color: const Color(0xFF2563EB),
                          width: 1.8,
                        ) // Cuadro resaltado nítido con borde completo
                      : (_isEditing
                            ? Border.all(
                                color: const Color(0xFF3B82F6),
                                width: 1.8,
                              ) // Borde activo de edición
                            : (isPlaying
                                  ? Border.all(
                                      color: const Color(0xFFF59E0B),
                                      width: 1.8,
                                    )
                                  : (widget.isYellowDecision
                                        ? Border.all(
                                            color: const Color(0xFFEAB308),
                                            width: 1.8,
                                          ) // Borde amarillo dorado
                                        : (isMarked
                                              ? Border.all(
                                                  color: const Color(
                                                    0xFF059669,
                                                  ),
                                                  width: 1.2,
                                                )
                                              : Border.all(
                                                  color: Colors.transparent,
                                                  width: 0.8,
                                                )))))),
            boxShadow: isAssignmentTarget
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
                      blurRadius: 4,
                      spreadRadius: 0.8,
                    ),
                  ]
                : (isCellSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.28),
                            blurRadius: 4,
                            spreadRadius: 0.8,
                          ),
                        ]
                      : (widget.isYellowDecision
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEAB308,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  spreadRadius: 0.8,
                                ),
                              ]
                            : (_isEditing
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.20),
                                        blurRadius: 3,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // El ancho disponible determina el modo de la celda del cuadro:
              // - >= 65px: fila horizontal clásica (acorde a la izquierda + fuelle).
              // - < 65px (los 4 cuadros en fila uno al lado del otro): celda
              //   compacta vertical con el acorde centrado; el tiempo y el
              //   fuelle se ocultan si no caben. La marcación por checkbox vive
              //   a la izquierda del número del compás, no en la celda.
              final showArrows = constraints.maxWidth >= 110;
              final showCompactArrows = constraints.maxWidth >= 52;
              final showTime = constraints.maxWidth >= 155;
              final chordTextWidth =
                  (constraints.maxWidth - (showArrows ? 30 : 0)).clamp(
                    1.0,
                    double.infinity,
                  );
              final chordFontSize = ChordTextFitter.fitFontSize(
                text: _controller.text,
                availableWidth: chordTextWidth,
                baseFontSize: 10,
                minFontSize: 6,
              );

              final chordField = Tooltip(
                message: hasChord
                    ? 'Acorde: ${widget.chord} · Ctrl+C copiar · Ctrl+V pegar'
                    : 'Ctrl+V pegar acorde copiado',
                waitDuration: const Duration(milliseconds: 600),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: widget.isMultiBeatAssignmentMode || !_isEditing,
                  textAlignVertical: TextAlignVertical.center,
                  textAlign: showArrows ? TextAlign.start : TextAlign.center,
                  onTap: () {
                    if (widget.isMultiBeatAssignmentMode) {
                      widget.onToggleMultiBeatAssignmentTarget?.call();
                    } else if (!_isEditing) {
                      _activateEdit();
                    }
                  },
                  style: TextStyle(
                    fontSize: chordFontSize,
                    letterSpacing: -0.2,
                    fontWeight: (isFocusedOrSelected || hasChord)
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: isAssignmentTarget
                        ? const Color(0xFF6D28D9)
                        : (isPlaying
                              ? const Color(0xFFB45309)
                              : (isFocusedOrSelected
                                    ? const Color(0xFF1D4ED8)
                                    : (hasChord
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF94A3B8)))),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '-',
                    hintStyle: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    _commit();
                  },
                  onSubmitted: (_) {
                    _commit();
                    _moveSelection(1);
                  },
                ),
              );

              final bellowsArrows = _BeatBellowsArrows(
                bellows: widget.bellows,
                isEnabled: hasChord,
                onBellowsChanged: hasChord ? widget.onBellowsChanged : null,
              );

              if (showArrows) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Acorde del cuadro, alineado a la izquierda (sin checkbox:
                    // el marcado vive a la izquierda del número del compás)
                    Expanded(
                      child: IgnorePointer(
                        ignoring: widget.isMultiBeatAssignmentMode,
                        child: chordField,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showTime) ...[
                          InkWell(
                            onTap: () => _showBeatTimingDialog(context),
                            child: Tooltip(
                              message: 'Editar tiempo del compás: ${widget.timeText}',
                              child: Text(
                                widget.timeText,
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: isCellSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isCellSelected
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF64748B),
                                  fontFamily: 'monospace',
                                  decoration: TextDecoration.underline,
                                  decorationStyle: TextDecorationStyle.dotted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                        ],
                        // Flechas Abre/Cierre a la derecha del acorde
                        Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: bellowsArrows,
                        ),
                      ],
                    ),
                  ],
                );
              }

              // Modo compacto: los 4 cuadros del compás en fila horizontal.
              // Únicamente el acorde centrado y (si cabe) el fuelle debajo:
              // la celda no lleva checkbox.
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IgnorePointer(
                    ignoring: widget.isMultiBeatAssignmentMode,
                    child: chordField,
                  ),
                  if (showCompactArrows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: bellowsArrows,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBeatTimingDialog(BuildContext context) {
    final defaultStart = widget.startTime ?? ((widget.measureIndex * 4 + widget.beatIndex) * 0.5);
    final defaultEnd = widget.endTime ?? (defaultStart + 0.5);

    final startCtrl = TextEditingController(text: defaultStart.toStringAsFixed(2));
    final endCtrl = TextEditingController(text: defaultEnd.toStringAsFixed(2));

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Editar Tiempo Compás ${widget.measureIndex + 1}.${widget.beatIndex + 1}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajusta los segundos de inicio y fin para sincronizar exactamente con el audio.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: startCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tiempo Inicio (segundos)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_outlined, size: 16),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: endCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tiempo Fin (segundos)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_off_outlined, size: 16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final s = double.tryParse(startCtrl.text.trim());
              final e = double.tryParse(endCtrl.text.trim());
              if (s != null && e != null && s >= 0 && s <= e) {
                // Notifier actualización formal mediante Hoare Triples
                final notifier = ProviderScope.containerOf(context, listen: false)
                    .read(accordionSimulatorProvider.notifier);
                notifier.updateMeasureBeatTiming(
                  barIndex: widget.measureIndex,
                  beatIndex: widget.beatIndex,
                  startTime: s,
                  endTime: e,
                );
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

/// Flechas de Abre (←) y Cierre (→) a la derecha de la casilla de verificación
/// para definir la dirección del fuelle del acorde.
/// Solo son válidas/interactivas para tiempos que tengan un acorde registrado.
class _BeatBellowsArrows extends StatelessWidget {
  final BellowsMode bellows;
  final bool isEnabled;
  final ValueChanged<BellowsMode>? onBellowsChanged;

  const _BeatBellowsArrows({
    required this.bellows,
    this.isEnabled = true,
    this.onBellowsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPull = isEnabled && bellows == BellowsMode.pull;
    final isPush = isEnabled && bellows == BellowsMode.push;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flecha Abre (Pull) - Izquierda Azul
          Tooltip(
            message: isEnabled
                ? 'Abre (Fuelle abriendo)'
                : 'Asigna un acorde al tiempo para definir el fuelle',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isEnabled
                  ? () => onBellowsChanged?.call(BellowsMode.pull)
                  : null,
              child: Container(
                width: 13.5,
                height: 13.5,
                decoration: BoxDecoration(
                  color: isPull ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isPull
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.arrowLeft,
                    size: 7.0,
                    color: isPull
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Flecha Cierre (Push) - Derecha Roja
          Tooltip(
            message: isEnabled
                ? 'Cierra (Fuelle cerrando)'
                : 'Asigna un acorde al tiempo para definir el fuelle',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isEnabled
                  ? () => onBellowsChanged?.call(BellowsMode.push)
                  : null,
              child: Container(
                width: 13.5,
                height: 13.5,
                decoration: BoxDecoration(
                  color: isPush ? const Color(0xFFFEF2F2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isPush
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.arrowRight,
                    size: 7.0,
                    color: isPush
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF94A3B8),
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

/// Checkbox compacto para marcar un tiempo del Compás.
/// Optimizado con área táctil cómoda y respuesta instantánea sin retrasos.
class _BeatMarkCheckbox extends StatelessWidget {
  final bool isChecked;
  final VoidCallback? onTap;

  const _BeatMarkCheckbox({super.key, required this.isChecked, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: isChecked,
      label: 'Seleccionar tiempo',
      child: GestureDetector(
        onTapDown: (_) => onTap?.call(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isChecked ? const Color(0xFF059669) : Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isChecked
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8),
                width: 1.2,
              ),
            ),
            child: isChecked
                ? const Center(
                    child: FaIcon(
                      FontAwesomeIcons.check,
                      size: 8,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado de la minibarra que marca o desmarca todos los checkboxes
/// de la cuadrícula del Compás.
class _SelectAllBeatsButton extends StatelessWidget {
  final bool allMarked;
  final VoidCallback onTap;

  const _SelectAllBeatsButton({
    super.key,
    required this.allMarked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: allMarked ? 'Deseleccionar todos' : 'Seleccionar todos',
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          checked: allMarked,
          label: 'Seleccionar todos los tiempos',
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: allMarked ? const Color(0xFF0284C7) : Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: allMarked
                    ? const Color(0xFF0369A1)
                    : const Color(0xFF94A3B8),
                width: 1.2,
              ),
            ),
            child: allMarked
                ? const Center(
                    child: FaIcon(
                      FontAwesomeIcons.check,
                      size: 8,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado rojo con icono de basura de la minibarra: borra los acordes
/// según el estado de la casilla de selección masiva contigua. Si la casilla
/// está marcada borra todos los acordes de la cuadrícula; en caso contrario
/// solo borra los acordes de las casillas marcadas directamente.
class _DeleteAllChordsButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;

  const _DeleteAllChordsButton({
    required this.onTap,
    this.tooltip = 'Borrar acordes',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: const ValueKey('delete_grid_chords_btn'),
      message: tooltip,
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFB91C1C), width: 1.2),
          ),
          child: const Center(
            child: FaIcon(FontAwesomeIcons.trash, size: 8, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Botón naranja con ícono de deselección: desmarca todas las casillas
/// marcadas en la cuadrícula del Compás sin borrar los acordes escritos.
class _ClearMarksButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearMarksButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Desmarcar selección',
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFD97706), width: 1.2),
          ),
          child: const Center(
            child: FaIcon(
              FontAwesomeIcons.squareXmark,
              size: 8,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón y menú de opciones para gestionar acordes completos según el fuelle
/// colocado inmediatamente a la derecha del control de BPM.
class _CompleteChordsButton extends ConsumerWidget {
  final int accordionNumber;
  final bool hasYellowDecisions;
  final int yellowDecisionsCount;

  const _CompleteChordsButton({
    required this.accordionNumber,
    required this.hasYellowDecisions,
    required this.yellowDecisionsCount,
  });

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    switch (action) {
      case 'assign':
        final res = notifier.assignCompleteChordsBellows(accordionNumber);
        final assigned = res['assigned'] ?? 0;
        final yellow = res['yellow'] ?? 0;
        final incomplete = res['incomplete'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$assigned acordes asignados. $yellow en amarillo (abren o cierran) para decidir. $incomplete incompletos.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        break;
      case 'select':
        final count = notifier.selectCompleteChordsBeats(accordionNumber);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count tiempos con acordes completos seleccionados en el compás.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'mark_yellow':
        final count = notifier.markYellowDecisionBeats(accordionNumber);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count acordes completos abriendo o cerrando marcados en amarillo.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'apply_pull':
        final count = notifier.applyYellowDecision(BellowsMode.pull);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count acordes amarillos aplicados a Abre (←).'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'apply_push':
        final count = notifier.applyYellowDecision(BellowsMode.push);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count acordes amarillos aplicados a Cierra (→).'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'clear_yellow':
        notifier.clearYellowDecisionBeats();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marcas amarillas de decisión eliminadas.'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: ValueKey('complete_chords_btn_$accordionNumber'),
      tooltip: 'Opciones de Acordes Completos por Fuelle',
      offset: const Offset(0, 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
      onSelected: (val) => _handleAction(context, ref, val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: hasYellowDecisions ? const Color(0xFFFEF9C3) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: hasYellowDecisions
                ? const Color(0xFFEAB308)
                : const Color(0xFFCBD5E1),
            width: hasYellowDecisions ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.checkDouble,
              size: 8.5,
              color: hasYellowDecisions
                  ? const Color(0xFFB45309)
                  : const Color(0xFF0284C7),
            ),
            if (hasYellowDecisions) ...[
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2.5,
                  vertical: 0.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$yellowDecisionsCount',
                  style: const TextStyle(
                    fontSize: 7.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          key: ValueKey('assign_complete_chords_opt'),
          value: 'assign',
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.wandMagicSparkles,
                size: 12,
                color: Color(0xFF0284C7),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asignar acordes completos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Auto-asigna unívocos y marca amarillos para decidir',
                      style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          key: ValueKey('select_complete_chords_opt'),
          value: 'select',
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.squareCheck,
                size: 12,
                color: Color(0xFF059669),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar en compás',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Marca checkboxes de tiempos con notas completas',
                      style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          key: ValueKey('mark_yellow_chords_opt'),
          value: 'mark_yellow',
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.circleExclamation,
                size: 12,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marcar amarillos para decidir',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Resalta acordes que abren o cierran para elegir',
                      style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasYellowDecisions) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            key: ValueKey('apply_yellow_pull_opt'),
            value: 'apply_pull',
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.arrowLeft,
                  size: 12,
                  color: Color(0xFF2563EB),
                ),
                SizedBox(width: 8),
                Text(
                  'Aplicar todos los amarillos a Abre (←)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            key: ValueKey('apply_yellow_push_opt'),
            value: 'apply_push',
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.arrowRight,
                  size: 12,
                  color: Color(0xFFDC2626),
                ),
                SizedBox(width: 8),
                Text(
                  'Aplicar todos los amarillos a Cierra (→)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            key: ValueKey('clear_yellow_opt'),
            value: 'clear_yellow',
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 12,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(width: 8),
                Text(
                  'Limpiar marcas amarillas',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón del metrónomo para activar/desactivar el click rítmico sincronizado al compás.
class _MetronomeButton extends StatelessWidget {
  final int accordionNumber;
  final bool isActive;
  final VoidCallback onTap;

  const _MetronomeButton({
    required this.accordionNumber,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive
          ? 'Metrónomo Activo (Click encendido)'
          : 'Activar Metrónomo (Click sincronizado con compás)',
      child: InkWell(
        key: ValueKey('metronome_toggle_btn_$accordionNumber'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF059669)
                  : const Color(0xFFCBD5E1),
              width: 0.9,
            ),
          ),
          child: FaIcon(
            FontAwesomeIcons.stopwatch,
            size: 9.5,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

/// Botón del marcador en vivo que indica y activa la captura de acordes con la Barra Espaciadora.
class _LiveMarkerButton extends StatelessWidget {
  final int accordionNumber;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  const _LiveMarkerButton({
    required this.accordionNumber,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isPlaying
        ? const Color(0xFFF59E0B)
        : const Color(0xFF8B5CF6);
    final activeBorder = isPlaying
        ? const Color(0xFFD97706)
        : const Color(0xFF7C3AED);

    return Tooltip(
      message: isActive
          ? 'Marcador en Vivo Activo: Presiona [Espacio] para marcar el acorde en el tiempo del slider'
          : 'Activar Marcador en Vivo [Espacio] sincronizado con la reproducción',
      child: InkWell(
        key: ValueKey('live_chord_marker_btn_$accordionNumber'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? activeBg : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? activeBorder : const Color(0xFFCBD5E1),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.bookmark,
                size: 9.0,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 3),
              Text(
                'Espacio',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón para activar/desactivar la detección automática de acordes en reproducción
/// (actuando exclusivamente cuando se detecta un cambio armónico).
class _AutoChordDetectButton extends StatelessWidget {
  final int accordionNumber;
  final bool isActive;
  final VoidCallback onTap;

  const _AutoChordDetectButton({
    required this.accordionNumber,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeBg = Color(0xFF0D9488); // Teal
    const activeBorder = Color(0xFF0F766E);

    return Tooltip(
      message: isActive
          ? 'Auto-Acorde Activo: Detecta y asigna acordes al reproducir SOLO en cada cambio armónico'
          : 'Activar Detección Automática de Acordes en Reproducción (solo en cambios de acorde)',
      child: InkWell(
        key: ValueKey('auto_chord_detect_btn_$accordionNumber'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? activeBg : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? activeBorder : const Color(0xFFCBD5E1),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.bolt,
                size: 9.0,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 3),
              Text(
                'Auto',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón de control y menú para ajustes de sincronización y fase del pulso (Beat Nudge / Sync).
class _BeatAdjustButton extends StatelessWidget {
  final int accordionNumber;
  final double nudgeOffsetSeconds;
  final void Function(double delta) onNudge;
  final VoidCallback onSync;
  final VoidCallback onReset;

  const _BeatAdjustButton({
    required this.accordionNumber,
    required this.nudgeOffsetSeconds,
    required this.onNudge,
    required this.onSync,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final ms = (nudgeOffsetSeconds * 1000).round();
    final isNudged = ms != 0;

    return PopupMenuButton<String>(
      key: ValueKey('beat_adjust_menu_btn_$accordionNumber'),
      tooltip:
          'Ajustes del Beat (Fase/Sincronización): ${ms >= 0 ? "+" : ""}$ms ms',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 24),
      onSelected: (val) {
        switch (val) {
          case '-50ms':
            onNudge(-0.050);
            break;
          case '-25ms':
            onNudge(-0.025);
            break;
          case '+25ms':
            onNudge(0.025);
            break;
          case '+50ms':
            onNudge(0.050);
            break;
          case 'sync':
            onSync();
            break;
          case 'reset':
            onReset();
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'Ajustes del Beat (Desfase: ${ms >= 0 ? "+" : ""}$ms ms)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const PopupMenuDivider(height: 4),
        const PopupMenuItem<String>(
          value: 'sync',
          height: 32,
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.arrowsRotate,
                size: 12,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 8),
              Text(
                'Sincronizar Beat al audio actual',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '-50ms',
          height: 30,
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.backward,
                size: 11,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 8),
              Text('Atrasar Beat -50 ms', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '-25ms',
          height: 30,
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.backwardStep,
                size: 11,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 8),
              Text('Atrasar Beat -25 ms', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '+25ms',
          height: 30,
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.forwardStep,
                size: 11,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 8),
              Text('Adelantar Beat +25 ms', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: '+50ms',
          height: 30,
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.forward,
                size: 11,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 8),
              Text('Adelantar Beat +50 ms', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 4),
        const PopupMenuItem<String>(
          value: 'reset',
          height: 30,
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.rotateLeft,
                size: 11,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 8),
              Text(
                'Restablecer desfase (0 ms)',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: isNudged ? const Color(0xFFEFF6FF) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isNudged ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.sliders,
              size: 9.0,
              color: isNudged
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 3),
            Text(
              isNudged ? '${ms >= 0 ? "+" : ""}$ms' : 'Beat',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: isNudged
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
