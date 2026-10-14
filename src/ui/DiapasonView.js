/**
 * @fileoverview Vista del Diapasón (Single Responsibility Principle).
 * Gestiona el renderizado y actualización visual de los 31 botones del acordeón.
 * @module ui/DiapasonView
 */

import { ButtonFactory } from './ButtonFactory.js';
import { ROW_NAMES, ROW_HEADER_LABELS, ROW_BASE_TONICS, BELLOWS_MODES, NOTATION_MODES } from '../core/Constants.js';
import { midiToName, getPitchClass } from '../theory/MusicTheory.js';

export class DiapasonView {
    /**
     * @param {HTMLElement} containerElement Elemento contenedor del diapasón (#diapason)
     * @param {string} [idPrefix=''] Prefijo opcional para los IDs de los botones del diapasón
     */
    constructor(containerElement, idPrefix = '') {
        if (!containerElement) {
            throw new Error('[DiapasonView] Se requiere un elemento contenedor válido.');
        }
        this._container = containerElement;
        this._idPrefix = idPrefix;
        this._isMirrored = false;
    }

    /**
     * Obtiene el estado actual del modo espejo.
     * @returns {boolean}
     */
    get isMirrored() {
        return this._isMirrored;
    }

    /**
     * Establece el modo espejo (intercambiar hileras 1 y 3).
     * @param {boolean} value
     */
    setMirrored(value) {
        this._isMirrored = Boolean(value);
        if (this._container) {
            this._container.classList.toggle('diapason--mirrored', this._isMirrored);
        }
    }

    /**
     * Alterna el modo espejo.
     * @returns {boolean} Nuevo estado
     */
    toggleMirrored() {
        this.setMirrored(!this._isMirrored);
        return this._isMirrored;
    }

    /**
     * Renderiza las 3 hileras de botones en el diapasón.
     * Normal: Hilera 3 (Adentro) a la izquierda, Hilera 2 (Medio) al centro, Hilera 1 (Afuera) a la derecha.
     * Espejo: Hilera 1 (Afuera) a la izquierda, Hilera 2 (Medio) al centro, Hilera 3 (Adentro) a la derecha.
     *
     * @param {Object} accordionData Objeto con las 3 hileras { row1, row2, row3 }
     * @param {string} activeRowKey Clave de la hilera activa ('row1', 'row2', 'row3')
     * @param {string} bellowsMode Modo de fuelle ('both', 'push', 'pull')
     * @param {string} notation Modo de notación ('latina', 'alemana')
     * @param {number} tuningOffset Desplazamiento de afinación
     * @param {Object} handlers Callbacks { onRowHeaderClick, onButtonClick, onButtonRightClick }
     */
    render(accordionData, activeRowKey, bellowsMode, notation, tuningOffset, handlers = {}) {
        this._container.innerHTML = "";
        this._container.classList.toggle('diapason--mirrored', this._isMirrored);

        const displayOrder = this._isMirrored ? ['row1', 'row2', 'row3'] : ['row3', 'row2', 'row1'];

        displayOrder.forEach(rowKey => {
            const col = document.createElement("div");
            col.className = `row-col row-col--${rowKey} ${rowKey}`;

            // Cabecera interactiva de la hilera
            const rowTonicMidi = ROW_BASE_TONICS[rowKey] + tuningOffset;
            const rootName = midiToName(rowTonicMidi, notation, true, tuningOffset);

            const header = document.createElement("div");
            header.className = `row-header ${rowKey === activeRowKey ? 'active-header' : ''}`;
            header.innerText = `${ROW_HEADER_LABELS[rowKey]}\n(${rootName})`;
            header.title = `Seleccionar escala de ${ROW_NAMES[rowKey]} (${rootName})`;

            if (handlers.onRowHeaderClick) {
                header.addEventListener('click', () => {
                    handlers.onRowHeaderClick(rowKey, rowTonicMidi, header);
                });
            }
            col.appendChild(header);

            // Generar botones con ButtonFactory
            if (accordionData[rowKey]) {
                accordionData[rowKey].forEach(buttonData => {
                    const btn = ButtonFactory.createButton(
                        buttonData,
                        bellowsMode,
                        notation,
                        tuningOffset,
                        {
                            onClick: handlers.onButtonClick,
                            onRightClick: handlers.onButtonRightClick,
                            idPrefix: this._idPrefix
                        }
                    );
                    col.appendChild(btn);
                });
            }

            this._container.appendChild(col);
        });
    }

    /**
     * Limpia todas las clases de resaltado y estados visuales de los botones.
     */
    clearHighlights() {
        const buttons = this._container.querySelectorAll('.btn-accordion');
        buttons.forEach(btn => {
            btn.classList.remove('push', 'pull', 'both', 'single-focus', 'chord-glow', 'detector-selected');
        });

        // Limpiar micro-resaltados en las notas textuales internas
        this._container.querySelectorAll('.btn-note-push, .btn-note-pull, .btn-note-single').forEach(el => {
            el.classList.remove('note-matched', 'note-dimmed');
        });

        // Limpiar etiquetas flotantes de fuelle (Abre/Cierra)
        this._container.querySelectorAll('.bellows-action-pill').forEach(el => el.remove());
    }

    /**
     * Muestra una etiqueta flotante sobre el botón con las palabras "Abre" o "Cierra" al sonar.
     * @param {HTMLElement} btnEl
     * @param {'push'|'pull'|'both'} direction
     * @param {number} [duration=650]
     */
    showActionBadge(btnEl, direction, duration = 650) {
        if (!btnEl) return;

        // Remover badge previo si existiese
        const prev = btnEl.querySelector('.bellows-action-pill');
        if (prev) prev.remove();

        const badge = document.createElement('span');
        const isPull = direction === 'pull';
        badge.className = `bellows-action-pill ${isPull ? 'abre' : 'cierra'}`;
        badge.innerText = isPull ? 'Abre' : 'Cierra';

        btnEl.appendChild(badge);

        if (btnEl._badgeTimer) clearTimeout(btnEl._badgeTimer);
        btnEl._badgeTimer = setTimeout(() => {
            badge.remove();
            btnEl._badgeTimer = null;
        }, duration);
    }

    /**
     * Resalta un único botón enfocado (por ejemplo en el paso activo de una escala o nota de arpegio).
     * @param {string} btnId
     * @param {string} directionClass 'push' o 'pull'
     */
    highlightSingleButton(btnId, directionClass) {
        this.clearHighlights();
        const btn = this._container.querySelector(`#${this._idPrefix}${btnId}`) || this._container.querySelector(`#${btnId}`);
        if (btn) {
            btn.classList.add(directionClass, 'single-focus');
            const targetNoteEl = directionClass === 'push' ? btn.querySelector('.btn-note-push') : btn.querySelector('.btn-note-pull');
            if (targetNoteEl) targetNoteEl.classList.add('note-matched');
            this.showActionBadge(btn, directionClass, 1200);
        }
    }

    /**
     * Resalta todos los botones que forman un acorde con Glow Verde y micro-resalta la nota exacta.
     * @param {Object} accordionData
     * @param {number[]} targetNotes Lista de notas (pitch classes 0-11 o MIDIs absolutos)
     * @param {boolean} [isExactMidi=false]
     * @param {string} [bellowsMode=BELLOWS_MODES.BOTH]
     */
    highlightChord(accordionData, targetNotes, isExactMidi = false, bellowsMode = BELLOWS_MODES.BOTH, excludedButtons = null) {
        this.clearHighlights();

        ['row3', 'row2', 'row1'].forEach(r => {
            if (!accordionData[r]) return;
            accordionData[r].forEach(b => {
                const btnEl = this._container.querySelector(`#${this._idPrefix}${b.id}`) || this._container.querySelector(`#${b.id}`);
                if (!btnEl) return;

                let isPush = false;
                let isPull = false;

                if (isExactMidi) {
                    isPush = targetNotes.includes(b.push);
                    isPull = targetNotes.includes(b.pull);
                } else {
                    const pMod = getPitchClass(b.push);
                    const plMod = getPitchClass(b.pull);
                    isPush = targetNotes.includes(pMod);
                    isPull = targetNotes.includes(plMod);
                }

                // Excluir botones que hayan sido desactivados en la barra lateral
                if (excludedButtons) {
                    if (excludedButtons.has(b.id)) return;
                    if (excludedButtons.has(`pull_${b.id}`)) isPull = false;
                    if (excludedButtons.has(`push_${b.id}`)) isPush = false;
                }

                // Filtrar estrictamente según el modo de fuelle para evitar falsos brillos
                if (bellowsMode === BELLOWS_MODES.PUSH && !isPush) return;
                if (bellowsMode === BELLOWS_MODES.PULL && !isPull) return;
                if (bellowsMode === BELLOWS_MODES.BOTH && !isPush && !isPull) return;

                // El botón califica para el acorde: agregar resplandor
                btnEl.classList.add('chord-glow');

                const pushNoteEl = btnEl.querySelector('.btn-note-push');
                const pullNoteEl = btnEl.querySelector('.btn-note-pull');
                const singleNoteEl = btnEl.querySelector('.btn-note-single');

                if (bellowsMode === BELLOWS_MODES.BOTH) {
                    if (isPush && isPull) {
                        btnEl.classList.add('both');
                        if (pushNoteEl) pushNoteEl.classList.add('note-matched');
                        if (pullNoteEl) pullNoteEl.classList.add('note-matched');
                    } else if (isPush) {
                        btnEl.classList.add('push');
                        if (pushNoteEl) pushNoteEl.classList.add('note-matched');
                        if (pullNoteEl) pullNoteEl.classList.add('note-dimmed');
                    } else if (isPull) {
                        btnEl.classList.add('pull');
                        if (pullNoteEl) pullNoteEl.classList.add('note-matched');
                        if (pushNoteEl) pushNoteEl.classList.add('note-dimmed');
                    }
                } else if (bellowsMode === BELLOWS_MODES.PUSH && isPush) {
                    btnEl.classList.add('push');
                    if (pushNoteEl) pushNoteEl.classList.add('note-matched');
                    if (pullNoteEl) pullNoteEl.classList.add('note-dimmed');
                    if (singleNoteEl) singleNoteEl.classList.add('note-matched');
                } else if (bellowsMode === BELLOWS_MODES.PULL && isPull) {
                    btnEl.classList.add('pull');
                    if (pullNoteEl) pullNoteEl.classList.add('note-matched');
                    if (pushNoteEl) pushNoteEl.classList.add('note-dimmed');
                    if (singleNoteEl) singleNoteEl.classList.add('note-matched');
                }
            });
        });
    }

    /**
     * Resalta los botones seleccionados manualmente en el modo detector.
     * @param {Array<{ btnId: string, direction: string }>} selectedButtons
     */
    highlightDetectorButtons(selectedButtons) {
        this.clearHighlights();
        selectedButtons.forEach(sel => {
            const btnEl = this._container.querySelector(`#${this._idPrefix}${sel.btnId}`) || this._container.querySelector(`#${sel.btnId}`);
            if (btnEl) {
                btnEl.classList.add('detector-selected', sel.direction);
            }
        });
    }

    /**
     * Dispara la animación de glow acústico momentáneo en los botones correspondientes a una nota MIDI.
     * @param {number|number[]} midi
     */
    triggerGlowByMidi(midi) {
        const noteMods = (Array.isArray(midi) ? midi : [midi]).map(m => getPitchClass(m));
        const buttons = this._container.querySelectorAll('.btn-accordion');

        buttons.forEach(btn => {
            const pMidi = getPitchClass(parseInt(btn.dataset.pushMidi));
            const plMidi = getPitchClass(parseInt(btn.dataset.pullMidi));
            if (noteMods.includes(pMidi) || noteMods.includes(plMidi)) {
                btn.classList.add('glow-active');
                setTimeout(() => btn.classList.remove('glow-active'), 250);
            }
        });
    }

    /**
     * Dispara glow sobre un elemento de botón específico y muestra la acción Abre / Cierra.
     * @param {HTMLElement} btnEl
     * @param {'push'|'pull'|null} [direction=null]
     */
    triggerGlowOnElement(btnEl, direction = null) {
        if (!btnEl) return;
        btnEl.classList.add("glow-active");
        if (direction) {
            this.showActionBadge(btnEl, direction, 700);
        }
        setTimeout(() => btnEl.classList.remove("glow-active"), 250);
    }
}
