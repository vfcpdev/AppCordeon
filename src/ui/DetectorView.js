/**
 * @fileoverview Vista del Detector Inteligente de Acordes (SRP).
 * Gestiona la selección manual de botones, el resultado armónico y los controles de análisis.
 * @module ui/DetectorView
 */

import { midiToName } from '../theory/MusicTheory.js';
import { NOTATION_MODES, ROW_NAMES } from '../core/Constants.js';

export class DetectorView {
    /**
     * @param {Object} elements Referencias DOM
     */
    constructor(elements) {
        this._btnToggleMode = elements.btnToggleMode;
        this._lblModeStatus = elements.lblModeStatus;
        this._dirButtons = elements.dirButtons;
        this._lblCount = elements.lblCount;
        this._strip = elements.strip;
        this._btnPlay = elements.btnPlay;
        this._btnArpeggio = elements.btnArpeggio;
        this._btnClear = elements.btnClear;

        // Elementos de la tarjeta de resultado
        this._mainNameEl = elements.mainNameEl;
        this._inversionBadgeEl = elements.inversionBadgeEl;
        this._rootEl = elements.rootEl;
        this._bassEl = elements.bassEl;
        this._formulaEl = elements.formulaEl;
        this._typeEl = elements.typeEl;
        this._altRow = elements.altRow;
        this._altText = elements.altText;

        this._isModeActive = false;
        this._currentDirection = 'auto'; // 'auto', 'push', 'pull'
        this._isArpeggioPlaying = false;
    }

    get isModeActive() {
        return this._isModeActive;
    }

    get currentDirection() {
        return this._currentDirection;
    }

    /**
     * Alterna o establece el modo de detección.
     * @param {boolean} [forceState]
     * @returns {boolean} Nuevo estado
     */
    toggleMode(forceState) {
        this._isModeActive = typeof forceState === 'boolean' ? forceState : !this._isModeActive;

        if (this._btnToggleMode && this._lblModeStatus) {
            if (this._isModeActive) {
                this._btnToggleMode.style.background = '#8b5cf6';
                this._btnToggleMode.style.color = '#ffffff';
                this._btnToggleMode.style.boxShadow = '0 0 14px rgba(139, 92, 246, 0.6)';
                this._lblModeStatus.innerText = 'ON';
            } else {
                this._btnToggleMode.style.background = 'rgba(139, 92, 246, 0.18)';
                this._btnToggleMode.style.color = '#c4b5fd';
                this._btnToggleMode.style.boxShadow = 'none';
                this._lblModeStatus.innerText = 'OFF';
            }
        }

        return this._isModeActive;
    }

    /**
     * Renderiza la tira de botones seleccionados para el análisis.
     * @param {Array} selectedButtons
     * @param {string} notation
     * @param {number} tuningOffset
     * @param {Object} handlers { onRemove, onPlayNote }
     */
    renderSelectedButtons(selectedButtons, notation = NOTATION_MODES.LATINA, tuningOffset = 0, handlers = {}) {
        if (!this._strip) return;
        this._strip.innerHTML = "";

        if (this._lblCount) {
            const count = selectedButtons.length;
            this._lblCount.innerText = `${count} botón${count === 1 ? '' : 'es'} seleccionado${count === 1 ? '' : 's'}`;
        }

        if (selectedButtons.length === 0) {
            this._strip.innerHTML = `<span style="font-size: 0.72rem; color: #94a3b8; font-style: italic;">Haz clic en los botones del diapasón para seleccionarlos...</span>`;
            this.renderAnalysisResult(null, notation);
            return;
        }

        selectedButtons.forEach((b, idx) => {
            const chip = document.createElement('div');
            chip.className = 'chord-step-chip';
            chip.style.borderColor = '#8b5cf6';
            chip.style.background = '#1e1b4b';

            const noteName = midiToName(b.midi, notation, false, tuningOffset);
            const dirBadge = b.direction === 'push' ? 'Cerrar' : 'Abrir';
            const rowName = ROW_NAMES[b.rowKey] || b.rowKey;

            chip.innerHTML = `
                <div style="display: flex; align-items: center; gap: 4px; justify-content: space-between; width: 100%;">
                    <strong style="color: #c4b5fd;">${noteName}</strong>
                    <span class="remove-btn" style="color: #f87171; font-size: 0.78rem; font-weight: 900; cursor: pointer; padding: 0 3px;" title="Quitar">×</span>
                </div>
                <span class="chord-role" style="color: #a78bfa;">${rowName} B${b.btnIndex} (${dirBadge})</span>
            `;

            chip.querySelector('.remove-btn').addEventListener('click', (e) => {
                e.stopPropagation();
                if (handlers.onRemove) handlers.onRemove(idx);
            });

            chip.addEventListener('click', () => {
                if (handlers.onPlayNote) handlers.onPlayNote(b);
            });

            this._strip.appendChild(chip);
        });
    }

    /**
     * Muestra el análisis del acorde (nombre, inversión, bajo real, etc.)
     * @param {Object|null} analysis
     * @param {string} notation
     */
    renderAnalysisResult(analysis, notation = NOTATION_MODES.LATINA) {
        if (!this._mainNameEl) return;

        if (!analysis) {
            this._mainNameEl.innerText = "Selecciona 2 o más botones";
            if (this._inversionBadgeEl) this._inversionBadgeEl.innerText = "-";
            if (this._rootEl) this._rootEl.innerText = "-";
            if (this._bassEl) this._bassEl.innerText = "-";
            if (this._formulaEl) this._formulaEl.innerText = "-";
            if (this._typeEl) this._typeEl.innerText = "-";
            if (this._altRow) this._altRow.style.display = 'none';
            return;
        }

        const chordTitle = notation === NOTATION_MODES.LATINA ? analysis.mainNameLat : analysis.mainNameAle;
        this._mainNameEl.innerText = chordTitle;

        if (this._inversionBadgeEl) this._inversionBadgeEl.innerText = analysis.inversionText;
        if (this._rootEl) this._rootEl.innerText = notation === NOTATION_MODES.LATINA ? analysis.rootNameLat : analysis.rootNameAle;
        if (this._bassEl) this._bassEl.innerText = notation === NOTATION_MODES.LATINA ? analysis.bassNameLat : analysis.bassNameAle;
        if (this._formulaEl) this._formulaEl.innerText = analysis.formula;
        if (this._typeEl) this._typeEl.innerText = `${analysis.family} · ${analysis.bellowsSummary}`;

        if (this._altRow && this._altText) {
            if (analysis.alternatives && analysis.alternatives.length > 0) {
                this._altRow.style.display = 'block';
                this._altText.innerText = analysis.alternatives.join('  ·  ');
            } else {
                this._altRow.style.display = 'none';
            }
        }
    }

    /**
     * Vincula eventos de la sección del detector.
     * @param {Object} handlers
     */
    bindEvents(handlers) {
        if (this._btnToggleMode) {
            this._btnToggleMode.addEventListener('click', handlers.onToggleMode);
        }

        if (this._dirButtons) {
            this._dirButtons.forEach(btn => {
                btn.addEventListener('click', () => {
                    this._dirButtons.forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    this._currentDirection = btn.dataset.dir || 'auto';
                    if (handlers.onDirectionChange) handlers.onDirectionChange(this._currentDirection);
                });
            });
        }

        if (this._btnPlay) this._btnPlay.addEventListener('click', handlers.onPlayChord);
        if (this._btnArpeggio) this._btnArpeggio.addEventListener('click', handlers.onArpeggio);
        if (this._btnClear) this._btnClear.addEventListener('click', handlers.onClear);
    }

    /**
     * Alterna visualmente el estado del botón Arpegio del detector.
     * @param {boolean} isPlaying
     */
    setArpeggioPlaying(isPlaying) {
        this._isArpeggioPlaying = isPlaying;
        if (!this._btnArpeggio) return;

        this._btnArpeggio.innerHTML = isPlaying
            ? '<i class="fas fa-stop"></i> Parar'
            : '<i class="fas fa-music"></i> Arpegio';
        this._btnArpeggio.style.background = isPlaying
            ? '#dc2626'
            : 'linear-gradient(135deg, #8b5cf6, #6d28d9)';
    }

    get isArpeggioPlaying() {
        return this._isArpeggioPlaying;
    }
}
