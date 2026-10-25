import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  @override
  ConsumerState<TonicBarWidget> createState() => _TonicBarWidgetState();
}

class _TonicBarWidgetState extends ConsumerState<TonicBarWidget> {
  OverlayEntry? _overlayEntry;
  Offset? _floatingPosition;
  static const double _floatingWidth = 92.0;

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
    if (_isFloating) {
      // Mientras flota, en la posición original se muestra un botón para re-acoplar o abrir
      return Container(
        width: 32,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Reanclar barra de Tónicas',
              child: InkWell(
                onTap: _dock,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const FaIcon(FontAwesomeIcons.thumbtack, size: 12, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 3,
              child: const Text(
                'TÓNICA FLOTANTE',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0284C7),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildBar(context, floating: false);
  }

  Widget _buildBar(BuildContext context, {required bool floating}) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);

    // Botones ordenados en 2 columnas verticales:
    // Columna 1 (6 notas naturales): Do, Re, Mi, Fa, Sol, La
    // Columna 2 (alteraciones y Si): Do#, Mi♭, Fa#, Sol#, Si♭, Si
    const col1 = [0, 2, 4, 5, 7, 9];      // Do, Re, Mi, Fa, Sol, La
    const col2 = [1, 3, 6, 8, 10, 11];   // Do#, Mi♭, Fa#, Sol#, Si♭, Si

    return Container(
      padding: const EdgeInsets.all(6),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera de la barra vertical con botón desacoplar/acoplar y drag handle
          GestureDetector(
            onPanUpdate: floating ? (details) => _moveFloating(details.delta) : null,
            child: Container(
              padding: const EdgeInsets.only(bottom: 6),
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
                        width: 3,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Tónica',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0284C7),
                          letterSpacing: 0.3,
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
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: floating ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FaIcon(
                              floating ? FontAwesomeIcons.thumbtack : FontAwesomeIcons.upRightFromSquare,
                              size: 9,
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
          const SizedBox(height: 6),

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
}
