/**
 * @fileoverview Controlador de Interacciones Teóricas (TheoryInteractionController).
 * Responsable exclusivo de:
 * - Acordes libres (selección, reproducción, arpegio, retención/pinning, grados armónicos/melódicos)
 * - Detector armónico inteligente (agregado de botones, análisis, arpegio, limpieza)
 * Desacoplado de AppController según el principio SRP.
 * @module controllers/TheoryInteractionController
 */

import { audioEngine } from '../audio/AudioEngine.js';
import { HarmonicAnalysisStrategy } from '../strategies/HarmonicAnalysisStrategy.js';
import { FeasibilityAnalysisStrategy } from '../strategies/FeasibilityAnalysisStrategy.js';
import { getPitchClass, midiToName } from '../theory/MusicTheory.js';
import { BELLOWS_MODES } from '../core/Constants.js';

export class TheoryInteractionController {
    /**
     * @param {Object} options
     * @param {import('../ui/ChordView.js').ChordView} options.chordView
     * @param {import('../ui/DetectorView.js').DetectorView} options.detectorView
     * @param {import('../ui/ExecutionView.js').ExecutionView} options.executionView
     * @param {import('../ui/DiapasonView.js').DiapasonView} options.diapasonView
     * @param {Object} options.appContext Objeto de acceso al estado y callbacks de AppController
     */
    constructor(options) {
        this._chordView = options.chordView;
        this._detectorView = options.detectorView;
        this._executionView = options.executionView;
        this._diapasonView = options.diapasonView;
        this._ctx = options.appContext;

        this._isChordPinned = false;
        this._pinnedChordData = null;
        this._detectorSelectedButtons = [];
    }

    get isChordPinned() {
        return this._isChordPinned;
    }

    get pinnedChordData() {
        return this._pinnedChordData;
    }

    get detectorSelectedButtons() {
        return this._detectorSelectedButtons;
    }

    set detectorSelectedButtons(val) {
        this._detectorSelectedButtons = val;
    }

    /**
     * Resalta y reproduce un acorde libre en el diapasón principal y sincroniza con el secundario.
     * @param {Object} chordData
     * @param {boolean} [shouldPlay=false]
     */
    showFreeChordOnAccordion(chordData, shouldPlay = false) {
        const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._ctx.getBellowsMode();
        const accordionData = this._ctx.getAccordionData();

        this._diapasonView.highlightChord(
            accordionData,
            chordData.targetNotes,
            chordData.isExactMidi,
            bellowsMode
        );

        this._ctx.syncSecondaryDiapason({
            notes: chordData.targetNotes,
            isExactMidi: chordData.isExactMidi,
            bellowsMode
        });

        this._chordView.showClearButton();

        if (shouldPlay) {
            let midisToPlay = chordData.playbackMidis;
            if (bellowsMode === BELLOWS_MODES.PUSH || bellowsMode === BELLOWS_MODES.PULL) {
                const feasibility = FeasibilityAnalysisStrategy.check(chordData, accordionData, bellowsMode);
                if (feasibility) {
                    const availableMidis = [];
                    feasibility.noteDetails.forEach((detail, idx) => {
                        const canPlay = bellowsMode === BELLOWS_MODES.PUSH ? detail.canPush : detail.canPull;
                        if (canPlay) {
                            availableMidis.push(chordData.playbackMidis[idx]);
                        }
                    });
                    if (availableMidis.length > 0) midisToPlay = availableMidis;
                }
            }
            audioEngine.play(midisToPlay);
        }
    }

    /**
     * Desfija el acorde libre activo y restaura el estado de la escala.
     */
    unpinChord() {
        this._isChordPinned = false;
        this._pinnedChordData = null;
        this._chordView.setPinned(false);
        audioEngine.stopAll();
        this._ctx.onChordUnpinned();
    }

    /**
     * Mantiene sonando el acorde fijado (modo bordón/pedal armónico).
     * @param {Object} chordData
     */
    holdChordAudio(chordData) {
        audioEngine.stopAll();
        audioEngine.playSustained(chordData.playbackMidis);
    }

    /**
     * Selecciona y resalta una nota específica dentro del arpegio del acorde libre.
     * @param {number} idx
     * @param {boolean} [shouldPlay=true]
     */
    selectChordNote(idx, shouldPlay = true) {
        const chord = this._chordView.getSelectedChordData();
        if (idx < 0 || idx >= chord.intervals.length) return;

        this._chordView.setActiveStep(idx);
        const pitchClass = chord.targetNotes[idx];
        const midi = chord.playbackMidis[idx];
        const notation = this._ctx.getCurrentNotation();
        const offset = this._ctx.getCurrentOffset();
        const noteName = midiToName(midi, notation, false, offset);
        const role = chord.roles[idx] || `Nota ${idx + 1}`;

        this._executionView.setNoteLabel(`${chord.typeName}: ${noteName} (${role})`);

        const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._ctx.getBellowsMode();
        const forms = this._ctx.calculateExecutionForms(pitchClass, chord.isExactMidi ? midi : false, bellowsMode);

        this._executionView.renderForms(forms, (selectedForm) => {
            this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
            this._ctx.syncSecondaryDiapason({
                notes: [pitchClass],
                isExactMidi: chord.isExactMidi,
                bellowsMode
            });
            audioEngine.play(selectedForm.midi);
        });

        if (forms.length > 0) {
            this._diapasonView.highlightSingleButton(forms[0].btnId, forms[0].directionClass);
            this._ctx.syncSecondaryDiapason({
                notes: [pitchClass],
                isExactMidi: chord.isExactMidi,
                bellowsMode
            });
            if (shouldPlay) audioEngine.play(forms[0].midi);
        }
    }

    /**
     * Reproduce arpegio del acorde libre seleccionado.
     */
    async playChordArpeggio() {
        const chord = this._chordView.getSelectedChordData();
        if (!chord || !chord.intervals.length) return;

        if (this._chordView.isArpeggioPlaying) {
            this._chordView.setArpeggioPlaying(false);
            return;
        }

        this._chordView.setArpeggioPlaying(true);
        for (let i = 0; i < chord.intervals.length; i++) {
            if (!this._chordView.isArpeggioPlaying) break;
            this.selectChordNote(i, true);
            const speed = this._ctx.getSpeed();
            await new Promise(r => setTimeout(r, speed));
        }

        this._chordView.setArpeggioPlaying(false);
        this.showFreeChordOnAccordion(chord, false);
    }

    /**
     * Agrega un botón físico al detector armónico inteligente.
     * @param {string} btnId
     * @param {string} direction
     * @param {number} midi
     */
    handleDetectorButtonClick(btnId, direction, midi) {
        const existingIdx = this._detectorSelectedButtons.findIndex(b => b.btnId === btnId && b.direction === direction);
        if (existingIdx >= 0) {
            this._detectorSelectedButtons.splice(existingIdx, 1);
        } else {
            this._detectorSelectedButtons.push({
                btnId,
                direction,
                midi,
                noteMod: getPitchClass(midi)
            });
            audioEngine.play(midi);
            const btnEl = document.getElementById(btnId);
            if (btnEl) this._diapasonView.triggerGlowOnElement(btnEl);
        }

        this.updateDetectorUI();
    }

    /**
     * Actualiza la tira del detector y calcula el análisis armónico con HarmonicAnalysisStrategy.
     */
    updateDetectorUI() {
        const notation = this._ctx.getCurrentNotation();
        const offset = this._ctx.getCurrentOffset();

        this._detectorView.renderSelectedButtons(
            this._detectorSelectedButtons,
            notation,
            offset,
            {
                onRemove: (idx) => {
                    this._detectorSelectedButtons.splice(idx, 1);
                    this.updateDetectorUI();
                },
                onPlayNote: (b) => {
                    audioEngine.play(b.midi);
                    const btnEl = document.getElementById(b.btnId);
                    if (btnEl) this._diapasonView.triggerGlowOnElement(btnEl);
                }
            }
        );

        const analysis = HarmonicAnalysisStrategy.analyze(
            this._detectorSelectedButtons,
            notation,
            offset
        );

        this._detectorView.renderAnalysisResult(analysis, notation);

        if (this._detectorView.isModeActive) {
            this._diapasonView.highlightDetectorButtons(this._detectorSelectedButtons);
            this._ctx.syncSecondaryDiapason();
        }
    }

    /**
     * Toca todas las notas del acorde detectado juntas.
     */
    playDetectorChord() {
        if (this._detectorSelectedButtons.length === 0) return;
        const midis = this._detectorSelectedButtons.map(b => b.midi);
        audioEngine.play(midis);
    }

    /**
     * Reproduce arpegio de las notas seleccionadas en el detector.
     */
    async playDetectorArpeggio() {
        if (this._detectorSelectedButtons.length === 0) return;

        if (this._detectorView.isArpeggioPlaying) {
            this._detectorView.setArpeggioPlaying(false);
            return;
        }

        this._detectorView.setArpeggioPlaying(true);

        for (let i = 0; i < this._detectorSelectedButtons.length; i++) {
            if (!this._detectorView.isArpeggioPlaying) break;
            const b = this._detectorSelectedButtons[i];
            audioEngine.play(b.midi);
            const btnEl = document.getElementById(b.btnId);
            if (btnEl) this._diapasonView.triggerGlowOnElement(btnEl);

            const speed = this._ctx.getSpeed();
            await new Promise(r => setTimeout(r, speed));
        }

        this._detectorView.setArpeggioPlaying(false);
    }
}
