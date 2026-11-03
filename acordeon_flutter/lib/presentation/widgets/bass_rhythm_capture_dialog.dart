import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/di/providers.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/bass_matrix_layout.dart';
import '../../domain/models/bass_rhythm_pattern.dart';
import '../controllers/accordion_controller.dart';

/// Modo de operación del panel de captura de patrones rítmicos (State Pattern).
enum CapturePanelMode {
  recording,
  reviewAndEdit,
}

/// Panel INLINE (no modal) de captura de patrones rítmicos de bajos.
///
/// **Por qué inline y no diálogo**: la captura requiere tocar los bajos del
/// panel mientras el temporizador corre. Un `showDialog` crea una barrera
/// modal que absorbe los pointers, impidiendo registrar golpes. Como widget
/// embebido sobre el propio panel, los bajos siguen accesibles.
///
/// Implementa State Pattern para desacoplar:
/// 1. [CapturePanelMode.recording]: Captura de pulsos en tiempo real.
/// 2. [CapturePanelMode.reviewAndEdit]: Audición, timeline desplazable, scrubbing,
///    control de BPM independiente y ajuste de 1 o 2 botones por golpe.
class BassRhythmCapturePanel extends ConsumerStatefulWidget {
  final int accordionNumber;
  final VoidCallback? onClose;

  const BassRhythmCapturePanel({
    super.key,
    this.accordionNumber = 1,
    this.onClose,
  });

  @override
  ConsumerState<BassRhythmCapturePanel> createState() =>
      _BassRhythmCapturePanelState();
}

class _BassRhythmCapturePanelState
    extends ConsumerState<BassRhythmCapturePanel> {
  late final TextEditingController _nameController;
  Set<int> _selectedButtons = {...BassMatrixLayout.buttonNumbers};

  CapturePanelMode _mode = CapturePanelMode.recording;
  BassRhythmPattern? _draftPattern;
  List<BassRhythmHit> _draftHits = [];
  int _selectedHitIndex = 0;
  double _bpm = 120.0;
  bool _isPlayingReview = false;
  double _playbackQuarter = 0.0;
  Timer? _reviewTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    final state = ref.read(accordionSimulatorProvider);
    final recorder = state.bassRhythmRecorder;
    if (recorder != null && recorder.isRecording) {
      _selectedButtons = {...recorder.selectedButtons};
      _nameController.text = recorder.name;
    } else if (state.selectedBassRhythmPattern != null) {
      final pat = state.selectedBassRhythmPattern!;
      _draftPattern = pat;
      _draftHits = List<BassRhythmHit>.from(pat.hits);
      _bpm = (pat.quarterNotesPerMinute ?? 120.0).clamp(40.0, 220.0);
      _nameController.text = pat.name;
    }
  }

  @override
  void dispose() {
    _reviewTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleButton(int buttonNumber) {
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    setState(() {
      if (!_selectedButtons.remove(buttonNumber)) {
        _selectedButtons.add(buttonNumber);
      }
    });
    if (ref.read(accordionSimulatorProvider).isBassCaptureActive) {
      notifier.toggleBassCaptureSelection(buttonNumber);
    }
  }

  void _startCapture() {
    if (_selectedButtons.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _mode = CapturePanelMode.recording;
    });
    ref.read(accordionSimulatorProvider.notifier).startBassRhythmCapture(
          name: _nameController.text,
          selectedButtons: _selectedButtons,
        );
  }

  void _stopCapture() {
    _reviewTimer?.cancel();
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final pattern = notifier.stopBassRhythmCapture();
    if (pattern != null && pattern.hits.isNotEmpty && mounted) {
      setState(() {
        _mode = CapturePanelMode.reviewAndEdit;
        _draftPattern = pattern;
        _draftHits = List<BassRhythmHit>.from(pattern.hits);
        _selectedHitIndex = 0;
        _bpm = pattern.quarterNotesPerMinute ?? 120.0;
        _playbackQuarter = 0.0;
        _isPlayingReview = false;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = pattern.name;
        }
      });
    } else {
      widget.onClose?.call();
    }
  }

  void _cancelCapture() {
    _reviewTimer?.cancel();
    ref.read(accordionSimulatorProvider.notifier).cancelBassRhythmCapture();
    widget.onClose?.call();
  }

  double _totalQuarters() {
    if (_draftHits.isEmpty) return 4.0;
    final last = _draftHits.last;
    final total = math.max(last.onsetQuarterBeats + math.max(last.durationQuarterBeats, 0.5), 4.0);
    return total;
  }

  int _resolveFundamental(int btn) {
    if (btn == 7 || btn == 4) return 7;
    if (btn == 8 || btn == 5) return 8;
    if (btn >= 7 && btn <= 12) return btn;
    return (btn + 6).clamp(7, 12);
  }

  int _resolveChord(int btn) {
    if (btn == 7 || btn == 4) return 4;
    if (btn == 8 || btn == 5) return 5;
    if (btn >= 1 && btn <= 6) return btn;
    return (btn - 6).clamp(1, 6);
  }

  void _playHitSound(BassRhythmHit hit) {
    final audioEngine = ref.read(audioEngineProvider);
    final bassData = ref.read(accordionSimulatorProvider).bassData1;
    for (final btnNum in hit.buttonIndexes) {
      final btn = bassData.firstWhere(
        (b) => b.btnIndex == btnNum,
        orElse: () => AccordionData.baseCincoLetrasBass.first,
      );
      final notes = btn.pushNotes.isNotEmpty ? btn.pushNotes : btn.pullNotes;
      for (final note in notes) {
        audioEngine.noteOn(note, velocity: 0.85);
        Future.delayed(const Duration(milliseconds: 140), () {
          audioEngine.noteOff(note);
        });
      }
    }
  }

  void _toggleHitButton({required bool isChord}) {
    if (_draftHits.isEmpty || _selectedHitIndex >= _draftHits.length) return;
    final currentHit = _draftHits[_selectedHitIndex];
    final fundBtn = _resolveFundamental(currentHit.buttonIndex);
    final chordBtn = _resolveChord(currentHit.buttonIndex);

    final isFundActive = currentHit.buttonIndexes.contains(fundBtn);
    final isChordActive = currentHit.buttonIndexes.contains(chordBtn);

    bool nextFund = isFundActive;
    bool nextChord = isChordActive;

    if (!isChord) {
      nextFund = !isFundActive;
    } else {
      nextChord = !isChordActive;
    }

    // Debe permitirse al menos un botón activo
    if (!nextFund && !nextChord) return;

    final BassRhythmHit updatedHit;
    if (nextFund && nextChord) {
      updatedHit = currentHit.copyWith(
        buttonIndex: fundBtn,
        pairedButtonIndex: chordBtn,
        pairedFingerNumber: 3,
      );
    } else if (nextFund) {
      updatedHit = currentHit.copyWith(
        buttonIndex: fundBtn,
        clearPairedButton: true,
      );
    } else {
      updatedHit = currentHit.copyWith(
        buttonIndex: chordBtn,
        clearPairedButton: true,
      );
    }

    setState(() {
      _draftHits[_selectedHitIndex] = updatedHit;
    });
    _playHitSound(updatedHit);
  }

  void _adjustHitOnset(double delta) {
    if (_draftHits.isEmpty || _selectedHitIndex >= _draftHits.length) return;
    final currentHit = _draftHits[_selectedHitIndex];
    final total = _totalQuarters();
    final newOnset = (currentHit.onsetQuarterBeats + delta).clamp(0.0, total);
    final updatedHit = currentHit.copyWith(
      onsetQuarterBeats: (newOnset * 100).round() / 100.0,
    );
    setState(() {
      _draftHits[_selectedHitIndex] = updatedHit;
      _sortHitsAndKeepSelection(updatedHit);
      _playbackQuarter = updatedHit.onsetQuarterBeats;
    });
    _playHitSound(updatedHit);
  }

  void _quantizeHitOnset({double grid = 0.25}) {
    if (_draftHits.isEmpty || _selectedHitIndex >= _draftHits.length) return;
    final currentHit = _draftHits[_selectedHitIndex];
    final quantized = ((currentHit.onsetQuarterBeats / grid).round() * grid)
        .clamp(0.0, _totalQuarters());
    final updatedHit = currentHit.copyWith(
      onsetQuarterBeats: (quantized * 100).round() / 100.0,
    );
    setState(() {
      _draftHits[_selectedHitIndex] = updatedHit;
      _sortHitsAndKeepSelection(updatedHit);
      _playbackQuarter = updatedHit.onsetQuarterBeats;
    });
    _playHitSound(updatedHit);
  }

  void _setHitDuration(double duration) {
    if (_draftHits.isEmpty || _selectedHitIndex >= _draftHits.length) return;
    final currentHit = _draftHits[_selectedHitIndex];
    final updatedHit = currentHit.copyWith(
      durationQuarterBeats: duration.clamp(0.1, 4.0),
    );
    setState(() {
      _draftHits[_selectedHitIndex] = updatedHit;
    });
  }

  void _setHitRow(int rowTarget) {
    if (_draftHits.isEmpty || _selectedHitIndex >= _draftHits.length) return;
    final currentHit = _draftHits[_selectedHitIndex];
    final isPaired = currentHit.pairedButtonIndex != null;
    final targetFund = rowTarget == 1 ? 7 : 8;
    final targetChord = rowTarget == 1 ? 4 : 5;
    final isFund =
        currentHit.buttonIndex == _resolveFundamental(currentHit.buttonIndex);

    final BassRhythmHit updatedHit;
    if (isPaired) {
      updatedHit = currentHit.copyWith(
        buttonIndex: targetFund,
        pairedButtonIndex: targetChord,
      );
    } else if (isFund) {
      updatedHit = currentHit.copyWith(
        buttonIndex: targetFund,
        clearPairedButton: true,
      );
    } else {
      updatedHit = currentHit.copyWith(
        buttonIndex: targetChord,
        clearPairedButton: true,
      );
    }
    setState(() {
      _draftHits[_selectedHitIndex] = updatedHit;
    });
    _playHitSound(updatedHit);
  }

  void _deleteSelectedHit() {
    if (_draftHits.length <= 1 || _selectedHitIndex >= _draftHits.length) return;
    setState(() {
      _draftHits.removeAt(_selectedHitIndex);
      if (_selectedHitIndex >= _draftHits.length) {
        _selectedHitIndex = _draftHits.length - 1;
      }
      _playbackQuarter = _draftHits[_selectedHitIndex].onsetQuarterBeats;
    });
  }

  void _addNewHitAtCurrentPosition() {
    final onset = (_playbackQuarter * 100).round() / 100.0;
    final newHit = BassRhythmHit(
      onsetQuarterBeats: onset,
      durationQuarterBeats: 0.5,
      buttonIndex: 7,
      buttonType: BassRhythmButtonType.fundamental,
      fingerNumber: 2,
    );
    setState(() {
      _draftHits.add(newHit);
      _sortHitsAndKeepSelection(newHit);
    });
    _playHitSound(newHit);
  }

  void _sortHitsAndKeepSelection(BassRhythmHit targetHit) {
    _draftHits.sort((a, b) => a.onsetQuarterBeats.compareTo(b.onsetQuarterBeats));
    _selectedHitIndex = _draftHits.indexOf(targetHit);
    if (_selectedHitIndex < 0) _selectedHitIndex = 0;
  }

  void _togglePlayReview() {
    if (_isPlayingReview) {
      _stopPlayReview();
    } else {
      _startPlayReview();
    }
  }

  void _startPlayReview() {
    _reviewTimer?.cancel();
    setState(() {
      _isPlayingReview = true;
    });

    final totalQuarters = _totalQuarters();
    const intervalMs = 25;
    double lastTriggerQuarter = _playbackQuarter - 0.05;

    _reviewTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final step = (intervalMs / 1000.0) * (_bpm / 60.0);
      var nextQuarter = _playbackQuarter + step;

      if (nextQuarter >= totalQuarters) {
        nextQuarter = 0.0;
        lastTriggerQuarter = -0.1;
      }

      // Disparar golpes cuyo onset caiga en esta ventana temporal
      for (var i = 0; i < _draftHits.length; i++) {
        final hit = _draftHits[i];
        if (hit.onsetQuarterBeats >= lastTriggerQuarter &&
            hit.onsetQuarterBeats <= nextQuarter) {
          _playHitSound(hit);
        }
      }

      lastTriggerQuarter = nextQuarter;
      setState(() {
        _playbackQuarter = nextQuarter;
      });
    });
  }

  void _stopPlayReview() {
    _reviewTimer?.cancel();
    setState(() {
      _isPlayingReview = false;
      _playbackQuarter = 0.0;
    });
  }

  void _saveFinalPattern() {
    if (_draftPattern == null) return;
    _reviewTimer?.cancel();
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final patternName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _draftPattern!.name;

    notifier.updateBassRhythmPattern(
      patternId: _draftPattern!.id,
      newName: patternName,
      newQuarterNotesPerMinute: _bpm,
      newHits: _draftHits,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Patrón "$patternName" guardado con ${_draftHits.length} golpes.',
          ),
        ),
      );
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(
      accordionSimulatorProvider.select((s) => s.bassRhythmRecorder),
    );
    final isRecording = recorder?.isRecording ?? false;
    final capturedHits = recorder?.hits.length ?? 0;

    final selectedPattern = ref.watch(
      accordionSimulatorProvider.select((s) => s.selectedBassRhythmPattern),
    );
    if (_draftHits.isEmpty && selectedPattern != null) {
      _draftPattern = selectedPattern;
      _draftHits = List.of(selectedPattern.hits);
      _bpm = (selectedPattern.quarterNotesPerMinute ?? 120.0).clamp(40.0, 220.0);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = selectedPattern.name;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.6),
        ),
      ),
      child: _mode == CapturePanelMode.reviewAndEdit
          ? _buildReviewAndEditMode()
          : _buildRecordingMode(isRecording, capturedHits),
    );
  }

  Widget _buildModeTabBar(bool isRecording) {
    final canReview = !isRecording && (_draftHits.isNotEmpty || _draftPattern != null);
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTabItem(
            label: 'Grabar',
            mode: CapturePanelMode.recording,
            keyName: 'capture_mode_recording_tab',
            enabled: !isRecording,
          ),
          _buildModeTabItem(
            label: 'Revisar / Editar',
            mode: CapturePanelMode.reviewAndEdit,
            keyName: 'capture_mode_review_tab',
            enabled: canReview,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabItem({
    required String label,
    required CapturePanelMode mode,
    required String keyName,
    required bool enabled,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      key: ValueKey(keyName),
      onTap: enabled
          ? () {
              if (mode == CapturePanelMode.reviewAndEdit && _draftHits.isEmpty) {
                final currentPattern = ref.read(accordionSimulatorProvider).selectedBassRhythmPattern;
                if (currentPattern != null) {
                  _draftPattern = currentPattern;
                  _draftHits = List.of(currentPattern.hits);
                  _bpm = (currentPattern.quarterNotesPerMinute ?? 120.0).clamp(40.0, 220.0);
                  if (_nameController.text.trim().isEmpty) {
                    _nameController.text = currentPattern.name;
                  }
                }
              }
              setState(() {
                _mode = mode;
              });
            }
          : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: !enabled
                ? const Color(0xFF94A3B8)
                : (isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingMode(bool isRecording, int capturedHits) {
    final patterns = ref.watch(
      accordionSimulatorProvider.select((s) => s.bassRhythmPatterns.length),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Capturar patrón rítmico',
                key: ValueKey('bass_capture_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildModeTabBar(isRecording),
            const SizedBox(width: 6),
            IconButton(
              key: const ValueKey('bass_capture_close_btn'),
              tooltip: 'Cerrar',
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              splashRadius: 13,
              onPressed: isRecording ? _cancelCapture : widget.onClose,
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('bass_capture_name_field'),
          controller: _nameController,
          enabled: !isRecording,
          maxLength: 40,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            labelText: 'Nombre del patrón',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Selecciona los bajos y tócalos en el panel mientras capturas',
          style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 2),
        const Text(
          'Teclado: 7 = ext. fila 1 · 8 = ext. fila 2 · 4 = int. fila 1 · 5 = int. fila 2',
          key: ValueKey('bass_capture_keyboard_hint'),
          style: TextStyle(fontSize: 9.5, color: Color(0xFF16A34A)),
        ),
        const SizedBox(height: 6),
        _buildMatrix(isRecording),
        const SizedBox(height: 4),
        if (isRecording)
          Text(
            'Capturando… $capturedHits golpe(s)',
            key: const ValueKey('bass_capture_status'),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDC2626),
            ),
          )
        else
          Text(
            '$patterns patrón(es) disponible(s)',
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const ValueKey('bass_capture_cancel_btn'),
              onPressed: isRecording ? _cancelCapture : widget.onClose,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30),
              ),
              child: Text(isRecording ? 'Cancelar' : 'Cerrar'),
            ),
            const SizedBox(width: 8),
            if (isRecording)
              FilledButton.icon(
                key: const ValueKey('bass_capture_stop_btn'),
                onPressed: _stopCapture,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                ),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('Finalizar y Editar',
                    style: TextStyle(fontSize: 11.5)),
              )
            else
              FilledButton.icon(
                key: const ValueKey('bass_capture_start_btn'),
                onPressed:
                    _selectedButtons.isEmpty ? null : _startCapture,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                ),
                icon: const Icon(Icons.fiber_manual_record, size: 13),
                label: const Text('Capturar',
                    style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewAndEditMode() {
    final selectedHit = (_draftHits.isNotEmpty && _selectedHitIndex < _draftHits.length)
        ? _draftHits[_selectedHitIndex]
        : null;
    final totalQuarters = _totalQuarters();

    final fundBtn = selectedHit != null ? _resolveFundamental(selectedHit.buttonIndex) : 7;
    final chordBtn = selectedHit != null ? _resolveChord(selectedHit.buttonIndex) : 4;

    final isFundActive = selectedHit != null && selectedHit.buttonIndexes.contains(fundBtn);
    final isChordActive = selectedHit != null && selectedHit.buttonIndexes.contains(chordBtn);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado del modo de edición
        Row(
          children: [
            const Icon(Icons.tune, size: 16, color: Color(0xFF059669)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Edición y Audición (${_draftHits.length} golpes)',
                key: const ValueKey('capture_review_title'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            _buildModeTabBar(false),
            const SizedBox(width: 6),
            IconButton(
              key: const ValueKey('capture_review_close_btn'),
              tooltip: 'Cerrar',
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              splashRadius: 13,
              onPressed: () {
                _stopPlayReview();
                widget.onClose?.call();
              },
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // 1. Línea de tiempo horizontal desplazable (Timeline) con botón para añadir golpe
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Línea de tiempo (golpes capturados):',
              style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            InkWell(
              key: const ValueKey('capture_timeline_add_hit_btn'),
              onTap: _addNewHitAtCurrentPosition,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 0.6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 11, color: Color(0xFF2563EB)),
                    SizedBox(width: 3),
                    Text('+ Golpe en Cursor', style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                for (var i = 0; i < _draftHits.length; i++) ...[
                  _buildTimelineHitCard(i, _draftHits[i], isSelected: i == _selectedHitIndex),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),

        // Barra de desplazamiento / Scrubbing interactiva
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Text(
                '${_playbackQuarter.toStringAsFixed(1)}q',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    key: const ValueKey('capture_review_scrubbing_slider'),
                    value: _playbackQuarter.clamp(0.0, totalQuarters),
                    min: 0.0,
                    max: totalQuarters > 0 ? totalQuarters : 4.0,
                    activeColor: const Color(0xFF16A34A),
                    inactiveColor: const Color(0xFFCBD5E1),
                    onChanged: (val) {
                      setState(() {
                        _playbackQuarter = val;
                      });
                    },
                  ),
                ),
              ),
              Text(
                '${totalQuarters.toStringAsFixed(1)}q',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 3),

        // 2. Editor del Golpe Seleccionado (Timing, Duración, Hileras y Botones)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fila 1: Título de Golpe + Controles de Onset/Timing + Borrar Golpe
              Row(
                children: [
                  Text(
                    'Golpe #${_selectedHitIndex + 1}:',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 0.6),
                    ),
                    child: Text(
                      '${selectedHit?.onsetQuarterBeats.toStringAsFixed(2)}q',
                      key: const ValueKey('capture_hit_onset_text'),
                      style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Botones de ajuste fino de tiempo
                  _buildMiniActionBtn(
                    key: 'capture_hit_onset_minus_btn',
                    label: '-0.1q',
                    tooltip: 'Adelantar golpe (-0.1 pulso)',
                    onTap: () => _adjustHitOnset(-0.1),
                  ),
                  const SizedBox(width: 3),
                  _buildMiniActionBtn(
                    key: 'capture_hit_onset_plus_btn',
                    label: '+0.1q',
                    tooltip: 'Retrasar golpe (+0.1 pulso)',
                    onTap: () => _adjustHitOnset(0.1),
                  ),
                  const SizedBox(width: 3),
                  _buildMiniActionBtn(
                    key: 'capture_hit_quantize_btn',
                    label: 'Q 1/4',
                    tooltip: 'Cuantizar al 1/4 de tiempo más cercano',
                    onTap: () => _quantizeHitOnset(grid: 0.25),
                  ),
                  const Spacer(),
                  // Indicador de 1 o 2 botones
                  Text(
                    (isFundActive && isChordActive)
                        ? '2 botones activos'
                        : '1 botón activo',
                    style: TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w800,
                      color: (isFundActive && isChordActive) ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Botón para eliminar el golpe seleccionado
                  Tooltip(
                    message: _draftHits.length > 1
                        ? 'Eliminar este golpe'
                        : 'El patrón debe tener al menos 1 golpe',
                    child: IconButton(
                      key: const ValueKey('capture_hit_delete_btn'),
                      constraints: const BoxConstraints.tightFor(width: 22, height: 22),
                      padding: EdgeInsets.zero,
                      splashRadius: 11,
                      onPressed: _draftHits.length > 1 ? _deleteSelectedHit : null,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 15,
                        color: _draftHits.length > 1 ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // Fila 2: Selector de Duración + Selector de Fila (Hilera 1 vs Hilera 2)
              Row(
                children: [
                  const Text('Duración:', style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(width: 4),
                  _buildDurationPill('0.25q', 0.25, selectedHit?.durationQuarterBeats ?? 0.5, 'capture_hit_duration_025_btn'),
                  const SizedBox(width: 3),
                  _buildDurationPill('0.5q', 0.5, selectedHit?.durationQuarterBeats ?? 0.5, 'capture_hit_duration_050_btn'),
                  const SizedBox(width: 3),
                  _buildDurationPill('1.0q', 1.0, selectedHit?.durationQuarterBeats ?? 0.5, 'capture_hit_duration_100_btn'),
                  const Spacer(),
                  const Text('Fila:', style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(width: 4),
                  _buildRowPill('Fila 1 (7/4)', isSelected: fundBtn == 7, keyName: 'capture_hit_row1_btn', onTap: () => _setHitRow(1)),
                  const SizedBox(width: 3),
                  _buildRowPill('Fila 2 (8/5)', isSelected: fundBtn != 7, keyName: 'capture_hit_row2_btn', onTap: () => _setHitRow(2)),
                ],
              ),
              const SizedBox(height: 4),

              // Fila 3: Los dos cuadros pequeños compactos: [Bajo Fundamental | Acorde Acompañante]
              Row(
                children: [
                  Expanded(
                    child: _buildHitButtonBox(
                      key: const ValueKey('capture_hit_box_fundamental'),
                      title: 'Bajo Fundamental',
                      buttonLabel: 'Botón $fundBtn',
                      isActive: isFundActive,
                      onTap: () => _toggleHitButton(isChord: false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildHitButtonBox(
                      key: const ValueKey('capture_hit_box_chord'),
                      title: 'Acorde Acompañante',
                      buttonLabel: 'Botón $chordBtn',
                      isActive: isChordActive,
                      onTap: () => _toggleHitButton(isChord: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 3. Controles de Reproducción y Tempo (BPM independiente)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('capture_review_play_btn'),
                tooltip: _isPlayingReview ? 'Pausar audición' : 'Reproducir audición',
                onPressed: _togglePlayReview,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isPlayingReview ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 24,
                  color: const Color(0xFF16A34A),
                ),
              ),
              IconButton(
                key: const ValueKey('capture_review_stop_btn'),
                tooltip: 'Detener',
                onPressed: _stopPlayReview,
                constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.stop, size: 20, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              // Control de Tempo / BPM
              Expanded(
                child: Row(
                  children: [
                    const Text('BPM:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        key: const ValueKey('capture_review_bpm_slider'),
                        value: _bpm,
                        min: 40.0,
                        max: 220.0,
                        divisions: 180,
                        activeColor: const Color(0xFF2563EB),
                        inactiveColor: const Color(0xFFCBD5E1),
                        onChanged: (val) {
                          setState(() {
                            _bpm = val;
                          });
                        },
                      ),
                    ),
                    Text(
                      '${_bpm.round()}',
                      key: const ValueKey('capture_review_bpm_text'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 4. Botones de acción: Grabar de nuevo y Guardar Patrón
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('capture_review_rerecord_btn'),
              onPressed: () {
                _stopPlayReview();
                _startCapture();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              icon: const Icon(Icons.fiber_manual_record, size: 12, color: Color(0xFFDC2626)),
              label: const Text('Grabar de nuevo', style: TextStyle(fontSize: 10.5)),
            ),
            FilledButton.icon(
              key: const ValueKey('capture_review_save_btn'),
              onPressed: _saveFinalPattern,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 30),
              ),
              icon: const Icon(Icons.save_rounded, size: 14),
              label: const Text('Guardar Patrón', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineHitCard(int index, BassRhythmHit hit, {required bool isSelected}) {
    final isBoth = hit.pairedButtonIndex != null;

    final badgeLabel = isBoth ? '2 Botones' : '1 Botón';
    final badgeColor = isBoth ? const Color(0xFF16A34A) : const Color(0xFF2563EB);

    return InkWell(
      key: ValueKey('capture_timeline_hit_$index'),
      onTap: () {
        setState(() {
          _selectedHitIndex = index;
          _playbackQuarter = hit.onsetQuarterBeats;
        });
        _playHitSound(hit);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '#${index + 1}',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
              ),
            ),
            Text(
              '${hit.onsetQuarterBeats.toStringAsFixed(1)}q',
              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniActionBtn({
    required String key,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.7),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationPill(
    String label,
    double val,
    double currentVal,
    String keyName,
  ) {
    final isSelected = (val - currentVal).abs() < 0.05;
    return InkWell(
      key: ValueKey(keyName),
      onTap: () => _setHitDuration(val),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildRowPill(
    String label, {
    required bool isSelected,
    required String keyName,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: ValueKey(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildHitButtonBox({
    required Key key,
    required String title,
    required String buttonLabel,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
            width: isActive ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w700,
                    color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  buttonLabel,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 9,
                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isActive ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.w900,
                      color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrix(bool isRecording) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 40),
            for (var c = 0; c < BassMatrixLayout.columns; c++)
              Expanded(
                child: Center(
                  child: Text(
                    BassMatrixLayout.columnLabelFor(c),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        for (var r = 0; r < BassMatrixLayout.rows; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    'Fila ${r + 1}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                for (var c = 0; c < BassMatrixLayout.columns; c++)
                  Expanded(
                    child: _BassMatrixCell(
                      row: r,
                      column: c,
                      isSelected: _selectedButtons.contains(
                        BassMatrixLayout.buttonNumberFor(row: r, column: c),
                      ),
                      onTap: () => _toggleButton(
                        BassMatrixLayout.buttonNumberFor(row: r, column: c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Caja de la matriz 2×2 con el nombre genérico del bajo físico.
class _BassMatrixCell extends ConsumerWidget {
  final int row;
  final int column;
  final bool isSelected;
  final VoidCallback onTap;

  const _BassMatrixCell({
    required this.row,
    required this.column,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonNumber =
        BassMatrixLayout.buttonNumberFor(row: row, column: column);
    final bassData = ref.watch(
      accordionSimulatorProvider.select((s) => s.bassData1),
    );

    // Nombre genérico del bajo físico (push/pull) para esa caja.
    final label = _genericLabelFor(bassData, buttonNumber);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Material(
        key: ValueKey('bass_matrix_cell_$buttonNumber'),
        color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFCBD5E1),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$buttonNumber',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? const Color(0xFF15803D)
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 10,
                      color: isSelected
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.0, height: 1.05),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Etiqueta genérica `Cierra / Abre` del bajo indicado.
  String _genericLabelFor(List<BassButtonModel> basses, int buttonNumber) {
    if (basses.isEmpty) return 'Bajo $buttonNumber';
    final fundamental = basses
        .where((b) =>
            b.type == ButtonType.fundamental && b.btnIndex == buttonNumber)
        .toList();
    final resolved = fundamental.isNotEmpty ? fundamental.first : basses.first;
    return '${resolved.namePush} / ${resolved.namePull}';
  }
}
