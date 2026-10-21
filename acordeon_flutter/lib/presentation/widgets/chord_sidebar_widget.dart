import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/accordion_controller.dart';

class ChordSidebarWidget extends ConsumerWidget {
  final int accordionNumber; // 1 or 2

  const ChordSidebarWidget({
    super.key,
    this.accordionNumber = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accordionSimulatorProvider);
    final isPrimary = accordionNumber == 1;

    final primaryColor = isPrimary ? const Color(0xFF0284C7) : const Color(0xFF059669);
    final title = isPrimary ? 'ACORDES CANCIÓN' : '2DO ACORDEÓN (EQUIV.)';

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera del Sidebar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFFE0F2FE) : const Color(0xFFD1FAE5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: isPrimary ? const Color(0xFFBAE6FD) : const Color(0xFFA7F3D0),
                ),
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  isPrimary ? FontAwesomeIcons.compactDisc : FontAwesomeIcons.clone,
                  size: 11,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selector de Octavas
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['2', '3', '4', '5', 'Todas'].map((oct) {
                        final isSelected = oct == 'Todas';
                        return Container(
                          margin: const EdgeInsets.only(right: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            oct,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left, size: 11, color: Color(0xFF64748B)),
                          Text(
                            'Todas',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                          Icon(Icons.chevron_right, size: 11, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Panel 1: Abre (Azul)
                _buildFingeringBox(
                  title: 'Abre',
                  icon: FontAwesomeIcons.arrowLeft,
                  badgeText: '4/9 bot.',
                  isPush: false,
                  h3Buttons: [
                    _ButtonBadge(index: 2, note: 'Sol', isActive: true),
                    _ButtonBadge(index: 3, note: 'Si♭', isActive: true),
                    _ButtonBadge(index: 6, note: 'Sol', isActive: false),
                    _ButtonBadge(index: 7, note: 'Si♭', isActive: false),
                  ],
                  h2Buttons: [],
                  h1Buttons: [
                    _ButtonBadge(index: 3, note: 'Mi♭', isActive: true),
                    _ButtonBadge(index: 4, note: 'Sol', isActive: true),
                    _ButtonBadge(index: 7, note: 'Mi♭', isActive: false),
                    _ButtonBadge(index: 8, note: 'Sol', isActive: false),
                  ],
                ),
                const SizedBox(height: 8),

                // Panel 2: Cierra (Rojo)
                _buildFingeringBox(
                  title: 'Cierra',
                  icon: FontAwesomeIcons.arrowRight,
                  badgeText: '4/16 bot.',
                  isPush: true,
                  h3Buttons: [
                    _ButtonBadge(index: 3, note: 'Si♭', isActive: true),
                    _ButtonBadge(index: 5, note: 'Mi♭', isActive: false),
                    _ButtonBadge(index: 6, note: 'Sol', isActive: false),
                  ],
                  h2Buttons: [
                    _ButtonBadge(index: 2, note: 'Mi♭', isActive: false),
                    _ButtonBadge(index: 3, note: 'Mi♭', isActive: true),
                    _ButtonBadge(index: 4, note: 'Sol', isActive: true),
                    _ButtonBadge(index: 5, note: 'Si♭', isActive: true),
                  ],
                  h1Buttons: [
                    _ButtonBadge(index: 2, note: 'Si♭', isActive: false),
                    _ButtonBadge(index: 5, note: 'Si♭', isActive: true),
                    _ButtonBadge(index: 6, note: 'Mi♭', isActive: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingeringBox({
    required String title,
    required FaIconData icon,
    required String badgeText,
    required bool isPush,
    required List<_ButtonBadge> h3Buttons,
    required List<_ButtonBadge> h2Buttons,
    required List<_ButtonBadge> h1Buttons,
  }) {
    final bannerColor = isPush ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final bannerBg = isPush ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Cabecera (Abre / Cierra)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              border: Border(bottom: BorderSide(color: bannerColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(icon, size: 8, color: bannerColor),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: bannerColor),
                    ),
                  ],
                ),
                Text(
                  badgeText,
                  style: const TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Columnas H3 (Ad), H2 (Med), H1 (Af)
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildColumn('H3 (Ad)', h3Buttons, bannerColor)),
                Container(width: 1, height: 90, color: const Color(0xFFE2E8F0)),
                Expanded(child: _buildColumn('H2 (Med)', h2Buttons, bannerColor)),
                Container(width: 1, height: 90, color: const Color(0xFFE2E8F0)),
                Expanded(child: _buildColumn('H1 (Af)', h1Buttons, bannerColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String header, List<_ButtonBadge> buttons, Color accentColor) {
    return Column(
      children: [
        Text(
          header,
          style: const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        if (buttons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('-', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
          )
        else
          ...buttons.map((b) {
            return Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: b.isActive ? accentColor.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: b.isActive ? accentColor.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (b.isActive) ...[
                    Icon(Icons.check, size: 8, color: accentColor),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    '${b.index}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: b.isActive ? accentColor : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    b.note,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: b.isActive ? FontWeight.w900 : FontWeight.normal,
                      color: b.isActive ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _ButtonBadge {
  final int index;
  final String note;
  final bool isActive;

  const _ButtonBadge({
    required this.index,
    required this.note,
    required this.isActive,
  });
}
