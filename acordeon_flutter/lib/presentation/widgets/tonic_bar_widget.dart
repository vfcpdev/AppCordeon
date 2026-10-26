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

    return TextSpan(
      children: [
        TextSpan(text: rootName, style: rootStyle),
        const TextSpan(text: '   '), // Espacio entre tónica y cualidad
        TextSpan(text: qualityStr, style: qualityStyle),
        if (extStr.isNotEmpty) ...[
          const TextSpan(text: '   '), // Espacio entre cualidad y extensión
          TextSpan(text: extStr, style: extensionStyle),
        ],
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

    final rootName = state.freeChordRoot >= 0 && state.freeChordRoot < TonicBarWidget.roots.length
        ? TonicBarWidget.roots[state.freeChordRoot]
        : '—';
    final currentChordDisplay = state.freeChordRoot >= 0
        ? '$rootName${_typeSymbol(state.freeChordType)}${_extensionSymbol(state.freeChordFourth, state.freeChordType)}'
        : '—';

    final barIndex = state.selectedBarIndex;
    final beatIndex = state.selectedBeatIndex;
    final hasSelectedCell = barIndex != null &&
        beatIndex != null &&
        barIndex >= 0 &&
        barIndex < state.measures.length &&
        beatIndex >= 0 &&
        beatIndex < state.measures[barIndex].beats.length;
    final markedCount = state.markedBeats.length;
    final targetLabel = markedCount > 0
        ? '$markedCount tiempo${markedCount == 1 ? '' : 's'} marcado${markedCount == 1 ? '' : 's'}'
        : (hasSelectedCell
            ? 'Compás ${barIndex + 1} · Tiempo ${beatIndex + 1}'
            : 'sin celda seleccionada');
    final insertSymbol = ChordCatalog.symbolFor(
      root: state.freeChordRoot,
      type: state.freeChordType,
      extension: state.freeChordFourth,
      latin: state.notation != NotationMode.alemana,
    );
    final canInsert =
        insertSymbol.isNotEmpty && (markedCount > 0 || hasSelectedCell);

    // Botones ordenados en 2 columnas verticales:
    // Columna 1 (6 notas naturales): Do, Re, Mi, Fa, Sol, La
    // Columna 2 (alteraciones y Si): Do#, Mi♭, Fa#, Sol#, Si♭, Si
    const col1 = [0, 2, 4, 5, 7, 9];      // Do, Re, Mi, Fa, Sol, La
    const col2 = [1, 3, 6, 8, 10, 11];   // Do#, Mi♭, Fa#, Sol#, Si♭, Si

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

                // Etiqueta del Acorde (sigla) y Botón de Compás (+) a su derecha
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF22C55E)),
                          ),
                          child: Text(
                            currentChordDisplay,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF065F46),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: canInsert
                            ? 'Agregar $insertSymbol a $targetLabel'
                            : 'Selecciona una tónica y marca tiempos o una celda del Compás',
                        child: InkWell(
                          key: const ValueKey('insert_chord_to_compas_btn'),
                          onTap: canInsert
                              ? () {
                                  final symbol =
                                      notifier.insertFreeChordIntoSelectedBeat();
                                  if (symbol == null) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text('$symbol → $targetLabel'),
                                        duration: const Duration(milliseconds: 1400),
                                      ),
                                    );
                                }
                              : null,
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: canInsert
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.plus,
                              size: 13,
                              color: canInsert
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Botones distribuidos en columnas
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna 1
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: col1.map((idx) {
                          final isSelected = state.freeChordRoot == idx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildTonicButton(
                              rootName: TonicBarWidget.roots[idx],
                              isActive: isSelected,
                              onTap: () => notifier.setFreeChordRoot(idx),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Columna 2
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: col2.map((idx) {
                          final isSelected = state.freeChordRoot == idx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildTonicButton(
                              rootName: TonicBarWidget.roots[idx],
                              isActive: isSelected,
                              onTap: () => notifier.setFreeChordRoot(idx),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTonicButton({
    required String rootName,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Tónica $rootName',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF059669) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isActive ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
              width: isActive ? 1.2 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rootName,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: isActive ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sigla de la cualidad (M, m, °, +, sus4).
  static String _typeSymbol(String type) {
    switch (type) {
      case 'maj':
        return '';
      case 'min':
        return 'm';
      case 'dim':
        return '°';
      case 'aug':
        return '+';
      case 'sus4':
        return 'sus4';
      default:
        return '';
    }
  }

  /// Sigla de la extensión (—, 8, 6, add9, 7, maj7, m7, °7).
  static String _extensionSymbol(String ext, [String type = '']) {
    switch (ext) {
      case 'octave':
        return '8';
      case 'dom7':
        return '7';
      case 'maj7':
        return 'maj7';
      case 'maj6':
        return '6';
      case 'add9':
        return 'add9';
      case 'min7':
        return type == 'min' ? '7' : 'm7';
      case 'dim7':
        return type == 'dim' ? '7' : '°7';
      default:
        return '';
    }
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
