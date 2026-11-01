import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../domain/models/accordion_data.dart';
import '../../domain/models/bass_matrix_layout.dart';
import '../../domain/models/bass_rhythm_pattern.dart';
import '../controllers/accordion_controller.dart';

/// Diálogo de captura de patrones rítmicos de bajos.
///
/// Reemplaza al antiguo combobox de selección de patrón y al listado modal:
/// ahora la fuente de verdad es una **matriz 2×2** que relaciona cada caja con
/// un bajo físico del instrumento:
///
/// |            | Externos (col 0) | Internos (col 1) |
/// |------------|------------------|------------------|
/// | Fila 1     | botón 7          | botón 4          |
/// | Fila 2     | botón 8          | botón 5          |
///
/// Principios aplicados:
/// - **SRP**: este widget sólo presenta la matriz y delega toda la lógica al
///   notifier / [BassRhythmRecorder] del dominio.
/// - **OCP**: la disposición vive en [BassMatrixLayout]; cambiar el mapeo no
///   toca la UI.
/// - **ISP / bajo acoplamiento**: usa selectores finos, no el estado completo.
/// - **Hoare**: las precondiciones ({P}) se validan en el notifier con
///   `require`, no en el widget.
class BassRhythmCaptureDialog extends ConsumerStatefulWidget {
  final int accordionNumber;

  const BassRhythmCaptureDialog({super.key, this.accordionNumber = 1});

  @override
  ConsumerState<BassRhythmCaptureDialog> createState() =>
      _BassRhythmCaptureDialogState();
}

class _BassRhythmCaptureDialogState
    extends ConsumerState<BassRhythmCaptureDialog> {
  late final TextEditingController _nameController;
  final Set<int> _selectedButtons = {...BassMatrixLayout.buttonNumbers};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: 'Patrón ${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
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
    }
  }

  void _cancelCapture() {
    ref.read(accordionSimulatorProvider.notifier).cancelBassRhythmCapture();
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

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Capturar patrón rítmico',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('bass_capture_close_btn'),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('bass_capture_name_field'),
                controller: _nameController,
                enabled: !isRecording,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Nombre del patrón',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecciona los bajos que ejecutarán el patrón',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              _buildMatrix(isRecording),
              const SizedBox(height: 6),
              if (isRecording)
                Text(
                  'Capturando… $capturedHits golpe(s)',
                  key: const ValueKey('bass_capture_status'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              if (!isRecording)
                Text(
                  '$patterns patrón(es) disponible(s)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('bass_capture_cancel_btn'),
                    onPressed: isRecording
                        ? () {
                            _cancelCapture();
                          }
                        : () => Navigator.of(context).pop(),
                    child: Text(isRecording ? 'Cancelar' : 'Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  if (isRecording)
                    FilledButton.icon(
                      key: const ValueKey('bass_capture_stop_btn'),
                      onPressed: _stopCapture,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Detener captura'),
                    )
                  else
                    FilledButton.icon(
                      key: const ValueKey('bass_capture_start_btn'),
                      onPressed: _selectedButtons.isEmpty ? null : _startCapture,
                      icon: const Icon(Icons.fiber_manual_record, size: 16),
                      label: const Text('Capturar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatrix(bool isRecording) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 56),
            for (var c = 0; c < BassMatrixLayout.columns; c++)
              Expanded(
                child: Center(
                  child: Text(
                    BassMatrixLayout.columnLabelFor(c),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < BassMatrixLayout.rows; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    'Fila ${r + 1}',
                    style: const TextStyle(
                      fontSize: 10.5,
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
                      isRecording: isRecording,
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
  final bool isRecording;
  final VoidCallback onTap;

  const _BassMatrixCell({
    required this.row,
    required this.column,
    required this.isSelected,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonNumber =
        BassMatrixLayout.buttonNumberFor(row: row, column: column);
    final state = ref.watch(accordionSimulatorProvider);
    final bassData = state.bassData1;

    // Nombre genérico del bajo físico (push/pull) para esa caja.
    final label = _genericLabelFor(bassData, buttonNumber, state.notation);

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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? const Color(0xFF15803D)
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 13,
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
                  style: const TextStyle(fontSize: 9.5, height: 1.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Etiqueta genérica `Cierra / Abre` del bajo indicado.
  String _genericLabelFor(
    List<BassButtonModel> basses,
    int buttonNumber,
    NotationMode notation,
  ) {
    if (basses.isEmpty) return 'Bajo $buttonNumber';
    final fundamental = basses
        .where((b) =>
            b.type == ButtonType.fundamental && b.btnIndex == buttonNumber)
        .toList();
    final resolved = fundamental.isNotEmpty ? fundamental.first : basses.first;
    return '${resolved.namePush} / ${resolved.namePull}';
  }
}

/// Abre el diálogo de captura de patrones de bajos.
///
/// {P}: `context.mounted`.
/// {Q}: el diálogo se cierra y la captura en curso (si la hay) queda cancelada.
Future<void> showBassRhythmCaptureDialog(
  BuildContext context, {
  int accordionNumber = 1,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => BassRhythmCaptureDialog(
      accordionNumber: accordionNumber,
    ),
  );
}

/// Lista compacta de patrones capturados, usada en el panel de bajos.
final bassRhythmPatternsProvider = Provider<List<BassRhythmPattern>>((ref) {
  return ref.watch(
    accordionSimulatorProvider.select((s) => s.bassRhythmPatterns),
  );
});
