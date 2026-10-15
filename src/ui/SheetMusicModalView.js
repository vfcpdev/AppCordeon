import { 
    COMO_ZAQUEO_SCORE_INFO, 
    COMO_ZAQUEO_BARS, 
    generateComoZaqueoMusicXml, 
    parseMusicXml, 
    buildComoZaqueoTimelineChords 
} from '../models/SheetMusicData.js';

/**
 * Controlador de la Ventana Modal de Partituras basada en OpenSheetMusicDisplay (OSMD)
 * Renderiza partituras interactivas en formato MusicXML / MXL directamente en el navegador,
 * con pentagramas, notas, clave, acordes, letra, zoom, navegación por compás y cursor de seguimiento.
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

        // Callbacks de integración
        this._onApplyChordsCallback = options.onApplyChords || null;
        this._onChordSelectedCallback = options.onChordSelected || null;

        this._initEvents();
        this._initDraggable();
        this.renderChordsStrip();
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

        // Navegación con teclado dentro del modal
        window.addEventListener('keydown', (e) => {
            if (!this.isOpen()) return;
            if (e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;

            if (e.key === 'ArrowLeft') {
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
        const name = file.name.toLowerCase();
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
}
