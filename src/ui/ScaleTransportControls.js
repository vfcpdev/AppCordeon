/**
 * @fileoverview Controles de Transporte y Loop para la Escala (ScaleTransportControls).
 * Responsable exclusivo de:
 * - Botones Anterior, Siguiente, Reinicio y Reproducción de la escala
 * - Modo Bucle (Loop) y límites de inicio/fin
 * - Slider y selector de velocidad / tempo
 * Cumple con el principio de segregación de interfaces (ISP) y responsabilidad única (SRP).
 * @module ui/ScaleTransportControls
 */

export class ScaleTransportControls {
    /**
     * @param {Object} elements
     * @param {HTMLElement} [elements.btnPrev]
     * @param {HTMLElement} [elements.btnNext]
     * @param {HTMLElement} [elements.btnPlay]
     * @param {HTMLElement} [elements.btnReset]
     * @param {HTMLElement} [elements.btnLoop]
     * @param {HTMLInputElement} [elements.loopStartInput]
     * @param {HTMLInputElement} [elements.loopEndInput]
     * @param {HTMLInputElement} [elements.speedSlider]
     * @param {HTMLElement} [elements.speedLabel]
     */
    constructor(elements = {}) {
        this._btnPrev = elements.btnPrev || null;
        this._btnNext = elements.btnNext || null;
        this._btnPlay = elements.btnPlay || null;
        this._btnReset = elements.btnReset || null;
        this._btnLoop = elements.btnLoop || null;
        this._loopStartInput = elements.loopStartInput || null;
        this._loopEndInput = elements.loopEndInput || null;
        this._speedSlider = elements.speedSlider || null;
        this._speedLabel = elements.speedLabel || null;

        this._isPlaying = false;
        this._isLooping = false;
    }

    get isLooping() {
        return this._isLooping;
    }

    get isPlaying() {
        return this._isPlaying;
    }

    /**
     * Configura los listeners de los controles de transporte.
     * @param {Object} handlers
     */
    bindTransportEvents(handlers) {
        if (this._btnPrev && handlers.onPrev) this._btnPrev.addEventListener('click', handlers.onPrev);
        if (this._btnNext && handlers.onNext) this._btnNext.addEventListener('click', handlers.onNext);
        if (this._btnReset && handlers.onReset) this._btnReset.addEventListener('click', handlers.onReset);
        if (this._btnPlay && handlers.onPlay) this._btnPlay.addEventListener('click', handlers.onPlay);

        if (this._btnLoop) {
            this._btnLoop.addEventListener('click', () => {
                this._isLooping = !this._isLooping;
                this._btnLoop.classList.toggle('active', this._isLooping);
            });
        }

        if (this._speedSlider) {
            this._speedSlider.addEventListener('input', (e) => {
                const val = parseInt(e.target.value, 10);
                if (this._speedLabel) this._speedLabel.textContent = `${val}ms`;
                if (handlers.onSpeedChange) handlers.onSpeedChange(val);
            });
        }
    }

    /**
     * Devuelve el rango configurado para el bucle.
     * @returns {{start: number, end: number}}
     */
    getLoopRange() {
        let start = this._loopStartInput ? parseInt(this._loopStartInput.value, 10) - 1 : 0;
        let end = this._loopEndInput ? parseInt(this._loopEndInput.value, 10) : 8;

        if (isNaN(start) || start < 0) start = 0;
        if (isNaN(end) || end > 8) end = 8;
        if (start >= end) start = Math.max(0, end - 1);

        return { start, end };
    }

    /**
     * Devuelve la velocidad actual en milisegundos.
     * @returns {number}
     */
    getSpeed() {
        return this._speedSlider ? parseInt(this._speedSlider.value, 10) : 500;
    }

    /**
     * Actualiza el estado visual del botón de reproducción.
     * @param {boolean} isPlaying
     */
    setPlayingState(isPlaying) {
        this._isPlaying = isPlaying;
        if (!this._btnPlay) return;

        this._btnPlay.classList.toggle('active', isPlaying);
        const icon = this._btnPlay.querySelector('i');
        if (icon) {
            icon.className = isPlaying ? 'fas fa-pause' : 'fas fa-play';
        }
    }
}
