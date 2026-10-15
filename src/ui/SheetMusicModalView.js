import { COMO_ZAQUEO_SCORE_INFO, COMO_ZAQUEO_BARS, buildComoZaqueoTimelineChords } from '../models/SheetMusicData.js';

/**
 * Controlador de la Ventana Modal Flotante de Partitura con Visor PDF
 * y Guía Sincronizada de Acordes.
 */
export class SheetMusicModalView {
    constructor(options = {}) {
        this._modal = document.getElementById('floatingSheetModal');
        this._dockPill = document.getElementById('sheetMinimizedDockPill');
        this._canvas = document.getElementById('sheetPdfCanvas');
        this._loadingOverlay = document.getElementById('sheetLoadingOverlay');
        this._header = document.getElementById('sheetModalHeader');
        this._chordsStrip = document.getElementById('sheetChordsScrollStrip');

        // Controles de ventana
        this._btnClose = document.getElementById('btnSheetClose');
        this._btnMinimize = document.getElementById('btnSheetMinimize');
        this._btnMaximize = document.getElementById('btnSheetMaximize');

        // Controles de navegación y zoom
        this._btnPrevPage = document.getElementById('btnSheetPrevPage');
        this._btnNextPage = document.getElementById('btnSheetNextPage');
        this._pageInput = document.getElementById('sheetPageInput');
        this._pageTotalLabel = document.getElementById('sheetPageTotal');
        this._btnZoomIn = document.getElementById('btnSheetZoomIn');
        this._btnZoomOut = document.getElementById('btnSheetZoomOut');
        this._zoomLabel = document.getElementById('sheetZoomLabel');

        // Acciones
        this._btnUpload = document.getElementById('btnSheetUploadCustom');
        this._fileInput = document.getElementById('sheetModalFileInput');
        this._btnPresetComoZaqueo = document.getElementById('btnSheetPresetComoZaqueo');
        this._btnApplyChords = document.getElementById('btnSheetApplyChords');

        // Títulos
        this._titleLabel = document.getElementById('sheetModalMainTitle');
        this._subTitleLabel = document.getElementById('sheetModalSubTitle');
        this._pillLabel = document.getElementById('sheetDockPillText');

        // Estado
        this._pdfDoc = null;
        this._currentPage = 1;
        this._totalPages = 1;
        this._zoomScale = 1.0;
        this._isRendering = false;
        this._pageRenderingQueue = null;
        this._currentScoreInfo = { ...COMO_ZAQUEO_SCORE_INFO };
        this._currentChords = [...COMO_ZAQUEO_BARS];
        this._activeChordChip = null;

        // Callback para aplicar acordes
        this._onApplyChordsCallback = options.onApplyChords || null;
        this._onChordSelectedCallback = options.onChordSelected || null;

        this._initEvents();
        this._initDraggable();
        this.renderChordsStrip();
    }

    /**
     * Inicializa eventos de botones y controles.
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

        // Navegación de páginas
        if (this._btnPrevPage) {
            this._btnPrevPage.addEventListener('click', () => this.prevPage());
        }
        if (this._btnNextPage) {
            this._btnNextPage.addEventListener('click', () => this.nextPage());
        }
        if (this._pageInput) {
            this._pageInput.addEventListener('change', (e) => {
                const pageNum = parseInt(e.target.value, 10);
                if (!isNaN(pageNum) && pageNum >= 1 && pageNum <= this._totalPages) {
                    this.goToPage(pageNum);
                } else {
                    e.target.value = this._currentPage;
                }
            });
        }

        // Zoom
        if (this._btnZoomIn) {
            this._btnZoomIn.addEventListener('click', () => this.zoom(0.15));
        }
        if (this._btnZoomOut) {
            this._btnZoomOut.addEventListener('click', () => this.zoom(-0.15));
        }

        // Carga de archivo personalizado
        if (this._btnUpload && this._fileInput) {
            this._btnUpload.addEventListener('click', () => this._fileInput.click());
            this._fileInput.addEventListener('change', (e) => {
                if (e.target.files && e.target.files[0]) {
                    this.loadCustomFile(e.target.files[0]);
                }
            });
        }

        // Cargar Preset Como Zaqueo
        if (this._btnPresetComoZaqueo) {
            this._btnPresetComoZaqueo.addEventListener('click', () => {
                this.loadPresetComoZaqueo();
            });
        }

        // Aplicar acordes a la canción en la cuadrícula
        if (this._btnApplyChords) {
            this._btnApplyChords.addEventListener('click', () => {
                this.applyChordsToSong();
            });
        }

        // Atajos de teclado cuando el modal está visible
        window.addEventListener('keydown', (e) => {
            if (this.isOpen() && !this.isMinimized()) {
                const tag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
                if (tag === 'input' || tag === 'textarea') return;

                if (e.key === 'ArrowRight' || e.key === 'PageDown') {
                    e.preventDefault();
                    this.nextPage();
                } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
                    e.preventDefault();
                    this.prevPage();
                }
            }
        });
    }

    /**
     * Hace la ventana arrastrable por el encabezado.
     * @private
     */
    _initDraggable() {
        if (!this._header || !this._modal) return;

        let isDragging = false;
        let startX = 0;
        let startY = 0;
        let initialLeft = 0;
        let initialTop = 0;

        const onPointerDown = (e) => {
            if (e.target.closest('.sheet-modal-win-controls')) return;
            if (this._modal.classList.contains('is-maximized')) return;

            isDragging = true;
            startX = e.clientX;
            startY = e.clientY;

            const rect = this._modal.getBoundingClientRect();
            initialLeft = rect.left;
            initialTop = rect.top;

            // Cambiar estilos mientras se arrastra
            this._modal.style.right = 'auto';
            this._modal.style.left = `${initialLeft}px`;
            this._modal.style.top = `${initialTop}px`;
            document.body.style.userSelect = 'none';

            window.addEventListener('pointermove', onPointerMove);
            window.addEventListener('pointerup', onPointerUp);
        };

        const onPointerMove = (e) => {
            if (!isDragging) return;
            const deltaX = e.clientX - startX;
            const deltaY = e.clientY - startY;

            let newLeft = initialLeft + deltaX;
            let newTop = initialTop + deltaY;

            // Restringir a los bordes de la pantalla
            const maxLeft = window.innerWidth - 150;
            const maxTop = window.innerHeight - 60;
            newLeft = Math.max(10, Math.min(newLeft, maxLeft));
            newTop = Math.max(10, Math.min(newTop, maxTop));

            this._modal.style.left = `${newLeft}px`;
            this._modal.style.top = `${newTop}px`;
        };

        const onPointerUp = () => {
            isDragging = false;
            document.body.style.userSelect = '';
            window.removeEventListener('pointermove', onPointerMove);
            window.removeEventListener('pointerup', onPointerUp);
        };

        this._header.addEventListener('pointerdown', onPointerDown);
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

        // Si aún no se ha cargado el documento inicial, cargarlo
        if (!this._pdfDoc) {
            this.loadPresetComoZaqueo();
        }
    }

    /**
     * Cierra el modal.
     */
    close() {
        if (!this._modal) return;
        this._modal.classList.add('hidden');
        if (this._dockPill) {
            this._dockPill.classList.add('hidden');
        }
    }

    /**
     * Minimiza la ventana a una pastilla flotante en la esquina.
     */
    minimize() {
        if (!this._modal) return;
        this._modal.classList.add('hidden');
        if (this._dockPill) {
            this._dockPill.classList.remove('hidden');
            if (this._pillLabel) {
                this._pillLabel.textContent = `${this._currentScoreInfo.title || 'Partitura'} (Pág. ${this._currentPage})`;
            }
        }
    }

    /**
     * Restaura la ventana desde el estado minimizado.
     */
    restore() {
        this.open();
    }

    /**
     * Alterna maximizar/restaurar tamaño.
     */
    toggleMaximize() {
        if (!this._modal) return;
        const isMax = this._modal.classList.toggle('is-maximized');
        const icon = this._btnMaximize ? this._btnMaximize.querySelector('i') : null;
        if (icon) {
            icon.className = isMax ? 'fas fa-compress' : 'fas fa-expand';
        }
        // Re-renderizar página con la nueva escala del viewport
        this.renderPage(this._currentPage);
    }

    isOpen() {
        return this._modal && !this._modal.classList.contains('hidden');
    }

    isMinimized() {
        return this._dockPill && !this._dockPill.classList.contains('hidden');
    }

    /**
     * Carga el PDF predefinido "Como Zaqueo - Haz un milagro en mí".
     */
    async loadPresetComoZaqueo() {
        this._currentScoreInfo = { ...COMO_ZAQUEO_SCORE_INFO };
        this._currentChords = [...COMO_ZAQUEO_BARS];

        if (this._titleLabel) {
            this._titleLabel.textContent = this._currentScoreInfo.title;
        }
        if (this._subTitleLabel) {
            this._subTitleLabel.textContent = `${this._currentScoreInfo.keyName} · ${this._currentScoreInfo.bpm} BPM · 4/4`;
        }

        this.renderChordsStrip();
        await this.loadPdfFromUrl('./COMO ZAQUEO - HAZ UN MILAGRO EN MI.pdf');
    }

    /**
     * Carga un PDF desde una URL.
     * @param {string} url
     */
    async loadPdfFromUrl(url) {
        if (typeof window.pdfjsLib === 'undefined') {
            console.warn('[SheetMusicModalView] pdfjsLib no está disponible en window.');
            return;
        }

        this._showLoading('Cargando partitura PDF...');
        try {
            window.pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
            const loadingTask = window.pdfjsLib.getDocument(url);
            this._pdfDoc = await loadingTask.promise;
            this._totalPages = this._pdfDoc.numPages;

            if (this._pageTotalLabel) {
                this._pageTotalLabel.textContent = this._totalPages;
            }

            this._currentPage = 1;
            await this.renderPage(this._currentPage);
        } catch (err) {
            console.error('[SheetMusicModalView] Error al cargar PDF:', err);
            this._showLoading(`Error al abrir PDF: ${err.message}`);
            setTimeout(() => this._hideLoading(), 3000);
        }
    }

    /**
     * Carga un archivo de partitura personalizado (PDF o imagen).
     * @param {File} file
     */
    async loadCustomFile(file) {
        if (!file) return;

        this._currentScoreInfo.title = file.name.replace(/\.[^/.]+$/, '');
        this._currentScoreInfo.sourceFile = file.name;

        if (this._titleLabel) {
            this._titleLabel.textContent = this._currentScoreInfo.title;
        }
        if (this._subTitleLabel) {
            this._subTitleLabel.textContent = `Archivo cargado: ${file.name}`;
        }

        if (file.type === 'application/pdf' || file.name.endsWith('.pdf')) {
            this._showLoading('Cargando partitura PDF...');
            try {
                const arrayBuffer = await file.arrayBuffer();
                window.pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
                const loadingTask = window.pdfjsLib.getDocument({ data: arrayBuffer });
                this._pdfDoc = await loadingTask.promise;
                this._totalPages = this._pdfDoc.numPages;

                if (this._pageTotalLabel) {
                    this._pageTotalLabel.textContent = this._totalPages;
                }

                this._currentPage = 1;
                await this.renderPage(this._currentPage);
            } catch (err) {
                console.error('[SheetMusicModalView] Error al procesar PDF:', err);
                this._showLoading(`Error al leer PDF: ${err.message}`);
                setTimeout(() => this._hideLoading(), 3000);
            }
        }
    }

    /**
     * Renderiza una página específica en el canvas.
     * @param {number} pageNum
     */
    async renderPage(pageNum) {
        if (!this._pdfDoc || !this._canvas) return;

        if (this._isRendering) {
            this._pageRenderingQueue = pageNum;
            return;
        }

        this._isRendering = true;
        this._showLoading(`Renderizando página ${pageNum}...`);

        try {
            const page = await this._pdfDoc.getPage(pageNum);
            const viewport = page.getViewport({ scale: this._zoomScale * 1.5 });
            const ctx = this._canvas.getContext('2d');

            this._canvas.height = viewport.height;
            this._canvas.width = viewport.width;

            const renderContext = {
                canvasContext: ctx,
                viewport: viewport
            };

            await page.render(renderContext).promise;

            this._currentPage = pageNum;
            if (this._pageInput) {
                this._pageInput.value = pageNum;
            }
            if (this._pillLabel) {
                this._pillLabel.textContent = `${this._currentScoreInfo.title} (Pág. ${pageNum})`;
            }

            // Habilitar/deshabilitar botones
            if (this._btnPrevPage) this._btnPrevPage.disabled = pageNum <= 1;
            if (this._btnNextPage) this._btnNextPage.disabled = pageNum >= this._totalPages;

            this._hideLoading();
            this._isRendering = false;

            if (this._pageRenderingQueue !== null) {
                const nextQueued = this._pageRenderingQueue;
                this._pageRenderingQueue = null;
                this.renderPage(nextQueued);
            }
        } catch (err) {
            console.error('[SheetMusicModalView] Error al renderizar página:', err);
            this._hideLoading();
            this._isRendering = false;
        }
    }

    prevPage() {
        if (this._currentPage > 1) {
            this.goToPage(this._currentPage - 1);
        }
    }

    nextPage() {
        if (this._currentPage < this._totalPages) {
            this.goToPage(this._currentPage + 1);
        }
    }

    goToPage(pageNum) {
        if (pageNum >= 1 && pageNum <= this._totalPages) {
            this.renderPage(pageNum);
        }
    }

    zoom(delta) {
        this._zoomScale = Math.max(0.5, Math.min(2.5, this._zoomScale + delta));
        if (this._zoomLabel) {
            this._zoomLabel.textContent = `${Math.round(this._zoomScale * 100)}%`;
        }
        this.renderPage(this._currentPage);
    }

    /**
     * Dibuja la tira interactiva de acordes compás por compás sobre la partitura.
     */
    renderChordsStrip() {
        if (!this._chordsStrip) return;
        this._chordsStrip.innerHTML = '';

        const fragment = document.createDocumentFragment();

        this._currentChords.forEach((item, idx) => {
            const chip = document.createElement('div');
            chip.className = 'sheet-chord-chip';
            chip.id = `sheet-chord-chip-${idx}`;
            chip.dataset.bar = item.bar;
            chip.dataset.chord = item.chord;
            chip.dataset.page = item.page || 1;
            chip.title = `Compás ${item.bar} (${item.section}): ${item.chord} (Página ${item.page || 1}) - Clic para escuchar y ver digitación`;

            chip.innerHTML = `
                <span class="sheet-chord-chip-name">${item.chord}</span>
                <span class="sheet-chord-chip-bar">c.${item.bar}</span>
            `;

            chip.addEventListener('click', (e) => {
                e.stopPropagation();
                this.selectChordChip(chip, item);
            });

            fragment.appendChild(chip);
        });

        this._chordsStrip.appendChild(fragment);
    }

    /**
     * Selecciona un chip de acorde: va a la página de la partitura y notifica para reproducir/sincronizar.
     */
    selectChordChip(chipEl, item) {
        if (this._activeChordChip) {
            this._activeChordChip.classList.remove('active-chord');
        }
        if (chipEl) {
            chipEl.classList.add('active-chord');
            this._activeChordChip = chipEl;
            chipEl.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
        }

        // Navegar a la página correspondiente en la partitura si está indicada
        if (item.page && item.page !== this._currentPage) {
            this.goToPage(item.page);
        }

        if (this._onChordSelectedCallback) {
            this._onChordSelectedCallback(item);
        }
    }

    /**
     * Sincroniza el acorde activo desde la reproducción general de la canción.
     * @param {number} barNumber
     * @param {string} chordSymbol
     */
    syncPlaybackBar(barNumber, chordSymbol) {
        if (!this._chordsStrip) return;

        const targetChip = this._chordsStrip.querySelector(`.sheet-chord-chip[data-bar="${barNumber}"]`);
        if (targetChip) {
            if (this._activeChordChip && this._activeChordChip !== targetChip) {
                this._activeChordChip.classList.remove('active-chord');
            }
            targetChip.classList.add('active-chord');
            this._activeChordChip = targetChip;
            targetChip.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });

            // Pasar automáticamente a la página de la partitura durante la reproducción si difiere
            const targetPage = parseInt(targetChip.dataset.page, 10);
            if (targetPage && targetPage !== this._currentPage && !this._isRendering) {
                this.goToPage(targetPage);
            }
        }
    }

    /**
     * Vuelca los acordes analizados de la partitura directamente en la cuadrícula de compases 4/4
     * y en el timeline del reproductor.
     */
    applyChordsToSong() {
        const bpm = this._currentScoreInfo.bpm || 70;
        const timeline = buildComoZaqueoTimelineChords(bpm);

        if (this._onApplyChordsCallback) {
            this._onApplyChordsCallback(timeline, bpm, this._currentScoreInfo);
        }
    }

    _showLoading(text) {
        if (!this._loadingOverlay) return;
        this._loadingOverlay.style.display = 'flex';
        const label = this._loadingOverlay.querySelector('span');
        if (label && text) label.textContent = text;
    }

    _hideLoading() {
        if (!this._loadingOverlay) return;
        this._loadingOverlay.style.display = 'none';
    }
}
