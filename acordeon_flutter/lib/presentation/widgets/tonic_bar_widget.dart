import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';

/// Barra vertical desacoplable de botones para la selección de Tónica del Constructor de Acordes.
/// Permite acoplarse al lado del Constructor de Acordes o flotar libremente por la pantalla.
class TonicBarWidget extends ConsumerStatefulWidget {
  final VoidCallback? onDock;
  final VoidCallback? onUndock;
  final bool isFloating;

  static const List<String> roots = [
    'Do', 'Do#', 'Re', 'Mi♭', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'Si♭', 'Si'
  ];

  const TonicBarWidget({
    super.key,
    this.onDock,
    this.onUndock,
    this.isFloating = false,
  });

  /// Genera TextSpans para el nombre del acorde con:
  /// - Tónica: Negro
  /// - Cualidad: Morado (#7C3AED)
  /// - Extensión: Rojo (#DC2626)
  /// Con espacio de separación entre cada texto.
  static TextSpan buildChordNameSpans({
    required int root,
    required String type,
    required String extension,
    bool latin = true,
    double fontSize = 9.0,
  }) {
    if (root < 0 || root >= TonicBarWidget.roots.length) {
      return TextSpan(
        text: '—',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      );
    }

    final rootName = (latin ? ChordCatalog.latinRootNames : ChordCatalog.germanRootNames)[root];

    final qualityStr = switch (type) {
      'maj' => 'Mayor',
      'min' => 'menor',
      'dim' => 'Disminuido',
      'aug' => 'Aumentado',
      'sus2' => 'Suspendido 2',
      'sus4' => 'Suspendido 4',
      _ => 'Mayor',
    };

    final extStr = switch (extension) {
      'octave' => 'Octava',
      'dom7' => 'Séptima',
      'maj7' => 'Séptima Mayor',
      'maj6' => 'Sexta',
      'add9' => 'Novena',
      'min7' => 'Séptima',
      'dim7' => 'Séptima',
      _ => '',
    };

    final rootStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Colors.black,
      letterSpacing: 0.3,
    );
    final qualityStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF7C3AED), // Morado
      letterSpacing: 0.3,
    );
    final extensionStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: const Color(0xFFDC2626), // Rojo
      letterSpacing: 0.3,
    );
    final notesStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF047857), // Verde esmeralda para las notas
      letterSpacing: 0.2,
    );

    final notes = ChordCatalog.noteNamesFor(
      root: root,
      type: type,
      extension: extension,
      latin: latin,
    );
    final notesStr = notes.isNotEmpty ? '   (${notes.join(' - ')})' : '';

    return TextSpan(
      children: [
        TextSpan(text: rootName, style: rootStyle),
        const TextSpan(text: '   '), // Espacio entre tónica y cualidad
        TextSpan(text: qualityStr, style: qualityStyle),
        if (extStr.isNotEmpty) ...[
          const TextSpan(text: '   '), // Espacio entre cualidad y extensión
          TextSpan(text: extStr, style: extensionStyle),
        ],
        if (notesStr.isNotEmpty)
          TextSpan(text: notesStr, style: notesStyle),
      ],
    );
  }

  @override
  ConsumerState<TonicBarWidget> createState() => _TonicBarWidgetState();
}

class _TonicBarWidgetState extends ConsumerState<TonicBarWidget> {
  OverlayEntry? _overlayEntry;
  Offset? _floatingPosition;
  static const double _floatingWidth = 118.0;

  bool get _isFloating => _floatingPosition != null;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _detach(Offset globalTopLeft) {
    final screen = MediaQuery.sizeOf(context);
    final maxX = (screen.width - _floatingWidth).clamp(0.0, double.infinity);
    final maxY = (screen.height - 200).clamp(0.0, double.infinity);

    _floatingPosition = Offset(
      globalTopLeft.dx.clamp(0.0, maxX),
      globalTopLeft.dy.clamp(0.0, maxY),
    );
    _insertOverlay();
    setState(() {});
  }

  void _insertOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final position = _floatingPosition;
          if (position == null) return const SizedBox.shrink();

          return Positioned(
            left: position.dx,
            top: position.dy,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: _floatingWidth,
                child: _buildBar(
                  context,
                  ref,
                  floating: true,
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _moveFloating(Offset delta) {
    final position = _floatingPosition;
    if (position == null) return;

    final screen = MediaQuery.sizeOf(context);
    final maxX = (screen.width - _floatingWidth).clamp(0.0, double.infinity);
    final maxY = (screen.height - 100).clamp(0.0, double.infinity);

    _floatingPosition = Offset(
      (position.dx + delta.dx).clamp(0.0, maxX),
      (position.dy + delta.dy).clamp(0.0, maxY),
    );
    _overlayEntry?.markNeedsBuild();
  }

  void _dock() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!mounted) return;
    setState(() => _floatingPosition = null);
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el estado para que la vista anclada y sus notificaciones se mantengan sincronizadas
    ref.watch(accordionSimulatorProvider);

    if (_isFloating) {
      // Espacio horizontal tipo chip, sin color, únicamente con el icono para acoplar tónica
      return Tooltip(
        message: 'Acoplar Tónica',
        child: InkWell(
          key: const ValueKey('dock_tonic_chip'),
          onTap: _dock,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.0,
              ),
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.thumbtack,
                size: 11,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ),
      );
    }

    return _buildBar(context, ref, floating: false);
  }

  Widget _buildBar(BuildContext context, WidgetRef ref, {required bool floating}) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: floating ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
          width: floating ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: floating ? 0.20 : 0.05),
            blurRadius: floating ? 14 : 8,
            offset: Offset(0, floating ? 6 : 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Etiqueta vertical del nombre del acorde (Fondo Blanco y letras negras, 90°)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: Semantics(
                label: fullChordName(
                  root: state.freeChordRoot,
                  type: state.freeChordType,
                  extension: state.freeChordFourth,
                  latin: state.notation != NotationMode.alemana,
                ),
                child: Text.rich(
                  TonicBarWidget.buildChordNameSpans(
                    root: state.freeChordRoot,
                    type: state.freeChordType,
                    extension: state.freeChordFourth,
                    latin: state.notation != NotationMode.alemana,
                  ),
                  key: const ValueKey('tonic_bar_full_chord_name'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),

          // Contenido principal de la barra de tónica
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera de la barra vertical con botón desacoplar/acoplar y drag handle
                GestureDetector(
                  onPanUpdate: floating ? (details) => _moveFloating(details.delta) : null,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 5),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 2.5,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Tónica',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        // Botón desacoplar / acoplar
                        Builder(
                          builder: (btnContext) {
                            return Tooltip(
                              message: floating ? 'Acoplar al constructor' : 'Desacoplar barra vertical',
                              child: InkWell(
                                onTap: () {
                                  if (floating) {
                                    _dock();
                                  } else {
                                    final renderBox = btnContext.findRenderObject() as RenderBox?;
                                    final offset = renderBox?.localToGlobal(Offset.zero) ?? const Offset(100, 100);
                                    _detach(offset + const Offset(-20, -10));
                                  }
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: floating ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FaIcon(
                                    floating ? FontAwesomeIcons.thumbtack : FontAwesomeIcons.upRightFromSquare,
                                    size: 8.5,
                                    color: floating ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Checkbox para abrir el modal de asignación múltiple
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: state.showMultiBeatModal
                              ? 'Cerrar ventana de asignación múltiple'
                              : 'Asignar acorde a varios compases (Compás.Cuadro)',
                          child: InkWell(
                            key: const ValueKey('multi_beat_modal_checkbox'),
                            onTap: () {
                              notifier.toggleMultiBeatModal();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: state.showMultiBeatModal
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: state.showMultiBeatModal
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF94A3B8),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: state.showMultiBeatModal
                                    ? const FaIcon(
                                        FontAwesomeIcons.check,
                                        size: 9.5,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nombre completo del acorde en lenguaje natural (ej. Do Mayor Séptima).
  static String fullChordName({
    required int root,
    required String type,
    required String extension,
    bool latin = true,
  }) {
    if (root < 0 || root >= TonicBarWidget.roots.length) return '—';
    final rootName = (latin ? ChordCatalog.latinRootNames : ChordCatalog.germanRootNames)[root];

    final qualityStr = switch (type) {
      'maj' => 'Mayor',
      'min' => 'menor',
      'dim' => 'Disminuido',
      'aug' => 'Aumentado',
      'sus2' => 'Suspendido 2',
      'sus4' => 'Suspendido 4',
      _ => 'Mayor',
    };

    final extStr = switch (extension) {
      'octave' => 'Octava',
      'dom7' => 'Séptima',
      'maj7' => 'Séptima Mayor',
      'maj6' => 'Sexta',
      'add9' => 'Novena',
      'min7' => 'Séptima',
      'dim7' => 'Séptima',
      _ => '',
    };

    if (extStr.isEmpty) {
      return '$rootName $qualityStr';
    }
    return '$rootName $qualityStr $extStr';
  }


}
