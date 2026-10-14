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
     * @param {import('../ui/DiapasonView.js').DiapasonView} [views.secondaryDiapasonView]
     * @param {import('../ui/ScaleBarView.js').ScaleBarView} views.scaleBarView
     * @param {import('../ui/ChordView.js').ChordView} views.chordView
     * @param {import('../ui/DetectorView.js').DetectorView} views.detectorView
     * @param {import('../ui/ExecutionView.js').ExecutionView} views.executionView
     * @param {import('../ui/AudioTrackView.js').AudioTrackView} [views.audioTrackView]
     * @param {import('../ui/CadenceView.js').CadenceView} [views.cadenceView]
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
        this._cadenceView = views.cadenceView;
        this._diapasonChordSidebarView = views.diapasonChordSidebarView;

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

        // Estado del Segundo Diapasón (Acordeón Comparativo / Equivalente)
        this._secondaryOffset = 0; // Por defecto Cinco Letras (Bb - Eb - Ab)
        this._secondaryEquivalenceMode = 'pitch'; // 'pitch' (Mismo Tono) | 'relative' (Misma Hilera)
        this._secondaryBellowsMode = BELLOWS_MODES.BOTH;
        this._isSecondaryDiapasonVisible = typeof localStorage !== 'undefined'
            ? localStorage.getItem('acordeon_secondary_visible') !== 'false'
            : true;
        this._secondaryAccordionData = getTransposedAccordion(this._secondaryOffset);

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
        if (this._secondaryDiapasonView) {
            this._secondaryDiapasonView.setMirrored(this._isDiapasonMirrored);
        }
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
        this._updateMirrorButtonUI();
        this._updateRowSelectorButtons();
        this._updatePrimaryTuningLabel();
        this._renderAll();
        this._renderSecondaryDiapason();
        this._syncSecondaryDiapason();
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
                // Mostrar en el diapasón los botones del acorde respetando la preferencia Abre / Cierra definida
                const bellowsFilter = chord.bellowsAction || this._bellowsMachine.mode;
                this._diapasonView.highlightChord(
                    this._accordionData,
                    chord.noteMods,
                    false,
                    bellowsFilter
                );
                this._syncSecondaryDiapason({
                    notes: chord.noteMods,
                    isExactMidi: false,
                    bellowsMode: bellowsFilter
                });
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
                if (this._secondaryDiapasonView) {
                    this._secondaryDiapasonView.setMirrored(this._isDiapasonMirrored);
                }
                this._updateMirrorButtonUI();
                this._renderDiapason();
                this._renderSecondaryDiapason();
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
                this._showFreeChordOnAccordion(chord, false);
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
            this._scaleOctaveMode || 'progressive'
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
        this._updateCadenceView();
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
     * Actualiza el estado visual y texto del botón de Modo Espejo.
     * @private
     */
    _updateMirrorButtonUI() {
        const btnToggleMirror = document.getElementById('btnToggleMirror');
        const lblMirrorStatus = document.getElementById('lblMirrorStatus');
        if (!btnToggleMirror) return;

        if (this._isDiapasonMirrored) {
            btnToggleMirror.classList.add('active');
            if (lblMirrorStatus) lblMirrorStatus.textContent = 'Af->Ad';
            btnToggleMirror.title = 'Orientación de hileras: Afuera (1) a la izquierda, Adentro (3) a la derecha (Af->Ad). Clic para alternar a Ad<-Af.';
        } else {
            btnToggleMirror.classList.remove('active');
            if (lblMirrorStatus) lblMirrorStatus.textContent = 'Ad<-Af';
            btnToggleMirror.title = 'Orientación de hileras: Adentro (3) a la izquierda, Afuera (1) a la derecha (Ad<-Af). Clic para alternar a Af->Ad.';
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
            });
        }

        // Toggle de Modo de Equivalencia (Mismo Tono / Misma Hilera)
        document.querySelectorAll('#secondaryEquivalenceToggle .segment-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('#secondaryEquivalenceToggle .segment-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this._secondaryEquivalenceMode = btn.dataset.mode;
                this._syncSecondaryDiapason();
            });
        });

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

        // Botón de alternancia de visibilidad del 2do diapasón con texto dinámico y persistencia
        const btnToggle = document.getElementById('btnToggleSecondaryDiapason');
        const secondaryCol = document.getElementById('secondaryDiapasonCol');

        const updateToggleBtnState = () => {
            if (!btnToggle || !secondaryCol) return;
            if (this._isSecondaryDiapasonVisible) {
                btnToggle.classList.add('active');
                btnToggle.innerHTML = '<i class="fas fa-columns"></i> 2do Acordeón: ON';
                secondaryCol.classList.remove('hidden');
                secondaryCol.style.display = '';
            } else {
                btnToggle.classList.remove('active');
                btnToggle.innerHTML = '<i class="fas fa-columns"></i> 2do Acordeón: OFF';
                secondaryCol.classList.add('hidden');
                secondaryCol.style.display = 'none';
            }
        };

        if (btnToggle && secondaryCol) {
            updateToggleBtnState();
            btnToggle.addEventListener('click', () => {
                this._isSecondaryDiapasonVisible = !this._isSecondaryDiapasonVisible;
                try {
                    localStorage.setItem('acordeon_secondary_visible', this._isSecondaryDiapasonVisible.toString());
                } catch (e) {
                    console.warn('[AppController] No se pudo persistir visibilidad 2do diapasón:', e);
                }
                updateToggleBtnState();
                if (this._isSecondaryDiapasonVisible) {
                    this._renderSecondaryDiapason();
                    this._syncSecondaryDiapason();
                }
                this._updateCadenceView();
                this._updateSidebarChordsView();
            });
        }
    }

    /**
     * Actualiza la sección de Armonía Diatónica: Cuarta y Quinta.
     * @private
     */
    _updateCadenceView() {
        if (!this._cadenceView) return;

        const rootPitchClass = getPitchClass(this._activeScaleRoot);
        const cadenceChords = getCadenceChords(
            rootPitchClass,
            this._selectedScaleType,
            this._currentNotation,
            this._currentOffset
        );

        const secAccordion = this._isSecondaryDiapasonVisible ? this._secondaryAccordionData : null;

        this._cadenceView.render(
            cadenceChords,
            this._accordionData,
            secAccordion,
            this._currentNotation,
            this._currentOffset,
            this._secondaryOffset,
            (selectedCadenceChord) => {
                // Al hacer clic en Tónica, Cuarta o Quinta:
                // 1. Resaltar en Diapasón 1
                this._diapasonView.highlightChord(
                    this._accordionData,
                    selectedCadenceChord.noteMods,
                    false,
                    this._bellowsMachine.mode
                );

                // 2. Resaltar en Diapasón 2 (Segundo Acordeón)
                this._syncSecondaryDiapason({
                    notes: selectedCadenceChord.noteMods,
                    isExactMidi: false,
                    bellowsMode: this._secondaryBellowsMode || this._bellowsMachine.mode
                });

                // 3. Reproducir sonido del acorde
                audioEngine.play(selectedCadenceChord.playbackMidis);

                // 4. Actualizar las barras laterales de acordes a la derecha de ambos diapasones
                this._updateSidebarChordsView(selectedCadenceChord);

                // 5. Actualizar digitaciones en ejecución
                const forms = this.calculateExecutionForms(selectedCadenceChord.rootPitchClass, false);
                this._executionView.setNoteLabel(`${selectedCadenceChord.chordName} (${selectedCadenceChord.roleName})`);
                this._executionView.renderForms(forms, (selectedForm) => {
                    this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
                    this._syncSecondaryDiapason({
                        notes: [selectedCadenceChord.rootPitchClass],
                        isExactMidi: false,
                        bellowsMode: this._secondaryBellowsMode || this._bellowsMachine.mode
                    });
                    audioEngine.play(selectedForm.midi);
                });
            }
        );
    }

    /**
     * Actualiza la barra lateral a la derecha de cada diapasón con los botones Abre y Cierra.
     * @private
     * @param {Object} [chord=null]
     */
    _updateSidebarChordsView(chord = null) {
        if (!this._diapasonChordSidebarView) return;

        let targetChord = chord;
        if (!targetChord) {
            const rootPitchClass = getPitchClass(this._activeScaleRoot);
            const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, this._currentOffset);
            const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, this._currentOffset);
            const isMinor = this._selectedScaleType === 'minor' || this._selectedScaleType === 'harmonic_minor';
            const intervals = isMinor ? [0, 3, 7] : [0, 4, 7];
            targetChord = {
                chordName: `${arrLat[rootPitchClass]} ${isMinor ? 'Menor' : 'Mayor'}`.trim(),
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
            }
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
                    audioEngine.play(tonicMidi);
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

        audioEngine.play(noteToPlay);
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
        audioEngine.play(noteToPlay);
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
                        direction: 'Cerrar (Push)',
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
                            direction: 'Cerrar (Push)',
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
                            direction: 'Abrir (Pull)',
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
     * Resalta y reproduce un acorde libre en el acordeón.
     * @private
     */
    _showFreeChordOnAccordion(chordData, shouldPlay = false) {
        const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._bellowsMachine.mode;
        this._diapasonView.highlightChord(
            this._accordionData,
            chordData.targetNotes,
            chordData.isExactMidi,
            bellowsMode
        );
        this._syncSecondaryDiapason({
            notes: chordData.targetNotes,
            isExactMidi: chordData.isExactMidi,
            bellowsMode
        });
        this._chordView.showClearButton();

        if (shouldPlay) {
            let midisToPlay = chordData.playbackMidis;
            if (bellowsMode === BELLOWS_MODES.PUSH || bellowsMode === BELLOWS_MODES.PULL) {
                const feasibility = FeasibilityAnalysisStrategy.check(chordData, this._accordionData, bellowsMode);
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

        const bellowsMode = this._chordView ? this._chordView.bellowsMode : this._bellowsMachine.mode;
        this._executionView.setNoteLabel(`${noteName} (${roleName})`);

        const forms = this.calculateExecutionForms(target, chord.isExactMidi, bellowsMode);
        this._executionView.renderForms(forms, (selectedForm) => {
            this._diapasonView.highlightSingleButton(selectedForm.btnId, selectedForm.directionClass);
            this._syncSecondaryDiapason({
                notes: [target],
                isExactMidi: chord.isExactMidi,
                bellowsMode
            });
            audioEngine.play(selectedForm.midi);
        });

        if (forms.length > 0) {
            this._diapasonView.highlightSingleButton(forms[0].btnId, forms[0].directionClass);
            this._syncSecondaryDiapason({
                notes: [target],
                isExactMidi: chord.isExactMidi,
                bellowsMode
            });
            if (shouldPlay) {
                audioEngine.play(forms[0].midi);
            }
        } else {
            this._diapasonView.clearHighlights();
            if (this._secondaryDiapasonView) this._secondaryDiapasonView.clearHighlights();
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
            this._syncSecondaryDiapason();
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
