/**
 * @fileoverview Controlador Principal de la Aplicación (Dependency Inversion Principle).
 * Coordina las vistas, el estado del fuelle, el motor de audio y las estrategias de análisis
 * mediante el EventBus central.
 * @module controllers/AppController
 */

import { eventBus } from '../core/EventBus.js';
import { BellowsStateMachine } from '../core/StateMachine.js';
import { audioEngine } from '../audio/AudioEngine.js';
import { audioPlayerController } from '../audio/AudioPlayerController.js';
import { AudioChordAnalyzer } from '../audio/AudioChordAnalyzer.js';
import { tuningRegistry } from '../models/Tunings.js';
import { getTransposedAccordion } from '../models/AccordionData.js';
import { generateScale, generateMajorScale, getHarmonicFamilyAndRelatedChords } from '../theory/Scales.js';
import { HarmonicAnalysisStrategy } from '../strategies/HarmonicAnalysisStrategy.js';
import { FeasibilityAnalysisStrategy } from '../strategies/FeasibilityAnalysisStrategy.js';
import { getPitchClass, midiToName } from '../theory/MusicTheory.js';
import {
    ROW_NAMES,
    ROW_BASE_TONICS,
    NOTATION_MODES,
    BELLOWS_MODES,
    DEFAULT_CONFIG
} from '../core/Constants.js';

export class AppController {
    /**
     * @param {Object} views Objeto con las vistas inyectadas
     * @param {import('../ui/DiapasonView.js').DiapasonView} views.diapasonView
     * @param {import('../ui/ScaleBarView.js').ScaleBarView} views.scaleBarView
     * @param {import('../ui/ChordView.js').ChordView} views.chordView
     * @param {import('../ui/DetectorView.js').DetectorView} views.detectorView
     * @param {import('../ui/ExecutionView.js').ExecutionView} views.executionView
     * @param {import('../ui/AudioTrackView.js').AudioTrackView} [views.audioTrackView]
     */
    constructor(views) {
        this._diapasonView = views.diapasonView;
        this._scaleBarView = views.scaleBarView;
        this._chordView = views.chordView;
        this._detectorView = views.detectorView;
        this._executionView = views.executionView;
        this._audioTrackView = views.audioTrackView;

        this._audioChordAnalyzer = new AudioChordAnalyzer();

        // Estado Global
        this._bellowsMachine = new BellowsStateMachine(DEFAULT_CONFIG.bellowsMode);
        this._currentOffset = DEFAULT_CONFIG.tuningOffset;
        this._currentNotation = DEFAULT_CONFIG.notation;
        this._activeRowKey = DEFAULT_CONFIG.defaultRow;
        this._selectedScaleRoot = 'auto'; // 'auto' o pitch class (0-11, ej: 7 para Sol)
        this._selectedScaleType = 'major'; // 'major', 'minor', 'harmonic_minor'
        this._activeScaleRoot = ROW_BASE_TONICS[this._activeRowKey] + this._currentOffset;
        this._currentStepIndex = 0;
        this._accordionData = getTransposedAccordion(this._currentOffset);
        this._scaleSteps = [];

        // Estado de Acorde Libre y Detector
        this._isChordPinned = false;
        this._pinnedChordData = null;
        this._detectorSelectedButtons = [];
        this._isScalePlaying = false;

        // Modo Espejo (Intercambiar Hileras 1 y 3)
        this._isDiapasonMirrored = typeof localStorage !== 'undefined' && localStorage.getItem('acordeon_is_mirrored') === 'true';
        if (this._diapasonView) {
            this._diapasonView.setMirrored(this._isDiapasonMirrored);
        }
    }

    /**
     * Inicializa la aplicación, enlaza eventos y dibuja el estado inicial.
     */
    init() {
        this._setupEventBusListeners();
        this._bindUIEvents();
        this._updateAccordionData();
        this._rebuildScale();

        // Inicializar vistas con datos
        this._chordView.populateRoots(this._currentNotation, this._currentOffset);
        this._updateMirrorButtonUI();
        this._renderAll();
    }

    /**
     * Registra listeners en el EventBus central.
     * @private
     */
    _setupEventBusListeners() {
        eventBus.on('bellows:changed', ({ current }) => {
            this._renderDiapason();
            this._updateFeasibilityAndChordDisplay();
            if (this._scaleSteps.length > 0 && !this._detectorView.isModeActive) {
                this.setStep(this._currentStepIndex, false);
            }
        });

        // Sincronización del Reproductor de Audio MP3
        eventBus.on('player:timeupdate', ({ currentTime, duration, progress }) => {
            if (this._audioTrackView) {
                this._audioTrackView.updateTime(currentTime, duration, progress);
            }
        });

        eventBus.on('player:state_change', ({ isPlaying }) => {
            if (this._audioTrackView) {
                this._audioTrackView.setPlayingState(isPlaying);
            }
        });

        eventBus.on('player:chord_active', ({ chord, index, syncWithDiapason }) => {
            if (this._audioTrackView) {
                this._audioTrackView.setActiveChord(chord, index);
            }
            if (syncWithDiapason && this._audioTrackView && this._audioTrackView.isSyncEnabled()) {
                // Mostrar en el diapasón los botones del acorde detectado en la canción
                this._diapasonView.highlightChord(
                    this._accordionData,
                    chord.noteMods,
                    false,
                    this._bellowsMachine.mode
                );
            }
        });

        eventBus.on('player:ended', () => {
            if (this._scaleSteps.length > 0 && !this._detectorView.isModeActive) {
                this.setStep(this._currentStepIndex, false);
            }
        });
    }

    /**
     * Enlaza eventos de interacción directa de las vistas y controles.
     * @private
     */
    _bindUIEvents() {
        // Selector de Afinación
        const tuningSelect = document.getElementById('tuningSelect');
        if (tuningSelect) {
            tuningSelect.innerHTML = "";
            tuningRegistry.getAll().forEach(t => {
                const opt = document.createElement('option');
                opt.value = t.offset;
                opt.innerText = `${t.name} (${t.rowsDescription})`;
                if (t.offset === this._currentOffset) opt.selected = true;
                tuningSelect.appendChild(opt);
            });

            tuningSelect.addEventListener('change', (e) => {
                this._currentOffset = parseInt(e.target.value);
                this._updateAccordionData();
                this._chordView.populateRoots(this._currentNotation, this._currentOffset);
                this._rebuildScale();
                this._renderAll();
                this._updateDetectorUI();
            });
        }

        // Segmentado de Notación (Latina / Alemana)
        document.querySelectorAll('#notationToggle .segment-btn, .toggle-segmented__btn[data-val]').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('#notationToggle .segment-btn, .toggle-segmented__btn[data-val]').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this._currentNotation = btn.dataset.val;
                this._chordView.populateRoots(this._currentNotation, this._currentOffset);
                this._renderAll();
                this._updateDetectorUI();
            });
        });

        // Botones de Fuelle
        document.querySelectorAll('#bellowsButtonGroup .bellows-btn, .bellows-group .bellows-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('#bellowsButtonGroup .bellows-btn, .bellows-group .bellows-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this._bellowsMachine.setMode(btn.dataset.mode);
            });
        });

        // Color de Fondo
        const bgColorInput = document.getElementById('bgColor');
        if (bgColorInput) {
            bgColorInput.addEventListener('input', (e) => {
                document.body.style.backgroundColor = e.target.value;
            });
        }

        // Modo Espejo del Diapasón (Intercambiar Hileras 1 y 3)
        const btnToggleMirror = document.getElementById('btnToggleMirror');
        if (btnToggleMirror) {
            btnToggleMirror.addEventListener('click', () => {
                this._isDiapasonMirrored = !this._isDiapasonMirrored;
                try {
                    localStorage.setItem('acordeon_is_mirrored', this._isDiapasonMirrored.toString());
                } catch (e) {
                    console.warn('[AppController] No se pudo persistir modo espejo:', e);
                }
                this._diapasonView.setMirrored(this._isDiapasonMirrored);
                this._updateMirrorButtonUI();
                this._renderDiapason();
                this._restoreActiveHighlights();
            });
        }

        // Configuración y Selección de Escala Independiente (ej: Sol en C-F-Bb)
        this._scaleBarView.bindScaleConfigEvents({
            onRootChange: (rootVal) => {
                this._selectedScaleRoot = rootVal;
                this._scaleBarView.clearActiveRelatedChord();
                this._rebuildScale();
                this._renderAll();
            },
            onTypeChange: (typeVal) => {
                this._selectedScaleType = typeVal;
                this._scaleBarView.clearActiveRelatedChord();
                this._rebuildScale();
                this._renderAll();
            }
        });

        // Transporte de Escala
        this._scaleBarView.bindTransportEvents({
            onPrev: () => this.setStep(this._currentStepIndex - 1, true),
            onNext: () => this.setStep(this._currentStepIndex + 1, true),
            onReset: () => this.setStep(0, true),
            onPlay: () => this.playScaleSequence(),
            onSpeedChange: (speed) => eventBus.emit('tempo:change', speed)
        });

        // Vista de Acordes
        this._chordView.bindEvents({
            onChange: () => {
                this._updateFeasibilityAndChordDisplay();
                const chord = this._chordView.getSelectedChordData();
                this._pinnedChordData = chord;
                this._showFreeChordOnAccordion(chord, false);
                if (this._isChordPinned) this._holdChordAudio(chord);

                const rootName = midiToName(chord.playbackMidis[0], this._currentNotation, false, this._currentOffset);
                this._executionView.setNoteLabel(`Acorde Libre: ${chord.typeName} (${rootName})`);
                const forms = this.calculateExecutionForms(chord.root, false);
                this._executionView.renderForms(forms, (selectedForm) => {
                    this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                    audioEngine.play(selectedForm.midi);
                });
            },
            onPlayChord: () => {
                const chord = this._chordView.getSelectedChordData();
                this._showFreeChordOnAccordion(chord, true);
            },
            onArpeggio: () => this.playChordArpeggio(),
            onPrevNote: () => {
                const chord = this._chordView.getSelectedChordData();
                let nextIdx = this._chordView._currentStepIndex - 1;
                if (nextIdx < 0) nextIdx = chord.intervals.length - 1;
                this.selectChordNote(nextIdx, true);
            },
            onNextNote: () => {
                const chord = this._chordView.getSelectedChordData();
                let nextIdx = this._chordView._currentStepIndex + 1;
                if (nextIdx >= chord.intervals.length) nextIdx = 0;
                this.selectChordNote(nextIdx, true);
            },
            onPinChange: (isPinned) => {
                this._isChordPinned = isPinned;
                if (isPinned) {
                    this._pinnedChordData = this._chordView.getSelectedChordData();
                    this._showFreeChordOnAccordion(this._pinnedChordData, false);
                    this._holdChordAudio(this._pinnedChordData);
                } else {
                    this.unpinChord();
                }
            },
            onClear: () => this.unpinChord()
        });

        this._chordView.onNoteClick((idx) => {
            this.selectChordNote(idx, true);
        });

        // Vista de Detector
        this._detectorView.bindEvents({
            onToggleMode: () => {
                const isActive = this._detectorView.toggleMode();
                if (isActive) {
                    if (this._isChordPinned) this.unpinChord();
                    this._diapasonView.highlightDetectorButtons(this._detectorSelectedButtons);
                } else {
                    this.setStep(this._currentStepIndex, false);
                }
            },
            onDirectionChange: (dir) => {
                eventBus.emit('detector:direction_change', dir);
            },
            onPlayChord: () => this.playDetectorChord(),
            onArpeggio: () => this.playDetectorArpeggio(),
            onClear: () => {
                this._detectorSelectedButtons = [];
                this._updateDetectorUI();
            }
        });

        // Vista de Analizador de Audio y Sincronizador de Acordes
        if (this._audioTrackView) {
            this._audioTrackView.bindEvents({
                onFileSelected: async (file) => {
                    try {
                        this._audioTrackView.showProgress(10, 'Decodificando archivo de audio...');
                        const buffer = await this._audioChordAnalyzer.decodeAudio(file);

                        this._audioTrackView.showProgress(25, 'Calculando cromagrama espectral...');
                        const report = await this._audioChordAnalyzer.analyze(buffer, (pct) => {
                            this._audioTrackView.showProgress(pct, 'Detectando acordes y tonalidad...');
                        });

                        this._audioTrackView.hideProgress();
                        audioPlayerController.loadTrack(buffer, report.chords);

                        this._audioTrackView.renderAnalysis(file, report, (seekTime) => {
                            audioPlayerController.seek(seekTime);
                        });
                    } catch (err) {
                        console.error('[AppController] Error al analizar audio:', err);
                        this._audioTrackView.showProgress(100, `Error: ${err.message}`);
                        setTimeout(() => this._audioTrackView.hideProgress(), 4000);
                    }
                },
                onPlayPause: () => {
                    if (audioPlayerController.isPlaying) {
                        audioPlayerController.pause();
                    } else {
                        audioPlayerController.play();
                    }
                },
                onStop: () => {
                    audioPlayerController.stop();
                    if (!this._detectorView.isModeActive) {
                        this.setStep(this._currentStepIndex, false);
                    }
                },
                onSeek: (percent) => {
                    audioPlayerController.seek(percent * audioPlayerController.duration);
                },
                onSyncToggle: (enabled) => {
                    audioPlayerController.setSyncWithDiapason(enabled);
                },
                onApplyTuning: (offset, rowKey) => {
                    this._currentOffset = offset;
                    this._activeRowKey = rowKey;

                    const tuningSelect = document.getElementById('tuningSelect');
                    if (tuningSelect) tuningSelect.value = offset;

                    this._updateAccordionData();
                    this._chordView.populateRoots(this._currentNotation, this._currentOffset);
                    this._rebuildScale();
                    this._renderAll();
                    this._updateDetectorUI();
                }
            });
        }
    }

    /**
     * Recalcula el mapa transpuesto del acordeón.
     * @private
     */
    _updateAccordionData() {
        this._accordionData = getTransposedAccordion(this._currentOffset);
    }

    /**
     * Reconstruye la escala para la tónica y modalidad seleccionadas.
     * @private
     */
    _rebuildScale() {
        if (this._selectedScaleRoot === 'auto') {
            this._activeScaleRoot = ROW_BASE_TONICS[this._activeRowKey] + this._currentOffset;
        } else {
            const rootMod = parseInt(this._selectedScaleRoot);
            // Octava 4 / Central
            this._activeScaleRoot = 60 + rootMod;
        }
        this._scaleSteps = generateScale(this._activeScaleRoot, this._selectedScaleType);
    }

    /**
     * Renderiza todo el conjunto visual.
     * @private
     */
    _renderAll() {
        this._renderDiapason();

        // 1. Llenar selector de tónicas de escala (permitiendo elegir Sol o cualquier tono)
        this._scaleBarView.populateScaleRoots(
            this._currentNotation,
            this._currentOffset,
            this._selectedScaleRoot
        );

        // 2. Renderizar los 8 grados de la escala
        this._scaleBarView.render(
            this._scaleSteps,
            this._currentStepIndex,
            this._selectedScaleType,
            this._currentNotation,
            this._currentOffset,
            (idx) => this.setStep(idx, true)
        );

        // 3. Renderizar Paleta de Tonos Relacionados y Familia Armónica
        const rootPitchClass = getPitchClass(this._activeScaleRoot);
        const relatedChords = getHarmonicFamilyAndRelatedChords(
            rootPitchClass,
            this._currentNotation,
            this._currentOffset
        );

        this._scaleBarView.renderRelatedChords(relatedChords, (chordItem) => {
            // Al hacer clic en un tono relacionado, se resalta en el diapasón y se reproduce
            this._diapasonView.highlightChord(
                this._accordionData,
                chordItem.noteMods,
                false,
                this._bellowsMachine.mode
            );
            audioEngine.play(chordItem.playbackMidis);
            this._executionView.setNoteLabel(`${chordItem.chordName} (${chordItem.roleName})`);

            const forms = this.calculateExecutionForms(chordItem.rootPitchClass, false);
            this._executionView.renderForms(forms, (selectedForm) => {
                this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                audioEngine.play(selectedForm.midi);
            });
        });

        this._updateFeasibilityAndChordDisplay();
        this._restoreActiveHighlights();
    }

    /**
     * Restaura los resaltados visuales activos en el diapasón según el estado actual.
     * @private
     */
    _restoreActiveHighlights() {
        if (this._detectorView.isModeActive) {
            this._diapasonView.highlightDetectorButtons(this._detectorSelectedButtons);
        } else if (this._isChordPinned && this._pinnedChordData) {
            this._diapasonView.highlightChord(
                this._accordionData,
                this._pinnedChordData.targetNotes,
                this._pinnedChordData.isExactMidi,
                this._bellowsMachine.mode
            );
        } else if (this._scaleSteps.length > 0) {
            this.setStep(this._currentStepIndex, false);
        }
    }

    /**
     * Actualiza el estado visual y texto del botón de Modo Espejo.
     * @private
     */
    _updateMirrorButtonUI() {
        const btnToggleMirror = document.getElementById('btnToggleMirror');
        const lblMirrorStatus = document.getElementById('lblMirrorStatus');
        if (!btnToggleMirror) return;

        if (this._isDiapasonMirrored) {
            btnToggleMirror.classList.add('active');
            if (lblMirrorStatus) lblMirrorStatus.innerText = 'Hileras: Espejo (1-2-3)';
            btnToggleMirror.title = 'Modo Espejo activado (Hilera 1 a la izquierda, Hilera 3 a la derecha). Haz clic para volver al modo normal.';
        } else {
            btnToggleMirror.classList.remove('active');
            if (lblMirrorStatus) lblMirrorStatus.innerText = 'Hileras: Normal (3-2-1)';
            btnToggleMirror.title = 'Modo Normal (Hilera 3 a la izquierda, Hilera 1 a la derecha). Haz clic para invertir al modo espejo.';
        }
    }

    /**
     * Renderiza el diapasón y vincula clics en botones físicos.
     * @private
     */
    _renderDiapason() {
        this._diapasonView.render(
            this._accordionData,
            this._activeRowKey,
            this._bellowsMachine.mode,
            this._currentNotation,
            this._currentOffset,
            {
                onRowHeaderClick: (rowKey, tonicMidi) => {
                    this._activeRowKey = rowKey;
                    this._selectedScaleRoot = 'auto'; // Restablecer a tónica de hilera
                    if (this._isChordPinned) this.unpinChord();
                    this._scaleBarView.clearActiveRelatedChord();
                    this._rebuildScale();
                    this._renderAll();
                    this.setStep(0, false);
                },
                onButtonClick: (buttonData, btnEl) => {
                    this._handleButtonClick(buttonData, btnEl, false);
                },
                onButtonRightClick: (buttonData, btnEl) => {
                    this._handleButtonClick(buttonData, btnEl, true);
                }
            }
        );
    }

    /**
     * Maneja el clic en un botón del diapasón (soporta modo normal y modo detector).
     * @private
     */
    _handleButtonClick(buttonData, btnEl, isRightClick = false) {
        if (this._detectorView.isModeActive) {
            let dir = 'push';
            const detectorDir = this._detectorView.currentDirection;

            if (detectorDir === 'auto') {
                if (isRightClick) {
                    dir = this._bellowsMachine.mode === BELLOWS_MODES.PUSH ? 'pull' : 'push';
                } else {
                    dir = this._bellowsMachine.mode === BELLOWS_MODES.PULL ? 'pull' : 'push';
                }
            } else {
                dir = isRightClick ? (detectorDir === 'push' ? 'pull' : 'push') : detectorDir;
            }

            const midi = dir === 'pull' ? buttonData.pull : buttonData.push;
            this._toggleDetectorButton(buttonData.id, buttonData.rowKey, buttonData.btnIndex, dir, midi);
            return;
        }

        const noteToPlay = this._bellowsMachine.resolveMidi(buttonData, isRightClick);
        audioEngine.play(noteToPlay);
        this._diapasonView.triggerGlowOnElement(btnEl);
    }

    /**
     * Establece el grado activo de la escala diatónica (I a VIII).
     * @param {number} stepIdx
     * @param {boolean} [shouldPlay=true]
     */
    setStep(stepIdx, shouldPlay = true) {
        if (!this._scaleSteps.length) return;
        this._currentStepIndex = ((stepIdx % this._scaleSteps.length) + this._scaleSteps.length) % this._scaleSteps.length;

        this._scaleBarView.setActiveStep(this._currentStepIndex);

        const currentStep = this._scaleSteps[this._currentStepIndex];
        const isChordMode = this._scaleBarView.isChordMode();
        const noteName = midiToName(currentStep.midi, this._currentNotation, false, this._currentOffset);

        this._executionView.setNoteLabel(`${noteName} (${currentStep.degreeNumeral})`);

        // Calcular todas las posiciones de ejecución posibles en el acordeón
        const executionForms = this.calculateExecutionForms(currentStep.pitchClass);
        this._executionView.renderForms(executionForms, (selectedForm) => {
            this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
            audioEngine.play(selectedForm.midi);
            const btnEl = document.getElementById(selectedForm.btnId);
            if (btnEl) this._diapasonView.triggerGlowOnElement(btnEl);
        });

        if (isChordMode) {
            this._diapasonView.highlightChord(
                this._accordionData,
                currentStep.chordPitchClasses,
                false,
                this._bellowsMachine.mode
            );
            if (shouldPlay) {
                audioEngine.play(currentStep.chordAbsoluteMidis);
            }
        } else {
            if (executionForms.length > 0) {
                this._diapasonView.highlightSingleButton(executionForms[0].btnId, executionForms[0].directionClass);
                if (shouldPlay) {
                    audioEngine.play(executionForms[0].midi);
                    const btnEl = document.getElementById(executionForms[0].btnId);
                    if (btnEl) this._diapasonView.triggerGlowOnElement(btnEl);
                }
            }
        }
    }

    /**
     * Calcula todas las formas de ejecutar una nota en el acordeón.
     * @param {number} noteTarget Pitch class (0-11) o nota MIDI exacta
     * @param {boolean} [isExactMidi=false]
     * @returns {Array}
     */
    calculateExecutionForms(noteTarget, isExactMidi = false) {
        const forms = [];
        const rowsOrder = [this._activeRowKey, ...['row3', 'row2', 'row1'].filter(r => r !== this._activeRowKey)];

        rowsOrder.forEach(r => {
            if (!this._accordionData[r]) return;
            this._accordionData[r].forEach(b => {
                const pTarget = isExactMidi ? b.push : getPitchClass(b.push);
                const plTarget = isExactMidi ? b.pull : getPitchClass(b.pull);

                const isPushMatch = pTarget === noteTarget;
                const isPullMatch = plTarget === noteTarget;

                if (isPushMatch && (this._bellowsMachine.mode === BELLOWS_MODES.BOTH || this._bellowsMachine.mode === BELLOWS_MODES.PUSH)) {
                    forms.push({
                        btnId: b.id,
                        rowName: ROW_NAMES[r],
                        rowKey: r,
                        btnNum: b.btnIndex,
                        direction: 'Cerrar (Push)',
                        directionClass: 'push',
                        midi: b.push,
                        isNatural: r === this._activeRowKey
                    });
                }
                if (isPullMatch && (this._bellowsMachine.mode === BELLOWS_MODES.BOTH || this._bellowsMachine.mode === BELLOWS_MODES.PULL)) {
                    forms.push({
                        btnId: b.id,
                        rowName: ROW_NAMES[r],
                        rowKey: r,
                        btnNum: b.btnIndex,
                        direction: 'Abrir (Pull)',
                        directionClass: 'pull',
                        midi: b.pull,
                        isNatural: r === this._activeRowKey
                    });
                }
            });
        });

        return forms;
    }

    /**
     * Reproduce la secuencia de notas de la escala con soporte para bucle y tempo.
     */
    async playScaleSequence() {
        if (this._isScalePlaying) {
            this._isScalePlaying = false;
            this._scaleBarView.setPlayingState(false);
            return;
        }

        this._isScalePlaying = true;
        this._scaleBarView.setPlayingState(true);

        const { start, end } = this._scaleBarView.getLoopRange();

        do {
            for (let i = start; i < end; i++) {
                if (!this._isScalePlaying) break;
                this.setStep(i, true);
                const speed = this._scaleBarView.getSpeed();
                await new Promise(r => setTimeout(r, speed));
            }
        } while (this._isScalePlaying && this._scaleBarView._isLooping);

        this._isScalePlaying = false;
        this._scaleBarView.setPlayingState(false);
    }

    /**
     * Actualiza la visualización del acorde libre y su factibilidad de fuelle.
     * @private
     */
    _updateFeasibilityAndChordDisplay() {
        const chord = this._chordView.getSelectedChordData();
        this._chordView.updateDisplay(
            chord,
            this._accordionData,
            this._bellowsMachine.mode,
            this._currentNotation,
            this._currentOffset
        );
    }

    /**
     * Resalta y reproduce un acorde libre en el acordeón.
     * @private
     */
    _showFreeChordOnAccordion(chordData, shouldPlay = false) {
        this._diapasonView.highlightChord(
            this._accordionData,
            chordData.targetNotes,
            chordData.isExactMidi,
            this._bellowsMachine.mode
        );
        this._chordView.showClearButton();

        if (shouldPlay) {
            audioEngine.play(chordData.playbackMidis);
        }
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

        const target = chord.isExactMidi ? chord.playbackMidis[idx] : chord.noteMods[idx];
        const noteName = chord.isExactMidi
            ? midiToName(chord.playbackMidis[idx], this._currentNotation, false, this._currentOffset)
            : midiToName(chord.playbackMidis[idx], this._currentNotation, true, this._currentOffset);
        const roleName = chord.roles[idx] || '';

        this._executionView.setNoteLabel(`${noteName} (${roleName})`);

        const forms = this.calculateExecutionForms(target, chord.isExactMidi);
        this._executionView.renderForms(forms, (selectedForm) => {
            this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
            audioEngine.play(selectedForm.midi);
        });

        if (forms.length > 0) {
            this._diapasonView.highlightSingleButton(forms[0].btnId, forms[0].directionClass);
            if (shouldPlay) {
                audioEngine.play(forms[0].midi);
            }
        } else {
            this._diapasonView.clearHighlights();
            if (shouldPlay) {
                audioEngine.play(chord.playbackMidis[idx]);
            }
        }
    }

    /**
     * Reproduce arpegio del acorde libre paso a paso.
     */
    async playChordArpeggio() {
        if (this._chordView.isArpeggioPlaying) {
            this._chordView.setArpeggioPlaying(false);
            return;
        }

        this._chordView.setArpeggioPlaying(true);
        const chord = this._chordView.getSelectedChordData();
        this._showFreeChordOnAccordion(chord, false);

        for (let i = 0; i < chord.intervals.length; i++) {
            if (!this._chordView.isArpeggioPlaying) break;
            this.selectChordNote(i, true);
            const speed = this._scaleBarView.getSpeed();
            await new Promise(r => setTimeout(r, speed));
        }

        this._chordView.setArpeggioPlaying(false);
    }

    /**
     * Mantiene sonando el acorde fijado.
     * @private
     */
    _holdChordAudio(chordData) {
        audioEngine.hold(chordData.playbackMidis);
    }

    /**
     * Desfija el acorde libre y restablece la escala.
     */
    unpinChord() {
        this._isChordPinned = false;
        this._pinnedChordData = null;
        this._chordView.unpin();
        audioEngine.stopAll();
        this.setStep(this._currentStepIndex, false);
    }

    // =========================================================================
    // SECCIÓN DEL DETECTOR INTELIGENTE
    // =========================================================================

    /**
     * Alterna la selección de un botón en el detector.
     * @private
     */
    _toggleDetectorButton(btnId, rowKey, btnIndex, direction, midi) {
        const existingIdx = this._detectorSelectedButtons.findIndex(b => b.btnId === btnId && b.direction === direction);
        if (existingIdx >= 0) {
            this._detectorSelectedButtons.splice(existingIdx, 1);
        } else {
            this._detectorSelectedButtons.push({
                btnId,
                rowKey,
                btnIndex,
                direction,
                midi,
                noteMod: getPitchClass(midi)
            });
            audioEngine.play(midi);
            const btnEl = document.getElementById(btnId);
            if (btnEl) this._diapasonView.triggerGlowOnElement(btnEl);
        }

        this._updateDetectorUI();
    }

    /**
     * Actualiza la tira del detector y calcula el análisis armónico con HarmonicAnalysisStrategy.
     * @private
     */
    _updateDetectorUI() {
        this._detectorView.renderSelectedButtons(
            this._detectorSelectedButtons,
            this._currentNotation,
            this._currentOffset,
            {
                onRemove: (idx) => {
                    this._detectorSelectedButtons.splice(idx, 1);
                    this._updateDetectorUI();
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
            this._currentNotation,
            this._currentOffset
        );

        this._detectorView.renderAnalysisResult(analysis, this._currentNotation);

        if (this._detectorView.isModeActive) {
            this._diapasonView.highlightDetectorButtons(this._detectorSelectedButtons);
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

            const speed = this._scaleBarView.getSpeed();
            await new Promise(r => setTimeout(r, speed));
        }

        this._detectorView.setArpeggioPlaying(false);
    }
}
