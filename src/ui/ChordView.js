/**
 * @fileoverview Vista del Selector de Acordes Libres, Arpegios y Factibilidad (SRP).
 * Gestiona el panel de selección de acordes, las notas del arpegio y los controles de fijado.
 * @module ui/ChordView
 */

import { getNoteNamesList, midiToName, getSpellingForScale } from '../theory/MusicTheory.js';
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
        this._octaveButtons = elements.octaveButtons || null;
        this._currentOctave = this._octaveSelect ? this._octaveSelect.value : 'all';
        this._notesDisplay = elements.notesDisplay;
        this._feasibilityBadge = elements.feasibilityBadge;
        this._strip = elements.strip;
        this._btnPlay = elements.btnPlay;
        this._btnArpeggio = elements.btnArpeggio;
        this._btnPrevNote = elements.btnPrevNote;
        this._btnNextNote = elements.btnNextNote;
        this._btnClear = elements.btnClear;
        this._chkFixChord = elements.chkFixChord;
        this._bellowsButtons = elements.bellowsButtons;
        this._currentBellowsMode = 'both';

        // Modo Armónico / Melódico en Acorde Libre
        this._modeButtons = elements.modeButtons;
        this._currentExecutionMode = 'harmonic'; // 'harmonic' | 'melodic'

        // Escala Generada del Acorde
        this._scaleHarmonicButtons = elements.scaleHarmonicButtons || null;
        this._scaleNameLabel = elements.scaleNameLabel;
        this._scaleGrid = elements.scaleGrid;
        this._btnSyncScale = elements.btnSyncScale;
        this._currentChordScaleSteps = [];
        this._activeScaleDegree = -1;
        this._scaleHarmonicMode = 'triad'; // 'triad' | 'seventh'

        this._currentStepIndex = -1;
        this._isArpeggioPlaying = false;
        this._onScaleDegreeClick = null;
    }

    get scaleHarmonicMode() {
        return this._scaleHarmonicMode;
    }

    set scaleHarmonicMode(mode) {
        this._scaleHarmonicMode = mode;
    }

    /**
     * Indica si el modo armónico está activo en el acorde libre.
     * @returns {boolean}
     */
    isHarmonicMode() {
        return this._currentExecutionMode === 'harmonic';
    }

    /**
     * Establece el modo de ejecución ('harmonic' o 'melodic').
     * @param {'harmonic'|'melodic'} mode
     */
    setExecutionMode(mode) {
        this._currentExecutionMode = mode;
        if (this._modeButtons) {
            this._modeButtons.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.mode === mode);
            });
        }
    }

    /**
     * Modo de fuelle actual en el selector de acorde libre ('both', 'push', 'pull').
     * @returns {string}
     */
    get bellowsMode() {
        return this._currentBellowsMode;
    }

    /**
     * Establece el modo de fuelle para el acorde libre.
     * @param {'both'|'push'|'pull'} mode
     */
    setBellowsMode(mode) {
        this._currentBellowsMode = mode;
        if (this._bellowsButtons) {
            this._bellowsButtons.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.mode === mode);
            });
        }
    }

    /**
     * Establece la octava seleccionada ('all', '3', '4', '5').
     * @param {string} octave
     */
    setOctave(octave) {
        this._currentOctave = String(octave);
        if (this._octaveSelect) {
            this._octaveSelect.value = String(octave);
        }
        if (this._octaveButtons) {
            this._octaveButtons.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.octave === String(octave));
            });
        }
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
        const octaveVal = this._currentOctave || (this._octaveSelect ? this._octaveSelect.value : 'all');

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
            this._notesDisplay.innerHTML = `<i class="fas fa-layer-group" style="font-size:0.68rem;margin-right:4px;"></i> Notas: <strong style="color:#0f172a;">${noteNamesText}</strong>`;
        }

        const feasibility = FeasibilityAnalysisStrategy.check(chordData, accordionData, bellowsMode);
        if (this._feasibilityBadge && feasibility) {
            this._feasibilityBadge.className = `bellows-feasibility-badge ${feasibility.cssClass}`;
            this._feasibilityBadge.innerHTML = `${feasibility.icon} <span>${feasibility.label}</span>`;
            this._feasibilityBadge.title = feasibility.description;
        }

        this.renderStrip(chordData, feasibility, notation, tuningOffset);
        this._renderChordScale(chordData, notation, tuningOffset);
    }

    /**
     * Renderiza la escala generada a partir del acorde seleccionado (grados I a VII).
     * @private
     */
    _renderChordScale(chordData, notation, tuningOffset) {
        if (!this._scaleGrid) return;
        this._scaleGrid.innerHTML = "";

        const noteNames = getNoteNamesList(notation, tuningOffset);
        const isMinor = chordData.type === 'min';
        const isDim = chordData.type === 'dim';

        // Escala diatónica correspondiente al tipo de acorde
        let scaleIntervals, numerals, triadQualities;
        let scaleTitle = '';

        if (isMinor) {
            scaleIntervals = [0, 2, 3, 5, 7, 8, 10]; // Menor Natural
            numerals = ['i', 'ii°', 'III', 'iv', 'v', 'VI', 'VII'];
            triadQualities = ['min', 'dim', 'maj', 'min', 'min', 'maj', 'maj'];
            scaleTitle = 'Menor Natural';
        } else if (isDim) {
            scaleIntervals = [0, 2, 3, 5, 6, 8, 9]; // Disminuida
            numerals = ['i°', 'ii', 'bIII', 'iv', 'bV', 'bVI', 'vi'];
            triadQualities = ['dim', 'min', 'maj', 'min', 'dim', 'maj', 'min'];
            scaleTitle = 'Disminuida';
        } else {
            scaleIntervals = [0, 2, 4, 5, 7, 9, 11]; // Mayor
            numerals = ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'];
            triadQualities = ['maj', 'min', 'min', 'maj', 'maj', 'min', 'dim'];
            scaleTitle = 'Mayor';
        }

        const rootName = noteNames[chordData.root];
        if (this._scaleNameLabel) {
            this._scaleNameLabel.innerText = `Escala del Acorde: ${rootName} ${scaleTitle}`;
        }

        const scaleTypeForSpelling = isMinor ? 'minor' : (isDim ? 'minor' : 'major');
        const spelledNotes = getSpellingForScale(chordData.root, scaleTypeForSpelling, notation, tuningOffset);
        const isSeventhMode = this._scaleHarmonicMode === 'seventh';

        // Mapeo riguroso de cuatríadas / séptimas según teoría musical diatónica
        const seventhQualitiesMajor = ['maj7', 'm7', 'm7', 'maj7', '7', 'm7', 'm7b5'];
        const seventhNumeralsMajor = ['Imaj7', 'ii7', 'iii7', 'IVmaj7', 'V7', 'vi7', 'viiø7'];
        const seventhIntervalsMap = {
            'maj7': [0, 4, 7, 11],
            'm7': [0, 3, 7, 10],
            '7': [0, 4, 7, 10],
            'm7b5': [0, 3, 6, 10]
        };

        this._currentChordScaleSteps = scaleIntervals.map((interval, i) => {
            const pitchClass = (chordData.root + interval) % 12;
            let quality = triadQualities[i];
            let numeral = numerals[i];
            let chordIntervals = quality === 'min' ? [0, 3, 7] : quality === 'dim' ? [0, 3, 6] : [0, 4, 7];

            if (isSeventhMode && !isMinor && !isDim) {
                quality = seventhQualitiesMajor[i];
                numeral = seventhNumeralsMajor[i];
                chordIntervals = seventhIntervalsMap[quality] || [0, 4, 7];
            }

            const chordPitchClasses = chordIntervals.map(ti => (pitchClass + ti) % 12);
            const baseMidi = 60 + pitchClass;
            const chordPlaybackMidis = chordIntervals.map(ti => baseMidi + ti);
            const noteName = spelledNotes[i] || noteNames[pitchClass];

            return {
                degreeIndex: i,
                numeral,
                pitchClass,
                noteName,
                quality,
                chordPitchClasses,
                chordPlaybackMidis,
                chordName: `${noteName} ${quality === 'maj' ? 'Mayor' : quality === 'min' ? 'Menor' : quality === 'dim' ? 'Dism.' : quality}`
            };
        });

        this._currentChordScaleSteps.forEach((step, idx) => {
            const chip = document.createElement('div');
            chip.className = 'scale-step-chip chord-scale-chip';
            if (idx === this._activeScaleDegree) {
                chip.classList.add('active-step');
            }

            chip.innerHTML = `
                <span class="chip-degree" style="font-size:0.60rem;font-weight:800;color:#64748b;">${step.numeral}</span>
                <strong style="font-size:0.75rem;font-weight:900;color:#0f172a;line-height:1.1;">${step.noteName}</strong>
                <span style="font-size:0.58rem;font-weight:700;color:#059669;margin-top:2px;">${step.quality === 'maj' ? 'Mayor' : step.quality === 'min' ? 'Menor' : 'Dism.'}</span>
            `;

            chip.addEventListener('click', (e) => {
                e.stopPropagation();
                this._activeScaleDegree = idx;
                const chips = this._scaleGrid.querySelectorAll('.chord-scale-chip');
                chips.forEach((c, i) => c.classList.toggle('active-step', i === idx));

                if (this._onScaleDegreeClick) {
                    this._onScaleDegreeClick(step, this.isHarmonicMode());
                }
            });

            this._scaleGrid.appendChild(chip);
        });
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

            chip.innerHTML = `
                <strong class="chord-chip-note">${noteName}</strong>
                <span class="chord-role">${roleName}</span>
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

        if (this._octaveButtons) {
            this._octaveButtons.forEach(btn => {
                btn.addEventListener('click', () => {
                    const oct = btn.dataset.octave || 'all';
                    this.setOctave(oct);
                    notifyChange();
                });
            });
        }

        if (this._bellowsButtons) {
            this._bellowsButtons.forEach(btn => {
                btn.addEventListener('click', () => {
                    this.setBellowsMode(btn.dataset.mode);
                    notifyChange();
                    if (handlers.onBellowsChange) handlers.onBellowsChange(btn.dataset.mode);
                });
            });
        }

        if (this._modeButtons) {
            this._modeButtons.forEach(btn => {
                btn.addEventListener('click', () => {
                    this.setExecutionMode(btn.dataset.mode);
                    if (handlers.onExecutionModeChange) handlers.onExecutionModeChange(btn.dataset.mode);
                });
            });
        }

        if (this._scaleHarmonicButtons) {
            this._scaleHarmonicButtons.forEach(btn => {
                btn.addEventListener('click', () => {
                    this._scaleHarmonicButtons.forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    this._scaleHarmonicMode = btn.dataset.harmonicMode || 'triad';
                    notifyChange();
                    if (handlers.onHarmonicModeChange) {
                        handlers.onHarmonicModeChange(this._scaleHarmonicMode);
                    }
                });
            });
        }

        if (this._btnSyncScale) {
            this._btnSyncScale.addEventListener('click', () => {
                const chord = this.getSelectedChordData();
                const isMinor = chord.type === 'min';
                if (handlers.onSyncToScale) {
                    handlers.onSyncToScale({
                        root: chord.root,
                        scaleType: isMinor ? 'minor' : 'major'
                    });
                }
            });
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
     * Registra callback para cuando el usuario hace clic en un grado de la escala del acorde.
     * @param {(stepData: Object, isHarmonic: boolean) => void} fn
     */
    onScaleDegreeClick(fn) {
        this._onScaleDegreeClick = fn;
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
