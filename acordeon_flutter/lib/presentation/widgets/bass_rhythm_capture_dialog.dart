import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/bass_matrix_layout.dart';
import '../controllers/accordion_controller.dart';

/// Panel INLINE (no modal) de captura de patrones rítmicos de bajos.
///
/// **Por qué inline y no diálogo**: la captura requiere tocar los bajos del
/// panel mientras el temporizador corre. Un `showDialog` crea una barrera
/// modal que absorbe los pointers, impidiendo registrar golpes. Como widget
/// embebido sobre el propio panel, los bajos siguen accesibles.
///
/// La fuente de verdad es una **matriz 2×2** que relaciona cada caja con un
/// bajo físico del instrumento:
///
/// |            | Externos (col 0) | Internos (col 1) |
/// |------------|------------------|------------------|
/// | Fila 1     | botón 7          | botón 4          |
/// | Fila 2     | botón 8          | botón 5          |
///
/// Principios aplicados:
/// - **SRP**: este widget sólo presenta la matriz y delega toda la lógica al
///   notifier / `BassRhythmRecorder` del dominio.
/// - **OCP**: la disposición vive en [BassMatrixLayout]; cambiar el mapeo no
///   toca la UI.
/// - **ISP / bajo acoplamiento**: usa selectores finos, no el estado completo.
/// - **Hoare**: las precondiciones ({P}) se validan en el notifier con
///   `require`, no en el widget.
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    // Si hay una captura ya activa (panel reabierto), refleja su selección.
    final recorder =
        ref.read(accordionSimulatorProvider).bassRhythmRecorder;
    if (recorder != null && recorder.isRecording) {
      _selectedButtons = {...recorder.selectedButtons};
      _nameController.text = recorder.name;
    }
  }

  @override
  void dispose() {
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
      // La captura en curso ignora golpes de cajas deseleccionadas.
      notifier.toggleBassCaptureSelection(buttonNumber);
    }
  }

  void _startCapture() {
    if (_selectedButtons.isEmpty) return;
    ref.read(accordionSimulatorProvider.notifier).startBassRhythmCapture(
          name: _nameController.text,
          selectedButtons: _selectedButtons,
        );
  }

  void _stopCapture() {
    final pattern =
        ref.read(accordionSimulatorProvider.notifier).stopBassRhythmCapture();
    if (pattern != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Patrón "${pattern.name}" guardado con ${pattern.hits.length} golpes.',
          ),
        ),
      );
      widget.onClose?.call();
    }
  }

  void _cancelCapture() {
    ref.read(accordionSimulatorProvider.notifier).cancelBassRhythmCapture();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(
      accordionSimulatorProvider.select((s) => s.bassRhythmRecorder),
    );
    final patterns = ref.watch(
      accordionSimulatorProvider.select((s) => s.bassRhythmPatterns.length),
    );
    final isRecording = recorder?.isRecording ?? false;
    final capturedHits = recorder?.hits.length ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.6),
        ),
      ),
      child: Column(
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
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 15),
                  label: const Text('Detener',
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
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        key: ValueKey('bass_matrix_cell_$buttonNumber'),
        color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFCBD5E1),
                width: isSelected ? 1.6 : 1,
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
                        fontSize: 13,
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
                      size: 11,
                      color: isSelected
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, height: 1.1),
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
