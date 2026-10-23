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
    final isPrimary = accordionNumber == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Badge + Selector de Afinación
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrimary ? const Color(0xFFE0F2FE) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPrimary ? const Color(0xFFBAE6FD) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      isPrimary ? FontAwesomeIcons.star : FontAwesomeIcons.clone,
                      size: 10,
                      color: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Acordeón $accordionNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isPrimary ? const Color(0xFF0369A1) : const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 240,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TuningDefinition>(
                    value: currentTuning,
                    isDense: true,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    items: TuningRegistry.defaultTunings.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(
                          '${t.name} (${t.rowsDescription})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: onTuningChanged,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12, color: Color(0xFFE2E8F0)),

          // Fila 2: Fuelle + Bajos + Mirror + Volumen
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Fuelle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Fuelle:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                        ),
                        child: const Text(
                          'Esc',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Abre (Azul)
                        Tooltip(
                          message: 'Abre (Fuelle)',
                          child: InkWell(
                            onTap: () => onBellowsChanged(BellowsMode.pull),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: bellowsMode == BellowsMode.pull ? const Color(0xFF2563EB) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.arrowLeft,
                                size: 11,
                                color: bellowsMode == BellowsMode.pull ? Colors.white : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),

                        // Cierra (Rojo)
                        Tooltip(
                          message: 'Cierra (Fuelle)',
                          child: InkWell(
                            onTap: () => onBellowsChanged(BellowsMode.push),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: bellowsMode == BellowsMode.push ? const Color(0xFFDC2626) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.arrowRight,
                                size: 11,
                                color: bellowsMode == BellowsMode.push ? Colors.white : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Toggle Bajos
              InkWell(
                onTap: onToggleBass,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: !isBassCollapsed ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    'Bajos',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: !isBassCollapsed ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),

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
                        isMirror ? 'Ad<-Af' : 'Af->Ad',
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

              // Volumen & Mute
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onToggleSyncVolume != null) ...[
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.link,
                        size: 10,
                        color: syncVolume ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      onPressed: onToggleSyncVolume,
                      tooltip: 'Sincronizar volumen',
                    ),
                  ],
                  IconButton(
                    icon: FaIcon(
                      isMuted ? FontAwesomeIcons.volumeXmark : FontAwesomeIcons.volumeHigh,
                      size: 11,
                      color: isMuted ? Colors.red : const Color(0xFF475569),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    onPressed: onToggleMute,
                    tooltip: 'Silenciar',
                  ),
                  SizedBox(
                    width: 70,
                    height: 20,
                    child: Slider(
                      value: isMuted ? 0.0 : volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: onVolumeChanged,
                    ),
                  ),
                  Text(
                    '${(volume * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
