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
    1. **Izquierda**: `.diapason-wrapper` (Diapasón con sus 31 botones y header de afinación/fuelle).
    2. **Derecha**: `.diapason-side-stack` (`width: 370px; min-width: 350px; display: flex; flex-direction: column; gap: 8px;`).

- **Estructura Interna del Stack Apilado (`.diapason-side-stack`)**:
  - **Arriba**: `.diapason-audio-chords-sidebar` ("Acordes Canción" o "2do Acordeón (Equiv.)").
    - Altura aproximada: ~320px.
    - Contiene los botones de voicing (2, 3, 4, 5, Todas), selector de octava y lista de botones activos de Abre/Cierra.
  - **Abajo**: `.diapason-chord-grid-panel` ("Cuadrícula de Acordes (4/4)").
    - Altura aproximada: ~240-280px con scroll vertical interno suave.
    - Contiene la barra de herramientas (selección, exportar/importar CSV, progresión manual, agregar compás, borrar, config filas, desacoplar) y la cuadrícula interactiva de 4 pulsos por compás.

### Sincronización con el Segundo Acordeón
- El segundo acordeón (`#secondaryDiapasonCol`) replica idénticamente este diseño apilado:
  - Arriba: `#secondaryDiapasonChordSidebar` ("2do Acordeón (Equiv.)").
  - Abajo: `#secondaryChordGridPanel` con su contenedor `#secondaryAudioMeasureGridContainer`.
- Ambas cuadrículas se renderizan y sincronizan en tiempo real:
  - Pulso activo (`.active-beat`) y compás activo (`.active-measure`) se iluminan simultáneamente al reproducir audio.
  - Al hacer clic en un compás/pulso de cualquiera de las dos cuadrículas, el audio salta a ese instante y ambos diapasones muestran sus digitaciones correspondientes.

---

## 3. Columna 2: `.app-layout__col--chords`
Al mover las cuadrículas debajo de las secciones de acordes de canción, la Columna 2 queda optimizada y limpia:
- Encabezado: "Analizador & Reproductor MP3".
- Insignia de acorde y compás activo (`#audioActiveChordBadge`).
- Barra de scrubber y tiempo (`#playerScrubberRow`).
- Barra de transporte y reproducción (Atrás, Play/Pausa, Adelante, Stop, Metrónomo, Volúmenes, BPM, Pitch Shift, Selector de Acordeón).
