/**
 * @fileoverview Vista de Escala Diatónica, Grados, Transporte y Tonos Relacionados (SRP).
 * Gestiona los chips de notas I a VIII, la selección libre de tónica (ej: Sol en C-F-Bb)
 * y la paleta armónica de tonos relacionados (Tónica, Dominante, Subdominante, Relativa, Disminuido, etc.).
 * @module ui/ScaleBarView
 */

import { midiToName, getNoteNamesList, getSpellingForScale, getPitchClass } from '../theory/MusicTheory.js';
import { NOTATION_MODES } from '../core/Constants.js';
import { SCALE_DEFINITIONS } from '../theory/Scales.js';

export class ScaleBarView {
    /**
     * @param {Object} elements Referencias a elementos del DOM
     */
    constructor(elements) {
        this._titleEl = elements.titleEl;
        this._gridEl = elements.gridEl;
        this._scaleRootSelect = elements.scaleRootSelect;
        this._scaleTypeSelect = elements.scaleTypeSelect;
        this._relatedChordsStrip = elements.relatedChordsStrip;
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
        this._octaveButtons = elements.octaveButtons;

        this._isPlaying = false;
        this._isLooping = false;
        this._activeRelatedChordId = null;

        // Alternancia de Colapso / Expansión de Acordes Relacionados
        this._btnToggleRelatedCollapse = document.getElementById('btnToggleRelatedCollapse');
        this._lblRelatedCollapse = document.getElementById('lblRelatedCollapse');
        this._iconRelatedCollapse = document.getElementById('iconRelatedCollapse');
        this._isRelatedCollapsed = false;

        if (this._btnToggleRelatedCollapse) {
            this._btnToggleRelatedCollapse.addEventListener('click', () => {
                this._isRelatedCollapsed = !this._isRelatedCollapsed;
                if (this._relatedChordsStrip) {
                    this._relatedChordsStrip.classList.toggle('collapsed', this._isRelatedCollapsed);
                }
                if (this._lblRelatedCollapse) {
                    this._lblRelatedCollapse.textContent = this._isRelatedCollapsed ? 'Expandir' : 'Colapsar';
                }
                if (this._iconRelatedCollapse) {
                    this._iconRelatedCollapse.className = this._isRelatedCollapsed ? 'fas fa-chevron-right' : 'fas fa-chevron-down';
                }
            });
        }
    }

    /**
     * Llena el combobox de tónicas para permitir estudiar cualquier escala independiente (ej: Sol).
     * @param {string} notation
     * @param {number} tuningOffset
     * @param {string|number} selectedVal 'auto' o número de pitch class (0-11)
     */
    populateScaleRoots(notation = NOTATION_MODES.LATINA, tuningOffset = 0, selectedVal = 'auto') {
        if (!this._scaleRootSelect) return;
        this._scaleRootSelect.innerHTML = "";

        const defaultOpt = document.createElement('option');
        defaultOpt.value = 'auto';
        defaultOpt.innerText = "Tónica de Hilera Activa (Auto)";
        if (selectedVal === 'auto') defaultOpt.selected = true;
        this._scaleRootSelect.appendChild(defaultOpt);

        const noteNames = getNoteNamesList(notation, tuningOffset);
        noteNames.forEach((name, i) => {
            const opt = document.createElement('option');
            opt.value = i;
            opt.innerText = `Escala de ${name}`;
            if (selectedVal !== 'auto' && parseInt(selectedVal) === i) {
                opt.selected = true;
            }
            this._scaleRootSelect.appendChild(opt);
        });
    }

    /**
     * Renderiza la barra con las notas y grados de la escala activa.
     * @param {Array} scaleSteps Lista de pasos de escala
     * @param {number} activeStepIndex Grado seleccionado
     * @param {string} scaleType 'major', 'minor', 'harmonic_minor'
     * @param {string} notation
     * @param {number} tuningOffset
     * @param {(stepIndex: number) => void} onStepSelect
     */
    render(scaleSteps, activeStepIndex, scaleType = 'major', notation = NOTATION_MODES.LATINA, tuningOffset = 0, onStepSelect) {
        if (!scaleSteps || scaleSteps.length === 0) return;

        const rootPitchClass = getPitchClass(scaleSteps[0].midi);
        const spelledNotes = getSpellingForScale(rootPitchClass, scaleType, notation, tuningOffset);
        const rootName = spelledNotes[0] || midiToName(scaleSteps[0].midi, notation, true, tuningOffset);
        const typeName = SCALE_DEFINITIONS[scaleType] ? SCALE_DEFINITIONS[scaleType].name : 'Mayor';

        if (this._titleEl) {
            this._titleEl.innerText = `Escala: ${rootName} ${typeName}`;
        }

        if (!this._gridEl) return;
        this._gridEl.innerHTML = "";

        scaleSteps.forEach((step, idx) => {
            const chip = document.createElement("div");
            chip.className = `note-chip ${step.isMainTriad ? 'main-triad' : ''} ${idx === activeStepIndex ? 'active-step' : ''}`;
            chip.id = `scale-chip-${idx}`;
            chip.title = `Grado ${step.degreeNumeral}: ${step.degreeName} (${step.quality})`;

            // Usar deletreo enarmónico exacto si está disponible (ej: Fa# en vez de Solb en G mayor)
            const noteName = (idx === 7 ? spelledNotes[0] : spelledNotes[idx]) || midiToName(step.midi, notation, true, tuningOffset);
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
     * Renderiza la paleta de Tonos Relacionados y Familia Armónica.
     * @param {import('../theory/Scales.js').RelatedChordItem[]} relatedChords
     * @param {(chordItem: Object) => void} onSelectChord
     */
    renderRelatedChords(relatedChords, onSelectChord) {
        if (!this._relatedChordsStrip) return;
        this._relatedChordsStrip.innerHTML = "";

        if (!relatedChords || relatedChords.length === 0) {
            this._relatedChordsStrip.innerHTML = `<span style="font-size:0.72rem; color:#94a3b8; font-style:italic;">No hay tonos relacionados disponibles</span>`;
            return;
        }

        relatedChords.forEach(chord => {
            const chip = document.createElement('button');
            chip.type = 'button';
            chip.className = 'related-chord-chip';
            chip.id = `rel-chord-${chord.id}`;
            chip.style.borderLeftColor = chord.colorBadge;

            if (this._activeRelatedChordId === chord.id) {
                chip.classList.add('active-related-chord');
            }

            chip.innerHTML = `
                <div style="display:flex; justify-content:space-between; align-items:center; width:100%; gap:4px;">
                    <strong>${chord.chordName}</strong>
                    <span style="font-size:0.60rem; color:${chord.colorBadge}; font-weight:800;">${chord.chordSymbol}</span>
                </div>
                <span class="related-chord-role">${chord.roleName}</span>
            `;

            chip.addEventListener('click', () => {
                this._activeRelatedChordId = chord.id;
                const all = this._relatedChordsStrip.querySelectorAll('.related-chord-chip');
                all.forEach(c => c.classList.remove('active-related-chord'));
                chip.classList.add('active-related-chord');

                if (onSelectChord) onSelectChord(chord);
            });

            this._relatedChordsStrip.appendChild(chip);
        });
    }

    /**
     * Desmarca el chip de tono relacionado activo.
     */
    clearActiveRelatedChord() {
        this._activeRelatedChordId = null;
        if (this._relatedChordsStrip) {
            const all = this._relatedChordsStrip.querySelectorAll('.related-chord-chip');
            all.forEach(c => c.classList.remove('active-related-chord'));
        }
    }

    /**
     * Actualiza el chip visual activo en la escala.
     * @param {number} activeStepIndex
     */
    setActiveStep(activeStepIndex) {
        if (!this._gridEl) return;
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
     * Vincula listeners para cambios en la configuración de la escala (tónica independiente y tipo).
     * @param {Object} handlers
     */
    bindScaleConfigEvents(handlers) {
        if (this._scaleRootSelect) {
            this._scaleRootSelect.addEventListener('change', (e) => {
                if (handlers.onRootChange) handlers.onRootChange(e.target.value);
            });
        }
        if (this._scaleTypeSelect) {
            this._scaleTypeSelect.addEventListener('change', (e) => {
                if (handlers.onTypeChange) handlers.onTypeChange(e.target.value);
            });
        }
        if (this._octaveButtons) {
            this._octaveButtons.forEach(btn => {
                btn.addEventListener('click', () => {
                    this._octaveButtons.forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    if (handlers.onOctaveChange) handlers.onOctaveChange(btn.dataset.octave);
                });
            });
        }
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
