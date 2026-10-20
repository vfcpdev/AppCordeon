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
import { generateScale, generateMajorScale, getHarmonicFamilyAndRelatedChords, getCadenceChords, getAccordionButtonsForChord } from '../theory/Scales.js';
import { HarmonicAnalysisStrategy } from '../strategies/HarmonicAnalysisStrategy.js';
import { FeasibilityAnalysisStrategy } from '../strategies/FeasibilityAnalysisStrategy.js';
import { getPitchClass, midiToName, getNoteNamesList, parseChordNotation } from '../theory/MusicTheory.js';
import {
    ROW_NAMES,
    ROW_BASE_TONICS,
    NOTATION_MODES,
    BELLOWS_MODES,
    DEFAULT_CONFIG
} from '../core/Constants.js';
import { DiapasonStageController } from './DiapasonStageController.js';
import { TheoryInteractionController } from './TheoryInteractionController.js';

export class AppController {
    /**
     * @param {Object} views Objeto con las vistas inyectadas
     * @param {import('../ui/DiapasonView.js').DiapasonView} views.diapasonView
     * @param {import('../ui/DiapasonView.js').DiapasonView} [views.secondaryDiapasonView]
     * @param {import('../ui/ScaleBarView.js').ScaleBarView} views.scaleBarView
     * @param {import('../ui/ChordView.js').ChordView} views.chordView
     * @param {import('../ui/DetectorView.js').DetectorView} views.detectorView
     * @param {import('../ui/ExecutionView.js').ExecutionView} views.executionView
     * @param {import('../ui/AudioTrackView.js').AudioTrackView} [views.audioTrackView]
     * @param {import('../ui/DiapasonChordSidebarView.js').DiapasonChordSidebarView} [views.diapasonChordSidebarView]
     */
    constructor(views) {
        this._diapasonView = views.diapasonView;
        this._secondaryDiapasonView = views.secondaryDiapasonView;
        this._scaleBarView = views.scaleBarView;
        this._chordView = views.chordView;
        this._detectorView = views.detectorView;
        this._executionView = views.executionView;
        this._audioTrackView = views.audioTrackView;
        this._diapasonChordSidebarView = views.diapasonChordSidebarView;
        this._leftHandBassView = views.leftHandBassView || null;
        this._secondaryLeftHandBassView = views.secondaryLeftHandBassView || null;

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

        // Modo de Ejecución de Octava de la Escala ('progressive' | 'same_octave')
        this._scaleOctaveMode = 'progressive';

        // Modo Armónico de Grados ('triad' | 'seventh') según rigor pedagógico
        this._scaleHarmonicMode = 'triad';

        // Estado del Segundo Diapasón (Acordeón Comparativo / Equivalente)
        this._secondaryOffset = 0; // Por defecto Cinco Letras (Bb - Eb - Ab)
        this._secondaryEquivalenceMode = 'pitch'; // 'pitch' (Mismo Tono) | 'relative' (Misma Hilera)
        this._secondaryBellowsMode = BELLOWS_MODES.BOTH;
        this._secondaryAccordionData = getTransposedAccordion(this._secondaryOffset);

        // Controlador del Escenario Físico (Volumen, Sincronización, Visibilidad y Modo Espejo)
        this._stageController = new DiapasonStageController({
            diapasonView: this._diapasonView,
            secondaryDiapasonView: this._secondaryDiapasonView,
            onStageChanged: (evt) => {
                if (evt.type === 'primary_mirror') {
                    this._renderDiapason();
                    this._restoreActiveHighlights();
                    this._updateSidebarChordsView();
                    this._updateRowSelectorButtons();
                } else if (evt.type === 'secondary_mirror') {
                    this._renderSecondaryDiapason();
                    this._syncSecondaryDiapason();
                    this._updateSidebarChordsView();
                } else if (evt.type === 'primary_visibility' || evt.type === 'secondary_visibility') {
                    if (evt.visible && evt.type === 'secondary_visibility') {
                        this._renderSecondaryDiapason();
                        this._syncSecondaryDiapason();
                    }
                    this._updateSidebarChordsView();
                }
            }
        });

        // Controlador de Interacciones Teóricas (Acordes Libres y Detector)
        this._theoryController = new TheoryInteractionController({
            chordView: this._chordView,
            detectorView: this._detectorView,
            executionView: this._executionView,
            diapasonView: this._diapasonView,
            appContext: {
                getBellowsMode: () => this._bellowsMachine.mode,
                getAccordionData: () => this._accordionData,
                syncSecondaryDiapason: (opts) => this._syncSecondaryDiapason(opts),
                getCurrentNotation: () => this._currentNotation,
                getCurrentOffset: () => this._currentOffset,
                calculateExecutionForms: (pitchClass, exactMidi, mode) => this.calculateExecutionForms(pitchClass, exactMidi, mode),
                getSpeed: () => this._scaleBarView.getSpeed(),
                onChordUnpinned: () => {
                    this._renderDiapason();
                    this._syncSecondaryDiapason();
                    if (this._scaleSteps.length > 0) {
                        this.setStep(this._currentStepIndex, false);
                    }
                }
            }
        });
    }

    get _isChordPinned() {
        return this._theoryController ? this._theoryController.isChordPinned : false;
    }

    set _isChordPinned(val) {
        if (this._theoryController) this._theoryController._isChordPinned = val;
    }

    get _pinnedChordData() {
        return this._theoryController ? this._theoryController.pinnedChordData : null;
    }

    set _pinnedChordData(val) {
        if (this._theoryController) this._theoryController._pinnedChordData = val;
    }

    get _detectorSelectedButtons() {
        return this._theoryController ? this._theoryController.detectorSelectedButtons : [];
    }

    set _detectorSelectedButtons(val) {
        if (this._theoryController) this._theoryController.detectorSelectedButtons = val;
    }

    get _isDiapasonMirrored() {
        return this._stageController ? this._stageController.isDiapasonMirrored : false;
    }

    set _isDiapasonMirrored(val) {
        if (this._stageController) this._stageController._isDiapasonMirrored = val;
    }

    get _isSecondaryDiapasonMirrored() {
        return this._stageController ? this._stageController.isSecondaryDiapasonMirrored : false;
    }

    set _isSecondaryDiapasonMirrored(val) {
        if (this._stageController) this._stageController._isSecondaryDiapasonMirrored = val;
    }

    get _isPrimaryDiapasonVisible() {
        return this._stageController ? this._stageController.isPrimaryVisible : true;
    }

    set _isPrimaryDiapasonVisible(val) {
        if (this._stageController) this._stageController._isPrimaryDiapasonVisible = val;
    }

    get _isSecondaryDiapasonVisible() {
        return this._stageController ? this._stageController.isSecondaryVisible : true;
    }

    set _isSecondaryDiapasonVisible(val) {
        if (this._stageController) this._stageController._isSecondaryDiapasonVisible = val;
    }

    /**
     * Inicializa la aplicación, enlaza eventos y dibuja el estado inicial.
     */
    init() {
        this._setupEventBusListeners();
        this._bindUIEvents();
        this._setupSecondaryDiapasonUI();
        this._updateAccordionData();
        this._rebuildScale();

        // Inicializar vistas con datos
        this._chordView.populateRoots(this._currentNotation, this._currentOffset);
        this._stageController.init();
        this._updateRowSelectorButtons();
        this._updatePrimaryTuningLabel();
        this._renderAll();
        this._renderSecondaryDiapason();
        this._syncSecondaryDiapason();

        if (this._leftHandBassView) {
            this._leftHandBassView.updateTuning(this._currentOffset, this._currentNotation);
        }
        if (this._secondaryLeftHandBassView) {
            this._secondaryLeftHandBassView.updateTuning(this._secondaryOffset ?? 0, this._currentNotation);
        }
    }

    /**
     * Aplica el volumen del Diapasón 1 delegando en el controlador de escenario.
     * @param {number} vol Porcentaje (0 a 100)
     * @param {boolean} isMuted
     * @param {boolean} [syncOther=true]
     * @private
     */
     _applyPrimaryVolume(vol, isMuted, syncOther = true) {
        if (this._stageController) {
            this._stageController.applyPrimaryVolume(vol, isMuted, syncOther);
        }
    }

    /**
     * Aplica el volumen del Diapasón 2 delegando en el controlador de escenario.
     * @param {number} vol Porcentaje (0 a 100)
     * @param {boolean} isMuted
     * @param {boolean} [syncOther=true]
     * @private
     */
    _applySecondaryVolume(vol, isMuted, syncOther = true) {
        if (this._stageController) {
            this._stageController.applySecondaryVolume(vol, isMuted, syncOther);
        }
    }

    /**
     * Actualiza el volumen maestro en dB para el sintetizador.
     * @private
     */
    _updateMasterAudioVolume() {
        if (this._stageController) {
            this._stageController.updateMasterAudioVolume();
        }
    }

    /**
     * Actualiza la interfaz de los botones de vinculación/sincronización de volumen.
     * @private
     */
    _updateVolumeSyncUI() {
        if (this._stageController) {
            this._stageController.updateVolumeSyncUI();
        }
    }

    /**
     * Registra listeners en el EventBus central.
     * @private
     */
    _setupEventBusListeners() {
        eventBus.on('bellows:changed', ({ current }) => {
            this._renderDiapason();
            this._renderSecondaryDiapason();
            this._updateFeasibilityAndChordDisplay();
            if (this._scaleSteps.length > 0 && !this._detectorView.isModeActive) {
                this.setStep(this._currentStepIndex, false);
            } else {
                this._syncSecondaryDiapason();
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
            if (this._diapasonChordSidebarView) {
                this._updateSidebarChordsView(chord);
                this._diapasonChordSidebarView.setActiveTimelineIndex(index);
            }
            if (syncWithDiapason && this._audioTrackView && this._audioTrackView.isSyncEnabled()) {
                if (chord) {
                    // Mostrar en el diapasón los botones del acorde respetando la preferencia Abre / Cierra definida y la cantidad de botones
                    const bellowsFilter = chord.bellowsAction || this._bellowsMachine.mode;
                    const deactivated = this._diapasonChordSidebarView ? this._diapasonChordSidebarView.getDeactivatedButtons() : null;
                    this._diapasonView.highlightChord(
                        this._accordionData,
                        chord.noteMods,
                        false,
                        bellowsFilter,
                        deactivated
                    );
                    this._syncSecondaryDiapason({
                        notes: chord.noteMods,
                        isExactMidi: false,
                        bellowsMode: bellowsFilter,
                        excludedButtons: deactivated
                    });
                } else {
                    this._diapasonView.clearHighlights();
                    if (this._isSecondaryDiapasonVisible && this._secondaryDiapasonView) {
                        this._secondaryDiapasonView.clearHighlights();
                    }
                }
            }

            // Reproducir el sonido del acorde a medida que va cambiando
            if (chord) {
                let midis = null;
                if (this._diapasonChordSidebarView) {
                    const deact = this._diapasonChordSidebarView.getDeactivatedButtons();
                    const activeDir = (chord.bellowsAction === 'push') ? 'push' : 'pull';
                    const btns = getAccordionButtonsForChord(this._accordionData, chord.noteMods, this._currentNotation, this._currentOffset);
                    const actBtns = (activeDir === 'push' ? btns.pushButtons : btns.pullButtons).filter(b => !deact.has(`${activeDir}_${b.id}`));
                    if (actBtns.length > 0) {
                        midis = actBtns.map(b => b.midi);
                    }
                }
                if (!midis || midis.length === 0) {
                    midis = chord.playbackMidis;
                }
                if (!midis || midis.length === 0) {
                    if (chord.noteMods && chord.noteMods.length > 0) {
                        midis = chord.noteMods.map(n => 60 + n);
                    } else if (typeof chord.root === 'number') {
                        midis = [60 + chord.root, 60 + chord.root + 4, 60 + chord.root + 7];
                    }
                }
                if (midis && midis.length > 0) {
                    const chordVol = audioPlayerController.getChordEffectiveVolume();
                    if (chordVol > 0) {
                        audioEngine.play(midis, "4n", chordVol);
                    }
                }
            }
        });

        eventBus.on('player:ended', () => {
            if (this._scaleSteps.length > 0 && !this._detectorView.isModeActive) {
                this.setStep(this._currentStepIndex, false);
            } else {
                this._syncSecondaryDiapason();
            }
        });
    }

    /**
     * Enlaza eventos de interacción directa de las vistas y controles.
     * @private
     */
    _bindUIEvents() {
        // Selector de Afinación Principal
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
                this._updatePrimaryTuningLabel();
                this._chordView.populateRoots(this._currentNotation, this._currentOffset);
                this._rebuildScale();
                this._renderAll();
                this._updateDetectorUI();
                this._syncSecondaryDiapason();
                if (this._leftHandBassView) {
                    this._leftHandBassView.updateTuning(this._currentOffset, this._currentNotation);
                }
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
                this._renderSecondaryDiapason();
                this._updateDetectorUI();
                this._syncSecondaryDiapason();
                this._updateSidebarChordsView();
                if (this._leftHandBassView) {
                    this._leftHandBassView.updateTuning(this._currentOffset, this._currentNotation);
                }
                if (this._secondaryLeftHandBassView) {
                    this._secondaryLeftHandBassView.updateTuning(this._secondaryOffset ?? 0, this._currentNotation);
                }
            });
        });

        // Botones de Fuelle Diapasón Principal
        document.querySelectorAll('#primaryBellowsButtonGroup .bellows-btn, #bellowsButtonGroup .bellows-btn, .bellows-group .bellows-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('#primaryBellowsButtonGroup .bellows-btn, #bellowsButtonGroup .bellows-btn, .bellows-group .bellows-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this._bellowsMachine.setMode(btn.dataset.mode);
            });
        });

        // Botones de Selección / Cambio de Hilera en la barra del Acordeón 1
        const primaryRowButtons = document.querySelectorAll('#primaryRowSelectorGroup .btn-row-select');
        primaryRowButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const rowKey = btn.dataset.row;
                if (!rowKey) return;
                this._activeRowKey = rowKey;
                this._selectedScaleRoot = 'auto'; // Restablecer a tónica de hilera
                if (this._isChordPinned) this.unpinChord();
                this._scaleBarView.clearActiveRelatedChord();
                this._rebuildScale();
                this._renderAll();
                this.setStep(0, false);
                this._updateRowSelectorButtons();
            });
        });

        // Color de Fondo
        const bgColorInput = document.getElementById('bgColor');
        if (bgColorInput) {
            bgColorInput.addEventListener('input', (e) => {
                document.body.style.backgroundColor = e.target.value;
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
            },
            onOctaveChange: (octaveMode) => {
                this._scaleOctaveMode = octaveMode;
                this._rebuildScale();
                this._renderAll();
                this.setStep(this._currentStepIndex, false);
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
                this._showFreeChordOnAccordion(chord, true);
                if (this._isChordPinned) this._holdChordAudio(chord);

                const rootName = midiToName(chord.playbackMidis[0], this._currentNotation, false, this._currentOffset);
                this._executionView.setNoteLabel(`Acorde Libre: ${chord.typeName} (${rootName})`);
                const forms = this.calculateChordExecutionForms(chord);
                this._executionView.renderForms(forms, (selectedForm) => {
                    if (selectedForm.isFullChord) {
                        this._showFreeChordOnAccordion(chord, true);
                    } else {
                        this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                        audioEngine.play(selectedForm.midi);
                    }
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
            onExecutionModeChange: (mode) => {
                const chord = this._chordView.getSelectedChordData();
                if (mode === 'harmonic') {
                    this._showFreeChordOnAccordion(chord, false);
                }
            },
            onHarmonicModeChange: (harmonicMode) => {
                this._scaleHarmonicMode = harmonicMode;
                const chord = this._chordView.getSelectedChordData();
                this._chordView.updateDisplay(chord, this._accordionData, this._chordView.bellowsMode, this._currentNotation, this._currentOffset);
            },
            onSyncToScale: ({ root, scaleType }) => {
                this._selectedScaleRoot = root;
                const scaleRootSelect = document.getElementById('scaleRootSelect');
                if (scaleRootSelect) scaleRootSelect.value = root;

                const scaleTypeSelect = document.getElementById('scaleTypeSelect');
                if (scaleTypeSelect) scaleTypeSelect.value = scaleType;

                this._rebuildScale();
                this._renderAll();
                this.setStep(0, true);

                const scaleSection = document.getElementById('scaleSection');
                if (scaleSection) {
                    scaleSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
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

        // Clic en los grados de la escala generada del acorde libre (Armónico / Melódico)
        this._chordView.onScaleDegreeClick((stepData, isHarmonic) => {
            const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._bellowsMachine.mode;
            if (isHarmonic) {
                // Modo Armónico: muestra y reproduce el acorde del grado
                this._diapasonView.highlightChord(
                    this._accordionData,
                    stepData.chordPitchClasses,
                    false,
                    bellowsMode
                );
                this._syncSecondaryDiapason({
                    notes: stepData.chordPitchClasses,
                    isExactMidi: false,
                    bellowsMode
                });
                audioEngine.play(stepData.chordPlaybackMidis);
                this._executionView.setNoteLabel(`Grado ${stepData.numeral}: ${stepData.chordName}`);

                const forms = this.calculateChordExecutionForms({
                    ...this._chordView.getSelectedChordData(),
                    intervals: [0, 4, 7],
                    roles: ['Tónica', '3ra', '5ta'],
                    playbackMidis: stepData.chordPlaybackMidis,
                    isExactMidi: false
                });
                this._executionView.renderForms(forms, (selectedForm) => {
                    if (selectedForm.isFullChord) {
                        this._diapasonView.highlightChord(this._accordionData, stepData.chordPitchClasses, false, bellowsMode);
                        this._syncSecondaryDiapason({
                            notes: stepData.chordPitchClasses,
                            isExactMidi: false,
                            bellowsMode
                        });
                        audioEngine.play(stepData.chordPlaybackMidis);
                    } else {
                        this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                        audioEngine.play(selectedForm.midi);
                    }
                });
            } else {
                // Modo Melódico: muestra y reproduce la nota individual del grado
                const forms = this.calculateExecutionForms(stepData.pitchClass, false, bellowsMode);
                this._executionView.setNoteLabel(`Grado ${stepData.numeral}: ${stepData.noteName}`);
                this._executionView.renderForms(forms, (selectedForm) => {
                    this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                    this._syncSecondaryDiapason({
                        notes: [stepData.pitchClass],
                        isExactMidi: false,
                        bellowsMode
                    });
                    audioEngine.play(selectedForm.midi);
                });
                if (forms.length > 0) {
                    this._diapasonView.highlightSingleButton(forms[0].btnId, forms[0].directionClass);
                    this._syncSecondaryDiapason({
                        notes: [stepData.pitchClass],
                        isExactMidi: false,
                        bellowsMode
                    });
                    audioEngine.play(forms[0].midi);
                }
            }
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
                    const fname = (file.name || '').toLowerCase();
                    if (!file.type.startsWith('audio/') && !fname.endsWith('.mp3') && !fname.endsWith('.wav') && !fname.endsWith('.ogg')) {
                        alert('Formato no admitido:\nPor favor carga un archivo de audio compatible (MP3, WAV, OGG).');
                        return;
                    }

                    try {
                        this._audioTrackView.showProgress(10, 'Decodificando archivo de audio...');
                        const buffer = await this._audioChordAnalyzer.decodeAudio(file);

                        this._audioTrackView.showProgress(25, `Calculando cromagrama [${this._audioChordAnalyzer.getEngineName()}]...`);
                        const report = await this._audioChordAnalyzer.analyze(buffer, (pct) => {
                            this._audioTrackView.showProgress(pct, `Detectando acordes [${this._audioChordAnalyzer.getEngineName()}]...`);
                        });

                        this._audioTrackView.hideProgress();
                        audioPlayerController.loadTrack(buffer, report.chords);

                        this._audioTrackView.renderAnalysis(file, report, (seekTime) => {
                            audioPlayerController.seek(seekTime);
                        });

                        // Poblar lista de acordes detectados en las barras laterales de ambos diapasones
                        if (this._diapasonChordSidebarView && report.chords && report.chords.length > 0) {
                            this._diapasonChordSidebarView.renderChordsList(
                                report.chords,
                                0,
                                (selectedChord) => {
                                    audioPlayerController.seek(selectedChord.startTime);
                                }
                            );
                            this._updateSidebarChordsView(report.chords[0]);
                        }
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
                    this._updatePrimaryTuningLabel();
                    this._chordView.populateRoots(this._currentNotation, this._currentOffset);
                    this._rebuildScale();
                    this._renderAll();
                    this._updateDetectorUI();
                    this._syncSecondaryDiapason();
                },
                onChordTimelineUpdated: (timeline) => {
                    if (this._diapasonChordSidebarView) {
                        this._diapasonChordSidebarView.renderChordsList(
                            timeline,
                            0,
                            (selectedChord) => {
                                audioPlayerController.seek(selectedChord.startTime);
                            }
                        );
                    }
                }
            });

            if (this._diapasonChordSidebarView) {
                this._diapasonChordSidebarView.setTimelineUpdateCallback((timeline, newIdx) => {
                    audioPlayerController.setChordsTimeline(timeline);
                    if (this._audioTrackView) {
                        if (this._audioTrackView._currentAnalysisData) {
                            this._audioTrackView._currentAnalysisData.chords = timeline;
                        }
                        this._audioTrackView.renderChordsStrip(timeline, (seekTime) => {
                            audioPlayerController.seek(seekTime);
                        });
                    }
                    if (newIdx >= 0 && newIdx < timeline.length) {
                        const ch = timeline[newIdx];
                        this._updateSidebarChordsView(ch);
                        if (this._audioTrackView) {
                            this._audioTrackView.setActiveChord(ch, newIdx);
                        }
                    }
                });
            }
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
        this._scaleSteps = generateScale(
            this._activeScaleRoot,
            this._selectedScaleType,
            this._scaleOctaveMode || 'progressive',
            this._scaleHarmonicMode || 'triad'
        );
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
            this._syncSecondaryDiapason({
                notes: chordItem.noteMods,
                isExactMidi: false,
                bellowsMode: this._bellowsMachine.mode
            });
            audioEngine.play(chordItem.playbackMidis);
            this._executionView.setNoteLabel(`${chordItem.chordName} (${chordItem.roleName})`);

            const forms = this.calculateExecutionForms(chordItem.rootPitchClass, false);
            this._executionView.renderForms(forms, (selectedForm) => {
                this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                this._syncSecondaryDiapason({
                    notes: [chordItem.rootPitchClass],
                    isExactMidi: false,
                    bellowsMode: this._bellowsMachine.mode
                });
                audioEngine.play(selectedForm.midi);
            });
        });

        this._updateFeasibilityAndChordDisplay();
        this._updateSidebarChordsView();
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
            return;
        }
        this._syncSecondaryDiapason();
    }

    /**
     * Actualiza el estado visual y texto del botón de Modo Espejo delegando en DiapasonStageController.
     * @private
     */
    _updateMirrorButtonUI() {
        if (this._stageController) {
            this._stageController.updateMirrorButtonsUI();
        }
    }

    /**
     * Actualiza el estado visual y texto del botón de Modo Espejo para el 2do Acordeón.
     * @private
     */
    _updateSecondaryMirrorButtonUI() {
        if (this._stageController) {
            this._stageController.updateMirrorButtonsUI();
        }
    }

    /**
     * Actualiza el estado visual, orden y tónicas de los botones de cambio de hilera en la barra.
     * @private
     */
    _updateRowSelectorButtons() {
        const rowButtons = document.querySelectorAll('#primaryRowSelectorGroup .btn-row-select');
        rowButtons.forEach(btn => {
            const rowKey = btn.dataset.row;
            btn.classList.toggle('active', rowKey === this._activeRowKey);
            const tonicEl = btn.querySelector('.row-tonic');
            if (tonicEl && rowKey) {
                const tonicMidi = ROW_BASE_TONICS[rowKey] + this._currentOffset;
                const rootName = midiToName(tonicMidi, this._currentNotation, true, this._currentOffset);
                tonicEl.textContent = `(${rootName})`;
            }
        });

        // Reordenar según modo espejo (Af->Ad vs Ad<-Af)
        const group = document.getElementById('primaryRowSelectorGroup');
        if (group) {
            const b1 = document.getElementById('btnRowSelect_row1');
            const b2 = document.getElementById('btnRowSelect_row2');
            const b3 = document.getElementById('btnRowSelect_row3');
            if (b1 && b2 && b3) {
                if (this._isDiapasonMirrored) {
                    if (group.firstElementChild !== b1) {
                        group.appendChild(b1);
                        group.appendChild(b2);
                        group.appendChild(b3);
                    }
                } else {
                    if (group.firstElementChild !== b3) {
                        group.appendChild(b3);
                        group.appendChild(b2);
                        group.appendChild(b1);
                    }
                }
            }
        }
    }

    /**
     * Configura la interfaz y eventos del segundo diapasón (acordeón comparativo).
     * @private
     */
    _setupSecondaryDiapasonUI() {
        const secSelect = document.getElementById('secondaryTuningSelect');
        if (secSelect) {
            secSelect.innerHTML = "";
            tuningRegistry.getAll().forEach(t => {
                const opt = document.createElement('option');
                opt.value = t.offset;
                opt.innerText = `${t.name} (${t.rowsDescription})`;
                // Por defecto 5 letras (offset: 0)
                if (t.id === 'cinco_letras' || (t.offset === this._secondaryOffset && !secSelect.value)) {
                    opt.selected = true;
                    this._secondaryOffset = t.offset;
                }
                secSelect.appendChild(opt);
            });

            secSelect.addEventListener('change', (e) => {
                this._secondaryOffset = parseInt(e.target.value);
                this._secondaryAccordionData = getTransposedAccordion(this._secondaryOffset);
                this._renderSecondaryDiapason();
                this._syncSecondaryDiapason();
                if (this._secondaryLeftHandBassView) {
                    this._secondaryLeftHandBassView.updateTuning(this._secondaryOffset, this._currentNotation);
                }
            });
        }

        // Botones de Fuelle para el Segundo Diapasón
        document.querySelectorAll('#secondaryBellowsButtonGroup .bellows-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('#secondaryBellowsButtonGroup .bellows-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this._secondaryBellowsMode = btn.dataset.mode;
                this._renderSecondaryDiapason();
                this._syncSecondaryDiapason();
            });
        });
    }

    /**
     * Actualiza la barra lateral a la derecha de cada diapasón con los botones Abre y Cierra.
     * @private
     * @param {Object} [chord=null]
     */
    _updateSidebarChordsView(chord = null) {
        if (!this._diapasonChordSidebarView) return;

        if (chord) {
            this._currentTrackChord = chord;
        }

        let targetChord = chord || this._currentTrackChord;
        if (!targetChord) {
            const rootPitchClass = getPitchClass(this._activeScaleRoot);
            const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, this._currentOffset);
            const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, this._currentOffset);
            const isMinor = this._selectedScaleType === 'minor' || this._selectedScaleType === 'harmonic_minor';
            const intervals = isMinor ? [0, 3, 7] : [0, 4, 7];
            const isAlemana = this._currentNotation === NOTATION_MODES.ALEMANA;
            targetChord = {
                chordName: isAlemana
                    ? `${arrAle[rootPitchClass]}${isMinor ? 'm' : ''}`.trim()
                    : `${arrLat[rootPitchClass]} ${isMinor ? 'Menor' : 'Mayor'}`.trim(),
                chordSymbol: `${arrAle[rootPitchClass]}${isMinor ? 'm' : ''}`.trim(),
                root: rootPitchClass,
                noteMods: intervals.map(i => (rootPitchClass + i) % 12),
                playbackMidis: intervals.map(i => 60 + rootPitchClass + i)
            };
        }

        this._diapasonChordSidebarView.renderActiveChord(
            targetChord,
            this._accordionData,
            this._secondaryAccordionData,
            this._currentNotation,
            this._currentOffset,
            this._secondaryOffset,
            (action) => {
                if (action.type === 'button_toggle_active') {
                    const targetChord = action.chord;
                    if (targetChord) {
                        const filterMode = targetChord.bellowsAction === 'both' ? 'both' : targetChord.bellowsAction;
                        const targetView = action.target === 'primary' ? this._diapasonView : this._secondaryDiapasonView;
                        const accData = action.target === 'primary' ? this._accordionData : this._secondaryAccordionData;
                        if (targetView && accData) {
                            targetView.highlightChord(
                                accData,
                                targetChord.noteMods,
                                false,
                                filterMode,
                                action.deactivatedButtons
                            );
                        }
                        this._syncSecondaryDiapason({
                            notes: targetChord.noteMods,
                            isExactMidi: false,
                            bellowsMode: filterMode,
                            excludedButtons: action.deactivatedButtons
                        });
                    }
                    return;
                }
                if (action.type === 'bellows_preference_change') {
                    const targetChord = action.chord;
                    if (targetChord) {
                        targetChord.bellowsAction = action.bellowsAction;
                        const filterMode = action.bellowsAction === 'both' ? 'both' : action.bellowsAction;
                        const targetView = action.target === 'primary' ? this._diapasonView : this._secondaryDiapasonView;
                        const accData = action.target === 'primary' ? this._accordionData : this._secondaryAccordionData;
                        const deactivated = this._diapasonChordSidebarView ? this._diapasonChordSidebarView.getDeactivatedButtons() : null;
                        if (targetView && accData) {
                            targetView.highlightChord(
                                accData,
                                targetChord.noteMods,
                                false,
                                filterMode,
                                deactivated
                            );
                        }
                        this._syncSecondaryDiapason({
                            notes: targetChord.noteMods,
                            isExactMidi: false,
                            bellowsMode: filterMode,
                            excludedButtons: deactivated
                        });
                    }
                    return;
                }
                if (action.singleButtonId) {
                    const targetView = action.target === 'primary' ? this._diapasonView : this._secondaryDiapasonView;
                    if (targetView) {
                        targetView.highlightSingleButton(action.singleButtonId, action.direction);
                        const btnEl = document.getElementById((action.target === 'secondary' ? 'sec_' : '') + action.singleButtonId);
                        if (btnEl) targetView.triggerGlowOnElement(btnEl, action.direction);
                    }
                    if (action.midi) {
                        audioEngine.play(action.midi);
                    }
                } else if (action.direction && action.chord) {
                    const targetView = action.target === 'primary' ? this._diapasonView : this._secondaryDiapasonView;
                    const accData = action.target === 'primary' ? this._accordionData : this._secondaryAccordionData;
                    const deactivated = this._diapasonChordSidebarView ? this._diapasonChordSidebarView.getDeactivatedButtons() : null;
                    if (targetView && accData) {
                        targetView.highlightChord(
                            accData,
                            action.chord.noteMods,
                            false,
                            action.direction,
                            deactivated
                        );
                    }
                    if (action.buttons && action.buttons.length > 0) {
                        const midis = action.buttons.map(b => b.midi).slice(0, 4);
                        audioEngine.play(midis);
                    }
                }
            },
            this._isDiapasonMirrored,
            this._isSecondaryDiapasonMirrored
        );
    }

    /**
     * Actualiza la etiqueta de afinación del acordeón principal en el encabezado del diapasón.
     * @private
     */
    _updatePrimaryTuningLabel() {
        const lbl = document.getElementById('lblPrimaryTuningName');
        if (!lbl) return;
        const tuning = tuningRegistry.getAll().find(t => t.offset === this._currentOffset);
        if (tuning) {
            lbl.textContent = `${tuning.name}`;
        } else {
            lbl.textContent = `Afinación (${this._currentOffset >= 0 ? '+' : ''}${this._currentOffset})`;
        }
    }

    /**
     * Renderiza el segundo diapasón comparativo.
     * @private
     */
    _renderSecondaryDiapason() {
        if (!this._secondaryDiapasonView) return;
        this._secondaryDiapasonView.render(
            this._secondaryAccordionData,
            this._activeRowKey,
            this._secondaryBellowsMode || this._bellowsMachine.mode,
            this._currentNotation,
            this._secondaryOffset,
            {
                onRowHeaderClick: (rowKey, tonicMidi) => {
                    const effectiveVol = this._isSecondaryDiapasonMuted ? 0 : this._secondaryDiapasonVolume;
                    if (effectiveVol > 0) {
                        audioEngine.play(tonicMidi, "8n", effectiveVol / 100);
                    }
                },
                onButtonClick: (buttonData, btnEl) => {
                    this._handleSecondaryButtonClick(buttonData, btnEl, false);
                },
                onButtonRightClick: (buttonData, btnEl) => {
                    this._handleSecondaryButtonClick(buttonData, btnEl, true);
                }
            }
        );
    }

    /**
     * Maneja el clic en un botón del segundo diapasón.
     * @private
     */
    _handleSecondaryButtonClick(buttonData, btnEl, isRightClick = false) {
        let noteToPlay;
        let direction;
        const bellows = this._secondaryBellowsMode || this._bellowsMachine.mode;

        if (bellows === BELLOWS_MODES.PULL) {
            noteToPlay = buttonData.pull;
            direction = 'pull';
        } else if (bellows === BELLOWS_MODES.PUSH) {
            noteToPlay = buttonData.push;
            direction = 'push';
        } else {
            noteToPlay = isRightClick ? buttonData.push : buttonData.pull;
            direction = (noteToPlay === buttonData.pull) ? 'pull' : 'push';
        }

        const effectiveVol = this._isSecondaryDiapasonMuted ? 0 : this._secondaryDiapasonVolume;
        if (effectiveVol > 0) {
            audioEngine.play(noteToPlay, "8n", effectiveVol / 100);
        }
        this._secondaryDiapasonView.triggerGlowOnElement(btnEl, direction);
    }

    /**
     * Obtiene el estado actual de notas/acordes activos en el simulador.
     * @private
     * @returns {Object|null}
     */
    _getCurrentActiveHighlightState() {
        if (this._detectorView && this._detectorView.isModeActive) {
            const pitchClasses = [...new Set(this._detectorSelectedButtons.map(b => b.noteMod))];
            return {
                notes: pitchClasses,
                isExactMidi: false,
                bellowsMode: this._bellowsMachine.mode
            };
        }
        if (this._isChordPinned && this._pinnedChordData) {
            const chord = this._pinnedChordData;
            const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._bellowsMachine.mode;
            return {
                notes: chord.targetNotes,
                isExactMidi: chord.isExactMidi,
                bellowsMode
            };
        }
        if (this._scaleSteps.length > 0 && this._currentStepIndex >= 0 && this._currentStepIndex < this._scaleSteps.length) {
            const currentStep = this._scaleSteps[this._currentStepIndex];
            const isChordMode = this._scaleBarView.isChordMode();
            if (isChordMode) {
                return {
                    notes: currentStep.chordPitchClasses,
                    isExactMidi: false,
                    bellowsMode: this._bellowsMachine.mode
                };
            } else {
                return {
                    notes: [currentStep.pitchClass],
                    isExactMidi: false,
                    bellowsMode: this._bellowsMachine.mode
                };
            }
        }
        return null;
    }

    /**
     * Sincroniza y resalta las notas/acordes equivalentes en el segundo diapasón.
     * @private
     * @param {Object} [overrideState=null]
     */
    _syncSecondaryDiapason(overrideState = null) {
        if (!this._secondaryDiapasonView || !this._isSecondaryDiapasonVisible) return;

        const state = overrideState || this._getCurrentActiveHighlightState();
        if (!state || !state.notes || state.notes.length === 0) {
            this._secondaryDiapasonView.clearHighlights();
            return;
        }

        const bellowsMode = this._secondaryBellowsMode || state.bellowsMode || this._bellowsMachine.mode;
        const isExactMidi = Boolean(state.isExactMidi);
        let targetNotes = [...state.notes];

        if (this._secondaryEquivalenceMode === 'relative') {
            // Modo "Misma Hilera / Digitación": transporta por la diferencia de afinaciones
            const semitoneShift = this._secondaryOffset - this._currentOffset;
            if (isExactMidi) {
                targetNotes = targetNotes.map(m => m + semitoneShift);
            } else {
                const shift = ((semitoneShift % 12) + 12) % 12;
                targetNotes = targetNotes.map(p => (p + shift) % 12);
            }
            this._secondaryDiapasonView.highlightChord(
                this._secondaryAccordionData,
                targetNotes,
                isExactMidi,
                bellowsMode,
                state.excludedButtons || null
            );
        } else {
            // Modo "Mismo Tono": mantiene la tonalidad real (exactos mismos pitch classes)
            if (isExactMidi) {
                targetNotes = targetNotes.map(m => getPitchClass(m));
            }
            this._secondaryDiapasonView.highlightChord(
                this._secondaryAccordionData,
                targetNotes,
                false,
                bellowsMode,
                state.excludedButtons || null
            );
        }
    }

    /**
     * Renderiza el diapasón y vincula clics en botones físicos.
     * @private
     */
    _renderDiapason() {
        this._updateRowSelectorButtons();
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
        const direction = (noteToPlay === buttonData.pull) ? 'pull' : 'push';
        if (!this._isDiapasonMuted && this._diapasonVolume > 0) {
            audioEngine.play(noteToPlay, "8n", this._diapasonVolume / 100);
        }
        this._diapasonView.triggerGlowOnElement(btnEl, direction);
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
            this._syncSecondaryDiapason({
                notes: [currentStep.pitchClass],
                isExactMidi: false,
                bellowsMode: this._bellowsMachine.mode
            });
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
            this._syncSecondaryDiapason({
                notes: currentStep.chordPitchClasses,
                isExactMidi: false,
                bellowsMode: this._bellowsMachine.mode
            });
            if (shouldPlay) {
                audioEngine.play(currentStep.chordAbsoluteMidis);
            }
        } else {
            this._syncSecondaryDiapason({
                notes: [currentStep.pitchClass],
                isExactMidi: false,
                bellowsMode: this._bellowsMachine.mode
            });
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
     * @param {string|null} [bellowsFilter=null] Filtro opcional ('both', 'push', 'pull')
     * @returns {Array}
     */
    calculateExecutionForms(noteTarget, isExactMidi = false, bellowsFilter = null) {
        const forms = [];
        const rowsOrder = [this._activeRowKey, ...['row3', 'row2', 'row1'].filter(r => r !== this._activeRowKey)];
        const effectiveBellows = bellowsFilter || this._bellowsMachine.mode;

        rowsOrder.forEach(r => {
            if (!this._accordionData[r]) return;
            this._accordionData[r].forEach(b => {
                const pTarget = isExactMidi ? b.push : getPitchClass(b.push);
                const plTarget = isExactMidi ? b.pull : getPitchClass(b.pull);

                const isPushMatch = pTarget === noteTarget;
                const isPullMatch = plTarget === noteTarget;

                if (isPushMatch && (effectiveBellows === BELLOWS_MODES.BOTH || effectiveBellows === BELLOWS_MODES.PUSH)) {
                    forms.push({
                        btnId: b.id,
                        rowName: ROW_NAMES[r],
                        rowKey: r,
                        btnNum: b.btnIndex,
                        direction: 'Cerrar',
                        directionClass: 'push',
                        midi: b.push,
                        isNatural: r === this._activeRowKey
                    });
                }
                if (isPullMatch && (effectiveBellows === BELLOWS_MODES.BOTH || effectiveBellows === BELLOWS_MODES.PULL)) {
                    forms.push({
                        btnId: b.id,
                        rowName: ROW_NAMES[r],
                        rowKey: r,
                        btnNum: b.btnIndex,
                        direction: 'Abrir',
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
     * Calcula las opciones de ejecución completas e independientes de hilera para un acorde libre.
     * @param {Object} chordData
     * @returns {Array}
     */
    calculateChordExecutionForms(chordData) {
        if (!chordData) return [];
        const forms = [];
        const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._bellowsMachine.mode;

        // Opción 1: Tocar todo el acorde completo en el diapasón
        forms.push({
            btnId: 'all_chord_notes',
            isFullChord: true,
            rowName: 'Diapasón Completo',
            rowKey: 'all',
            btnNum: '★',
            direction: 'Acorde Completo',
            directionClass: 'both',
            midi: chordData.playbackMidis,
            isNatural: true,
            customLabel: `✨ Acorde Completo: ${chordData.typeName} (Todas las notas)`
        });

        // Opciones por cada una de las notas del acorde a través de TODAS las hileras (sin sesgo)
        const allRows = ['row1', 'row2', 'row3'];
        chordData.intervals.forEach((interval, idx) => {
            const role = chordData.roles[idx] || '';
            const targetMod = ((chordData.root + interval) % 12 + 12) % 12;
            const targetMidi = chordData.playbackMidis[idx];
            const noteName = midiToName(targetMidi, this._currentNotation, true, this._currentOffset);

            allRows.forEach(r => {
                if (!this._accordionData[r]) return;
                this._accordionData[r].forEach(b => {
                    const pMatch = chordData.isExactMidi ? (b.push === targetMidi) : (getPitchClass(b.push) === targetMod);
                    const plMatch = chordData.isExactMidi ? (b.pull === targetMidi) : (getPitchClass(b.pull) === targetMod);

                    if (pMatch && (bellowsMode === BELLOWS_MODES.BOTH || bellowsMode === BELLOWS_MODES.PUSH)) {
                        forms.push({
                            btnId: b.id,
                            isFullChord: false,
                            rowName: ROW_NAMES[r],
                            rowKey: r,
                            btnNum: b.btnIndex,
                            direction: 'Cerrar',
                            directionClass: 'push',
                            midi: b.push,
                            isNatural: false,
                            customLabel: `${role} (${noteName}): ${ROW_NAMES[r]} B${b.btnIndex} [Cerrar]`
                        });
                    }
                    if (plMatch && (bellowsMode === BELLOWS_MODES.BOTH || bellowsMode === BELLOWS_MODES.PULL)) {
                        forms.push({
                            btnId: b.id,
                            isFullChord: false,
                            rowName: ROW_NAMES[r],
                            rowKey: r,
                            btnNum: b.btnIndex,
                            direction: 'Abrir',
                            directionClass: 'pull',
                            midi: b.pull,
                            isNatural: false,
                            customLabel: `${role} (${noteName}): ${ROW_NAMES[r]} B${b.btnIndex} [Abrir]`
                        });
                    }
                });
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
        const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._bellowsMachine.mode;
        this._chordView.updateDisplay(
            chord,
            this._accordionData,
            bellowsMode,
            this._currentNotation,
            this._currentOffset
        );
    }

    /**
     * Resalta y reproduce un acorde libre en el acordeón delegando en TheoryInteractionController.
     * @private
     */
    _showFreeChordOnAccordion(chordData, shouldPlay = false) {
        if (this._theoryController) {
            this._theoryController.showFreeChordOnAccordion(chordData, shouldPlay);
        }
    }

    /**
     * Selecciona y resalta una nota específica dentro del arpegio del acorde libre.
     * @param {number} idx
     * @param {boolean} [shouldPlay=true]
     */
    selectChordNote(idx, shouldPlay = true) {
        if (this._theoryController) {
            this._theoryController.selectChordNote(idx, shouldPlay);
        }
    }

    /**
     * Reproduce arpegio del acorde libre paso a paso.
     */
    async playChordArpeggio() {
        if (this._theoryController) {
            await this._theoryController.playChordArpeggio();
        }
    }

    /**
     * Mantiene sonando el acorde fijado.
     * @private
     */
    _holdChordAudio(chordData) {
        if (this._theoryController) {
            this._theoryController.holdChordAudio(chordData);
        }
    }

    /**
     * Desfija el acorde libre y restablece la escala.
     */
    unpinChord() {
        if (this._theoryController) {
            this._theoryController.unpinChord();
        }
    }

    // =========================================================================
    // SECCIÓN DEL DETECTOR INTELIGENTE
    // =========================================================================

    /**
     * Alterna la selección de un botón en el detector.
     * @private
     */
    _toggleDetectorButton(btnId, rowKey, btnIndex, direction, midi) {
        if (this._theoryController) {
            this._theoryController.handleDetectorButtonClick(btnId, direction, midi);
        }
    }

    /**
     * Actualiza la tira del detector y calcula el análisis armónico delegando en TheoryInteractionController.
     * @private
     */
    _updateDetectorUI() {
        if (this._theoryController) {
            this._theoryController.updateDetectorUI();
        }
    }

    /**
     * Toca todas las notas del acorde detectado juntas.
     */
    playDetectorChord() {
        if (this._theoryController) {
            this._theoryController.playDetectorChord();
        }
    }

    /**
     * Reproduce arpegio de las notas seleccionadas en el detector.
     */
    async playDetectorArpeggio() {
        if (this._theoryController) {
            await this._theoryController.playDetectorArpeggio();
        }
    }
}
