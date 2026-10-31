import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/chord_catalog.dart';
import '../../domain/theory/chord_detector_engine.dart';
import '../controllers/accordion_controller.dart';

/// Widget compacto, reactivo y desacoplable para el Detector Inteligente de Acordes.
/// Se ubica directamente debajo de la sección "Estado del Acorde" o como ventana flotante.
class ChordDetectorWidget extends ConsumerWidget {
  final double? width;
  final bool isFloating;
  final VoidCallback? onDock;

  const ChordDetectorWidget({
    super.key,
    this.width,
    this.isFloating = false,
    this.onDock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    final chord = state.detectedChord;
    final hasSelection = state.detectorSelectedButtons.isNotEmpty;
    final notation = state.notation;

    // Disponibilidad en el fuelle (Abre / Cierra)
    final availability = chord != null
        ? ChordDetectorEngine.evaluateDiapasonBellows(
            chordPitchClasses: chord.pitchClasses,
            trebleData: state.trebleData1,
          )
        : null;

    final cardWidth = width ?? 185.0;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: state.detectorMode
              ? const Color(0xFFC084FC)
              : const Color(0xFFCBD5E1),
          width: state.detectorMode ? 1.2 : 0.8,
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
          // ─── CABECERA: TÍTULO Y BOTONES DE ACCIÓN ──────────────────────
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(
                  FontAwesomeIcons.microchip,
                  size: 10,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Detector',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 6),

                // 1. Push Button Activo / Inactivo (Sin texto, Verde = Activo, Rojo = Inactivo)
                Tooltip(
                  message: state.detectorMode
                      ? 'Detector Activo (clic para desactivar)'
                      : 'Detector Inactivo (clic para activar)',
                  child: InkWell(
                    key: const ValueKey('detector_toggle_active_btn'),
                    onTap: notifier.toggleDetectorMode,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: state.detectorMode
                            ? const Color(0xFF16A34A) // Verde Activo
                            : const Color(0xFFDC2626), // Rojo Inactivo
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: (state.detectorMode
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626))
                                .withValues(alpha: 0.4),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const FaIcon(
                        FontAwesomeIcons.powerOff,
                        size: 8.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 2. Botón Play (Solo icono)
                Tooltip(
                  message: 'Reproducir acorde',
                  child: InkWell(
                    key: const ValueKey('detector_play_btn'),
                    onTap: hasSelection ? notifier.playDetectorChord : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: hasSelection
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: FaIcon(
                        FontAwesomeIcons.play,
                        size: 8.5,
                        color: hasSelection ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 3. Botón Arpegio (Solo icono, igual que en Acorde)
                Tooltip(
                  message: 'Reproducir arpegio',
                  child: InkWell(
                    key: const ValueKey('detector_arpeggio_btn'),
                    onTap: hasSelection ? notifier.arpeggioDetectorChord : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: hasSelection
                            ? const Color(0xFF059669)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        size: 8.5,
                        color: hasSelection ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 4. Botón Limpiar (Solo icono trash)
                Tooltip(
                  message: 'Limpiar selección',
                  child: InkWell(
                    key: const ValueKey('detector_clear_btn'),
                    onTap: hasSelection ? notifier.clearDetector : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: hasSelection
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: FaIcon(
                        FontAwesomeIcons.trashCan,
                        size: 8.5,
                        color: hasSelection
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 5. Botón Desacoplar / Acoplar
                Tooltip(
                  message: state.isChordDetectorUndocked
                      ? 'Acoplar Detector de Acordes'
                      : 'Desacoplar Detector de Acordes (mover libremente)',
                  child: InkWell(
                    key: const ValueKey('detector_undock_btn'),
                    onTap: onDock ?? notifier.toggleUndockChordDetector,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: state.isChordDetectorUndocked
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: state.isChordDetectorUndocked
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: FaIcon(
                        state.isChordDetectorUndocked
                            ? FontAwesomeIcons.compress
                            : FontAwesomeIcons.arrowUpRightFromSquare,
                        size: 8.0,
                        color: state.isChordDetectorUndocked
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // ─── ESTADO DE SELECCIÓN O GUÍA ────────────────────────────────
          if (!hasSelection)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                state.detectorMode
                    ? 'Toca 2 o más botones en el diapasón para identificar el acorde.'
                    : 'Activa el botón verde para seleccionar botones en el diapasón.',
                style: const TextStyle(
                  fontSize: 7.8,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                  height: 1.2,
                ),
              ),
            )
          else ...[
            // Tira de conteo
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${state.detectorSelectedButtons.length} botones',
                    style: const TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  if (chord != null && chord.inversion.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        chord.inversion,
                        style: const TextStyle(
                          fontSize: 7.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E22CE),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ─── ACORDE CONSTRUIDO / IDENTIFICADO ────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del acorde (sigue notación)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chord != null
                              ? chord.formattedName(notation)
                              : 'Identificando...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: chord != null
                                ? const Color(0xFF581C87)
                                : const Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chord != null && chord.chordSymbol.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Text(
                            chord.formattedSymbol(notation),
                            style: const TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Notas que forman el acorde
                  if (chord != null) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Notas: ',
                            style: TextStyle(
                              fontSize: 8.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B21A8),
                            ),
                          ),
                          TextSpan(
                            text: chord.pitchClasses
                                .map((pc) {
                                  final normPc = ((pc % 12) + 12) % 12;
                                  return notation == NotationMode.alemana
                                      ? ChordCatalog.germanRootNames[normPc]
                                      : ChordCatalog.latinRootNames[normPc];
                                })
                                .join(' - '),
                            style: const TextStyle(
                              fontSize: 8.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Lógica del acorde en el diapasón: Fuelle Abre / Cierra
                    if (availability != null)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: availability.isCompletePull
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: availability.isCompletePull
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFDE68A),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                availability.isCompletePull
                                    ? 'Abre (←): Completo'
                                    : 'Abre: ${availability.pullMatchedPcs.length}/${chord.pitchClasses.length}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 7.2,
                                  fontWeight: FontWeight.w800,
                                  color: availability.isCompletePull
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: availability.isCompletePush
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: availability.isCompletePush
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFDE68A),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                availability.isCompletePush
                                    ? 'Cierra (→): Completo'
                                    : 'Cierra: ${availability.pushMatchedPcs.length}/${chord.pitchClasses.length}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 7.2,
                                  fontWeight: FontWeight.w800,
                                  color: availability.isCompletePush
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 5),

                    // Botones de acción: Asignar y Mostrar en Diapasón
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            key: const ValueKey('detector_assign_btn'),
                            onTap: () {
                              notifier.assignDetectedChordToCompas(1);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Acorde ${chord.formattedSymbol(notation)} asignado al compás.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FaIcon(FontAwesomeIcons.squareCheck, size: 7.5, color: Colors.white),
                                    SizedBox(width: 2.5),
                                    Text(
                                      'Asignar',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Tooltip(
                            message: 'Transferir al constructor y fijar en diapasón',
                            child: InkWell(
                              key: const ValueKey('detector_show_diapason_btn'),
                              onTap: () {
                                notifier.showDetectedChordOnDiapason();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Acorde ${chord.formattedSymbol(notation)} transferido al constructor y diapasón.',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(FontAwesomeIcons.eye, size: 7.5, color: Colors.white),
                                      SizedBox(width: 2.5),
                                      Text(
                                        'Diapasón',
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (chord.alternatives.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Alt: ${chord.alternatives.join(", ")}',
                        style: const TextStyle(
                          fontSize: 7.2,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
