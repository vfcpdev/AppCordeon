/**
 * @fileoverview Editor de Secuencias de Acordes para la Cuadrícula (ChordSequenceEditor).
 * Responsable exclusivo de:
 * - Interfaz del Mini-Popover de acordes sobre la cuadrícula
 * - Procesamiento de entradas en texto (comas, acentos, formato)
 * - Previsualización de chips de asignación a cada pulso (#1: G, #2: C...)
 * - Asignación, sustitución o eliminación de acordes en la secuencia
 * Cumple con el principio de responsabilidad única (SRP).
 * @module ui/ChordSequenceEditor
 */

import { formatChordInputString, parseChordNotation, getNoteNamesList } from '../theory/MusicTheory.js';
import { NOTATION_MODES } from '../core/Constants.js';

export class ChordSequenceEditor {
    /**
     * @param {Object} options
     * @param {HTMLElement} options.popover Elemento contenedor del popover
     * @param {HTMLElement} options.title Elemento de título del popover
     * @param {HTMLInputElement} options.input Campo de texto para los acordes
     * @param {HTMLElement} options.feedback Contenedor de previsualización de chips
     * @param {HTMLElement} options.gridWrapper Contenedor relativo de la cuadrícula
     * @param {Function} options.onSave Callback al guardar acordes en la línea de tiempo
     * @param {Function} options.onDelete Callback al eliminar acordes de la secuencia
     * @param {Function} options.onClose Callback al cerrar el editor
     */
    constructor(options) {
        this._popover = options.popover;
        this._title = options.title;
        this._input = options.input;
        this._feedback = options.feedback;
        this._gridWrapper = options.gridWrapper;

        this._onSave = options.onSave || (() => {});
        this._onDelete = options.onDelete || (() => {});
        this._onClose = options.onClose || (() => {});

        this._btnDelete = options.btnDelete;
        this._btnCancel = options.btnCancel;
        this._btnSave = options.btnSave;
        this._btnNext = options.btnNext;
        this._btnClose = options.btnClose;

        this._initEvents();
    }

    /**
     * Inicializa eventos del mini-popover de acordes.
     * @private
     */
    _initEvents() {
        if (this._btnClose) this._btnClose.addEventListener('click', () => this.close());
        if (this._btnCancel) this._btnCancel.addEventListener('click', () => this.close());
        if (this._btnDelete) this._btnDelete.addEventListener('click', () => this._onDelete());
        if (this._btnSave) this._btnSave.addEventListener('click', () => this._onSave(false));
        if (this._btnNext) this._btnNext.addEventListener('click', () => this._onSave(true));

        if (this._input) {
            this._input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this._onSave(e.shiftKey ? false : true);
                } else if (e.key === 'Tab') {
                    e.preventDefault();
                    this._onSave(true);
                } else if (e.key === 'Delete' || e.key === 'Del') {
                    if (!this._input.value) {
                        e.preventDefault();
                        this._onDelete();
                    }
                }
            });

            this._input.addEventListener('input', () => {
                const input = this._input;
                const start = input.selectionStart;
                const end = input.selectionEnd;
                const oldVal = input.value;
                const newVal = formatChordInputString(oldVal);
                if (oldVal !== newVal) {
                    input.value = newVal;
                    if (start !== null && end !== null) {
                        input.setSelectionRange(start, end);
                    }
                }
                this.updateSequenceFeedback(this._currentSequence || []);
            });
        }
    }

    /**
     * Abre el mini-popover para una secuencia de pulsos seleccionada.
     * @param {Array} selectedSequence Lista de pulsos seleccionados
     * @param {HTMLElement} [anchorSlot] Elemento HTML de anclaje visual
     * @param {Array} existingChords Línea de tiempo de acordes existente
     * @param {number} totalBars Cantidad total de compases
     */
    openForSequence(selectedSequence, anchorSlot, existingChords, totalBars = 4) {
        if (!this._popover || !this._gridWrapper || selectedSequence.length === 0) return;

        this._currentSequence = selectedSequence;
        const count = selectedSequence.length;
        const first = selectedSequence[0];
        const last = selectedSequence[count - 1];
        const totalBeats = totalBars * 4;

        if (this._title) {
            if (count === totalBeats && count > 1) {
                this._title.innerHTML = `<i class="fas fa-check-double"></i> Todas (${count})`;
            } else if (count === 1) {
                this._title.innerHTML = `<i class="fas fa-music"></i> #${1} · C${first.barIndex + 1}.P${first.beatIndex + 1}`;
            } else {
                this._title.innerHTML = `<i class="fas fa-list-ol"></i> 1 al ${count}`;
            }
        }

        const currentSymbols = selectedSequence.map(item => {
            const c = (existingChords || []).find(
                ch => ch.startTime <= (item.beatStart + 0.05) && ch.endTime > (item.beatStart + 0.05)
            );
            return c ? c.chordSymbol : '';
        });

        if (this._input && !this._input.value) {
            const nonEmpty = currentSymbols.filter(Boolean);
            if (nonEmpty.length > 0) {
                if (nonEmpty.length === count && currentSymbols.every(s => s === currentSymbols[0])) {
                    this._input.value = currentSymbols[0];
                } else {
                    this._input.value = currentSymbols.filter(Boolean).join(', ');
                }
            }
        }

        this.updateSequenceFeedback(selectedSequence);

        this._popover.style.display = 'flex';
        this._popover.classList.remove('hidden');

        const targetSlot = anchorSlot || last.slot || document.getElementById(`beat-slot-${last.barIndex}-${last.beatIndex}`);
        const wrapper = targetSlot?.closest('.chord-measure-grid-wrapper') || this._gridWrapper;
        if (wrapper && this._popover.parentElement !== wrapper) {
            wrapper.appendChild(this._popover);
        }
        const wrapperRect = wrapper ? wrapper.getBoundingClientRect() : this._gridWrapper.getBoundingClientRect();

        let arrowX = wrapperRect.width / 2;
        if (targetSlot) {
            const slotRect = targetSlot.getBoundingClientRect();
            const slotCenterX = slotRect.left - wrapperRect.left + (slotRect.width / 2);
            arrowX = Math.max(16, Math.min(wrapperRect.width - 16, slotCenterX));
        }

        const top = wrapperRect.height + 6;

        this._popover.style.left = '0px';
        this._popover.style.width = '100%';
        this._popover.style.boxSizing = 'border-box';
        this._popover.style.top = `${Math.round(top)}px`;
        this._popover.style.setProperty('--popover-arrow-x', `${Math.round(arrowX)}px`);

        if (this._input) {
            setTimeout(() => {
                this._input.focus();
                this._input.select();
            }, 30);
        }
    }

    /**
     * Muestra la previsualización en vivo de cómo se asignarán los acordes a cada cuadro en orden.
     * @param {Array} selectedSequence
     */
    updateSequenceFeedback(selectedSequence) {
        if (!this._feedback) return;
        const count = (selectedSequence || []).length;
        if (count === 0) {
            this._feedback.textContent = '';
            return;
        }

        const raw = (this._input ? this._input.value : '').trim();
        if (!raw) {
            this._feedback.innerHTML = `<span style="color:#94a3b8; font-size:0.68rem;">Escribe acordes separados por comas para asignar en orden (1 al ${count}): ej. <code>G, C, D</code></span>`;
            return;
        }

        const tokens = raw.split(',').map(s => s.trim()).filter(s => s.length > 0);
        if (tokens.length === 0) {
            this._feedback.innerHTML = `<span style="color:#94a3b8; font-size:0.68rem;">Escribe acordes separados por comas: ej. <code>G, C, D</code></span>`;
            return;
        }

        const chips = selectedSequence.map((item, idx) => {
            let chordText = '';
            if (tokens.length === 1) {
                chordText = tokens[0];
            } else if (idx < tokens.length) {
                chordText = tokens[idx];
            } else if (tokens.length > 1 && count % tokens.length === 0) {
                chordText = tokens[idx % tokens.length];
            } else {
                chordText = '—';
            }

            const isAssigned = chordText && chordText !== '—';
            return `<span style="display:inline-flex; align-items:center; gap:2px; margin:1px 2px; padding:1px 5px; border-radius:4px; font-size:0.66rem; font-weight:700; background:${isAssigned ? 'rgba(56,189,248,0.18)' : 'rgba(255,255,255,0.05)'}; color:${isAssigned ? '#38bdf8' : '#64748b'}; border:1px solid ${isAssigned ? '#0284c7' : '#334155'};">#${idx + 1}: ${chordText}</span>`;
        }).join('');

        this._feedback.innerHTML = `<div style="display:flex; flex-wrap:wrap; gap:2px; align-items:center;">${chips}</div>`;
    }

    /**
     * Cierra el popover y limpia el texto ingresado.
     */
    close() {
        if (this._popover) {
            this._popover.style.display = 'none';
            this._popover.classList.add('hidden');
        }
        if (this._input) {
            this._input.value = '';
        }
        if (this._feedback) {
            this._feedback.textContent = '';
        }
        this._currentSequence = [];
        this._onClose();
    }

    get rawValue() {
        return (this._input ? this._input.value : '').trim();
    }

    set rawValue(val) {
        if (this._input) this._input.value = val;
    }
}
