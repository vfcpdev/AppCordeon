# SPEC-001: Desacoplamiento Modular del Controlador de Acordeón (Facade + Sub-Controllers)

- **Estado:** Aprobado / En Planificación
- **Nivel SDD:** Nivel 2 (*Spec-Anchored*)
- **Módulos afectados:** `acordeon_flutter/lib/presentation/controllers/`
- **Fecha:** 2026-11-03

---

## 1. Objetivo
Descomponer el megacontrolador monolítico `AccordionSimulatorNotifier` (~4,800 líneas) en sub-controladores de dominio altamente cohesivos y con bajo acoplamiento, exponiendo una **Fachada Unificada (Facade Pattern)** para preservar intacta la interfaz pública que consumen los widgets y los 286 tests unitarios existentes.

---

## 2. Requisitos Funcionales y No Funcionales

### Requisitos Funcionales (RF):
1. **RF-01 (Transporte):** Aislar la máquina de estados de reproducción (Play/Pause, BPM, cursor de tiempo, metrónomo) en `AccordionTransportController`.
2. **RF-02 (Armonía y Afinación):** Aislar la lógica de afinaciones, cálculo de notas por botón, tonalidad y detección de acordes en `AccordionHarmonicController`.
3. **RF-03 (Bajos y Ritmo):** Aislar la captura, edición, cuantización y reproducción de patrones rítmicos de bajos en `AccordionBassRhythmController`.
4. **RF-04 (Análisis de Audio):** Aislar la decodificación PCM, detección de transientes y estimación de tempo en `AccordionAudioAnalysisController`.
5. **RF-05 (Fachada Compatible):** `AccordionSimulatorNotifier` debe actuar como orquestador / Facade, delegando en los sub-controladores y sincronizando el estado unificado `AccordionSimulatorState`.

### Requisitos No Funcionales (RNF):
1. **RNF-01 (Compatibilidad Regresiva):** 100% de los tests unitarios (`flutter test`) deben ejecutarse y pasar con 0 fallos sin requerir modificar los tests existentes.
2. **RNF-02 (Rendimiento / Latencia Cero):** La delegación entre la fachada y los sub-controladores debe ser directa en memoria (O(1)), sin overhead de serialización o asincronía espuria.
3. **RNF-03 (Linter):** 0 advertencias o errores en `flutter analyze lib`.

---

## 3. Reglas y Restricciones
* **Restricción 1:** No mutar `AccordionSimulatorState` directamente; preservar la inmutabilidad funcional mediante `state = state.copyWith(...)`.
* **Restricción 2:** Las dependencias externas (relojes, sintetizadores, decodificadores) se inyectan a través de los providers de Riverpod definidos en `lib/core/di/providers.dart`.
* **Restricción 3:** Los widgets no deben instanciar sub-controladores directamente salvo que sea para aislar repintados específicos; la fachada `accordionSimulatorProvider` se mantiene como punto de entrada público.

---

## 4. Contratos Formales: Triplas de Hoare

### Tripla Hoare 01: Modificación de Fuelle en Compás (Transporte / Compás)
$$\{ \text{state.grid.cells}[i].\text{bellows} = B_0 \land B \in \{\text{push}, \text{pull}, \text{both}\} \}$$
$$\Downarrow \quad \text{SetCellBellows}(i, B)$$
$$\{ \text{state.grid.cells}[i].\text{bellows} = B \land \text{state.history.canUndo} = \text{true} \}$$

### Tripla Hoare 02: Desplazamiento Fino de Golpe en Patrón de Bajos (Bass Rhythm)
$$\{ \text{beat.onset} = t_0 \land \Delta \in \mathbb{R} \land 0.0 \le t_0 \le 4.0 \}$$
$$\Downarrow \quad \text{NudgeBeatOnset}(\text{beatIndex}, \Delta)$$
$$\{ \text{beat.onset} = \max(0.0, \min(4.0, t_0 + \Delta)) \land \text{state.isDirty} = \text{true} \}$$

### Tripla Hoare 03: Detección y Asignación de Acorde (Armonía)
$$\{ \text{notes} \neq \emptyset \land \text{tuning} \in \text{Tunings} \}$$
$$\Downarrow \quad \text{AssignDetectedChord}(\text{notes})$$
$$\{ \text{state.activeChord} = \text{DetectChord}(\text{notes}) \land \forall n \in \text{notes}, n \in \text{state.activeChord.pitchClasses} \}$$

---

## 5. Plan de Ejecución Seguro (Por Fases)
1. **Fase 1:** Extraer `AccordionTransportController` (transporte, compás y reloj) y conectar con Facade.
2. **Fase 2:** Extraer `AccordionBassRhythmController` (patrones rítmicos, edición y estado de bajos).
3. **Fase 3:** Extraer `AccordionHarmonicController` (teoría musical, afinaciones, botones 3D).
4. **Fase 4:** Extraer `AccordionAudioAnalysisController` (decodificación y FFT).
5. **Fase 5:** Verificación rigurosa con `flutter test` y `flutter analyze lib`.

