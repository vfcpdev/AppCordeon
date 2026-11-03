# SPEC-002: Asignación Individual y en Cascada de Fuelle por Acorde en Compás

- **Estado:** Completado y Verificado (303/303 Tests OK, 0 issues Linter)
- **Nivel SDD:** Nivel 2 (*Spec-Anchored*)
- **Módulos afectados:** `acordeon_flutter/lib/domain/commands/`, `lib/presentation/controllers/`, `lib/presentation/widgets/measure_grid_widget.dart`
- **Fecha:** 2026-11-03

---

## 1. Objetivo
Permitir a los músicos y analistas asignar la dirección del fuelle (`Abre` / `Cierra` / `Ambos`) a una celda de compás de dos formas:
1. **Asignación Individual:** Afecta únicamente al pulso/celda seleccionado en el compás.
2. **Asignación en Cascada (Global por Acorde):** Aplica el mismo estado de fuelle a todas las apariciones de ese mismo acorde a lo largo de toda la cuadrícula de compases.

---

## 2. Requisitos y Reglas

### Requisitos Funcionales:
* **RF-01 (Modo Individual):** Un clic normal sobre el botón de fuelle (`Abre` / `Cierra`) asigna la dirección exclusivamente al compás/pulso activo.
* **RF-02 (Modo Cascada / Aplicar a Todos):** 
  - Debe proveerse una acción explícita e intuitiva en la UI (por ejemplo: un control o modificador "Aplicar a todos los [NombreAcorde]" o botón dedicado de cascada / pulsación larga / interruptor de ámbito).
  - Al ejecutarse, busca todas las celdas de la cuadrícula que compartan el mismo símbolo o tónica/cualidad del acorde seleccionado y actualiza su fuelle a la dirección elegida.
* **RF-03 (Deshacer/Rehacer Atómico):** Tanto la asignación individual como la asignación en cascada deben registrarse como un único paso atómico en el historial Memento (`_gridHistory`), de modo que un solo "Deshacer" revierta todas las celdas afectadas por la cascada.

### Reglas y Restricciones:
* **Regla 1:** Si la celda seleccionada no tiene un acorde definido (`chord.isEmpty`), la asignación en cascada debe degradarse de forma segura a asignación individual sin fallar ni alterar compases vacíos.
* **Regla 2 (Preservación de Invariantes):** Las notas, textos y duraciones de los compases deben permanecer invariantes; únicamente muta el campo `bellows` (`BellowsMode.push`, `BellowsMode.pull`, `BellowsMode.both`).

---

## 3. Contratos Formales: Triplas de Hoare

### Tripla Hoare 01: Asignación Individual
$$\{ \text{targetCell} = \text{grid.cell}(b, t) \land B \in \{\text{push}, \text{pull}, \text{both}\} \}$$
$$\Downarrow \quad \text{SetCellBellows}(b, t, B)$$
$$\{ \text{grid.cell}(b, t).\text{bellows} = B \land \forall (i, j) \neq (b, t), \, \text{grid.cell}(i, j) = \text{old}(\text{grid.cell}(i, j)) \}$$

### Tripla Hoare 02: Asignación en Cascada por Acorde
Sea $C = \text{targetChordName}(\text{selectedCell})$:
$$\{ C \neq \emptyset \land B \in \{\text{push}, \text{pull}, \text{both}\} \}$$
$$\Downarrow \quad \text{CascadeChordBellows}(C, B)$$
$$\{ \forall \text{cell} \in \text{grid}, \, (\text{cell}.\text{chord} = C \implies \text{cell}.\text{bellows} = B) \land (\text{cell}.\text{chord} \neq C \implies \text{cell}.\text{bellows} = \text{old}(\text{cell}.\text{bellows})) \}$$

---

## 4. Diseño OOP & Patrones
* **Command Pattern (`CascadeChordBellowsCommand`):** Encapsula la mutación de estado en lote y calcula la lista de celdas modificadas para auditoría y atomicidad en `GridHistoryMemento`.
* **Strategy / Predicate Filter:** Coincidencia exacta de acordes mediante función normalizadora para garantizar que variaciones menores de espacios o notación no dejen celdas sin actualizar.

