import { 
    COMO_ZAQUEO_SCORE_INFO, 
    COMO_ZAQUEO_BARS, 
    generateComoZaqueoMusicXml, 
    parseMusicXml, 
    buildComoZaqueoTimelineChords 
} from '../models/SheetMusicData.js';
import { wasmMelodyBridge } from '../audio/WasmMelodyBridge.js';

/**
 * Controlador de la Ventana Modal de Partituras basada en OpenSheetMusicDisplay (OSMD)
 * Renderiza partituras interactivas en formato MusicXML / MXL directamente en el navegador,
 * con pentagramas, notas, clave, acordes, letra, zoom, navegación por compás y cursor de seguimiento.
 * Incorpora extracción melódica ultrarrápida con Rust (WASM) y replicación interactiva en el acordeón seleccionado.
 */
export class SheetMusicModalView {
    constructor(options = {}) {
        this._modal = document.getElementById('floatingSheetModal');
        this._dockPill = document.getElementById('sheetMinimizedDockPill');
        this._scoreContainer = document.getElementById('osmdScoreContainer');
        this._loadingOverlay = document.getElementById('sheetLoadingOverlay');
        this._header = document.getElementById('sheetModalHeader');
        this._chordsStrip = document.getElementById('sheetChordsScrollStrip');
        this._viewport = document.getElementById('sheetModalViewport');

        // Controles de ventana
        this._btnClose = document.getElementById('btnSheetClose');
        this._btnMinimize = document.getElementById('btnSheetMinimize');
        this._btnMaximize = document.getElementById('btnSheetMaximize');

        // Controles de navegación de compás
        this._btnFirstMeasure = document.getElementById('btnSheetFirstMeasure');
        this._btnPrevMeasure = document.getElementById('btnSheetPrevMeasure');
        this._btnNextMeasure = document.getElementById('btnSheetNextMeasure');
        this._measureInput = document.getElementById('sheetMeasureInput');
        this._measureTotalLabel = document.getElementById('sheetMeasureTotal');
        this._btnToggleCursor = document.getElementById('btnSheetToggleCursor');

        // Controles de zoom
        this._btnZoomIn = document.getElementById('btnSheetZoomIn');
        this._btnZoomOut = document.getElementById('btnSheetZoomOut');
        this._btnZoomFit = document.getElementById('btnSheetZoomFit');
        this._zoomLabel = document.getElementById('sheetZoomLabel');

        // Selector de Acordeón de Destino (Barra de Herramientas)
        this._btnTargetPrimary = document.getElementById('btnSheetTargetPrimary');
        this._btnTargetSecondary = document.getElementById('btnSheetTargetSecondary');
        this._btnTargetBoth = document.getElementById('btnSheetTargetBoth');

        // Modal de Selección de Acordeón tras Subir Partitura
        this._targetModalOverlay = document.getElementById('sheetTargetModalOverlay');
        this._targetDialogScoreName = document.getElementById('sheetTargetDialogScoreName');
        this._btnTargetModalClose = document.getElementById('btnSheetTargetModalClose');
        this._btnTargetModalConfirm = document.getElementById('btnSheetTargetModalConfirm');
        this._targetOptionCards = document.querySelectorAll('.sheet-target-option-card');
        this._cardPrimaryTuning = document.getElementById('sheetTargetCardPrimaryTuning');
        this._cardSecondaryTuning = document.getElementById('sheetTargetCardSecondaryTuning');
        this._tempSelectedTarget = 'primary';

        // Controles de Melodía y Reproductor
        this._melodyStrip = document.getElementById('sheetMelodyScrollStrip');
        this._melodyCountBadge = document.getElementById('sheetMelodyCount');
        this._melodyEngineTag = document.getElementById('sheetMelodyEngineTag');
        this._btnMelodyPlay = document.getElementById('btnSheetMelodyPlay');
        this._lblMelodyPlay = document.getElementById('lblSheetMelodyPlay');
        this._btnMelodyStop = document.getElementById('btnSheetMelodyStop');
        this._btnMelodyPrev = document.getElementById('btnSheetMelodyPrev');
        this._btnMelodyNext = document.getElementById('btnSheetMelodyNext');
        this._melodyBpmInput = document.getElementById('sheetMelodyBpm');
        this._melodyProgressLabel = document.getElementById('sheetMelodyProgress');

        // Acciones e importación
        this._btnUploadXml = document.getElementById('btnSheetUploadXml');
        this._fileInput = document.getElementById('sheetXmlFileInput');
        this._btnPresetComoZaqueo = document.getElementById('btnSheetPresetComoZaqueo');
        this._btnApplyChords = document.getElementById('btnSheetApplyChords');

        // Títulos
        this._titleLabel = document.getElementById('sheetModalMainTitle');
        this._subTitleLabel = document.getElementById('sheetModalSubTitle');
        this._pillLabel = document.getElementById('sheetDockPillText');

        // Estado
        this._osmd = null;
        this._isOsmdReady = false;
        this._currentMeasure = 1;
        this._totalMeasures = 74;
        this._zoomScale = 1.0;
        this._isCursorVisible = true;
        this._currentScoreInfo = { ...COMO_ZAQUEO_SCORE_INFO };
        this._currentChords = [...COMO_ZAQUEO_BARS];
        this._activeChordChip = null;
        this._currentMusicXmlContent = null;

        // Estado de Replicación Melódica ('primary' | 'secondary' | 'both')
        this._targetAccordion = 'primary';
        this._melodyNotes = [];
        this._activeMelodyIndex = -1;
        this._activeMelodyChip = null;
        this._isMelodyPlaying = false;
        this._melodyTimer = null;
        this._melodyBpm = 70;

        // Callbacks de integración
        this._onApplyChordsCallback = options.onApplyChords || null;
        this._onChordSelectedCallback = options.onChordSelected || null;
        this._onReplicateMelodyNoteCallback = options.onReplicateMelodyNote || null;
        this._findAccordionButtonCallback = options.findAccordionButton || null;
        this._getAccordionTuningsCallback = options.getAccordionTunings || null;

        this._initEvents();
        this._initMelodyEvents();
        this._initDraggable();
        this.renderChordsStrip();
        this._initWasmEngine();
    }

    /**
     * Inicializa eventos de la barra de herramientas, controles y teclado.
     * @private
     */
    _initEvents() {
        if (this._btnClose) {
            this._btnClose.addEventListener('click', () => this.close());
        }
        if (this._btnMinimize) {
            this._btnMinimize.addEventListener('click', () => this.minimize());
        }
        if (this._btnMaximize) {
            this._btnMaximize.addEventListener('click', () => this.toggleMaximize());
        }
        if (this._dockPill) {
            this._dockPill.addEventListener('click', () => this.restore());
        }

        // Navegación de compases
        if (this._btnFirstMeasure) {
            this._btnFirstMeasure.addEventListener('click', () => this.goToMeasure(1));
        }
        if (this._btnPrevMeasure) {
            this._btnPrevMeasure.addEventListener('click', () => this.prevMeasure());
        }
        if (this._btnNextMeasure) {
            this._btnNextMeasure.addEventListener('click', () => this.nextMeasure());
        }
        if (this._measureInput) {
            this._measureInput.addEventListener('change', (e) => {
                const barNum = parseInt(e.target.value, 10);
                if (!isNaN(barNum) && barNum >= 1 && barNum <= this._totalMeasures) {
                    this.goToMeasure(barNum);
                } else {
                    e.target.value = this._currentMeasure;
                }
            });
        }
        if (this._btnToggleCursor) {
            this._btnToggleCursor.addEventListener('click', () => this.toggleCursor());
        }

        // Controles de zoom
        if (this._btnZoomIn) {
            this._btnZoomIn.addEventListener('click', () => this.zoom(0.15));
        }
        if (this._btnZoomOut) {
            this._btnZoomOut.addEventListener('click', () => this.zoom(-0.15));
        }
        if (this._btnZoomFit) {
            this._btnZoomFit.addEventListener('click', () => this.zoomFit());
        }

        // Carga de preset Como Zaqueo
        if (this._btnPresetComoZaqueo) {
            this._btnPresetComoZaqueo.addEventListener('click', () => this.loadPresetComoZaqueo());
        }

        // Importación de archivo MusicXML (.xml, .musicxml, .mxl)
        if (this._btnUploadXml && this._fileInput) {
            this._btnUploadXml.addEventListener('click', () => this._fileInput.click());
            this._fileInput.addEventListener('change', (e) => {
                const file = e.target.files && e.target.files[0];
                if (file) {
                    this.loadMusicXmlFile(file);
                }
            });
        }

        // Aplicar acordes a la canción y diapasón
        if (this._btnApplyChords) {
            this._btnApplyChords.addEventListener('click', () => this.applyChordsToApp());
        }

        // Arrastrar y soltar archivos MusicXML directamente en el visor de partituras
        const dropTargets = [this._modal, this._viewport].filter(Boolean);
        dropTargets.forEach(target => {
            target.addEventListener('dragover', (e) => {
                e.preventDefault();
                e.stopPropagation();
            });
            target.addEventListener('drop', (e) => {
                e.preventDefault();
                e.stopPropagation();
                if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]) {
                    this.loadMusicXmlFile(e.dataTransfer.files[0]);
                }
            });
        });

        // Navegación con teclado dentro del modal
        window.addEventListener('keydown', (e) => {
            if (!this.isOpen()) return;
            if (e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;

            if (e.shiftKey && e.key === 'ArrowLeft') {
                e.preventDefault();
                this.prevMelodyNote();
            } else if (e.shiftKey && e.key === 'ArrowRight') {
                e.preventDefault();
                this.nextMelodyNote();
            } else if (e.code === 'Space' && !e.target.closest('input')) {
                e.preventDefault();
                this.toggleMelodyPlay();
            } else if (e.key === 'ArrowLeft') {
                e.preventDefault();
                this.prevMeasure();
            } else if (e.key === 'ArrowRight') {
                e.preventDefault();
                this.nextMeasure();
            } else if (e.key === 'Home') {
                e.preventDefault();
                this.goToMeasure(1);
            } else if (e.key === 'Escape') {
                this.close();
            } else if (e.key === '+' || e.key === '=') {
                e.preventDefault();
                this.zoom(0.15);
            } else if (e.key === '-') {
                e.preventDefault();
                this.zoom(-0.15);
            }
        });
    }

    /**
     * Inicializa la instancia de OpenSheetMusicDisplay en el contenedor.
     * @private
     */
    _ensureOsmd() {
        if (this._osmd) return true;
        if (!this._scoreContainer) {
            this._scoreContainer = document.getElementById('osmdScoreContainer');
        }
        if (!this._scoreContainer) return false;

        const OSMDClass = window.opensheetmusicdisplay ? window.opensheetmusicdisplay.OpenSheetMusicDisplay : null;
        if (!OSMDClass) {
            console.error('[OSMD] La librería OpenSheetMusicDisplay no está disponible en window.opensheetmusicdisplay');
            return false;
        }

        try {
            this._osmd = new OSMDClass(this._scoreContainer, {
                autoResize: true,
                backend: 'svg',
                drawTitle: true,
                drawSubtitle: true,
                drawComposer: true,
                drawPartNames: false,
                drawMeasureNumbers: true,
                drawMetronomeMarks: true,
                drawingParameters: 'compacttight',
                cursorsOptions: [{
                    type: 0,
                    color: '#4f46e5',
                    alpha: 0.5,
                    follow: true
                }]
            });
            this._osmd.zoom = this._zoomScale;
            this._isOsmdReady = true;
            return true;
        } catch (err) {
            console.error('[OSMD] Error al instanciar OpenSheetMusicDisplay:', err);
            return false;
        }
    }

    /**
     * Abre el modal flotante de la partitura.
     */
    open() {
        if (!this._modal) return;
        this._modal.classList.remove('hidden');
        if (this._dockPill) {
            this._dockPill.classList.add('hidden');
        }

        if (!this._isOsmdReady) {
            this.loadPresetComoZaqueo();
        } else {
            // Re-renderizar si cambió el tamaño del contenedor
            this._osmd.render();
        }
    }

    /**
     * Cierra el modal flotante.
     */
    close() {
        if (!this._modal) return;
        this._modal.classList.add('hidden');
        if (this._dockPill) {
            this._dockPill.classList.add('hidden');
        }
    }

    /**
     * Minimiza el modal en una pastilla flotante inferior.
     */
    minimize() {
        if (!this._modal) return;
        this._modal.classList.add('hidden');
        if (this._dockPill) {
            this._dockPill.classList.remove('hidden');
            if (this._pillLabel) {
                this._pillLabel.textContent = `${this._currentScoreInfo.title || 'Partitura MusicXML'}`;
            }
        }
    }

    /**
     * Restaura el modal desde la pastilla flotante.
     */
    restore() {
        if (this._dockPill) {
            this._dockPill.classList.add('hidden');
        }
        if (this._modal) {
            this._modal.classList.remove('hidden');
            if (this._osmd) {
                this._osmd.render();
            }
        }
    }

    /**
     * Alterna pantalla completa / tamaño maximizado de la ventana.
     */
    toggleMaximize() {
        if (!this._modal) return;
        this._modal.classList.toggle('is-maximized');
        const isMax = this._modal.classList.contains('is-maximized');
        const icon = this._btnMaximize ? this._btnMaximize.querySelector('i') : null;
        if (icon) {
            icon.className = isMax ? 'fas fa-compress' : 'fas fa-expand';
        }
        if (this._osmd) {
            setTimeout(() => this.zoomFit(), 150);
        }
    }

    isOpen() {
        return this._modal && !this._modal.classList.contains('hidden');
    }

    /**
     * Carga el preset integrado de "Como Zaqueo - Haz un milagro en mí" en MusicXML.
     */
    async loadPresetComoZaqueo() {
        this._showLoading(true, 'Generando partitura MusicXML...');
        this._currentScoreInfo = { ...COMO_ZAQUEO_SCORE_INFO };
        this._currentChords = [...COMO_ZAQUEO_BARS];
        this._totalMeasures = this._currentChords.length;

        this._updateHeaderTitles();
        this.renderChordsStrip();

        try {
            // Intentar cargar archivo estático o generar string XML
            let xmlSource = null;
            try {
                const res = await fetch('./assets/scores/como_zaqueo.musicxml');
                if (res.ok) {
                    xmlSource = await res.text();
                }
            } catch (e) {
                // Fallback a generación in-memory
            }

            if (!xmlSource) {
                xmlSource = generateComoZaqueoMusicXml(this._currentScoreInfo, this._currentChords);
            }

            await this.loadScore(xmlSource);
        } catch (err) {
            console.error('[OSMD] Error cargando preset Como Zaqueo:', err);
            this._showLoading(false);
        }
    }

    /**
     * Carga un archivo MusicXML seleccionado por el usuario (.xml, .musicxml, .mxl).
     * @param {File} file
     */
    async loadMusicXmlFile(file) {
        if (!file) return;
        const name = (file.name || '').toLowerCase();

        // Validación estricta: NO admitir PDF para partituras
        if (name.endsWith('.pdf')) {
            alert('Formato no compatible:\nLas partituras no se importan en formato PDF.\n\nPor favor importa la partitura en formato MusicXML (.xml, .musicxml o .mxl) para renderizado interactivo con OpenSheetMusicDisplay.');
            return;
        }

        const isMusicXml = name.endsWith('.xml') || name.endsWith('.musicxml') || name.endsWith('.mxl');
        if (!isMusicXml) {
            alert(`El archivo "${file.name}" no es compatible.\n\nLas partituras solo se pueden importar en formato MusicXML (.xml, .musicxml, .mxl).`);
            return;
        }

        this._showLoading(true, `Cargando ${file.name}...`);

        try {
            if (name.endsWith('.mxl')) {
                // Archivo comprimido MXL (requiere ArrayBuffer)
                const arrayBuffer = await file.arrayBuffer();
                await this.loadScore(arrayBuffer, {
                    title: file.name.replace(/\.[^/.]+$/, ''),
                    artist: 'Importado',
                    sourceFile: file.name
                });
            } else {
                // Archivo de texto plano MusicXML / XML
                const text = await file.text();
                const parsedData = parseMusicXml(text);

                if (parsedData) {
                    this._currentScoreInfo = {
                        title: parsedData.title || file.name.replace(/\.[^/.]+$/, ''),
                        artist: 'Partitura MusicXML',
                        sourceFile: file.name,
                        key: parsedData.key || 'G',
                        keyName: parsedData.key || 'Sol Mayor',
                        bpm: parsedData.bpm || 70,
                        meter: parsedData.meter || '4/4',
                        totalBars: parsedData.totalBars
                    };
                    this._currentChords = parsedData.bars;
                    this._totalMeasures = parsedData.totalBars;
                    this._updateHeaderTitles();
                    this.renderChordsStrip();
                }

                await this.loadScore(text);
            }

            // Mostrar modal para seleccionar en qué acordeón se ejecutará la melodía (Acordeón 1, 2 o Ambos)
            setTimeout(() => {
                this.openTargetModal(this._currentScoreInfo.title || file.name.replace(/\.[^/.]+$/, ''));
            }, 350);
        } catch (err) {
            console.error('[OSMD] Error al importar archivo MusicXML:', err);
            alert(`No se pudo cargar la partitura MusicXML: ${err.message}`);
            this._showLoading(false);
        }
    }

    /**
     * Carga y renderiza el contenido MusicXML en OpenSheetMusicDisplay.
     * @param {string|ArrayBuffer} source Cadena XML, ArrayBuffer o URL
     * @param {Object} [meta=null]
     */
    async loadScore(source, meta = null) {
        if (!this._ensureOsmd()) {
            this._showLoading(false);
            return;
        }

        this._showLoading(true, 'Renderizando partitura con OSMD...');
        this._currentMusicXmlContent = source;

        try {
            await this._osmd.load(source);
            this._osmd.zoom = this._zoomScale;
            this._osmd.render();

            if (this._osmd.Sheet) {
                const sheetMeasures = this._osmd.Sheet.sourceMeasures.length;
                if (sheetMeasures > 0) {
                    this._totalMeasures = sheetMeasures;
                }
            }

            if (this._measureTotalLabel) {
                this._measureTotalLabel.textContent = this._totalMeasures;
            }
            if (this._measureInput) {
                this._measureInput.max = this._totalMeasures;
            }

            if (this._osmd.cursor) {
                this._osmd.cursor.show();
                this._isCursorVisible = true;
                if (this._btnToggleCursor) {
                    this._btnToggleCursor.classList.add('active');
                }
            }

            this.goToMeasure(1);

            if (typeof source === 'string') {
                this.loadMelodyFromXml(source);
            }

            this._showLoading(false);
        } catch (err) {
            console.error('[OSMD] Error al renderizar la partitura:', err);
            this._showLoading(false);
            throw err;
        }
    }

    /**
     * Ajusta el nivel de zoom y re-renderiza.
     * @param {number} delta
     */
    zoom(delta) {
        if (!this._osmd) return;
        this._zoomScale = Math.min(2.5, Math.max(0.4, Math.round((this._zoomScale + delta) * 100) / 100));
        if (this._zoomLabel) {
            this._zoomLabel.textContent = `${Math.round(this._zoomScale * 100)}%`;
        }
        this._osmd.zoom = this._zoomScale;
        this._osmd.render();
        this._scrollToMeasure(this._currentMeasure);
    }

    /**
     * Ajusta el zoom para que la partitura llene el ancho del viewport de la ventana.
     */
    zoomFit() {
        if (!this._osmd || !this._viewport || !this._scoreContainer) return;
        const viewportWidth = this._viewport.clientWidth - 40; // márgenes
        const svgEl = this._scoreContainer.querySelector('svg');
        if (svgEl) {
            const currentWidth = svgEl.getBoundingClientRect().width;
            if (currentWidth > 50) {
                const ratio = viewportWidth / (currentWidth / this._zoomScale);
                this._zoomScale = Math.min(2.0, Math.max(0.4, Math.round(ratio * 100) / 100));
                if (this._zoomLabel) {
                    this._zoomLabel.textContent = `${Math.round(this._zoomScale * 100)}%`;
                }
                this._osmd.zoom = this._zoomScale;
                this._osmd.render();
                this._scrollToMeasure(this._currentMeasure);
            }
        }
    }

    /**
     * Navega a un compás específico en la partitura OSMD.
     * @param {number} barNumber
     */
    goToMeasure(barNumber) {
        if (!this._osmd) return;
        this._currentMeasure = Math.min(this._totalMeasures, Math.max(1, barNumber));

        if (this._measureInput) {
            this._measureInput.value = this._currentMeasure;
        }

        // Mover cursor de OSMD
        if (this._osmd.cursor && this._isCursorVisible) {
            try {
                this._osmd.cursor.reset();
                while (!this._osmd.cursor.iterator.endReached) {
                    if (this._osmd.cursor.iterator.currentMeasureIndex >= (this._currentMeasure - 1)) {
                        break;
                    }
                    this._osmd.cursor.next();
                }
            } catch (e) {
                // fallback silencioso
            }
        }

        // Resaltar en la tira de acordes
        this._highlightChordChip(this._currentMeasure);

        // Desplazar viewport
        this._scrollToMeasure(this._currentMeasure);

        // Actualizar botones prev/next
        if (this._btnPrevMeasure) this._btnPrevMeasure.disabled = this._currentMeasure <= 1;
        if (this._btnNextMeasure) this._btnNextMeasure.disabled = this._currentMeasure >= this._totalMeasures;
    }

    prevMeasure() {
        if (this._currentMeasure > 1) {
            this.goToMeasure(this._currentMeasure - 1);
        }
    }

    nextMeasure() {
        if (this._currentMeasure < this._totalMeasures) {
            this.goToMeasure(this._currentMeasure + 1);
        }
    }

    /**
     * Alterna la visibilidad del cursor interactivo.
     */
    toggleCursor() {
        if (!this._osmd || !this._osmd.cursor) return;
        this._isCursorVisible = !this._isCursorVisible;
        if (this._isCursorVisible) {
            this._osmd.cursor.show();
            if (this._btnToggleCursor) this._btnToggleCursor.classList.add('active');
        } else {
            this._osmd.cursor.hide();
            if (this._btnToggleCursor) this._btnToggleCursor.classList.remove('active');
        }
    }

    /**
     * Desplaza el viewport hacia el compás indicado.
     * @private
     * @param {number} barNumber
     */
    _scrollToMeasure(barNumber) {
        if (!this._scoreContainer || !this._viewport) return;
        // Buscar el elemento gráfico del compás en el SVG generado por OSMD
        const measureSelector = `[id*="measure"][id*="${barNumber}"]`;
        let targetEl = this._scoreContainer.querySelector(measureSelector);

        // Si no se encuentra por id, calcular posición aproximada
        if (!targetEl) {
            const svgEls = this._scoreContainer.querySelectorAll('svg');
            if (svgEls.length > 0) {
                const totalHeight = this._scoreContainer.scrollHeight;
                const estimatedTop = (barNumber / this._totalMeasures) * totalHeight;
                this._viewport.scrollTo({ top: Math.max(0, estimatedTop - 120), behavior: 'smooth' });
                return;
            }
        }

        if (targetEl) {
            targetEl.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
        }
    }

    /**
     * Resalta la ficha del compás en la tira de acordes superior.
     * @private
     * @param {number} barNumber
     */
    _highlightChordChip(barNumber) {
        if (!this._chordsStrip) return;
        const targetChip = this._chordsStrip.querySelector(`.sheet-chord-chip[data-bar="${barNumber}"]`);
        if (targetChip && targetChip !== this._activeChordChip) {
            if (this._activeChordChip) {
                this._activeChordChip.classList.remove('active-chord');
            }
            targetChip.classList.add('active-chord');
            this._activeChordChip = targetChip;
            targetChip.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
        }
    }

    /**
     * Renderiza la tira horizontal de acordes compás a compás sobre la partitura.
     */
    renderChordsStrip() {
        if (!this._chordsStrip) return;
        this._chordsStrip.innerHTML = '';

        this._currentChords.forEach((item) => {
            const chip = document.createElement('div');
            chip.className = 'sheet-chord-chip';
            chip.dataset.bar = item.bar;
            chip.dataset.chord = item.chord;
            chip.title = `Compás ${item.bar} (${item.section || ''}): ${item.chord}${item.lyrics ? ' - "' + item.lyrics + '"' : ''} - Clic para escuchar y saltar`;

            chip.innerHTML = `
                <span class="sheet-chord-chip-name">${item.chord}</span>
                <span class="sheet-chord-chip-bar">c. ${item.bar}</span>
            `;

            chip.addEventListener('click', () => {
                this.goToMeasure(item.bar);
                if (this._onChordSelectedCallback) {
                    this._onChordSelectedCallback(item);
                }
            });

            this._chordsStrip.appendChild(chip);
        });
    }

    /**
     * Sincroniza la partitura durante la reproducción de audio/canción en tiempo real.
     * @param {number} barNumber
     * @param {string} [chordSymbol='']
     */
    syncPlaybackBar(barNumber, chordSymbol = '') {
        this.goToMeasure(barNumber);
    }

    /**
     * Aplica la progresión de acordes extraída de la partitura MusicXML
     * a la cuadrícula 4/4 del reproductor y diapasón.
     */
    applyChordsToApp() {
        const bpm = this._currentScoreInfo.bpm || 70;
        const timeline = buildComoZaqueoTimelineChords(bpm, this._currentChords);

        if (this._onApplyChordsCallback) {
            this._onApplyChordsCallback(timeline, bpm, this._currentScoreInfo);
        }

        // Notificación visual rápida
        if (this._btnApplyChords) {
            const origHtml = this._btnApplyChords.innerHTML;
            this._btnApplyChords.innerHTML = '<i class="fas fa-check"></i> ¡Acordes Aplicados!';
            this._btnApplyChords.style.background = '#059669';
            setTimeout(() => {
                this._btnApplyChords.innerHTML = origHtml;
                this._btnApplyChords.style.background = '';
            }, 1800);
        }
    }

    /**
     * Actualiza los títulos del encabezado de la ventana.
     * @private
     */
    _updateHeaderTitles() {
        if (this._titleLabel) {
            this._titleLabel.textContent = this._currentScoreInfo.title || 'Partitura MusicXML';
        }
        if (this._subTitleLabel) {
            this._subTitleLabel.textContent = `${this._currentScoreInfo.keyName || this._currentScoreInfo.key || 'Sol Mayor'} · ${this._currentScoreInfo.bpm || 70} BPM · ${this._currentScoreInfo.meter || '4/4'}`;
        }
        if (this._pillLabel) {
            this._pillLabel.textContent = `${this._currentScoreInfo.title || 'Partitura MusicXML'}`;
        }
    }

    /**
     * Muestra u oculta el overlay de carga.
     * @private
     * @param {boolean} show
     * @param {string} [message='Cargando partitura...']
     */
    _showLoading(show, message = 'Cargando partitura...') {
        if (!this._loadingOverlay) return;
        this._loadingOverlay.style.display = show ? 'flex' : 'none';
        const textEl = this._loadingOverlay.querySelector('span');
        if (textEl) {
            textEl.textContent = message;
        }
    }

    /**
     * Inicializa el comportamiento arrastrable de la ventana modal flotante.
     * @private
     */
    _initDraggable() {
        if (!this._header || !this._modal) return;
        let isDragging = false;
        let startX, startY, initialLeft, initialTop;

        this._header.addEventListener('mousedown', (e) => {
            if (e.target.closest('.sheet-modal-win-controls')) return;
            if (this._modal.classList.contains('is-maximized')) return;

            isDragging = true;
            const rect = this._modal.getBoundingClientRect();
            startX = e.clientX;
            startY = e.clientY;
            initialLeft = rect.left;
            initialTop = rect.top;

            this._modal.style.right = 'auto';
            this._modal.style.left = `${initialLeft}px`;
            this._modal.style.top = `${initialTop}px`;
            e.preventDefault();
        });

        window.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            const dx = e.clientX - startX;
            const dy = e.clientY - startY;

            let newLeft = initialLeft + dx;
            let newTop = initialTop + dy;

            // Restringir a límites de ventana
            newLeft = Math.max(10, Math.min(window.innerWidth - 120, newLeft));
            newTop = Math.max(10, Math.min(window.innerHeight - 80, newTop));

            this._modal.style.left = `${newLeft}px`;
            this._modal.style.top = `${newTop}px`;
        });

        window.addEventListener('mouseup', () => {
            isDragging = false;
        });
    }

    /**
     * Sincroniza los acordes de la partitura actual con la cuadrícula 4/4 y diapasón,
     * sin cargar archivos ni sustituir el reproductor de audio principal.
     */
    applyChordsToApp() {
        if (!this._currentChords || this._currentChords.length === 0) return;
        const bpm = (this._currentScoreInfo && this._currentScoreInfo.bpm) || 70;

        let timelineChords;
        if (this._currentScoreInfo && this._currentScoreInfo.sourceFile === COMO_ZAQUEO_SCORE_INFO.sourceFile) {
            timelineChords = buildComoZaqueoTimelineChords(bpm);
        } else {
            const barDuration = (60 / bpm) * 4;
            timelineChords = this._currentChords.map(barItem => {
                const parsed = parseChordNotation(barItem.chord);
                const mIndex = barItem.bar - 1;
                const startTime = mIndex * barDuration;
                const endTime = startTime + barDuration;
                const baseMidi = 60 + (parsed ? parsed.root : 0);
                const noteMods = parsed && parsed.noteMods ? parsed.noteMods : [0, 4, 7];
                const playbackMidis = parsed && parsed.playbackMidis ? parsed.playbackMidis : [60, 64, 67];

                return {
                    chordSymbol: barItem.chord,
                    root: parsed ? parsed.root : 0,
                    type: parsed ? parsed.type : 'major',
                    noteMods: noteMods,
                    playbackMidis: playbackMidis,
                    startTime: startTime,
                    endTime: endTime,
                    bar: barItem.bar
                };
            });
        }

        if (this._onApplyChordsCallback) {
            this._onApplyChordsCallback(timelineChords, bpm, this._currentScoreInfo);
        }

        // Feedback visual en el botón de sincronización
        if (this._btnApplyChords) {
            const originalHtml = this._btnApplyChords.innerHTML;
            this._btnApplyChords.innerHTML = '<i class="fas fa-check"></i> ¡Sincronizado!';
            this._btnApplyChords.classList.add('btn-sheet-action--success');
            setTimeout(() => {
                this._btnApplyChords.innerHTML = originalHtml;
                this._btnApplyChords.classList.remove('btn-sheet-action--success');
            }, 2000);
        }
    }

    /**
     * Inicializa en segundo plano el motor de extracción en Rust (WebAssembly).
     * @private
     */
    async _initWasmEngine() {
        try {
            await wasmMelodyBridge.init();
            this._updateMelodyEngineUI();
        } catch (e) {
            console.warn('[SheetMusicModalView] Error inicializando motor Rust WASM:', e);
        }
    }

    /**
     * Actualiza el badge visual del motor de extracción activo (Rust WASM o JS).
     * @private
     */
    _updateMelodyEngineUI() {
        if (!this._melodyEngineTag) return;
        const engineName = wasmMelodyBridge.getEngineName();
        const isRust = engineName.includes('Rust');
        this._melodyEngineTag.innerHTML = `<i class="fas fa-bolt"></i> ${engineName}`;
        this._melodyEngineTag.style.background = isRust ? 'rgba(16, 185, 129, 0.2)' : 'rgba(99, 102, 241, 0.2)';
        this._melodyEngineTag.style.borderColor = isRust ? 'rgba(16, 185, 129, 0.5)' : 'rgba(99, 102, 241, 0.4)';
        this._melodyEngineTag.style.color = isRust ? '#34d399' : '#a5b4fc';
        this._melodyEngineTag.title = `Motor de extracción melódica: ${engineName}`;
    }

    /**
     * Inicializa los eventos de la sección melódica y reproductor secuencial.
     * @private
     */
    _initMelodyEvents() {
        // Selector de acordeón de destino (Barra de Herramientas)
        if (this._btnTargetPrimary) {
            this._btnTargetPrimary.addEventListener('click', () => this.setTargetAccordion('primary'));
        }
        if (this._btnTargetSecondary) {
            this._btnTargetSecondary.addEventListener('click', () => this.setTargetAccordion('secondary'));
        }
        if (this._btnTargetBoth) {
            this._btnTargetBoth.addEventListener('click', () => this.setTargetAccordion('both'));
        }

        // Modal Diálogo de Selección de Acordeón
        if (this._btnTargetModalClose) {
            this._btnTargetModalClose.addEventListener('click', () => this.closeTargetModal());
        }
        if (this._btnTargetModalConfirm) {
            this._btnTargetModalConfirm.addEventListener('click', () => {
                this.setTargetAccordion(this._tempSelectedTarget || 'primary');
                this.closeTargetModal();
            });
        }
        if (this._targetOptionCards && this._targetOptionCards.length > 0) {
            this._targetOptionCards.forEach(card => {
                card.addEventListener('click', () => {
                    this._targetOptionCards.forEach(c => c.classList.remove('active'));
                    card.classList.add('active');
                    this._tempSelectedTarget = card.dataset.target || 'primary';
                });
                card.addEventListener('dblclick', () => {
                    this.setTargetAccordion(card.dataset.target || 'primary');
                    this.closeTargetModal();
                });
            });
        }

        // Controles de reproducción secuencial
        if (this._btnMelodyPlay) {
            this._btnMelodyPlay.addEventListener('click', () => this.toggleMelodyPlay());
        }
        if (this._btnMelodyStop) {
            this._btnMelodyStop.addEventListener('click', () => this.stopMelodySequence());
        }
        if (this._btnMelodyPrev) {
            this._btnMelodyPrev.addEventListener('click', () => this.prevMelodyNote());
        }
        if (this._btnMelodyNext) {
            this._btnMelodyNext.addEventListener('click', () => this.nextMelodyNote());
        }

        // Control de tempo BPM
        if (this._melodyBpmInput) {
            this._melodyBpmInput.addEventListener('change', (e) => {
                const bpm = parseInt(e.target.value, 10);
                if (!isNaN(bpm) && bpm >= 40 && bpm <= 240) {
                    this._melodyBpm = bpm;
                } else {
                    e.target.value = this._melodyBpm;
                }
            });
        }
    }

    /**
     * Enlaza los callbacks de replicación melódica y búsqueda de botones en los acordeones.
     * @param {Object} callbacks
     */
    setReplicateCallbacks(callbacks = {}) {
        if (callbacks.onReplicateMelodyNote) {
            this._onReplicateMelodyNoteCallback = callbacks.onReplicateMelodyNote;
        }
        if (callbacks.findAccordionButton) {
            this._findAccordionButtonCallback = callbacks.findAccordionButton;
            this.renderMelodyStrip();
        }
        if (callbacks.getAccordionTunings) {
            this._getAccordionTuningsCallback = callbacks.getAccordionTunings;
        }
    }

    /**
     * Abre el modal emergente para seleccionar en qué acordeón se ejecutará la melodía.
     * @param {string} [scoreTitle='']
     */
    openTargetModal(scoreTitle = '') {
        if (!this._targetModalOverlay) return;

        if (this._targetDialogScoreName) {
            this._targetDialogScoreName.textContent = scoreTitle || (this._currentScoreInfo && this._currentScoreInfo.title) || 'Partitura Cargada';
        }

        if (this._getAccordionTuningsCallback) {
            try {
                const tunings = this._getAccordionTuningsCallback();
                if (tunings) {
                    if (this._cardPrimaryTuning) this._cardPrimaryTuning.textContent = `Acordeón 1 (${tunings.primaryName || 'Cinco Letras'})`;
                    if (this._cardSecondaryTuning) this._cardSecondaryTuning.textContent = `Acordeón 2 (${tunings.secondaryName || 'Cinco Letras'})`;
                }
            } catch (e) {}
        }

        this._tempSelectedTarget = this._targetAccordion || 'primary';
        if (this._targetOptionCards) {
            this._targetOptionCards.forEach(card => {
                card.classList.toggle('active', card.dataset.target === this._tempSelectedTarget);
            });
        }

        this._targetModalOverlay.classList.remove('hidden');
    }

    /**
     * Cierra el modal de selección de acordeón de destino.
     */
    closeTargetModal() {
        if (!this._targetModalOverlay) return;
        this._targetModalOverlay.classList.add('hidden');
    }

    /**
     * Establece el acordeón de destino ('primary', 'secondary' o 'both').
     * @param {string} target 'primary' | 'secondary' | 'both'
     */
    setTargetAccordion(target) {
        this._targetAccordion = ['primary', 'secondary', 'both'].includes(target) ? target : 'primary';

        if (this._btnTargetPrimary) {
            this._btnTargetPrimary.classList.toggle('active', this._targetAccordion === 'primary');
        }
        if (this._btnTargetSecondary) {
            this._btnTargetSecondary.classList.toggle('active', this._targetAccordion === 'secondary');
        }
        if (this._btnTargetBoth) {
            this._btnTargetBoth.classList.toggle('active', this._targetAccordion === 'both');
        }

        // Re-renderizar la tira para actualizar la digitación correspondiente a la afinación del acordeón seleccionado
        this.renderMelodyStrip();

        // Si hay una nota activa, replicarla en el nuevo acordeón seleccionado
        if (this._activeMelodyIndex >= 0 && this._melodyNotes[this._activeMelodyIndex]) {
            this.selectMelodyNote(this._activeMelodyIndex, true);
        }
    }

    /**
     * Extrae las notas melódicas desde una cadena MusicXML mediante Rust WASM (o fallback JS).
     * @param {string} xmlText
     */
    loadMelodyFromXml(xmlText) {
        if (!xmlText || typeof xmlText !== 'string') return;
        try {
            const report = wasmMelodyBridge.extractMelody(xmlText);
            this._melodyNotes = report && report.notes ? report.notes : [];
            this._activeMelodyIndex = -1;
            this._activeMelodyChip = null;

            if (report.bpm && (!this._melodyBpm || this._melodyBpm === 70)) {
                this._melodyBpm = Math.round(report.bpm);
                if (this._melodyBpmInput) {
                    this._melodyBpmInput.value = this._melodyBpm;
                }
            }

            if (this._melodyCountBadge) {
                this._melodyCountBadge.textContent = `${this._melodyNotes.length} notas`;
            }

            this._updateMelodyEngineUI();
            this.renderMelodyStrip();
        } catch (err) {
            console.warn('[SheetMusicModalView] Error extrayendo notas melódicas:', err);
        }
    }

    /**
     * Renderiza la tira interactiva de notas melódicas con mapeo al acordeón seleccionado.
     */
    renderMelodyStrip() {
        if (!this._melodyStrip) return;
        this._melodyStrip.innerHTML = '';

        if (!this._melodyNotes || this._melodyNotes.length === 0) {
            this._melodyStrip.innerHTML = '<span style="font-size:0.64rem; color:#64748b; padding:4px 8px;">No se encontraron notas melódicas en la partitura.</span>';
            if (this._melodyProgressLabel) this._melodyProgressLabel.textContent = '0 / 0';
            return;
        }

        if (this._melodyProgressLabel) {
            const current = this._activeMelodyIndex >= 0 ? this._activeMelodyIndex + 1 : 0;
            this._melodyProgressLabel.textContent = `${current} / ${this._melodyNotes.length}`;
        }

        this._melodyNotes.forEach((note, idx) => {
            const chip = document.createElement('div');
            chip.className = `sheet-melody-chip ${idx === this._activeMelodyIndex ? 'active-melody-note' : ''}`;
            chip.dataset.index = idx;
            chip.dataset.bar = note.bar;
            chip.dataset.midi = note.midi;

            // Mapeo en el acordeón seleccionado
            let btnBadgeHtml = '';
            if (note.is_rest) {
                btnBadgeHtml = '<span class="sheet-melody-chip-btn sheet-melody-chip-btn--rest">Silencio</span>';
            } else if (this._targetAccordion === 'both') {
                const btn1 = this._findButtonForNote(note.midi, 'primary');
                const btn2 = this._findButtonForNote(note.midi, 'secondary');

                const b1Html = btn1
                    ? `<span class="sheet-melody-chip-btn ${btn1.direction === 'push' ? 'sheet-melody-chip-btn--push' : 'sheet-melody-chip-btn--pull'}" title="Acordeón 1: ${btn1.btnLabel} (${btn1.bellowsText})">1: ${btn1.btnLabel}</span>`
                    : '<span class="sheet-melody-chip-btn sheet-melody-chip-btn--unmapped" title="Acordeón 1: Sin botón">1: -</span>';
                
                const b2Html = btn2
                    ? `<span class="sheet-melody-chip-btn ${btn2.direction === 'push' ? 'sheet-melody-chip-btn--push' : 'sheet-melody-chip-btn--pull'}" title="Acordeón 2: ${btn2.btnLabel} (${btn2.bellowsText})">2: ${btn2.btnLabel}</span>`
                    : '<span class="sheet-melody-chip-btn sheet-melody-chip-btn--unmapped" title="Acordeón 2: Sin botón">2: -</span>';

                btnBadgeHtml = `<div style="display:flex; flex-direction:column; gap:2px; width:100%; margin-top:2px;">${b1Html}${b2Html}</div>`;
            } else {
                const btnMatch = this._findButtonForNote(note.midi, this._targetAccordion);
                if (btnMatch) {
                    const isPush = btnMatch.direction === 'push';
                    const dirClass = isPush ? 'sheet-melody-chip-btn--push' : 'sheet-melody-chip-btn--pull';
                    const arrowIcon = isPush ? '▾' : '▴';
                    btnBadgeHtml = `<span class="sheet-melody-chip-btn ${dirClass}" title="${btnMatch.btnLabel} (${btnMatch.bellowsText})">${btnMatch.btnLabel} ${arrowIcon} ${btnMatch.bellowsText}</span>`;
                } else {
                    btnBadgeHtml = '<span class="sheet-melody-chip-btn sheet-melody-chip-btn--unmapped" title="Nota fuera del registro del acordeón seleccionado">Sin botón</span>';
                }
            }

            chip.innerHTML = `
                <span class="sheet-melody-chip-pitch">${note.is_rest ? '𝄽' : note.pitch_name}</span>
                <span class="sheet-melody-chip-pos">c.${note.bar} · p.${note.beat}</span>
                ${btnBadgeHtml}
            `;

            const targetName = this._targetAccordion === 'both' ? 'Ambos Acordeones' : (this._targetAccordion === 'primary' ? 'Acordeón 1' : 'Acordeón 2');
            chip.title = `Nota ${idx + 1}: ${note.pitch_name} (Compás ${note.bar}, pulso ${note.beat})${note.lyric ? ' - "' + note.lyric + '"' : ''} - Clic para reproducir e iluminar en ${targetName}`;

            chip.addEventListener('click', () => {
                if (this._isMelodyPlaying) {
                    this.pauseMelodySequence();
                }
                this.selectMelodyNote(idx, true);
            });

            this._melodyStrip.appendChild(chip);
        });
    }

    /**
     * Resuelve el botón físico para una nota MIDI en el acordeón de destino.
     * @private
     * @param {number} midi
     * @param {string} [target=this._targetAccordion]
     * @returns {Object|null}
     */
    _findButtonForNote(midi, target = this._targetAccordion) {
        if (!midi) return null;
        if (this._findAccordionButtonCallback) {
            return this._findAccordionButtonCallback(midi, target);
        }
        return null;
    }

    /**
     * Selecciona una nota melódica, sincroniza el pentagrama, actualiza la tira y la replica en el acordeón.
     * @param {number} index
     * @param {boolean} [triggerAction=true]
     */
    selectMelodyNote(index, triggerAction = true) {
        if (!this._melodyNotes || index < 0 || index >= this._melodyNotes.length) return;
        this._activeMelodyIndex = index;
        const note = this._melodyNotes[index];

        // Actualizar chips en la tira
        if (this._melodyStrip) {
            if (this._activeMelodyChip) {
                this._activeMelodyChip.classList.remove('active-melody-note');
            }
            const targetChip = this._melodyStrip.querySelector(`.sheet-melody-chip[data-index="${index}"]`);
            if (targetChip) {
                targetChip.classList.add('active-melody-note');
                this._activeMelodyChip = targetChip;
                targetChip.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
            }
        }

        // Actualizar indicador de progreso
        if (this._melodyProgressLabel) {
            this._melodyProgressLabel.textContent = `${index + 1} / ${this._melodyNotes.length}`;
        }

        // Sincronizar compás en OSMD
        if (note.bar && note.bar !== this._currentMeasure) {
            this.goToMeasure(note.bar);
        }

        // Replicar en el acordeón seleccionado
        if (triggerAction && this._onReplicateMelodyNoteCallback) {
            this._onReplicateMelodyNoteCallback(note, this._targetAccordion);
        }
    }

    /**
     * Alterna la reproducción automática y secuencial de la melodía.
     */
    toggleMelodyPlay() {
        if (this._isMelodyPlaying) {
            this.pauseMelodySequence();
        } else {
            this.playMelodySequence();
        }
    }

    /**
     * Inicia la reproducción secuencial de la melodía en el acordeón seleccionado.
     */
    playMelodySequence() {
        if (!this._melodyNotes || this._melodyNotes.length === 0) return;
        this._isMelodyPlaying = true;
        this._updateMelodyPlayButtonUI();

        if (this._activeMelodyIndex < 0 || this._activeMelodyIndex >= this._melodyNotes.length - 1) {
            this._activeMelodyIndex = 0;
        }

        const playNext = () => {
            if (!this._isMelodyPlaying) return;
            if (this._activeMelodyIndex >= this._melodyNotes.length) {
                this.stopMelodySequence();
                return;
            }

            const currentIdx = this._activeMelodyIndex;
            const note = this._melodyNotes[currentIdx];
            this.selectMelodyNote(currentIdx, true);

            // Calcular duración en ms a partir del tempo BPM
            const durationBeats = note.duration_beats || 1.0;
            const noteDurationMs = Math.max(120, Math.round((durationBeats * 60 / (this._melodyBpm || 70)) * 1000));

            this._activeMelodyIndex++;
            this._melodyTimer = setTimeout(playNext, noteDurationMs);
        };

        playNext();
    }

    /**
     * Pausa la reproducción secuencial de la melodía.
     */
    pauseMelodySequence() {
        this._isMelodyPlaying = false;
        if (this._melodyTimer) {
            clearTimeout(this._melodyTimer);
            this._melodyTimer = null;
        }
        this._updateMelodyPlayButtonUI();
    }

    /**
     * Detiene la reproducción secuencial y restablece la posición al inicio.
     */
    stopMelodySequence() {
        this.pauseMelodySequence();
        this._activeMelodyIndex = -1;
        if (this._melodyProgressLabel && this._melodyNotes) {
            this._melodyProgressLabel.textContent = `0 / ${this._melodyNotes.length}`;
        }
        if (this._activeMelodyChip) {
            this._activeMelodyChip.classList.remove('active-melody-note');
            this._activeMelodyChip = null;
        }
        if (this._onReplicateMelodyNoteCallback) {
            this._onReplicateMelodyNoteCallback(null, this._targetAccordion);
        }
    }

    /**
     * Retrocede a la nota melódica anterior.
     */
    prevMelodyNote() {
        if (!this._melodyNotes || this._melodyNotes.length === 0) return;
        if (this._isMelodyPlaying) this.pauseMelodySequence();
        const prevIdx = Math.max(0, (this._activeMelodyIndex <= 0 ? 0 : this._activeMelodyIndex - 1));
        this.selectMelodyNote(prevIdx, true);
    }

    /**
     * Avanza a la siguiente nota melódica.
     */
    nextMelodyNote() {
        if (!this._melodyNotes || this._melodyNotes.length === 0) return;
        if (this._isMelodyPlaying) this.pauseMelodySequence();
        const nextIdx = Math.min(this._melodyNotes.length - 1, this._activeMelodyIndex + 1);
        this.selectMelodyNote(nextIdx, true);
    }

    /**
     * Actualiza la apariencia del botón Play/Pausa de la melodía.
     * @private
     */
    _updateMelodyPlayButtonUI() {
        if (!this._btnMelodyPlay) return;
        if (this._isMelodyPlaying) {
            this._btnMelodyPlay.classList.add('is-playing');
            this._btnMelodyPlay.innerHTML = '<i class="fas fa-pause"></i> <span id="lblSheetMelodyPlay">Pausar</span>';
            this._btnMelodyPlay.title = 'Pausar reproducción secuencial (Espacio)';
        } else {
            this._btnMelodyPlay.classList.remove('is-playing');
            this._btnMelodyPlay.innerHTML = '<i class="fas fa-play"></i> <span id="lblSheetMelodyPlay">Replicar</span>';
            this._btnMelodyPlay.title = 'Reproducir y replicar melodía en acordeón seleccionado (Espacio)';
        }
    }
}

