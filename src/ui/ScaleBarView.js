/**
 * @fileoverview Vista de Escala Diatónica, Grados y Barra de Transporte (SRP).
 * Gestiona los chips de notas I a VIII y la reproducción secuencial con loop y velocidad.
 * @module ui/ScaleBarView
 */

import { midiToName } from '../theory/MusicTheory.js';
import { NOTATION_MODES } from '../core/Constants.js';

export class ScaleBarView {
    /**
     * @param {Object} elements Referencias a elementos del DOM
     */
    constructor(elements) {
        this._titleEl = elements.titleEl;
        this._gridEl = elements.gridEl;
        this._fixChordCheckbox = elements.fixChordCheckbox;
        this._btnPrev = elements.btnPrev;
        this._btnNext = elements.btnNext;
        this._btnPlay = elements.btnPlay;
        this._btnReset = elements.btnReset;
        this._btnLoop = elements.btnLoop;
        this._loopStartInput = elements.loopStartInput;
        this._loopEndInput = elements.loopEndInput;
        this._speedSlider = elements.speedSlider;
        this._speedLabel = elements.speedLabel;

        this._isPlaying = false;
        this._isLooping = false;
    }

    /**
     * Renderiza la barra con las notas y grados de la escala activa.
     * @param {Array} scaleSteps Lista de pasos de escala de generateMajorScale()
     * @param {number} activeStepIndex Grado seleccionado
     * @param {string} notation
     * @param {number} tuningOffset
     * @param {(stepIndex: number) => void} onStepSelect Callback al hacer clic en un grado
     */
    render(scaleSteps, activeStepIndex, notation = NOTATION_MODES.LATINA, tuningOffset = 0, onStepSelect) {
        if (!scaleSteps || scaleSteps.length === 0) return;

        const rootName = midiToName(scaleSteps[0].midi, notation, true, tuningOffset);
        if (this._titleEl) {
            this._titleEl.innerText = `Escala: ${rootName} Mayor`;
        }

        if (!this._gridEl) return;
        this._gridEl.innerHTML = "";

        scaleSteps.forEach((step, idx) => {
            const chip = document.createElement("div");
            chip.className = `note-chip ${step.isMainTriad ? 'main-triad' : ''} ${idx === activeStepIndex ? 'active-step' : ''}`;
            chip.id = `scale-chip-${idx}`;
            chip.title = `Grado ${step.degreeNumeral}: ${step.degreeName} (${step.quality})`;

            const noteName = midiToName(step.midi, notation, true, tuningOffset);
            chip.innerHTML = `
                <strong>${noteName}</strong>
                <span class="chip-degree">${step.degreeNumeral}</span>
                <span class="chip-chord">${step.quality}</span>
            `;

            chip.addEventListener('click', () => {
                if (onStepSelect) onStepSelect(idx);
            });

            this._gridEl.appendChild(chip);
        });
    }

    /**
     * Actualiza el chip visual activo.
     * @param {number} activeStepIndex
     */
    setActiveStep(activeStepIndex) {
        const chips = this._gridEl.querySelectorAll('.note-chip');
        chips.forEach((c, idx) => {
            c.classList.toggle('active-step', idx === activeStepIndex);
        });
    }

    /**
     * Indica si el modo de acorde fijo está marcado.
     * @returns {boolean}
     */
    isChordMode() {
        return this._fixChordCheckbox ? this._fixChordCheckbox.checked : false;
    }

    /**
     * Configura los listeners de los controles de transporte.
     * @param {Object} handlers
     */
    bindTransportEvents(handlers) {
        if (this._btnPrev) this._btnPrev.addEventListener('click', handlers.onPrev);
        if (this._btnNext) this._btnNext.addEventListener('click', handlers.onNext);
        if (this._btnReset) this._btnReset.addEventListener('click', handlers.onReset);
        if (this._btnPlay) this._btnPlay.addEventListener('click', handlers.onPlay);

        if (this._btnLoop) {
            this._btnLoop.addEventListener('click', () => {
                this._isLooping = !this._isLooping;
                this._btnLoop.classList.toggle('active', this._isLooping);
                this._btnLoop.innerHTML = this._isLooping
                    ? '<i class="fas fa-sync-alt"></i> Loop: ON'
                    : '<i class="fas fa-sync-alt"></i> Loop: OFF';
                if (handlers.onLoopToggle) handlers.onLoopToggle(this._isLooping);
            });
        }

        if (this._speedSlider) {
            this._speedSlider.addEventListener('input', (e) => {
                const val = e.target.value;
                if (this._speedLabel) this._speedLabel.innerText = `${val} ms`;
                if (handlers.onSpeedChange) handlers.onSpeedChange(parseInt(val));
            });
        }
    }

    /**
     * Actualiza el estado visual del botón Play/Stop.
     * @param {boolean} isPlaying
     */
    setPlayingState(isPlaying) {
        this._isPlaying = isPlaying;
        if (!this._btnPlay) return;

        this._btnPlay.classList.toggle('playing', isPlaying);
        this._btnPlay.innerHTML = isPlaying
            ? '<i class="fas fa-stop"></i>'
            : '<i class="fas fa-play"></i>';
    }

    /**
     * Retorna el rango de loop configurado [inicio (0-indexed), fin (1-indexed)].
     * @returns {{ start: number, end: number }}
     */
    getLoopRange() {
        const start = this._loopStartInput ? Math.max(0, parseInt(this._loopStartInput.value) - 1) : 0;
        const end = this._loopEndInput ? Math.min(8, parseInt(this._loopEndInput.value)) : 8;
        return { start, end };
    }

    /**
     * Retorna el tempo en ms configurado.
     * @returns {number}
     */
    getSpeed() {
        return this._speedSlider ? parseInt(this._speedSlider.value) : 350;
    }
}
