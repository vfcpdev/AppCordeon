# 🪗 Simulador de Acordeón Diatónico Híbrido Pro

Simulador interactivo de alto rendimiento de **Acordeón Diatónico Profesional (Sistema de 31 botones / 3 hileras - 5 Letras)**, diseñado con síntesis de audio Web Audio en tiempo real, cambio de afinaciones vallenatas y diatónicas, teoría musical interactiva (escalas, grados diatónicos y arpegios), detector armónico inteligente con análisis de inversión y bajo real, así como visor de posiciones de digitación según la dirección del fuelle.

---

## 🎯 Características Principales

1. **Diapasón Diatónico Real de 31 Botones (Sistema Panal / Honeycomb)**:
   - Disposición exacta 10-11-10 botones: Hilera Afuera (10 botones), Hilera Medio (11 botones), Hilera Adentro (10 botones).
   - Botones estilo nácar/perla con indicación visual diferenciada al cerrar fuelle (*Push* - Rojo) y al abrir (*Pull* - Azul).
   - Respuesta acústica interactiva con brillo neón (*glow*) al pulsar.

2. **Síntesis Web Audio en Tiempo Real**:
   - Timbre característico de lengüetas de acordeón con síntesis polifónica Tone.js (`PolySynth`), oscilador triangular y envolvente ADSR de respuesta rápida.
   - Modo de acorde sostenido (*Pin / Fijo*) y reproducción de secuencias y arpegios automáticos con control de tempo.

3. **Detector Inteligente de Acordes e Inversiones**:
   - Selección libre de botones en el diapasón para análisis armónico instantáneo.
   - **Detección de Bajo Real**: Identifica la nota más grave del acorde seleccionado para determinar inversiones exactas:
     - Estado Fundamental (Tónica en el bajo)
     - 1ra Inversión (3ra en el bajo)
     - 2da Inversión (5ta en el bajo)
     - 3ra Inversión (7ma en el bajo)
     - Cifrado Slash / Bajo alternativo
   - Reconocimiento de más de 25 plantillas de acordes (tríadas, cuatríadas, novenas, suspendidos y alternativas equivalentes).
   - Resumen de coherencia del fuelle (todos cerrando, todos abriendo o fuelle mixto).

4. **Teoría Musical Interactiva y Grados Diatónicos**:
   - Generador de escalas mayores y sus 8 grados diatónicos (I al VIII).
   - Resaltado de grados pilares (I, III, V, VIII) con calidades de acordes de cada grado.
   - Barra de transporte unificada con reproducción secuencial, bucle (*Loop*) con rango personalizable (*In/Fin*) y control de tempo en milisegundos.

5. **Factibilidad de Fuelle y Digitaciones**:
   - Verificación en tiempo real de si un acorde o arpegio se puede tocar completamente cerrando, abriendo o si requiere alternar fuelle (*Mixed*).
   - Selector de posiciones de digitación para encontrar todas las alternativas de una nota en las 3 hileras.

6. **Afinaciones Flexibles y Notación Dual**:
   - Soporte para **Cinco Letras** (B♭ - E♭ - A♭), **Rey Vallenato** (G - C - F), **Guacamayo** (A - D - G), **Simila** (B - E - A), **Cuatro Letras** (F - B♭ - E♭), **Sabanera** (C - F - B♭) y **Anisada** (E - A - D).
   - Conmutación instantánea entre Cifrado Latino (*Do, Re, Mi...*) y Cifrado Alemán / Anglosajón (*C, D, E...*).

7. **Analizador de Canciones (MP3 / Audio) y Sincronización en Vivo**:
   - Carga de archivos de audio (MP3, WAV, OGG) mediante selector o *Drag & Drop*.
   - **Extracción de Acordes Espectral**: Algoritmo de cromagrama (Harmonic Pitch Class Profile) y correlación de plantillas armónicas cuadro a cuadro.
   - **Detección de Tonalidad Principal**: Algoritmo Krumhansl-Schmuckler sobre la melodía completa, sugiriendo la afinación idónea del acordeón y la hilera tonal correspondiente con un botón de configuración automática.
   - **Sincronización en el Diapasón en Tiempo Real**: Conforme se reproduce la canción, los botones correspondientes a cada acorde detectado se iluminan dinámicamente en el acordeón en sus posiciones de cerrar (*Push*) o abrir (*Pull*).
   - Barra de tiempo (*Scrubbing*) interactiva y marcadores de acordes clickeables para saltar a cualquier punto de la pieza.

8. **Soporte PWA Híbrido**:
   - `manifest.json` y `sw.js` (Service Worker) para instalación como aplicación web de escritorio o móvil con funcionamiento offline.

---

## 🏛️ Arquitectura, Principios SOLID y Patrones de Diseño

El proyecto fue migrado desde un prototipo monolítico a una arquitectura modular pura en **JavaScript ESM (ES6)**:

### 1. Principios SOLID
- **Single Responsibility Principle (SRP)**:
  - `AudioEngine.js` / `WebAudioSynth.js`: Exclusivamente síntesis sonora.
  - `MusicTheory.js` / `Scales.js`: Cálculos teóricos puros (sin tocar el DOM).
  - `AccordionData.js`: Mapeos físicos de botones y transposición inmutable.
  - `DiapasonView.js`: Renderizado y manipulación del DOM del teclado.
- **Open/Closed Principle (OCP)**:
  - `Tunings.js` (`TuningRegistry`): Permite registrar nuevas afinaciones mediante configuración (`tuningRegistry.register(...)`) sin modificar el código interno del reproductor.
- **Liskov Substitution Principle (LSP)**:
  - `IAudioEngine.js`: Define el contrato para sintetizadores; `WebAudioSynth` o futuros sintetizadores de samples (`SampledSynth`) pueden intercambiarse sin romper el sistema.
- **Interface Segregation Principle (ISP)**:
  - Vistas y componentes del DOM reciben solo los datos y callbacks específicos que requieren.
- **Dependency Inversion Principle (DIP)**:
  - `AppController` coordina las vistas, estado y audio a través del bus de eventos central (`EventBus`) e interfaces abstractas.

### 2. Patrones de Diseño
- **Observer / Event Bus**: `EventBus.js` desacopla los eventos globales (`bellows:changed`, `audio:played`, etc.).
- **Singleton**: Garantiza una única instancia para `AudioEngine` y `EventBus`.
- **Strategy Pattern**:
  - `HarmonicAnalysisStrategy.js`: Algoritmo de detección, ponderación de coincidencias e inversiones.
  - `FeasibilityAnalysisStrategy.js`: Algoritmo de evaluación de factibilidad de fuelle.
- **Factory Pattern**:
  - `ButtonFactory.js`: Fábrica para construir botones de panal con atributos y eventos correspondientes.
- **State Pattern**:
  - `StateMachine.js` (`BellowsStateMachine`): Autómata de estados (`PUSH`, `PULL`, `BOTH`) que resuelve notas y validaciones sin anidar condicionales.

---

## 📂 Estructura del Proyecto

```
Acordeón/
├── index.html                   # Entry point de la aplicación web y PWA
├── manifest.json                # Web App Manifest
├── sw.js                        # Service Worker para ejecución offline
├── package.json                 # Configuración de paquete ESM y scripts
├── README.md                    # Documentación técnica completa
├── .gitignore
├── ArpegioV5.html               # Prototipo histórico preservado
├── css/
│   ├── variables.css            # Tokens de diseño y variables CSS
│   ├── reset.css                # Normalización y reset CSS
│   ├── layout.css               # Disposición general y cuadrícula responsive
│   ├── diapason.css             # Panal Honeycomb de 31 botones y efectos glow
│   ├── controls.css             # Paneles BEM, chips, badges y transporte
│   └── main.css                 # Agregador maestro de hojas de estilo
└── src/
    ├── app.js                   # Bootstrap de la aplicación
    ├── core/
    │   ├── Constants.js         # Constantes de notas, hileras y grados
    │   ├── EventBus.js          # Bus de eventos Observer Singleton
    │   └── StateMachine.js      # Autómata de estados de fuelle (State Pattern)
    ├── audio/
    │   ├── IAudioEngine.js      # Interfaz de síntesis (LSP)
    │   ├── WebAudioSynth.js     # Implementación con Tone.PolySynth
    │   └── AudioEngine.js       # Gestor Singleton de audio
    ├── models/
    │   ├── AccordionData.js     # Mapeo físico 10-11-10 y transposición
    │   └── Tunings.js           # Registro extensible de afinaciones (OCP)
    ├── theory/
    │   ├── MusicTheory.js       # Funciones puras de intervalos y pitch classes
    │   ├── Scales.js            # Escala mayor y acordes de grados
    │   └── ChordTemplates.js    # Catálogo de plantillas de acordes
    ├── strategies/
    │   ├── HarmonicAnalysisStrategy.js   # Detector armónico y bajo real
    │   └── FeasibilityAnalysisStrategy.js # Análisis de factibilidad de fuelle
    ├── ui/
    │   ├── ButtonFactory.js     # Factory Pattern para botones Honeycomb
    │   ├── DiapasonView.js      # Vista del diapasón
    │   ├── ScaleBarView.js      # Vista de escalas y transporte
    │   ├── ChordView.js         # Vista de acordes libres y arpegios
    │   ├── DetectorView.js      # Vista del detector de acordes
    │   └── ExecutionView.js     # Vista de formas de digitación
    └── controllers/
        └── AppController.js     # Orquestador principal (DIP)
```

---

## 🚀 Cómo Ejecutar Localmente

Como el proyecto utiliza módulos nativos de JavaScript (**ESM**), debe servirse a través de un servidor HTTP local:

### Opción 1: Con npm (Node.js)
```bash
# Iniciar servidor local en el puerto 3000
npm run dev
```

### Opción 2: Con npx serve
```bash
npx serve .
```

### Opción 3: Con Python 3
```bash
python -m http.server 3000
```

Abre en tu navegador favorito: `http://localhost:3000`

---

## 📜 Licencia
Distribuido bajo la Licencia MIT.
