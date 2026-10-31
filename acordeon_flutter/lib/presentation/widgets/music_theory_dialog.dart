import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/theory/music_theory_topics.dart';

/// Modal interactivo de Teoría Musical aplicada al Acordeón Diatónico.
/// Cuenta con menú lateral a la izquierda (Básico a Avanzado) y panel de contenido a la derecha.
class MusicTheoryDialog extends StatefulWidget {
  const MusicTheoryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const MusicTheoryDialog(),
    );
  }

  @override
  State<MusicTheoryDialog> createState() => _MusicTheoryDialogState();
}

class _MusicTheoryDialogState extends State<MusicTheoryDialog> {
  int _selectedTopicIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.90).clamp(650.0, 920.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(480.0, 680.0);

    final currentTopic = MusicTheoryCatalog.topics[_selectedTopicIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ─── CABECERA DEL MODAL ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Slate oscuro elegante
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.graduationCap,
                      size: 16,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Teoría Musical del Acordeón Diatónico',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'De los fundamentos del pentagrama a la armonía y progresiones tradicionales',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                    tooltip: 'Cerrar ventana',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // ─── CUERPO PRINCIPAL: MENÚ LATERAL + CONTENIDO ──────────────────
            Expanded(
              child: Row(
                children: [
                  // Menú lateral izquierdo (230 px)
                  Container(
                    width: 230,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                          child: Text(
                            'MÓDULOS DE APRENDIZAJE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF64748B).withValues(alpha: 0.9),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            itemCount: MusicTheoryCatalog.topics.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 3),
                            itemBuilder: (context, index) {
                              final topic = MusicTheoryCatalog.topics[index];
                              final isSelected = index == _selectedTopicIndex;

                              return InkWell(
                                key: ValueKey('theory_topic_item_$index'),
                                onTap: () => setState(() => _selectedTopicIndex = index),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF93C5FD) : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      FaIcon(
                                        topic.icon,
                                        size: 13,
                                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              topic.title,
                                              style: TextStyle(
                                                fontSize: 10.8,
                                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                                              decoration: BoxDecoration(
                                                color: topic.levelColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                topic.level,
                                                style: TextStyle(
                                                  fontSize: 8.0,
                                                  fontWeight: FontWeight.w800,
                                                  color: topic.levelColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Panel de contenido derecho (Expanded)
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Encabezado del tema activo
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: currentTopic.levelColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: FaIcon(
                                    currentTopic.icon,
                                    size: 18,
                                    color: currentTopic.levelColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentTopic.title,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Text(
                                        currentTopic.subtitle,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: currentTopic.levelColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: currentTopic.levelColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    currentTopic.level,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: currentTopic.levelColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 14),

                            // Secciones del tema
                            ...currentTopic.sections.map((sec) => _buildSectionCard(sec)),
                          ],
                        ),
                      ),
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

  Widget _buildSectionCard(TheorySectionItem sec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la sección
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  sec.heading,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Descripción explicativa
          Text(
            sec.description,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF334155),
              height: 1.45,
            ),
          ),

          // Puntos clave / viñetas
          if (sec.bulletPoints != null && sec.bulletPoints!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: sec.bulletPoints!.map((pt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.circle, size: 5, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            pt,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Diagrama musical / caja de notación
          if (sec.musicalDiagram != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Terminal oscuro
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.music, size: 11, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sec.musicalDiagram!,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE2E8F0),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tabla estructurada
          if (sec.tableData != null && sec.tableData!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: sec.tableData!.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 10.2,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              fontSize: 10.2,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Tip o consejo práctico en el acordeón
          if (sec.accordionTip != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB), // Ámbar suave
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: FaIcon(
                      FontAwesomeIcons.lightbulb,
                      size: 11,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Aplicación en el Acordeón: ',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          TextSpan(
                            text: sec.accordionTip!,
                            style: const TextStyle(
                              fontSize: 10.0,
                              color: Color(0xFF78350F),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
