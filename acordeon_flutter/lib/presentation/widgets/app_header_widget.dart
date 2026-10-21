import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../controllers/accordion_controller.dart';
import 'audio_loader_dialog.dart';

class AppHeaderWidget extends ConsumerWidget {
  const AppHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Branding + Selectores A1 / A2
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                FontAwesomeIcons.compactDisc,
                size: 22,
                color: Color(0xFF0284C7),
              ),
              const SizedBox(width: 10),
              const Text(
                'Acordeón Diatónico Pro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 14),

              // Botones A1 y A2
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleBtn(
                      title: 'A1',
                      icon: FontAwesomeIcons.star,
                      isActive: state.showDiapason1,
                      onTap: notifier.toggleDiapason1,
                    ),
                    const SizedBox(width: 4),
                    _buildToggleBtn(
                      title: 'A2',
                      icon: FontAwesomeIcons.clone,
                      isActive: state.showDiapason2,
                      onTap: notifier.toggleDiapason2,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Acciones: Dropzone MP3 + Notación Latina/Alemana + Paleta de fondo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropzone de audio (ícono nube + nota)
              Tooltip(
                message: 'Seleccionar y cargar archivo MP3 o WAV local de tu equipo',
                child: InkWell(
                  onTap: () {
                    notifier.pickAndAnalyzeAudio(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: state.isAnalyzingAudio
                          ? const Color(0xFFFEF3C7)
                          : (state.audioReport != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: state.isAnalyzingAudio
                            ? const Color(0xFFF59E0B)
                            : (state.audioReport != null ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
                        style: BorderStyle.solid,
                        width: state.audioReport != null ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.isAnalyzingAudio) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Analizando...',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ] else if (state.audioReport != null) ...[
                          const FaIcon(FontAwesomeIcons.music, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              state.loadedAudioFileName ?? 'Pista Cargada',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle, size: 13, color: Color(0xFF10B981)),
                        ] else ...[
                          const FaIcon(FontAwesomeIcons.cloudArrowUp, size: 13, color: Color(0xFF0284C7)),
                          const SizedBox(width: 5),
                          const FaIcon(FontAwesomeIcons.music, size: 11, color: Color(0xFF0F172A)),
                          const SizedBox(width: 6),
                          const Text(
                            'Cargar Audio',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Demo rápido (1 Clic)
              Tooltip(
                message: 'Cargar Pista Demo de Vallenato (1 Clic)',
                child: InkWell(
                  onTap: () {
                    notifier.loadDemoAudioTrack(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 11, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text(
                          'Demo',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Toggle Notación
              ToggleButtons(
                isSelected: [
                  state.notation == NotationMode.latina,
                  state.notation == NotationMode.alemana,
                ],
                onPressed: (idx) {
                  notifier.setNotation(
                    idx == 0 ? NotationMode.latina : NotationMode.alemana,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: const Color(0xFF0284C7),
                constraints: const BoxConstraints(minHeight: 28, minWidth: 60),
                children: const [
                  Text('Latina', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('Alemana', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 12),

              // Selector de Color de Fondo
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.palette, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  const Text('Fondo:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 5),
                  PopupMenuButton<Color>(
                    tooltip: 'Cambiar color de fondo',
                    onSelected: (color) => notifier.setBackgroundColor(color),
                    itemBuilder: (context) => [
                      _buildColorMenuItem(const Color(0xFFF1F5F9), 'Gris Pizarra Claro'),
                      _buildColorMenuItem(const Color(0xFFFFFFFF), 'Blanco Puro'),
                      _buildColorMenuItem(const Color(0xFFF0F9FF), 'Azul Glaciar Suave'),
                      _buildColorMenuItem(const Color(0xFFFEFCE8), 'Crema Ámbar'),
                      _buildColorMenuItem(const Color(0xFFE2E8F0), 'Gris Plomo Zinc'),
                      _buildColorMenuItem(const Color(0xFF0F172A), 'Modo Oscuro Profundo'),
                    ],
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: state.backgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn({
    required String title,
    required FaIconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 10,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<Color> _buildColorMenuItem(Color color, String label) {
    return PopupMenuItem<Color>(
      value: color,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
