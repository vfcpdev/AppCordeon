import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../core/di/providers.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';

class MeasureGridWidget extends ConsumerStatefulWidget {
  final int accordionNumber;
  final double? width;

  const MeasureGridWidget({
    super.key,
    this.accordionNumber = 1,
    this.width,
  });

  @override
  ConsumerState<MeasureGridWidget> createState() => _MeasureGridWidgetState();
}

class _MeasureGridWidgetState extends ConsumerState<MeasureGridWidget> {
  late final ScrollController _compasScrollController;

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isPrimary = widget.accordionNumber == 1;

    final bpm = state.audioReport?.bpm ?? 120;
    final totalBeats = state.measures.length * 4;
    final allMarked = totalBeats > 0 && state.markedBeats.length == totalBeats;
    final hasMarks = state.markedBeats.isNotEmpty;
    final effectiveWidth = widget.width ?? (isPrimary ? 104.5 : 82.5);

    // Detectar si hay un acorde seleccionado en algún cuadro del compás o en el constructor
    final selectedBar = state.selectedBarIndex;
    final selectedBeat = state.selectedBeatIndex;
    String? selectedChord;
    if (selectedBar != null && selectedBeat != null &&
        selectedBar >= 0 && selectedBar < state.measures.length) {
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
      latin: state.notation != NotationMode.alemana,
    );

    final chordToEdit = selectedChord ??
        ((state.multiBeatChord != null && state.multiBeatChord!.isNotEmpty)
            ? state.multiBeatChord
            : (constructorChord.isNotEmpty ? constructorChord : null));

    final hasOccurrences = chordToEdit != null &&
        state.measures.any((m) => m.beats.any((b) => b.chord.trim() == chordToEdit));
    final isEditActive = selectedChord != null || hasOccurrences;

    return SizedBox(
      width: effectiveWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
          // Minibarra superior: selección masiva de checkboxes y borrado de acordes
          if (isPrimary)
            Container(
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: effectiveWidth > 150 ? effectiveWidth : 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botones de Guardar (JSON), Importar (JSON) y Editar — aumentados 50%
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: 'Guardar compases en JSON',
                            child: InkWell(
                              onTap: () async {
                                final jsonStr = notifier.exportMeasuresToJson();
                                final storage = ref.read(fileStorageProvider);
                                final timestamp = DateTime.now().millisecondsSinceEpoch;
                                await storage.saveFile(
                                  fileName: 'compases_$timestamp.json',
                                  content: jsonStr,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Compases guardados en formato JSON.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const FaIcon(
                                  FontAwesomeIcons.download,
                                  size: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Importar compases desde archivo JSON',
                            child: InkWell(
                              onTap: () async {
                                final storage = ref.read(fileStorageProvider);
                                final content = await storage.pickTextFile(allowedExtensions: ['json']);
                                if (content != null && content.isNotEmpty) {
                                  final success = notifier.loadMeasuresFromJson(content);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Compases restaurados exitosamente desde JSON.'
                                              : 'Error al importar: archivo JSON no válido.',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.all(6),
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
                          const SizedBox(width: 4),
                          // Botón de edición a la derecha de importar compás
                          Tooltip(
                            message: isEditActive
                                ? 'Editar asignación múltiple de $chordToEdit'
                                : 'Selecciona un acorde en el compás para editarlo',
                            child: InkWell(
                              key: const ValueKey('edit_multi_beat_chord_btn'),
                              onTap: isEditActive
                                  ? () {
                                      final targetChord = chordToEdit;
                                      if (targetChord == null || targetChord.isEmpty) return;
                                      final positions = <String>[];
                                      for (var m = 0; m < state.measures.length; m++) {
                                        for (var b = 0; b < state.measures[m].beats.length; b++) {
                                          if (state.measures[m].beats[b].chord.trim() == targetChord) {
                                            positions.add('${m + 1}.${b + 1}');
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
                                padding: const EdgeInsets.all(6),
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
                                  color: isEditActive ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                  // Botones de selección masiva y borrado
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasMarks) ...[
                        _DeleteAllChordsButton(
                          onTap: () {
                            notifier.deleteAllGridChords();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Acordes borrados de la cuadrícula.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 3),
                        // Desmarcar todas las casillas seleccionadas
                        _ClearMarksButton(
                          onTap: notifier.clearBeatMarks,
                        ),
                        const SizedBox(width: 3),
                      ],
                      _SelectAllBeatsButton(
                        allMarked: allMarked,
                        onTap: notifier.toggleAllBeatMarks,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
          // Cabecera: Título "Compás" + Control de BPM editable con Subir / Bajar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFFF1F5F9) : const Color(0xFFD1FAE5),
              border: Border(bottom: BorderSide(color: isPrimary ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // En la tarjeta estrecha el título no cabe junto al BPM.
                final showTitle = constraints.maxWidth >= 80;
                final compactBpm = constraints.maxWidth < 120;
                return Row(
                  children: [
                    if (showTitle) ...[
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              isPrimary
                                  ? FontAwesomeIcons.music
                                  : FontAwesomeIcons.link,
                              size: 8,
                              color: isPrimary
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                isPrimary ? 'Compás' : 'Compás A2',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w900,
                                  color: isPrimary
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF059669),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                    // Control de BPM editable con botones subir/bajar
                    Expanded(
                      child: Align(
                        alignment: showTitle
                            ? Alignment.centerRight
                            : Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _BpmInputControl(
                            bpm: bpm,
                            compact: compactBpm,
                            onChanged: (newVal) =>
                                notifier.updateAudioBpm(newVal),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Transporte y Seeker de Tiempo (Solo en Diapasón 1)
                if (isPrimary) ...[
                  _buildTransportAndSeeker(context, state, notifier),
                  const SizedBox(width: 4),
                ],

                // Columna Central: Cuadrícula de Compases con 4 Tiempos por fila
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 330),
                    child: RawScrollbar(
                      controller: _compasScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thickness: 8.0, // Aumentado ~30% sobre el grosor estándar (6.0px -> 8.0px)
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
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                // Número de compás
                                Container(
                                  width: 18,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
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

                                // 4 Beats / Tiempos del compás
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: measure.beats.asMap().entries.map((entry) {
                                      final beatIdx = entry.key;
                                      final beat = entry.value;

                                      final isCurrentPlayhead = state.isPlayingAudio &&
                                          state.selectedBarIndex == mIdx &&
                                          state.selectedBeatIndex == beatIdx;

                                      return _InlineBeatChordEditor(
                                        accordionId: widget.accordionNumber,
                                        measureIndex: mIdx,
                                        beatIndex: beatIdx,
                                        totalMeasures: state.measures.length,
                                        chord: beat.chord,
                                        timeText: beat.timeText,
                                        bellows: beat.bellows,
                                        isCurrentPlayhead: isCurrentPlayhead,
                                        isMarked: notifier.isBeatMarked(mIdx, beatIdx),
                                        hasBottomBorder: beatIdx < measure.beats.length - 1,
                                        notation: state.notation,
                                        onChanged: (newChord) {
                                          notifier.updateMeasureBeat(mIdx, beatIdx, newChord);
                                        },
                                        onSelected: () {
                                          notifier.selectBeat(mIdx, beatIdx);
                                        },
                                        onToggleMark: () {
                                          notifier.toggleBeatMark(mIdx, beatIdx);
                                        },
                                        onBellowsChanged: (bellows) {
                                          notifier.setBeatBellows(mIdx, beatIdx, bellows);
                                        },
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
                ),
              ],
            ),
          ),

          // Volumen propio del Compás (pista + acordes marcados)
          if (isPrimary)
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
    const SizedBox(height: 6),

    // Sección de Información debajo de la ventana de Compás:
    // Informa si el acorde está completo o incompleto según el fuelle (Abre y Cierra)
    _buildChordBellowsInfoCard(context, state, effectiveWidth),
  ],
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

    final namesList = isLatin ? ChordCatalog.latinRootNames : ChordCatalog.germanRootNames;
    final chordNoteNames = chordPcs.map((pc) => namesList[pc]).toList();
    final missingPushNames = missingPush.map((pc) => namesList[pc]).toList();
    final missingPullNames = missingPull.map((pc) => namesList[pc]).toList();

    final isSelectedPull = targetBellows == BellowsMode.pull;
    final isSelectedPush = targetBellows == BellowsMode.push;
    final currentIsComplete = isSelectedPull
        ? isCompletePull
        : (isSelectedPush ? isCompletePush : (isCompletePush || isCompletePull));

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: !hasTarget
              ? const Color(0xFFCBD5E1)
              : (currentIsComplete ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
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
                      : (currentIsComplete ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
    final accentColor = isPush ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final badgeBg = isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final badgeFg = isComplete ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
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
                    isComplete ? FontAwesomeIcons.check : FontAwesomeIcons.xmark,
                    size: 6.5,
                    color: badgeFg,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isComplete ? 'Completo' : 'Incompleto ($presentCount/$totalNotes)',
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

  Widget _buildTransportAndSeeker(
    BuildContext context,
    AccordionSimulatorState state,
    AccordionSimulatorNotifier notifier,
  ) {
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
        if (state.audioReport != null || state.loadedAudioFileName != null) ...[
          _buildTransportBtn(
            icon: state.isAudioCoupled
                ? FontAwesomeIcons.link
                : FontAwesomeIcons.linkSlash,
            isActive: state.isAudioCoupled,
            onTap: notifier.toggleAudioCoupling,
            tooltip: state.isAudioCoupled
                ? 'Desacoplar audio del Compás'
                : 'Acoplar audio al Compás',
          ),
          const SizedBox(height: 4),
          if (state.audioReport != null && state.audioReport!.chords.isNotEmpty) ...[
            _buildTransportBtn(
              icon: FontAwesomeIcons.tableCells,
              onTap: () {
                notifier.applyChordsToMeasures(state.audioReport!.chords);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Acordes detectados cargados en el Compás.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Cargar acordes analizados en el Compás',
            ),
            const SizedBox(height: 4),
          ],
        ],
        _buildTransportBtn(
          icon: FontAwesomeIcons.arrowsRotate,
          isActive: state.syncDiapason,
          onTap: notifier.toggleSyncDiapason,
          tooltip: 'Sincronizar Diapasón',
        ),
        const SizedBox(height: 8),

        // Tiempo actual y Seeker Vertical
        SizedBox(
          width: 26,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatTime(state.currentAudioTime),
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
            ),
          ),
        ),
        SizedBox(
          height: 140,
          width: 22,
          child: RotatedBox(
            // 1 cuarto de giro: el mínimo (00:00) queda arriba y el avance
            // baja por la pista, como un seeker de reproducción vertical.
            quarterTurns: 1,
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
                value: state.currentAudioTime.clamp(0.0, state.totalAudioDuration > 0 ? state.totalAudioDuration : 1.0),
                min: 0.0,
                max: state.totalAudioDuration > 0 ? state.totalAudioDuration : 1.0,
                onChanged: (v) => notifier.seekAudio(v),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 26,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '-${_formatTime((state.totalAudioDuration - state.currentAudioTime).clamp(0.0, double.infinity))}',
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(double sec) {
    final s = sec.clamp(0.0, 99999.0).toInt();
    final mins = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
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
  mayor,      // '0'
  menor,      // '.' o ','
  septima,    // '/'
  aumentada,  // '+'
  disminuida, // '-'
  sus,        // '8'
  cuarta,     // '9'
}

class _ChordTools {
  static const roots = [
    'Do#', 'Dob', 'Do♭', 'Do',
    'Re#', 'Reb', 'Re♭', 'Re',
    'Mi#', 'Mib', 'Mi♭', 'Mi',
    'Fa#', 'Fab', 'Fa♭', 'Fa',
    'Sol#', 'Solb', 'Sol♭', 'Sol',
    'La#', 'Lab', 'La♭', 'La',
    'Si#', 'Sib', 'Si♭', 'Si',
    'C#', 'Db', 'C♭', 'C',
    'D#', 'Eb', 'D♭', 'D',
    'E#', 'Eb', 'E♭', 'E',
    'F#', 'Fb', 'F♭', 'F',
    'G#', 'Gb', 'G♭', 'G',
    'A#', 'Ab', 'A♭', 'A',
    'B#', 'Bb', 'B♭', 'B'
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
    if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.numpadDivide) {
      return _ChordModKey.septima;
    }
    if (key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
      return _ChordModKey.aumentada;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      return _ChordModKey.disminuida;
    }
    return null;
  }

  static String applyModifier(String chord, _ChordModKey mod, NotationMode notation) {
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
  final BellowsMode bellows;
  final bool isCurrentPlayhead;
  final bool isMarked;
  final bool hasBottomBorder;
  final NotationMode notation;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSelected;
  final VoidCallback? onToggleMark;
  final ValueChanged<BellowsMode>? onBellowsChanged;

  const _InlineBeatChordEditor({
    required this.accordionId,
    required this.measureIndex,
    required this.beatIndex,
    required this.totalMeasures,
    required this.chord,
    required this.timeText,
    this.bellows = BellowsMode.both,
    required this.isCurrentPlayhead,
    required this.isMarked,
    required this.hasBottomBorder,
    this.notation = NotationMode.latina,
    required this.onChanged,
    this.onSelected,
    this.onToggleMark,
    this.onBellowsChanged,
  });

  @override
  State<_InlineBeatChordEditor> createState() => _InlineBeatChordEditorState();
}

class _InlineBeatChordEditorState extends State<_InlineBeatChordEditor> {
  // Registro separado por accordionId para evitar interferencia entre acordeones
  static final Map<int, Map<String, _InlineBeatChordEditorState>> _registries = {};
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
  bool get _isSelected => _selectedKey == _nodeKey;
  bool get _isCellHighlighted => _isSelected && !_isEditing;


  @override
  void initState() {
    super.initState();
    _registry[_nodeKey] = this;
    _controller = TextEditingController(text: widget.chord);

    _cellFocusNode = FocusNode(debugLabel: 'beat_cell_$_nodeKey');
    _cellFocusNode.onKeyEvent = _handleCellKeyEvent;

    _focusNode = FocusNode(debugLabel: 'beat_text_$_nodeKey');
    _focusNode.onKeyEvent = _handleTextFieldKeyEvent;

    _focusNode.addListener(() {
      final hasFocus = _focusNode.hasFocus;
      if (hasFocus) {
        if (!_isEditing) {
          _isEditing = true;
          _selectedKey = _nodeKey;
          _update();
        }
      } else {
        if (_isEditing) {
          _isEditing = false;
          _commit();
          _update();
        }
      }
    });

    _cellFocusNode.addListener(() {
      if (_cellFocusNode.hasFocus) {
        if (_selectedKey != _nodeKey) {
          final oldKey = _selectedKey;
          _selectedKey = _nodeKey;
          if (oldKey != null) {
            _registry[oldKey]?._setIdle();
          }
          _update();
        }
        widget.onSelected?.call();
      } else {
        _update();
      }
    });

    if (_selectedKey == _nodeKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setSelected();
      });
    }
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _InlineBeatChordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measureIndex != widget.measureIndex || oldWidget.beatIndex != widget.beatIndex) {
      _registry.remove('${oldWidget.measureIndex}_${oldWidget.beatIndex}');
      _registry[_nodeKey] = this;
    }
    if (oldWidget.chord != widget.chord && !_isEditing) {
      _controller.value = TextEditingValue(
        text: widget.chord,
        selection: TextSelection.collapsed(offset: widget.chord.length),
      );
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
    if (trimmed != widget.chord) {
      widget.onChanged(trimmed);
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

      final oldKey = _selectedKey;
      _selectedKey = targetKey;
      if (oldKey != null && oldKey != targetKey) {
        _registry[oldKey]?._setIdle();
      }

      final targetState = _registry[targetKey];
      if (targetState != null) {
        targetState._setSelected();
      }
    }
  }

  void _setSelected() {
    _commit();
    _isEditing = false;
    _focusNode.unfocus();
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
    if (mounted) setState(() {});
  }

  void _activateEdit() {
    final oldKey = _selectedKey;
    _selectedKey = _nodeKey;
    if (oldKey != null && oldKey != _nodeKey) {
      _registry[oldKey]?._setIdle();
    }
    widget.onSelected?.call();
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
    _controller.value = TextEditingValue(
      text: chord,
      selection: TextSelection.collapsed(offset: chord.length),
    );
    widget.onChanged(chord);
    if (mounted) setState(() {});
  }

  KeyEventResult _handleCellKeyEvent(FocusNode node, KeyEvent event) {
    if (_isEditing) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      // Modificadores armónicos: . Menor, / 7ma, + Aumentada, - Disminuida
      final mod = _ChordTools.parseModifierKey(event);
      if (mod != null) {
        final updated = _ChordTools.applyModifier(_controller.text, mod, widget.notation);
        _applyChord(updated);
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
        // Flecha derecha: saca de foco / permanece el cuadro seleccionado
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Flecha abajo: cambia al compás/cuadro siguiente
        _moveSelection(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Flecha arriba: cambia al compás/cuadro anterior
        _moveSelection(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _activateEdit();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTextFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Flecha derecha: saca de foco de edición, pero permanece el cuadro seleccionado
        _commit();
        _setSelected();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Flecha abajo: cambia al compás/cuadro siguiente
        _moveSelection(1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Flecha arriba: cambia al compás/cuadro anterior
        _moveSelection(-1);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        // Tab o Escape: saca de foco de edición pero mantiene cuadro seleccionado
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
    final isMarked = widget.isMarked;

    return Focus(
      focusNode: _cellFocusNode,
      child: GestureDetector(
        onTap: () {
          _activateEdit();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: isCellSelected
                ? const Color(0xFFDBEAFE) // Resaltado azul suave y vivo para cuadro seleccionado
                : (_isEditing
                    ? Colors.white // Fondo blanco limpio al editar
                    : (isPlaying
                        ? const Color(0xFFFEF3C7)
                        : (isMarked
                            ? const Color(0xFFF0FDF4) // Tiempo marcado con el checkbox
                            : Colors.white))),
            borderRadius: BorderRadius.circular(4),
            border: isCellSelected
                ? Border.all(color: const Color(0xFF2563EB), width: 1.8) // Cuadro resaltado nítido con borde completo
                : (_isEditing
                    ? Border.all(color: const Color(0xFF3B82F6), width: 1.8) // Borde activo de edición
                    : (isPlaying
                        ? Border.all(color: const Color(0xFFF59E0B), width: 1.8)
                        : (isMarked
                            ? Border.all(
                                color: const Color(0xFF059669),
                                width: 1.2,
                              )
                            : Border.all(
                                color: widget.hasBottomBorder
                                    ? const Color(0xFFE2E8F0)
                                    : Colors.transparent,
                                width: 0.8,
                              )))),
            boxShadow: isCellSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      blurRadius: 4,
                      spreadRadius: 0.8,
                    ),
                  ]
                : (_isEditing
                    ? [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.20),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Con la tarjeta de Compás estrecha, el tiempo no cabe junto al
              // acorde y al checkbox: se oculta para evitar desbordamientos.
              final showArrows = constraints.maxWidth >= 65;
              final showTime = constraints.maxWidth >= 100;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cuadro de texto interactivo con foco directo y navegación Tab + Arriba / Abajo
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      readOnly: !_isEditing,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: (isFocusedOrSelected || hasChord)
                            ? FontWeight.w900
                            : FontWeight.w500,
                        color: isPlaying
                            ? const Color(0xFFB45309)
                            : (isFocusedOrSelected
                                ? const Color(0xFF1D4ED8)
                                : (hasChord
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF94A3B8))),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '-',
                        hintStyle: TextStyle(
                          fontSize: 8.5,
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
                  ),
                  if (showTime) ...[
                    const SizedBox(width: 2),
                    Text(
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
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  // Checkbox para marcar el tiempo y flechas Abre/Cierre a su derecha
                  Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BeatMarkCheckbox(
                          key: ValueKey(
                            'beat_checkbox_${widget.measureIndex}_${widget.beatIndex}',
                          ),
                          isChecked: isMarked,
                          onTap: widget.onToggleMark,
                        ),
                        if (showArrows) ...[
                          const SizedBox(width: 2),
                          _BeatBellowsArrows(
                            bellows: widget.bellows,
                            isEnabled: hasChord,
                            onBellowsChanged: hasChord ? widget.onBellowsChanged : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
              onTap: isEnabled ? () => onBellowsChanged?.call(BellowsMode.pull) : null,
              child: Container(
                width: 13.5,
                height: 13.5,
                decoration: BoxDecoration(
                  color: isPull ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isPull ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.arrowLeft,
                    size: 7.0,
                    color: isPull ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
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
              onTap: isEnabled ? () => onBellowsChanged?.call(BellowsMode.push) : null,
              child: Container(
                width: 13.5,
                height: 13.5,
                decoration: BoxDecoration(
                  color: isPush ? const Color(0xFFFEF2F2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isPush ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.arrowRight,
                    size: 7.0,
                    color: isPush ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
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

  const _BeatMarkCheckbox({
    super.key,
    required this.isChecked,
    this.onTap,
  });

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

/// Botón cuadrado rojo con icono de basura de la minibarra: borra todos los
/// acordes registrados en la cuadrícula del Compás.
class _DeleteAllChordsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAllChordsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Borrar todos los acordes',
      child: GestureDetector(
        onTapDown: (_) => onTap(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: const Color(0xFFB91C1C),
              width: 1.2,
            ),
          ),
          child: const Center(
            child: FaIcon(
              FontAwesomeIcons.trash,
              size: 8,
              color: Colors.white,
            ),
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
            border: Border.all(
              color: const Color(0xFFD97706),
              width: 1.2,
            ),
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
