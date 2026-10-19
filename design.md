# Diseño y Arquitectura de Interfaz - Acordeón Diatónico Pro

Este documento especifica las reglas de estructura visual y componentes para asegurar que los diapasones permanezcan completos y que la cuadrícula y barras laterales se mantengan sincronizadas y apiladas sin desajustes.

---

## 1. Regla Crítica: Preservación Absoluta de los Diapasones
1. **Integridad de los 31 Botones**:
   - Cada diapasón (Acordeón 1 y Acordeón 2) contiene 31 botones organizados en 3 hileras (10, 11, 10).
   - Ninguna regla CSS de ancho, margen, padding o flexbox debe comprimir, desbordar o truncar los diapasones ni sus botones.
   - El contenedor `.diapason-wrapper` mantiene `width: fit-content;` y fluye naturalmente.

---

## 2. Disposición de las Columnas y Apilamiento de Cuadrículas

### Columna 1: `.app-layout__col--stage`
Contiene la barra superior (`.diapason-top-bar`), los diapasones (`.diapasons-stage-container`) y las posiciones de ejecución.

- **Estructura por Diapasón (`#primaryDiapasonCol` y `#secondaryDiapasonCol`)**:
  - Cada diapasón se compone de `.diapason-content-row`, que contiene:
    1. **Izquierda**: `.diapason-wrapper` (Diapasón con sus 31 botones, header de afinación/fuelle, e insignia del acorde activo acompañada a su derecha por la barra de volumen con slider y botón de mute que controla ambos diapasones).
    2. **Derecha**: `.diapason-side-stack` (`width: 370px; min-width: 350px; display: flex; flex-direction: column; gap: 8px;`).

- **Estructura Interna del Stack Apilado (`#primaryDiapasonSideStack`)**:
  - **Superior**: `.diapason-audio-chords-sidebar` ("Acordes Canción").
    - Controles de voicing (2, 3, 4, 5, Todas) y selector de octava organizados en una sola fila compacta (sin la palabra "Botones"). Lista de botones activos de Abre/Cierra.
  - **Medio**: `.diapason-chord-grid-panel` ("Cuadrícula de Acordes (4/4)").
    - Encabezado: Los botones de acción se ubican en el encabezado de forma limpia sin título redundante.
    - Mini-popover (`#gridChordMiniPopover`): Se expande exactamente al mismo ancho (100%) que la sección de la cuadrícula.
  - **Inferior**: `#audioAnalysisSection` ("Controles del Reproductor & Analizador").
    - Situado directamente debajo de la cuadrícula de acordes de forma limpia (sin contenedor exterior, sin borde grueso, sin marco ni título redundante).
    - Contiene la barra de tiempo y scrubbing (`#playerScrubberRow`), controles de transporte (Play/Pausa, Detener, Atrás/Adelante), metrónomo sincronizado, BPM, velocidad, volumen y sincronización de diapasón.

### Sincronización con el Segundo Acordeón
- El segundo acordeón (`#secondaryDiapasonCol`) replica este diseño apilado en su propio stack:
  - Arriba: `#secondaryDiapasonChordSidebar` ("2do Acordeón (Equiv.)").
  - Abajo: `#secondaryChordGridPanel` con su contenedor `#secondaryAudioMeasureGridContainer`.
- Ambas cuadrículas se renderizan y sincronizan en tiempo real:
  - Pulso activo (`.active-beat`) y compás activo (`.active-measure`) se iluminan simultáneamente al reproducir audio desde el analizador/reproductor.
  - Al hacer clic en un compás/pulso de cualquiera de las dos cuadrículas, el audio salta a ese instante y ambos diapasones muestran sus digitaciones correspondientes.

---

## 3. Columna 2: `.app-layout__col--chords`
- **Acorde Libre (`#freeChordSection`)**:
  - Selector de tónica, tipo de acorde, 4ta nota y octava.
  - Dirección de fuelle y tira de notas de arpegio.
  - Escala generada del acorde con botón "Cargar en Escalas".
- **Escala Diatónica (`#scaleSection`)**:
  - Situada directamente debajo de Acorde Libre.
  - Modos Melódico y Armónico, selectores de escala, tira interactiva de grados I a VIII.
  - Barra de transporte de escala, loop y velocidad.

---

## 4. Columna 3: `.app-layout__col--theory`
- **Detector de Acordes (`#detectorSection`)**:
  - Modo selección manual de botones, reproducción de acorde y arpegio detectado.

