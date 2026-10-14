/**
 * @fileoverview Vista del Selector de Acordes Libres, Arpegios y Factibilidad (SRP).
 * Gestiona el panel de selección de acordes, las notas del arpegio y los controles de fijado.
 * @module ui/ChordView
 */

import { getNoteNamesList, midiToName } from '../theory/MusicTheory.js';
import { NOTATION_MODES } from '../core/Constants.js';
import { FeasibilityAnalysisStrategy } from '../strategies/FeasibilityAnalysisStrategy.js';

export class ChordView {
    /**
     * @param {Object} elements Referencias DOM
     */
    constructor(elements) {
        this._rootSelect = elements.rootSelect;
        this._typeSelect = elements.typeSelect;
        this._fourthSelect = elements.fourthSelect;
        this._octaveSelect = elements.octaveSelect;
        this._notesDisplay = elements.notesDisplay;
        this._feasibilityBadge = elements.feasibilityBadge;
        this._strip = elements.strip;
        this._btnPlay = elements.btnPlay;
        this._btnArpeggio = elements.btnArpeggio;
        this._btnPrevNote = elements.btnPrevNote;
        this._btnNextNote = elements.btnNextNote;
        this._btnClear = elements.btnClear;
        this._chkFixChord = elements.chkFixChord;

        this._currentStepIndex = -1;
        this._isArpeggioPlaying = false;
    }

    /**
     * Llena el combobox de tónicas con los nombres según la afinación y notación actual.
     * @param {string} notation
     * @param {number} tuningOffset
     */
    populateRoots(notation = NOTATION_MODES.LATINA, tuningOffset = 0) {
        if (!this._rootSelect) return;
        const prevVal = this._rootSelect.value;
        this._rootSelect.innerHTML = "";

        const noteNames = getNoteNamesList(notation, tuningOffset);
        noteNames.forEach((n, i) => {
            const opt = document.createElement('option');
            opt.value = i;
            opt.innerText = n;
            if (prevVal !== "" && parseInt(prevVal) === i) {
                opt.selected = true;
            } else if (prevVal === "" && i === 0) {
                opt.selected = true;
            }
            this._rootSelect.appendChild(opt);
        });
    }

    /**
     * Calcula la estructura y notas del acorde actualmente seleccionado en los desplegables.
     * @returns {Object}
     */
    getSelectedChordData() {
        const root = parseInt(this._rootSelect ? this._rootSelect.value : "0") || 0;
        const type = this._typeSelect ? this._typeSelect.value : 'maj';
        const fourth = this._fourthSelect ? this._fourthSelect.value : 'none';
        const octaveVal = this._octaveSelect ? this._octaveSelect.value : 'all';

        let baseIntervals = [0, 4, 7];
        let baseRoles = ['Tónica', '3ra Mayor', '5ta Justa'];
        let typeName = 'Mayor';

        if (type === 'min') {
            baseIntervals = [0, 3, 7];
            baseRoles = ['Tónica', '3ra Menor', '5ta Justa'];
            typeName = 'Menor';
        } else if (type === 'dim') {
            baseIntervals = [0, 3, 6];
            baseRoles = ['Tónica', '3ra Menor', '5ta Dism.'];
            typeName = 'Disminuido';
        } else if (type === 'aug') {
            baseIntervals = [0, 4, 8];
            baseRoles = ['Tónica', '3ra Mayor', '5ta Aum.'];
            typeName = 'Aumentado';
        } else if (type === 'sus4') {
            baseIntervals = [0, 5, 7];
            baseRoles = ['Tónica', '4ta Justa', '5ta Justa'];
            typeName = 'Sus4';
        }

        const intervals = [...baseIntervals];
        const roles = [...baseRoles];
        let fourthLabel = '';

        if (fourth === 'octave') {
            intervals.push(12);
            roles.push('+8va');
            fourthLabel = ' (+8va)';
        } else if (fourth === 'dom7') {
            intervals.push(10);
            roles.push('+7ma Menor');
            fourthLabel = ' 7';
        } else if (fourth === 'maj7') {
            intervals.push(11);
            roles.push('+7ma Mayor');
            fourthLabel = ' Maj7';
        } else if (fourth === 'maj6') {
            intervals.push(9);
            roles.push('+6ta');
            fourthLabel = ' 6';
        } else if (fourth === 'add9') {
            intervals.push(14);
            roles.push('+9na');
            fourthLabel = ' (Add9)';
        }

        const noteMods = intervals.map(i => ((root + i) % 12 + 12) % 12);

        let isExactMidi = false;
        let targetNotes = [];
        let playbackMidis = [];

        if (octaveVal === 'all') {
            isExactMidi = false;
            targetNotes = noteMods;
            playbackMidis = intervals.map(i => 60 + root + i);
        } else {
            isExactMidi = true;
            const baseMidi = (parseInt(octaveVal) + 1) * 12 + root;
            targetNotes = intervals.map(i => baseMidi + i);
            playbackMidis = targetNotes;
        }

        return {
            root,
            type,
            fourth,
            typeName: typeName + fourthLabel,
            octaveVal,
            intervals,
            roles,
            noteMods,
            isExactMidi,
            targetNotes,
            playbackMidis
        };
    }

    /**
     * Renderiza el resumen de notas del acorde y actualiza el badge de factibilidad.
     * @param {Object} chordData
     * @param {Object} accordionData
     * @param {string} bellowsMode
     * @param {string} notation
     * @param {number} tuningOffset
     */
    updateDisplay(chordData, accordionData, bellowsMode, notation, tuningOffset) {
        if (!chordData) return;

        const noteNames = getNoteNamesList(notation, tuningOffset);
        let noteNamesText;
        if (chordData.isExactMidi) {
            noteNamesText = chordData.playbackMidis.map(m => midiToName(m, notation, false, tuningOffset)).join(' · ');
        } else {
            noteNamesText = chordData.noteMods.map(m => noteNames[m]).join(' · ');
        }

        if (this._notesDisplay) {
            this._notesDisplay.innerHTML = `<i class="fas fa-layer-group" style="font-size:0.68rem;margin-right:4px;"></i> Notas: <strong style="color:#ffffff;">${noteNamesText}</strong>`;
        }

        const feasibility = FeasibilityAnalysisStrategy.check(chordData, accordionData, bellowsMode);
        if (this._feasibilityBadge && feasibility) {
            this._feasibilityBadge.className = `bellows-feasibility-badge ${feasibility.cssClass}`;
            this._feasibilityBadge.innerHTML = `${feasibility.icon} <span>${feasibility.label}</span>`;
            this._feasibilityBadge.title = feasibility.description;
        }

        this.renderStrip(chordData, feasibility, notation, tuningOffset);
    }

    /**
     * Renderiza los chips interactivos de las notas del acorde (arpegio).
     * @param {Object} chordData
     * @param {Object} feasibility
     * @param {string} notation
     * @param {number} tuningOffset
     */
    renderStrip(chordData, feasibility, notation, tuningOffset) {
        if (!this._strip) return;
        this._strip.innerHTML = "";

        const noteNames = getNoteNamesList(notation, tuningOffset);

        chordData.intervals.forEach((interval, idx) => {
            const chip = document.createElement('div');
            chip.className = 'chord-step-chip';
            if (idx === this._currentStepIndex) {
                chip.classList.add('active-chord-step');
            }

            const noteMod = ((chordData.root + interval) % 12 + 12) % 12;
            const noteName = chordData.isExactMidi
                ? midiToName(chordData.playbackMidis[idx], notation, false, tuningOffset)
                : noteNames[noteMod];

            const roleName = chordData.roles[idx] || '';

            const noteFeat = feasibility ? feasibility.noteDetails[idx] : null;
            let bellowsBadge = '';
            if (noteFeat) {
                if (noteFeat.canPush && noteFeat.canPull) {
                    bellowsBadge = '<span class="note-bellows-dir both">Abrir/Cerrar</span>';
                } else if (noteFeat.canPush) {
                    bellowsBadge = '<span class="note-bellows-dir push">Cerrar</span>';
                } else if (noteFeat.canPull) {
                    bellowsBadge = '<span class="note-bellows-dir pull">Abrir</span>';
                } else {
                    bellowsBadge = '<span class="note-bellows-dir none">Falta</span>';
                }
            }

            chip.innerHTML = `
                <strong>${noteName}</strong>
                <span class="chord-role">${roleName}</span>
                ${bellowsBadge}
            `;

            chip.addEventListener('click', (e) => {
                e.stopPropagation();
                if (this._onNoteClick) this._onNoteClick(idx);
            });

            this._strip.appendChild(chip);
        });
    }

    /**
     * Actualiza el chip de la nota activa en el arpegio.
     * @param {number} idx
     */
    setActiveStep(idx) {
        this._currentStepIndex = idx;
        if (!this._strip) return;
        const chips = this._strip.querySelectorAll('.chord-step-chip');
        chips.forEach((c, i) => {
            c.classList.toggle('active-chord-step', i === idx);
        });
    }

    /**
     * Asigna callback para cuando se hace clic en una nota del arpegio.
     * @param {(idx: number) => void} fn
     */
    onNoteClick(fn) {
        this._onNoteClick = fn;
    }

    /**
     * Vincula eventos de cambio en desplegables y botones de acorde.
     * @param {Object} handlers
     */
    bindEvents(handlers) {
        const notifyChange = () => {
            this._currentStepIndex = -1;
            if (handlers.onChange) handlers.onChange();
        };

        if (this._rootSelect) {
            this._rootSelect.addEventListener('change', notifyChange);
            this._rootSelect.addEventListener('input', notifyChange);
        }
        if (this._typeSelect) {
            this._typeSelect.addEventListener('change', notifyChange);
            this._typeSelect.addEventListener('input', notifyChange);
        }
        if (this._fourthSelect) {
            this._fourthSelect.addEventListener('change', notifyChange);
            this._fourthSelect.addEventListener('input', notifyChange);
        }
        if (this._octaveSelect) {
            this._octaveSelect.addEventListener('change', notifyChange);
            this._octaveSelect.addEventListener('input', notifyChange);
        }

        if (this._btnPlay) this._btnPlay.addEventListener('click', handlers.onPlayChord);
        if (this._btnArpeggio) this._btnArpeggio.addEventListener('click', handlers.onArpeggio);
        if (this._btnPrevNote) this._btnPrevNote.addEventListener('click', handlers.onPrevNote);
        if (this._btnNextNote) this._btnNextNote.addEventListener('click', handlers.onNextNote);
        if (this._btnClear) this._btnClear.addEventListener('click', handlers.onClear);

        if (this._chkFixChord) {
            this._chkFixChord.addEventListener('change', (e) => {
                if (handlers.onPinChange) handlers.onPinChange(e.target.checked);
            });
        }
    }

    /**
     * @returns {boolean}
     */
    isChordPinned() {
        return this._chkFixChord ? this._chkFixChord.checked : false;
    }

    /**
     * Desmarca visualmente el acorde fijo.
     */
    unpin() {
        if (this._chkFixChord) this._chkFixChord.checked = false;
        if (this._btnClear) this._btnClear.style.display = 'none';
    }

    /**
     * Muestra el botón de limpiar acorde.
     */
    showClearButton() {
        if (this._btnClear) this._btnClear.style.display = 'inline-flex';
    }

    /**
     * Cambia el estado visual del botón de arpegio.
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
            : 'linear-gradient(135deg, #10b981, #059669)';
    }

    get isArpeggioPlaying() {
        return this._isArpeggioPlaying;
    }
}
