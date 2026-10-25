import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/models/tuning.dart';


class DiapasonCardHeader extends StatelessWidget {
  final int accordionNumber; // 1 or 2
  final TuningDefinition currentTuning;
  final ValueChanged<TuningDefinition?> onTuningChanged;
  final BellowsMode bellowsMode;
  final ValueChanged<BellowsMode> onBellowsChanged;
  final bool isBassCollapsed;
  final VoidCallback onToggleBass;
  final bool isMirror;
  final VoidCallback onToggleMirror;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final bool syncVolume;
  final VoidCallback? onToggleSyncVolume;

  const DiapasonCardHeader({
    super.key,
    required this.accordionNumber,
    required this.currentTuning,
    required this.onTuningChanged,
    required this.bellowsMode,
    required this.onBellowsChanged,
    required this.isBassCollapsed,
    required this.onToggleBass,
    required this.isMirror,
    required this.onToggleMirror,
    required this.volume,
    required this.onVolumeChanged,
    required this.isMuted,
    required this.onToggleMute,
    this.syncVolume = false,
    this.onToggleSyncVolume,
  });

  @override
  Widget build(BuildContext context) {
  

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Divider(height: 8, color: Color(0xFFE2E8F0)),

          // Fila 2: Mirror
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Mirror (Invertir Hileras Af->Ad)
              InkWell(
                onTap: onToggleMirror,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMirror ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.arrowsRotate,
                        size: 9,
                        color: isMirror ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isMirror ? 'Af<-Ad' : 'Ad->Af',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isMirror ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
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
