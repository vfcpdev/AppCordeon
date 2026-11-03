import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../domain/theory/chord_catalog.dart';
import '../controllers/accordion_controller.dart';
import 'chord_quality_selector_widget.dart';

/// Matriz de notas tónicas organizada en 2 filas por 6 columnas con selector
/// de cualidades directamente debajo (1 fila de 6 cualidades con el mismo ancho y alineadas).
///
/// Principios aplicados:
/// - Single Responsibility Principle (SRP): Encapsula la representación
///   matricial 2x6 de tónicas y la integración de cualidades y botón de inserción.
/// - Tripla de Hoare:
///   - Precondición {P}: `rootIndex >= 0 && rootIndex < 12`.
///   - Ejecución {C}: `notifier.setFreeChordRoot(rootIndex)`.
///   - Poscondición {Q}: `state.freeChordRoot == rootIndex`.
class TonicNotesMatrixWidget extends ConsumerWidget {
  final Widget? trailing;

  const TonicNotesMatrixWidget({super.key, this.trailing});

  /// Distribución 2 filas x 6 columnas:
  /// Fila 1: Do, Do#, Re, Mi♭, Mi, Fa (índices 0 a 5)
  /// Fila 2: Fa#, Sol, Sol#, La, Si♭, Si (índices 6 a 11)
  static const List<List<int>> matrixRows = [
    [0, 1, 2, 3, 4, 5],
    [6, 7, 8, 9, 10, 11],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accordionSimulatorProvider);
    final notifier = ref.read(accordionSimulatorProvider.notifier);
    final isLatin = state.notation != NotationMode.alemana;
    final rootNames = isLatin ? ChordCatalog.latinRootNames : ChordCatalog.germanRootNames;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...matrixRows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      children: row.map((rootIndex) {
                        final isSelected = state.freeChordRoot == rootIndex;
                        final rootName = rootNames[rootIndex];

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Tooltip(
                              message: 'Tónica $rootName',
                              child: InkWell(
                                key: ValueKey('tonic_matrix_btn_$rootIndex'),
                                onTap: () => notifier.setFreeChordRoot(rootIndex),
                                borderRadius: BorderRadius.circular(4),
                                child: AspectRatio(
                                  aspectRatio: 2.0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 90),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF059669) : Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                        width: isSelected ? 1.2 : 0.8,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF059669).withValues(alpha: 0.3),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 0.5),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          rootName,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
                // Selector de cualidades encapsulado en un contenedor con color sutil gris claro para diferenciarlo de las tónicas
                Padding(
                  padding: const EdgeInsets.only(top: 2.5, bottom: 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    child: const ChordQualitySelectorWidget(),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}
