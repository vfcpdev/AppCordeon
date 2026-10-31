import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/audio_analysis_models.dart';
import '../controllers/accordion_controller.dart';

class EditAudioKeyBpmDialog extends ConsumerStatefulWidget {
  final AudioAnalysisReport report;

  const EditAudioKeyBpmDialog({
    super.key,
    required this.report,
  });

  @override
  ConsumerState<EditAudioKeyBpmDialog> createState() => _EditAudioKeyBpmDialogState();
}

class _EditAudioKeyBpmDialogState extends ConsumerState<EditAudioKeyBpmDialog> {
  static const List<String> noteNames = [
    'Do / C',
    'Do♯ / C#',
    'Re / D',
    'Mi♭ / Eb',
    'Mi / E',
    'Fa / F',
    'Fa♯ / F#',
    'Sol / G',
    'Sol♯ / G#',
    'La / A',
    'Si♭ / Bb',
    'Si / B',
  ];

  late int _selectedRootMod;
  late String _selectedMode;
  late TextEditingController _bpmController;

  @override
  void initState() {
    super.initState();
    _selectedRootMod = widget.report.mainKey.rootMod % 12;
    _selectedMode = widget.report.mainKey.mode.toLowerCase() == 'minor' ? 'minor' : 'major';
    _bpmController = TextEditingController(text: widget.report.bpm.toString());
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final parsedBpm = int.tryParse(_bpmController.text.trim()) ?? widget.report.bpm;

    notifier.updateAudioKeyAndBpm(
      rootMod: _selectedRootMod,
      mode: _selectedMode,
      bpm: parsedBpm,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tono y BPM corregidos: ${_selectedMode == "major" ? "Mayor" : "Menor"} a $parsedBpm BPM',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.sliders,
                    size: 16,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Corregir Tono Principal y BPM',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Selector de Tónica (Nota)
            const Text(
              'NOTA PRINCIPAL (TÓNICA):',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedRootMod,
                  isExpanded: true,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(
                        noteNames[index],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRootMod = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modalidad (Mayor / Menor)
            const Text(
              'MODALIDAD:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text(
                        'Mayor',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    selected: _selectedMode == 'major',
                    selectedColor: const Color(0xFF0284C7),
                    labelStyle: TextStyle(
                      color: _selectedMode == 'major' ? Colors.white : const Color(0xFF334155),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMode = 'major');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text(
                        'Menor',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    selected: _selectedMode == 'minor',
                    selectedColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: _selectedMode == 'minor' ? Colors.white : const Color(0xFF334155),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMode = 'minor');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tempo (BPM)
            const Text(
              'TEMPO (BPM):',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bpmController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      hintText: 'Ej. 128',
                      suffixText: 'BPM',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Disminuir BPM (-5)',
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                  onPressed: () {
                    final current = int.tryParse(_bpmController.text) ?? widget.report.bpm;
                    final next = (current - 5).clamp(30, 300);
                    _bpmController.text = next.toString();
                  },
                ),
                IconButton(
                  tooltip: 'Aumentar BPM (+5)',
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF64748B)),
                  onPressed: () {
                    final current = int.tryParse(_bpmController.text) ?? widget.report.bpm;
                    final next = (current + 5).clamp(30, 300);
                    _bpmController.text = next.toString();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botones de acción
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Guardar y Aplicar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _saveChanges,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
