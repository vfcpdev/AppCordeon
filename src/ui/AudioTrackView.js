/**
 * @fileoverview Vista del Analizador de Pistas de Audio MP3 y Sincronizador de Acordes (SRP).
 * Gestiona el panel de carga de archivos, visualización de tonalidad principal,
 * barra de progreso, ajuste de tono (pitch shifting / transposición) y acordes en tiempo real.
 * @module ui/AudioTrackView
 */

import { audioChordAnalyzer } from '../audio/AudioChordAnalyzer.js';
import { audioPlayerController } from '../audio/AudioPlayerController.js';
import { metronomeEngine } from '../audio/MetronomeEngine.js';
import { getNoteNamesList, parseChordNotation, formatChordInputString } from '../theory/MusicTheory.js';
import { NOTATION_MODES, ROW_BASE_TONICS } from '../core/Constants.js';
import { eventBus } from '../core/EventBus.js';
import { tuningRegistry } from '../models/Tunings.js';
import { audioEngine } from '../audio/AudioEngine.js';
import { MeasureGridComponent } from './MeasureGridComponent.js';
import { ChordSequenceEditor } from './ChordSequenceEditor.js';

export class AudioTrackView {
    /**
     * @param {Object} elements Referencias a elementos del DOM
     */
    constructor(elements) {
        this._container = elements.container;
        this._fileInput = elements.fileInput;
        this._dropZone = elements.dropZone;
        this._progressContainer = elements.progressContainer;
        this._progressBar = elements.progressBar;
        this._progressText = elements.progressText;

        this._trackInfoCard = elements.trackInfoCard;
        this._fileNameLabel = elements.fileNameLabel;
        this._mainKeyBadge = elements.mainKeyBadge;
        this._audioKeySelect = elements.audioKeySelect;
        this._tuningRecommendation = elements.tuningRecommendation;
        this._btnApplyTuning = elements.btnApplyTuning;

        this._playbackControls = elements.playbackControls;
        this._btnPlayPause = elements.btnPlayPause;
        this._btnStop = elements.btnStop;
        this._timeDisplay = elements.timeDisplay;
        this._timelineSeeker = elements.timelineSeeker;
        this._activeChordBadge = elements.activeChordBadge;
        this._chkSyncDiapason = elements.chkSyncDiapason;
        this._chordsStrip = elements.chordsStrip;

        // Nuevos controles de transporte, metrónomo, velocidad y cuadrícula
        this._measureGridContainer = document.getElementById('audioMeasureGridContainer');
        this._secondaryMeasureGridContainer = document.getElementById('secondaryAudioMeasureGridContainer');
        this._secondaryGridWrapper = document.getElementById('secondaryChordMeasureGridWrapper');
        this._gridPanel = document.getElementById('primaryChordGridPanel');
        this._btnPrevMeasure = document.getElementById('btnPrevMeasure');
        this._btnNextMeasure = document.getElementById('btnNextMeasure');
        this._btnToggleMetronome = document.getElementById('btnToggleMetronome');
        this._metronomeToggleLabel = document.getElementById('metronomeToggleLabel');
        this._audioSpeedSelect = document.getElementById('audioSpeedSelect');
        this._btnBpmMinus = document.getElementById('btnBpmMinus');
        this._btnBpmPlus = document.getElementById('btnBpmPlus');
        this._playerBpmDisplay = document.getElementById('playerBpmDisplay');
        this._playerBpmInput = document.getElementById('playerBpmInput');
        this._audioTimeCurrent = document.getElementById('audioTimeCurrent');
        this._audioTimeRemaining = document.getElementById('audioTimeRemaining');
        this._activeChordTitle = document.getElementById('activeChordTitle');
        this._btnEditActiveChord = document.getElementById('btnEditActiveChord');
        this._activeMeasureBeatInfo = document.getElementById('activeMeasureBeatInfo');

        // Control de volumen del sonido del acorde en el reproductor
        this._btnToggleChordMute = document.getElementById('btnToggleChordMute');
        this._iconChordVolume = document.getElementById('iconChordVolume');
        this._playerChordVolumeSlider = document.getElementById('playerChordVolumeSlider');
        this._playerChordVolumeDisplay = document.getElementById('playerChordVolumeDisplay');

        this._currentBpm = 120;
        this._activeBeatSlot = null;
        this._activeMeasureRow = null;
        this._secActiveBeatSlot = null;
        this._secActiveMeasureRow = null;
        this._lastScrollMeasure = -1;
        this._lblAnalysisEngine = document.getElementById('lblAnalysisEngine');

        // Mini-popover para edición rápida en cuadrícula
        this._chordMeasureGridWrapper = document.getElementById('chordMeasureGridWrapper');
        this._miniPopover = document.getElementById('gridChordMiniPopover');
        this._miniPopoverTitle = document.getElementById('miniPopoverTitle');
        this._miniPopoverInput = document.getElementById('miniPopoverChordInput');
        this._miniPopoverFeedback = document.getElementById('miniPopoverFeedback');
        this._btnMiniDelete = document.getElementById('btnMiniPopoverDelete');
        this._btnMiniCancel = document.getElementById('btnMiniPopoverCancel');
        this._btnMiniSave = document.getElementById('btnMiniPopoverSave');
        this._btnMiniNext = document.getElementById('btnMiniPopoverNext');
        this._btnMiniClose = document.getElementById('btnMiniPopoverClose');
        this._activeMiniSlot = null;
        this._isDraggingGrid = false;
        this._dragStartBeat = null;
        this._dragEndBeat = null;
        this._selectedGridRange = null;
        this._selectedSequence = [];

        // Controles de volumen del metrónomo
        this._playerMetronomeVolumeSlider = document.getElementById('playerMetronomeVolumeSlider');
        this._playerMetronomeVolumeDisplay = document.getElementById('playerMetronomeVolumeDisplay');
        this._btnToggleMetronomeMute = document.getElementById('btnToggleMetronomeMute');
        this._iconMetronomeVolume = document.getElementById('iconMetronomeVolume');
        this._isMetronomeMuted = false;
        this._lastMetronomeVolume = 0.70;

        // Botones de gestión de cuadrícula: Seleccionar Todo, Borrar Selección, Borrar Todo, + Compás, etc.
        this._btnSelectAllGridSlots = document.getElementById('btnSelectAllGridSlots');
        this._btnDeleteSelectedSlots = document.getElementById('btnDeleteSelectedSlots');
        this._btnExportChordsCsv = document.getElementById('btnExportChordsCsv');
        this._btnImportChordsCsv = document.getElementById('btnImportChordsCsv');
        this._inputImportChordsCsv = document.getElementById('inputImportChordsCsv');
        this._btnClearAllGridChords = document.getElementById('btnClearAllGridChords');
        this._btnAddMeasureRow = document.getElementById('btnAddMeasureRow');
        this._btnManualProgressionInput = document.getElementById('btnManualProgressionInput');

        // Modal emergente para digitar progresión completa
        this._manualProgModal = document.getElementById('manualProgressionModal');
        this._manualProgInput = document.getElementById('manualProgressionInput');
        this._manualProgDurationSelect = document.getElementById('manualProgDurationSelect');
        this._chkManualProgReplaceAll = document.getElementById('chkManualProgReplaceAll');
        this._manualProgFeedback = document.getElementById('manualProgFeedback');
        this._btnManualProgClose = document.getElementById('btnManualProgClose');
        this._btnManualProgCancel = document.getElementById('btnManualProgCancel');
        this._btnManualProgApply = document.getElementById('btnManualProgApply');

        // Modo Desacoplado / Ventana Completa para la cuadrícula
        this._isGridUndocked = false;
        this._gridCols = '4'; // 4 compases por fila por defecto en ventana completa
        this._gridRows = '3'; // 3 filas visibles por defecto en modo normal
        this._btnUndockChordGrid = document.getElementById('btnUndockChordGrid');
        this._iconUndockChordGrid = document.getElementById('iconUndockChordGrid');
        this._lblUndockChordGrid = document.getElementById('lblUndockChordGrid');
        this._gridColsPillGroup = document.getElementById('gridColsPillGroup');
        this._btnConfigGridRows = document.getElementById('btnConfigGridRows');
        this._gridRowsConfigModal = document.getElementById('gridRowsConfigModal');
        this._inputGridRowsCount = document.getElementById('inputGridRowsCount');
        this._btnGridRowsModalClose = document.getElementById('btnGridRowsModalClose');
        this._btnGridRowsModalCancel = document.getElementById('btnGridRowsModalCancel');
        this._btnGridRowsModalApply = document.getElementById('btnGridRowsModalApply');
        this._gridRowsModalFeedback = document.getElementById('gridRowsModalFeedback');

        // Controles de Ajuste de Tono (Pitch Shift)
        this._btnPitchDown = elements.btnPitchDown;
        this._btnPitchUp = elements.btnPitchUp;
        this._btnPitchReset = elements.btnPitchReset;
        this._lblPitchShift = elements.lblPitchShift;

        // Controles de Afinación de Acordeón Objetivo
        this._audioAccordionSelect = elements.audioAccordionSelect;
        this._audioAccordionRowsContainer = elements.audioAccordionRowsContainer;
        this._btnSyncTuningToDiapason = elements.btnSyncTuningToDiapason;

        // Modal de Edición de Acordes del Timeline
        this._btnAddChord = elements.btnAddChord || document.getElementById('btnAddChordAtCurrentTime');
        this._modal = document.getElementById('chordEditorModal');
        this._modalBackdrop = document.getElementById('chordEditorBackdrop');
        this._btnCloseModal = document.getElementById('btnCloseChordEditor');
        this._btnCancelModal = document.getElementById('btnCancelEditorChord');
        this._btnSaveModal = document.getElementById('btnSaveEditorChord');
        this._btnDeleteModal = document.getElementById('btnDeleteEditorChord');
        this._btnSetStartCurrentTime = document.getElementById('btnSetStartCurrentTime');
        this._btnSetEndCurrentTime = document.getElementById('btnSetEndCurrentTime');
        this._chkAutoAdjustAdjacent = document.getElementById('chkAutoAdjustAdjacent');
        this._editorRootSelect = document.getElementById('editorChordRoot');
        this._editorTypeSelect = document.getElementById('editorChordType');
        this._editorStartInput = document.getElementById('editorChordStart');
        this._editorEndInput = document.getElementById('editorChordEnd');

        this._editingChordIndex = -1;

        // Barra de desplazamiento con marcadores visuales de acordes
        this._trackSeekerContainer = document.getElementById('trackSeekerContainer');
        this._chordProgressBarTrack = document.getElementById('chordProgressBarTrack');
        this._chordTrackPlayhead = document.getElementById('chordTrackPlayhead');

        // Barra flotante rápida de edición y extensión
        this._chordQuickToolbar = document.getElementById('chordQuickToolbar');
        this._quickChordName = document.getElementById('quickChordName');
        this._quickChordTimes = document.getElementById('quickChordTimes');
        this._btnCloseQuickToolbar = document.getElementById('btnCloseQuickToolbar');
        this._btnExtendMinus = document.getElementById('btnExtendMinus');
        this._btnExtendPlus = document.getElementById('btnExtendPlus');
        this._btnExtendToCurrent = document.getElementById('btnExtendToCurrent');
        this._quickRootSelect = document.getElementById('quickRootSelect');
        this._quickTypeSelect = document.getElementById('quickTypeSelect');
        this._btnApplyReplaceChord = document.getElementById('btnApplyReplaceChord');
        this._btnQuickDeleteChord = document.getElementById('btnQuickDeleteChord');
        this._btnQuickOpenEditor = document.getElementById('btnQuickOpenEditor');
        this._selectedQuickChordIndex = -1;

        this._originalAnalysisData = null;
        this._currentPitchShift = 0;
        this._onChordMarkerClick = (seekTime) => {
            audioPlayerController.seek(seekTime);
        };
        this._selectedAccordionTuningId = null;
        this._selectedAccordionRowKey = 'row2';
        this._handlers = null;

        // Progresión predeterminada (Cinco Letras / Vallenato tradicional)
        const defaultChords = [
            { root: 10, chordType: 'major', chordName: 'Si♭ (Bb)', chordSymbol: 'Bb', noteMods: [10, 2, 5], startTime: 0, endTime: 4, confidence: 1.0, bassNote: 10, bellowsAction: 'both' },
            { root: 3, chordType: 'major', chordName: 'Mi♭ (Eb)', chordSymbol: 'Eb', noteMods: [3, 7, 10], startTime: 4, endTime: 8, confidence: 1.0, bassNote: 3, bellowsAction: 'both' },
            { root: 5, chordType: '7', chordName: 'Fa 7 (F7)', chordSymbol: 'F7', noteMods: [5, 9, 0, 3], startTime: 8, endTime: 12, confidence: 1.0, bassNote: 5, bellowsAction: 'both' },
            { root: 10, chordType: 'major', chordName: 'Si♭ (Bb)', chordSymbol: 'Bb', noteMods: [10, 2, 5], startTime: 12, endTime: 16, confidence: 1.0, bassNote: 10, bellowsAction: 'both' }
        ];

        this._currentAnalysisData = {
            duration: 16,
            bpm: 120,
            mainKey: {
                rootMod: 10,
                mode: 'major',
                keyNameLat: 'Si♭ Mayor',
                keyNameEng: 'Bb Major',
                keyNameAle: 'Bb Major',
                recommendedTuning: 'Cinco Letras (Bb-Eb-Ab)',
                recommendedOffset: 10,
                recommendedRow: 'row1'
            },
            chords: defaultChords
        };
        this._originalAnalysisData = this._currentAnalysisData;

        this._initChordEditor();
        this._initChordQuickToolbar();
        this._initTransportAndMetronome();
        this._initMiniChordPopover();

        if (this._btnEditActiveChord) {
            this._btnEditActiveChord.addEventListener('click', (e) => {
                e.stopPropagation();
                const curTime = audioPlayerController.currentTime || 0;
                const timeline = (this._currentAnalysisData && this._currentAnalysisData.chords) || [];
                const chordIdx = timeline.findIndex(c => curTime >= c.startTime && curTime < c.endTime);
                this._openChordEditor(chordIdx, curTime);
            });
        }

        // Poblar selector de tono con la tonalidad inicial (solo visual)
        this._populateKeySelect(this._currentAnalysisData.mainKey);

        // Renderizar cuadrícula de compases inmediatamente
        this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, this._currentBpm);
        this.renderChordsStrip(this._currentAnalysisData.chords, this._onChordMarkerClick);
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, this._currentBpm);
        audioPlayerController.setChordsTimeline(this._currentAnalysisData.chords);
    }

    /**
     * Vincula eventos de la vista de audio.
     * @param {Object} handlers
     */
    bindEvents(handlers) {
        this._handlers = handlers;

        if (this._fileInput) {
            this._fileInput.addEventListener('change', (e) => {
                if (e.target.files && e.target.files[0]) {
                    handlers.onFileSelected(e.target.files[0]);
                }
            });
        }

        if (this._dropZone) {
            this._dropZone.addEventListener('dragover', (e) => {
                e.preventDefault();
                this._dropZone.classList.add('drag-over');
            });
            this._dropZone.addEventListener('dragleave', () => {
                this._dropZone.classList.remove('drag-over');
            });
            this._dropZone.addEventListener('drop', (e) => {
                e.preventDefault();
                this._dropZone.classList.remove('drag-over');
                if (e.dataTransfer.files && e.dataTransfer.files[0]) {
                    handlers.onFileSelected(e.dataTransfer.files[0]);
                }
            });
        }

        if (this._btnPlayPause) {
            this._btnPlayPause.addEventListener('click', handlers.onPlayPause);
        }

        if (this._btnStop) {
            this._btnStop.addEventListener('click', handlers.onStop);
        }

        if (this._timelineSeeker) {
            this._timelineSeeker.addEventListener('input', (e) => {
                const percent = parseFloat(e.target.value);
                handlers.onSeek(percent);
            });
        }

        if (this._trackSeekerContainer) {
            this._trackSeekerContainer.addEventListener('click', (e) => {
                if (e.target.closest('.chord-segment-block') || e.target.closest('.chord-segment-handle-right')) return;
                const rect = this._trackSeekerContainer.getBoundingClientRect();
                const percent = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
                if (handlers && handlers.onSeek) {
                    handlers.onSeek(percent);
                } else {
                    const dur = audioPlayerController.duration || (this._currentAnalysisData && this._currentAnalysisData.duration) || 16;
                    audioPlayerController.seek(percent * dur);
                }
            });
        }

        if (this._btnApplyTuning) {
            this._btnApplyTuning.addEventListener('click', () => {
                const data = this._currentAnalysisData || this._originalAnalysisData;
                if (data && data.mainKey && handlers.onApplyTuning) {
                    handlers.onApplyTuning(
                        data.mainKey.recommendedOffset,
                        data.mainKey.recommendedRow
                    );
                }
            });
        }

        if (this._chkSyncDiapason) {
            this._chkSyncDiapason.addEventListener('change', (e) => {
                if (handlers.onSyncToggle) {
                    handlers.onSyncToggle(e.target.checked);
                }
            });
        }

        // Eventos de ajuste de tono
        if (this._btnPitchDown) {
            this._btnPitchDown.addEventListener('click', () => {
                this.setPitchShift(this._currentPitchShift - 1, handlers);
            });
        }

        if (this._btnPitchUp) {
            this._btnPitchUp.addEventListener('click', () => {
                this.setPitchShift(this._currentPitchShift + 1, handlers);
            });
        }

        if (this._btnPitchReset) {
            this._btnPitchReset.addEventListener('click', () => {
                this.setPitchShift(0, handlers);
            });
        }

        // Selector manual de tono de referencia (solo visual: recalcula todos los acordes con referencia al tono ajustado)
        if (this._audioKeySelect) {
            this._audioKeySelect.addEventListener('change', (e) => {
                if (!this._originalAnalysisData || !this._originalAnalysisData.mainKey) return;
                const [targetRootStr, targetMode] = e.target.value.split('_');
                const targetRoot = parseInt(targetRootStr, 10);
                const originalRoot = this._originalAnalysisData.mainKey.rootMod;

                let diff = (targetRoot - originalRoot + 12) % 12;
                if (diff > 6) diff -= 12; // Transposición más cercana (-6 a +6)

                this.setPitchShift(diff, handlers || this._handlers, targetMode);
            });
        }

        // Selector de Tipos de Tonalidades / Afinaciones en Acordeones
        if (this._audioAccordionSelect) {
            this._audioAccordionSelect.addEventListener('change', (e) => {
                const val = e.target.value;
                if (val === 'original') {
                    this._selectedAccordionTuningId = null;
                    this.setPitchShift(0, handlers);
                    this._renderAccordionRowButtons(handlers);
                    return;
                }
                this._selectedAccordionTuningId = val;
                this._applySelectedAccordionTuning(handlers);
            });
        }

        // Botón para sincronizar la afinación seleccionada directamente con el acordeón virtual
        if (this._btnSyncTuningToDiapason) {
            this._btnSyncTuningToDiapason.addEventListener('click', () => {
                if (!handlers || !handlers.onApplyTuning) return;

                if (!this._selectedAccordionTuningId && this._currentAnalysisData && this._currentAnalysisData.mainKey) {
                    handlers.onApplyTuning(
                        this._currentAnalysisData.mainKey.recommendedOffset,
                        this._currentAnalysisData.mainKey.recommendedRow || 'row2'
                    );
                    return;
                }

                const tuning = tuningRegistry.get(this._selectedAccordionTuningId);
                if (tuning) {
                    handlers.onApplyTuning(tuning.offset, this._selectedAccordionRowKey || 'row2');
                }
            });
        }
    }

    /**
     * Muestra la barra de progreso de análisis de audio.
     * @param {number} percent 0 a 100
     * @param {string} [message="Analizando audio..."]
     */
    showProgress(percent, message = "Analizando audio...") {
        if (this._progressContainer) {
            this._progressContainer.style.display = 'block';
        }
        if (this._progressBar) {
            this._progressBar.style.width = `${percent}%`;
        }
        if (this._progressText) {
            this._progressText.innerText = `${message} (${percent}%)`;
        }
    }

    /**
     * Oculta la barra de progreso.
     */
    hideProgress() {
        if (this._progressContainer) {
            this._progressContainer.style.display = 'none';
        }
    }

    /**
     * Muestra los resultados del análisis musical del archivo cargado.
     * @param {File} file
     * @param {import('../audio/AudioChordAnalyzer.js').AudioAnalysisReport} analysisData
     * @param {(seekTime: number) => void} onChordMarkerClick
     */
    renderAnalysis(file, analysisData, onChordMarkerClick) {
        this._originalAnalysisData = analysisData;
        this._currentAnalysisData = analysisData;
        this._currentPitchShift = 0;
        this._onChordMarkerClick = onChordMarkerClick;

        if (this._trackInfoCard) {
            this._trackInfoCard.style.display = 'flex';
        }
        if (this._playbackControls) {
            this._playbackControls.style.display = 'flex';
        }

        if (this._fileNameLabel) {
            this._fileNameLabel.innerText = file.name;
        }

        // Poblar combobox para cambiar la tonalidad manualmente
        this._populateKeySelect(analysisData.mainKey);

        // Poblar selector con los tipos de tonalidades de acordeón registradas
        this._populateAccordionTuningsSelect(analysisData.mainKey);
        this._renderAccordionRowButtons(this._handlers);

        // Actualizar badges
        this._updateKeyDisplay(analysisData.mainKey);
        const songBpm = analysisData.bpm || 120;
        this.setBPM(songBpm);

        // Cuadrícula de compases interactiva y tira de acordes
        this.renderMeasureGrid(analysisData.chords, analysisData.duration, songBpm);
        this.renderChordsStrip(analysisData.chords, onChordMarkerClick);
        this.renderChordProgressBar(analysisData.chords, analysisData.duration, songBpm);

        // Restablecer indicador de pitch
        if (this._lblPitchShift) {
            this._lblPitchShift.innerText = '0 st';
        }

        // Actualizar indicador del motor de detección (Rust WASM o JS)
        if (this._lblAnalysisEngine) {
            this._lblAnalysisEngine.textContent = analysisData.engine || 'JavaScript';
        }

        // Actualizar tiempos iniciales
        this.updateTime(0, analysisData.duration, 0);
    }

    /**
     * Llena el combobox con los tipos de afinaciones y tonalidades de acordeón registradas.
     * @private
     */
    _populateAccordionTuningsSelect(mainKey) {
        if (!this._audioAccordionSelect) return;
        this._audioAccordionSelect.innerHTML = "";

        // Opción de tono original
        const optOriginal = document.createElement('option');
        optOriginal.value = 'original';
        optOriginal.innerText = `Original: ${mainKey.keyNameLat} (0 st)`;
        this._audioAccordionSelect.appendChild(optOriginal);

        const allTunings = tuningRegistry.getAll();
        let matchedTuningId = null;

        allTunings.forEach(tuning => {
            const opt = document.createElement('option');
            opt.value = tuning.id;
            opt.innerText = `${tuning.name} (${tuning.rowsDescription})`;

            // Si coincide con la recomendación del analizador, seleccionarla por defecto
            if (mainKey.recommendedTuning && mainKey.recommendedTuning.toLowerCase().includes(tuning.name.toLowerCase().split(' ')[0])) {
                opt.selected = true;
                matchedTuningId = tuning.id;
            }
            this._audioAccordionSelect.appendChild(opt);
        });

        // Si no hubo coincidencia por nombre, preseleccionar la afinación sugerida por offset
        if (!matchedTuningId && allTunings.length > 0) {
            const foundByOffset = allTunings.find(t => t.offset === mainKey.recommendedOffset);
            matchedTuningId = foundByOffset ? foundByOffset.id : allTunings[0].id;
            this._audioAccordionSelect.value = matchedTuningId;
        }

        this._selectedAccordionTuningId = matchedTuningId;
    }

    /**
     * Aplica la afinación de acordeón seleccionada adaptando la canción a la hilera más idónea.
     * @private
     */
    _applySelectedAccordionTuning(handlers) {
        if (!this._selectedAccordionTuningId || !this._originalAnalysisData) return;
        const tuning = tuningRegistry.get(this._selectedAccordionTuningId);
        if (!tuning) return;

        const isMinor = this._originalAnalysisData.mainKey.mode === 'minor';
        const originalRoot = this._originalAnalysisData.mainKey.rootMod;

        const rows = [
            { key: 'row1', base: (ROW_BASE_TONICS.row1 + tuning.offset) % 12 },
            { key: 'row2', base: (ROW_BASE_TONICS.row2 + tuning.offset) % 12 },
            { key: 'row3', base: (ROW_BASE_TONICS.row3 + tuning.offset) % 12 }
        ];

        let bestRow = rows[1]; // Por defecto hilera del medio (row2)
        let bestDiff = 999;

        rows.forEach(r => {
            const targetTonic = isMinor ? (r.base + 9) % 12 : r.base;
            let diff = (targetTonic - originalRoot + 12) % 12;
            if (diff > 6) diff -= 12;
            if (Math.abs(diff) < Math.abs(bestDiff)) {
                bestDiff = diff;
                bestRow = r;
            }
        });

        this._selectedAccordionRowKey = bestRow.key;
        this.setPitchShift(bestDiff, handlers);
        this._renderAccordionRowButtons(handlers);
    }

    /**
     * Renderiza los 3 botones de las hileras del acordeón seleccionado con su tonalidad y semitonos.
     * @private
     */
    _renderAccordionRowButtons(handlers) {
        if (!this._audioAccordionRowsContainer) return;
        this._audioAccordionRowsContainer.innerHTML = "";

        if (!this._selectedAccordionTuningId || this._selectedAccordionTuningId === 'original' || !this._originalAnalysisData) {
            const lbl = document.createElement('div');
            lbl.style.fontSize = '0.66rem';
            lbl.style.color = '#64748b';
            lbl.style.fontStyle = 'italic';
            lbl.innerText = 'Tono original seleccionado. Elige una afinación de acordeón arriba para ver sus hileras.';
            this._audioAccordionRowsContainer.appendChild(lbl);
            return;
        }

        const tuning = tuningRegistry.get(this._selectedAccordionTuningId);
        if (!tuning) return;

        const isMinor = this._originalAnalysisData.mainKey.mode === 'minor';
        const originalRoot = this._originalAnalysisData.mainKey.rootMod;
        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, tuning.offset);

        const rowsData = [
            { key: 'row1', label: 'Hilera 1 (Afuera)', base: (ROW_BASE_TONICS.row1 + tuning.offset) % 12 },
            { key: 'row2', label: 'Hilera 2 (Medio)', base: (ROW_BASE_TONICS.row2 + tuning.offset) % 12 },
            { key: 'row3', label: 'Hilera 3 (Adentro)', base: (ROW_BASE_TONICS.row3 + tuning.offset) % 12 }
        ];

        rowsData.forEach(r => {
            const targetTonic = isMinor ? (r.base + 9) % 12 : r.base;
            let diff = (targetTonic - originalRoot + 12) % 12;
            if (diff > 6) diff -= 12;

            const btn = document.createElement('button');
            btn.type = 'button';
            const isActive = (this._currentPitchShift === diff);
            btn.className = `accordion-row-btn ${isActive ? 'active' : ''}`;
            btn.title = `Adaptar a ${r.label} (${arrLat[targetTonic]} ${isMinor ? 'Menor' : 'Mayor'}) aplicando ${diff > 0 ? '+' : ''}${diff} semitonos`;

            btn.innerHTML = `
                <span class="row-title">${r.label}</span>
                <span class="row-tonality">${arrLat[targetTonic]} ${isMinor ? 'Menor' : 'Mayor'}</span>
                <span class="row-shift">${diff > 0 ? '+' : ''}${diff} st</span>
            `;

            btn.addEventListener('click', () => {
                this._selectedAccordionRowKey = r.key;
                this.setPitchShift(diff, handlers || this._handlers);
            });

            this._audioAccordionRowsContainer.appendChild(btn);
        });
    }

    /**
     * Llena el combobox con las 24 tonalidades mayores y menores agrupadas.
     * @private
     */
    _populateKeySelect(currentKey) {
        if (!this._audioKeySelect) return;
        this._audioKeySelect.innerHTML = "";
        this._audioKeySelect.style.display = 'inline-block';

        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, 0);

        const curRoot = currentKey ? currentKey.rootMod : 0;
        const curMode = currentKey ? currentKey.mode : 'major';

        const optGroupMaj = document.createElement('optgroup');
        optGroupMaj.label = 'Tonalidades Mayores';
        for (let r = 0; r < 12; r++) {
            const optMaj = document.createElement('option');
            optMaj.value = `${r}_major`;
            optMaj.innerText = `${arrLat[r]} Mayor (${arrAle[r]})`;
            if (r === curRoot && curMode === 'major') optMaj.selected = true;
            optGroupMaj.appendChild(optMaj);
        }
        this._audioKeySelect.appendChild(optGroupMaj);

        const optGroupMin = document.createElement('optgroup');
        optGroupMin.label = 'Tonalidades Menores';
        for (let r = 0; r < 12; r++) {
            const optMin = document.createElement('option');
            optMin.value = `${r}_minor`;
            optMin.innerText = `${arrLat[r]} Menor (${arrAle[r]}m)`;
            if (r === curRoot && curMode === 'minor') optMin.selected = true;
            optGroupMin.appendChild(optMin);
        }
        this._audioKeySelect.appendChild(optGroupMin);
    }

    /**
     * Aplica un desplazamiento de tono VISUAL en semitonos (-12 a +12).
     * El audio de la canción NO se modifica: solo se recalculan y transponen todos los acordes
     * con referencia a la tonalidad ajustada, actualizando la cuadrícula y el diapasón.
     * @param {number} semitones
     * @param {Object} [handlers]
     * @param {string} [targetMode=null]
     */
    setPitchShift(semitones, handlers, targetMode = null) {
        if (!this._originalAnalysisData) return;

        // Conservar ediciones manuales y preferencias Abre/Cierra hechas sobre la vista transpuesta
        this._syncOriginalFromCurrent();

        const clamped = Math.max(-12, Math.min(12, semitones));
        this._currentPitchShift = clamped;

        if (this._lblPitchShift) {
            this._lblPitchShift.innerText = `${clamped > 0 ? '+' : ''}${clamped} st`;
        }

        // 1. Transponer y recalcular reporte con audioChordAnalyzer (solo datos visuales)
        const transposedReport = audioChordAnalyzer.transposeReport(
            this._originalAnalysisData,
            clamped,
            targetMode
        );
        this._currentAnalysisData = transposedReport;

        // 2. El audio conserva su tono original (sin detune); solo se actualiza la línea de acordes sincronizada
        audioPlayerController.setPitchShift(clamped);
        audioPlayerController.setChordsTimeline(transposedReport.chords);

        // 3. Sincronizar selector de tonalidad
        this._updateKeyDisplay(transposedReport.mainKey);

        // 4. Re-renderizar cuadrícula de compases con todos los acordes recalculados
        this.renderMeasureGrid(transposedReport.chords, this._currentAnalysisData.duration, this.getBPM());
        this.renderChordsStrip(transposedReport.chords, this._onChordMarkerClick);
        this.renderChordProgressBar(transposedReport.chords, this._currentAnalysisData.duration, this.getBPM());

        // 5. Notificar actualización de acordes a los controladores (diapasón y sidebar)
        const curHandlers = handlers || this._handlers;
        if (curHandlers && curHandlers.onChordTimelineUpdated) {
            curHandlers.onChordTimelineUpdated(transposedReport.chords);
        }

        // 6. Refrescar acorde activo inmediatamente si existe en el tiempo actual
        const curTime = audioPlayerController.currentTime || 0;
        const activeChord = (transposedReport.chords || []).find(c => curTime >= c.startTime && curTime < c.endTime);
        if (activeChord) {
            const chordIdx = transposedReport.chords.indexOf(activeChord);
            this.setActiveChord(activeChord, chordIdx);
            eventBus.emit('player:chord_active', {
                chord: activeChord,
                index: chordIdx,
                syncWithDiapason: this.isSyncEnabled()
            });
        }

        // 7. Actualizar estado visual de los botones de las hileras del acordeón
        this._renderAccordionRowButtons(curHandlers);
    }

    /**
     * Reconstruye el reporte original (tono real de la canción) a partir de la vista transpuesta,
     * para que las ediciones de acordes no se pierdan al cambiar de tono.
     * @private
     */
    _syncOriginalFromCurrent() {
        if (!this._currentAnalysisData) return;
        if (!this._currentPitchShift) {
            this._originalAnalysisData = this._currentAnalysisData;
            return;
        }
        const restored = audioChordAnalyzer.transposeReport(this._currentAnalysisData, -this._currentPitchShift);
        if (restored && this._originalAnalysisData && this._originalAnalysisData.mainKey) {
            // Mantener la tonalidad original detectada exactamente como estaba
            restored.mainKey = this._originalAnalysisData.mainKey;
        }
        this._originalAnalysisData = restored;
    }

    /**
     * Actualiza la selección del tono ajustado en el combobox (solo visual).
     * @private
     */
    _updateKeyDisplay(mainKey) {
        if (this._audioKeySelect && mainKey) {
            this._audioKeySelect.value = `${mainKey.rootMod}_${mainKey.mode}`;
        }
    }

    /**
     * Inicializa el modal y eventos de edición de acordes.
     * @private
     */
    _initChordEditor() {
        if (!this._modal) return;

        // Poblar selector de tónica si está vacío o solo tiene 1 opción
        if (this._editorRootSelect && this._editorRootSelect.options.length <= 1) {
            this._editorRootSelect.innerHTML = '';
            const latinNotes = getNoteNamesList(NOTATION_MODES.LATIN);
            const englishNotes = getNoteNamesList(NOTATION_MODES.ENGLISH);
            latinNotes.forEach((lat, i) => {
                const opt = document.createElement('option');
                opt.value = i;
                opt.textContent = `${lat} / ${englishNotes[i]}`;
                this._editorRootSelect.appendChild(opt);
            });
        }

        this._editorNotationInput = document.getElementById('editorChordNotationInput');
        this._btnApplyNotation = document.getElementById('btnApplyChordNotation');
        this._notationFeedback = document.getElementById('chordNotationFeedback');

        const applyParsedNotation = (shouldNotify = true) => {
            if (!this._editorNotationInput) return false;
            const parsed = parseChordNotation(this._editorNotationInput.value);
            if (parsed) {
                if (this._editorRootSelect) this._editorRootSelect.value = parsed.root;
                if (this._editorTypeSelect) {
                    this._editorTypeSelect.value = parsed.chordType;
                    if (this._editorTypeSelect.value !== parsed.chordType) {
                        const opt = document.createElement('option');
                        opt.value = parsed.chordType;
                        opt.textContent = parsed.chordName;
                        this._editorTypeSelect.appendChild(opt);
                        this._editorTypeSelect.value = parsed.chordType;
                    }
                }
                if (this._notationFeedback) {
                    const latinNotes = getNoteNamesList(NOTATION_MODES.LATINA, 0);
                    this._notationFeedback.style.color = '#15803d';
                    this._notationFeedback.innerHTML = `<i class="fas fa-check-circle"></i> <strong>${parsed.chordSymbol}</strong> (${parsed.chordName}) · Notas: ${parsed.noteMods.map(n => latinNotes[n]).join(', ')}`;
                }
                if (audioEngine && parsed.playbackMidis) {
                    audioEngine.play(parsed.playbackMidis, "4n");
                }
                return true;
            } else if (this._editorNotationInput.value.trim() !== '') {
                if (this._notationFeedback) {
                    this._notationFeedback.style.color = '#b91c1c';
                    this._notationFeedback.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Notación no reconocida (ej: CM7, Esus4, Am, Bb7)`;
                }
                return false;
            } else {
                if (this._notationFeedback) this._notationFeedback.innerHTML = '';
                return false;
            }
        };

        if (this._editorNotationInput) {
            this._editorNotationInput.addEventListener('input', () => {
                const input = this._editorNotationInput;
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
                applyParsedNotation(false);
            });
            this._editorNotationInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    if (applyParsedNotation(true)) {
                        this._saveEditedChord();
                    }
                }
            });
        }

        if (this._btnApplyNotation) {
            this._btnApplyNotation.addEventListener('click', () => {
                applyParsedNotation(true);
            });
        }

        // Sincronizar el input de texto cuando cambian los selectores desplegables
        const updateNotationInputFromSelects = () => {
            if (!this._editorRootSelect || !this._editorTypeSelect || !this._editorNotationInput) return;
            const root = parseInt(this._editorRootSelect.value, 10);
            const qual = this._editorTypeSelect.value;
            const tempChord = this._buildChordObject(root, qual, 0, 1);
            this._editorNotationInput.value = tempChord.chordSymbol;
            if (this._notationFeedback) {
                this._notationFeedback.style.color = '#4338ca';
                this._notationFeedback.innerHTML = `<i class="fas fa-music"></i> ${tempChord.chordSymbol} (${tempChord.chordName})`;
            }
            if (audioEngine && tempChord.playbackMidis) {
                audioEngine.play(tempChord.playbackMidis, "4n");
            }
        };

        if (this._editorRootSelect) {
            this._editorRootSelect.addEventListener('change', updateNotationInputFromSelects);
        }
        if (this._editorTypeSelect) {
            this._editorTypeSelect.addEventListener('change', updateNotationInputFromSelects);
        }

        if (this._btnCloseModal) {
            this._btnCloseModal.addEventListener('click', () => this._closeChordEditor());
        }
        if (this._btnCancelModal) {
            this._btnCancelModal.addEventListener('click', () => this._closeChordEditor());
        }
        if (this._modalBackdrop) {
            this._modalBackdrop.addEventListener('click', () => this._closeChordEditor());
        }
        if (this._btnSaveModal) {
            this._btnSaveModal.addEventListener('click', () => this._saveEditedChord());
        }
        if (this._btnDeleteModal) {
            this._btnDeleteModal.addEventListener('click', () => this._deleteEditedChord());
        }
        if (this._btnAddChord) {
            this._btnAddChord.addEventListener('click', (e) => {
                e.stopPropagation();
                const curTime = audioPlayerController.currentTime || 0;
                const bpm = this.getBPM();
                const beatSec = 60 / bpm;
                const barSec = 4 * beatSec;
                const m = Math.floor(curTime / barSec);
                const b = Math.floor((curTime % barSec) / beatSec);
                const beatStart = (m * barSec) + (b * beatSec);
                const beatMid = beatStart + (beatSec * 0.25);
                const chords = (this._currentAnalysisData && this._currentAnalysisData.chords) || [];
                const chord = chords.find(c => c.startTime <= beatMid && c.endTime > beatMid);
                const slot = document.getElementById(`beat-slot-${m}-${b}`) || document.querySelector('.measure-beat-slot');
                if (slot) {
                    this._clearSequenceSelection();
                    this._toggleSlotInSequence((m * 4) + b, m, b, beatStart, beatSec, slot);
                }
            });
        }
        if (this._btnSetStartCurrentTime) {
            this._btnSetStartCurrentTime.addEventListener('click', () => {
                const curTime = audioPlayerController.currentTime || 0;
                if (this._editorStartInput) this._editorStartInput.value = curTime.toFixed(2);
            });
        }
        if (this._btnSetEndCurrentTime) {
            this._btnSetEndCurrentTime.addEventListener('click', () => {
                const curTime = audioPlayerController.currentTime || 0;
                if (this._editorEndInput) this._editorEndInput.value = curTime.toFixed(2);
            });
        }
    }

    /**
     * Inicializa los controles de la barra rápida de extensión y reemplazo de acordes.
     * @private
     */
    _initChordQuickToolbar() {
        const latinNotes = getNoteNamesList(NOTATION_MODES.LATIN);
        if (this._quickRootSelect) {
            this._quickRootSelect.innerHTML = '';
            latinNotes.forEach((name, i) => {
                const opt = document.createElement('option');
                opt.value = i;
                opt.textContent = name;
                this._quickRootSelect.appendChild(opt);
            });
        }

        if (this._btnCloseQuickToolbar) {
            this._btnCloseQuickToolbar.addEventListener('click', () => {
                this._closeQuickToolbar();
            });
        }

        if (this._btnExtendMinus) {
            this._btnExtendMinus.addEventListener('click', () => {
                this._adjustQuickChordDuration(-0.5);
            });
        }

        if (this._btnExtendPlus) {
            this._btnExtendPlus.addEventListener('click', () => {
                this._adjustQuickChordDuration(+0.5);
            });
        }

        if (this._btnExtendToCurrent) {
            this._btnExtendToCurrent.addEventListener('click', () => {
                const curTime = audioPlayerController.currentTime || 0;
                this._setQuickChordEndTime(curTime);
            });
        }

        if (this._btnApplyReplaceChord) {
            this._btnApplyReplaceChord.addEventListener('click', () => {
                this._replaceQuickChord();
            });
        }

        if (this._btnQuickDeleteChord) {
            this._btnQuickDeleteChord.addEventListener('click', () => {
                if (this._selectedQuickChordIndex >= 0) {
                    this._editingChordIndex = this._selectedQuickChordIndex;
                    this._deleteEditedChord();
                    this._closeQuickToolbar();
                }
            });
        }

        if (this._btnQuickOpenEditor) {
            this._btnQuickOpenEditor.addEventListener('click', () => {
                const idx = this._selectedQuickChordIndex;
                this._closeQuickToolbar();
                if (idx >= 0) {
                    this._openChordEditor(idx);
                }
            });
        }
    }

    /**
     * Abre el menú rápido para un acorde seleccionado en la barra de desplazamiento.
     * @param {number} idx
     * @private
     */
    _openQuickToolbar(idx) {
        if (!this._chordQuickToolbar) return;
        const timeline = (this._currentAnalysisData && this._currentAnalysisData.chords) || [];
        const chord = timeline[idx];
        if (!chord) return;

        this._selectedQuickChordIndex = idx;
        this._updateQuickToolbarDisplay(idx);

        this._chordQuickToolbar.style.display = 'block';
        this._chordQuickToolbar.classList.remove('hidden');

        // Resaltar el bloque seleccionado
        if (this._chordProgressBarTrack) {
            const blocks = this._chordProgressBarTrack.querySelectorAll('.chord-segment-block');
            blocks.forEach((b, i) => {
                b.classList.toggle('selected-chord-segment', i === idx);
            });
        }
    }

    /**
     * Actualiza la información en la barra rápida.
     * @param {number} idx
     * @private
     */
    _updateQuickToolbarDisplay(idx) {
        const timeline = (this._currentAnalysisData && this._currentAnalysisData.chords) || [];
        const chord = timeline[idx];
        if (!chord) return;

        if (this._quickChordName) this._quickChordName.textContent = chord.chordName;
        if (this._quickChordTimes) {
            this._quickChordTimes.textContent = `${this._formatTime(chord.startTime)} - ${this._formatTime(chord.endTime)} (${(chord.endTime - chord.startTime).toFixed(1)}s)`;
        }
        if (this._quickRootSelect) this._quickRootSelect.value = chord.root ?? 0;
        if (this._quickTypeSelect) this._quickTypeSelect.value = chord.chordType || 'major';
    }

    /**
     * Cierra el menú rápido.
     * @private
     */
    _closeQuickToolbar() {
        if (this._chordQuickToolbar) {
            this._chordQuickToolbar.style.display = 'none';
            this._chordQuickToolbar.classList.add('hidden');
        }
        this._selectedQuickChordIndex = -1;
        if (this._chordProgressBarTrack) {
            const blocks = this._chordProgressBarTrack.querySelectorAll('.chord-segment-block');
            blocks.forEach(b => b.classList.remove('selected-chord-segment'));
        }
    }

    /**
     * Ajusta la duración de fin del acorde en deltaSeconds.
     * @param {number} deltaSeconds
     * @private
     */
    _adjustQuickChordDuration(deltaSeconds) {
        if (this._selectedQuickChordIndex < 0 || !this._currentAnalysisData || !this._currentAnalysisData.chords) return;
        const timeline = this._currentAnalysisData.chords;
        const chord = timeline[this._selectedQuickChordIndex];
        if (!chord) return;

        const newEnd = Math.max(chord.startTime + 0.2, chord.endTime + deltaSeconds);
        chord.endTime = parseFloat(newEnd.toFixed(2));

        // Ajustar siguiente acorde adyacente si coincide
        if (this._selectedQuickChordIndex < timeline.length - 1) {
            const next = timeline[this._selectedQuickChordIndex + 1];
            if (next && next.startTime < chord.endTime) {
                next.startTime = chord.endTime;
            }
        }

        audioPlayerController.setChordsTimeline(timeline);
        this.renderChordsStrip(timeline, this._onChordMarkerClick);
        this.renderChordProgressBar(timeline, this._currentAnalysisData.duration);
        this._updateQuickToolbarDisplay(this._selectedQuickChordIndex);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(timeline);
        }
    }

    /**
     * Fija el fin del acorde actual hasta el tiempo indicado (ej. tiempo actual de reproducción).
     * @param {number} targetTime
     * @private
     */
    _setQuickChordEndTime(targetTime) {
        if (this._selectedQuickChordIndex < 0 || !this._currentAnalysisData || !this._currentAnalysisData.chords) return;
        const timeline = this._currentAnalysisData.chords;
        const chord = timeline[this._selectedQuickChordIndex];
        if (!chord) return;

        const newEnd = Math.max(chord.startTime + 0.2, targetTime);
        chord.endTime = parseFloat(newEnd.toFixed(2));

        if (this._selectedQuickChordIndex < timeline.length - 1) {
            const next = timeline[this._selectedQuickChordIndex + 1];
            if (next && next.startTime < chord.endTime) {
                next.startTime = chord.endTime;
            }
        }

        audioPlayerController.setChordsTimeline(timeline);
        this.renderChordsStrip(timeline, this._onChordMarkerClick);
        this.renderChordProgressBar(timeline, this._currentAnalysisData.duration);
        this._updateQuickToolbarDisplay(this._selectedQuickChordIndex);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(timeline);
        }
    }

    /**
     * Reemplaza el acorde actual con la nueva tónica y cualidad seleccionada.
     * @private
     */
    _replaceQuickChord() {
        if (this._selectedQuickChordIndex < 0 || !this._currentAnalysisData || !this._currentAnalysisData.chords) return;
        const timeline = this._currentAnalysisData.chords;
        const chord = timeline[this._selectedQuickChordIndex];
        if (!chord) return;

        const root = parseInt(this._quickRootSelect.value, 10);
        const chordType = this._quickTypeSelect.value;
        const updatedChord = this._buildChordObject(root, chordType, chord.startTime, chord.endTime, chord.bellowsAction);

        timeline[this._selectedQuickChordIndex] = updatedChord;

        audioPlayerController.setChordsTimeline(timeline);
        this.renderChordsStrip(timeline, this._onChordMarkerClick);
        this.renderChordProgressBar(timeline, this._currentAnalysisData.duration);
        this._updateQuickToolbarDisplay(this._selectedQuickChordIndex);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(timeline);
        }
    }

    /**
     * Genera un objeto de acorde con nombres, notas e intervalos.
     * @private
     */
    _buildChordObject(root, chordType, startTime, endTime, bellowsAction = 'both') {
        const latinNotes = getNoteNamesList(NOTATION_MODES.LATINA);
        const englishNotes = getNoteNamesList(NOTATION_MODES.ALEMANA);
        const rootNameLat = latinNotes[root] || 'Do';
        const rootNameEng = englishNotes[root] || 'C';

        let typeLabel = '';
        let symbolSuffix = '';
        let noteIntervals = [0, 4, 7]; // Triada Mayor por defecto

        if (chordType === 'minor') {
            typeLabel = 'm';
            symbolSuffix = 'm';
            noteIntervals = [0, 3, 7];
        } else if (chordType === 'maj7') {
            typeLabel = 'Maj7';
            symbolSuffix = 'Maj7';
            noteIntervals = [0, 4, 7, 11];
        } else if (chordType === 'm7') {
            typeLabel = 'm7';
            symbolSuffix = 'm7';
            noteIntervals = [0, 3, 7, 10];
        } else if (chordType === '7') {
            typeLabel = '7';
            symbolSuffix = '7';
            noteIntervals = [0, 4, 7, 10];
        } else if (chordType === 'm7b5') {
            typeLabel = 'm7(♭5)';
            symbolSuffix = 'm7(♭5)';
            noteIntervals = [0, 3, 6, 10];
        } else if (chordType === 'dim7') {
            typeLabel = 'dim7';
            symbolSuffix = 'dim7';
            noteIntervals = [0, 3, 6, 9];
        } else if (chordType === 'dim') {
            typeLabel = 'dim';
            symbolSuffix = 'dim';
            noteIntervals = [0, 3, 6];
        } else if (chordType === 'aug7') {
            typeLabel = '7(♯5)';
            symbolSuffix = '7(♯5)';
            noteIntervals = [0, 4, 8, 10];
        } else if (chordType === 'aug') {
            typeLabel = 'aum';
            symbolSuffix = 'aug';
            noteIntervals = [0, 4, 8];
        } else if (chordType === 'sus4') {
            typeLabel = 'sus4';
            symbolSuffix = 'sus4';
            noteIntervals = [0, 5, 7];
        } else if (chordType === 'sus2') {
            typeLabel = 'sus2';
            symbolSuffix = 'sus2';
            noteIntervals = [0, 2, 7];
        } else if (chordType === '7sus4') {
            typeLabel = '7sus4';
            symbolSuffix = '7sus4';
            noteIntervals = [0, 5, 7, 10];
        } else if (chordType === 'add9') {
            typeLabel = 'add9';
            symbolSuffix = 'add9';
            noteIntervals = [0, 2, 4, 7];
        } else if (chordType === 'maj9') {
            typeLabel = 'Maj9';
            symbolSuffix = 'Maj9';
            noteIntervals = [0, 2, 4, 7, 11];
        } else if (chordType === 'min9') {
            typeLabel = 'm9';
            symbolSuffix = 'm9';
            noteIntervals = [0, 2, 3, 7, 10];
        } else if (chordType === '9') {
            typeLabel = '9';
            symbolSuffix = '9';
            noteIntervals = [0, 2, 4, 7, 10];
        } else if (chordType === 'maj6' || chordType === '6') {
            typeLabel = '6';
            symbolSuffix = '6';
            noteIntervals = [0, 4, 7, 9];
        } else if (chordType === 'min6' || chordType === 'm6') {
            typeLabel = 'm6';
            symbolSuffix = 'm6';
            noteIntervals = [0, 3, 7, 9];
        } else if (chordType === '5') {
            typeLabel = '5';
            symbolSuffix = '5';
            noteIntervals = [0, 7];
        }

        const chordName = `${rootNameLat} ${typeLabel}`.trim();
        const chordSymbol = `${rootNameEng}${symbolSuffix}`.trim();
        const noteMods = noteIntervals.map(interval => (root + interval) % 12);
        const playbackMidis = noteIntervals.map(interval => 60 + root + interval);

        return {
            root,
            chordType,
            chordName,
            chordSymbol,
            noteMods,
            playbackMidis,
            startTime,
            endTime,
            confidence: 1.0,
            bassNote: root,
            bellowsAction: bellowsAction || 'both'
        };
    }

    /**
     * Renderiza los segmentos de cada acorde sobre la barra de desplazamiento,
     * mostrando barras visuales de inicio (verde) y fin (amarillo/ámbar) con handle para extender.
     * @param {Array} chords
     * @param {number} [duration]
     */
    /**
     * Dibuja los cuadros sobre la pista (rejilla musical basada en BPM),
     * mostrando en el cuadro donde ocurre el cambio de acorde el símbolo en notación alemana.
     * @param {Array} chords
     * @param {number} [duration]
     * @param {number} [bpm]
     */
    renderChordProgressBar(chords, duration, bpm) {
        if (!this._chordProgressBarTrack) return;
        this._chordProgressBarTrack.innerHTML = '';

        if (!chords || chords.length === 0) return;

        const dur = duration || (this._currentAnalysisData && this._currentAnalysisData.duration) || audioPlayerController.duration || (chords.length ? chords[chords.length - 1].endTime : 16);
        if (!dur || dur <= 0) return;

        const songBpm = bpm || (this._currentAnalysisData && this._currentAnalysisData.bpm) || 120;
        const beatSec = 60 / songBpm;
        const barSec = 4 * beatSec; // 1 compás = 4 tiempos
        const totalBars = Math.max(1, Math.ceil(dur / barSec));

        this._barSec = barSec;
        this._totalBars = totalBars;

        for (let m = 0; m < totalBars; m++) {
            const barStart = m * barSec;
            const barEnd = Math.min(dur, (m + 1) * barSec);
            const startPct = Math.max(0, Math.min(100, (barStart / dur) * 100));
            const endPct = Math.max(0, Math.min(100, (barEnd / dur) * 100));
            const widthPct = Math.max(0.1, endPct - startPct);

            // Determinar qué acorde está sonando en este cuadro/compás
            const checkTime = barStart + Math.min(0.1, (barEnd - barStart) * 0.5);
            const chord = chords.find(c => c.startTime <= checkTime && c.endTime > checkTime) || chords[chords.length - 1];

            // Identificar si en este cuadro se produce un cambio de acorde
            let isChordChange = false;
            if (m === 0) {
                isChordChange = true;
            } else {
                const prevTime = (m - 1) * barSec + Math.min(0.1, barSec * 0.5);
                const prevChord = chords.find(c => c.startTime <= prevTime && c.endTime > prevTime);
                if (!prevChord || (chord && (prevChord.rootMod !== chord.rootMod || prevChord.quality !== chord.quality))) {
                    isChordChange = true;
                }
            }

            const box = document.createElement('div');
            box.className = `track-bpm-box ${isChordChange ? 'is-chord-change' : ''}`;
            box.id = `track-bar-${m}`;
            box.dataset.barIndex = m;
            box.dataset.startTime = barStart;
            box.style.left = `${startPct}%`;
            box.style.width = `${widthPct}%`;

            if (isChordChange && chord) {
                box.title = `Compás ${m + 1} (${this._formatTime(barStart)} - ${this._formatTime(barEnd)}) | Cambio de acorde: ${chord.chordSymbol}`;
                box.innerHTML = `<span class="track-box-chord-german">${chord.chordSymbol}</span>`;
            } else {
                box.title = `Compás ${m + 1} (${this._formatTime(barStart)} - ${this._formatTime(barEnd)})${chord ? ' | ' + chord.chordSymbol : ''}`;
                box.innerHTML = `<span class="track-box-tick"></span>`;
            }

            // Al hacer clic sobre cualquier cuadro, reproducir desde ese compás
            box.addEventListener('click', (e) => {
                e.stopPropagation();
                audioPlayerController.seek(barStart);
            });

            this._chordProgressBarTrack.appendChild(box);
        }
    }

    /**
     * Inicia el arrastre interactivo en el borde derecho del acorde para extender su duración en tiempo real.
     * @param {MouseEvent} startEvent
     * @param {number} idx
     * @param {number} totalDuration
     * @private
     */
    _startDragExtend(startEvent, idx, totalDuration) {
        if (!this._currentAnalysisData || !this._currentAnalysisData.chords) return;
        const timeline = this._currentAnalysisData.chords;
        const chord = timeline[idx];
        if (!chord || !this._trackSeekerContainer) return;

        const containerRect = this._trackSeekerContainer.getBoundingClientRect();
        const block = document.getElementById(`chord-segment-${idx}`);

        const onMouseMove = (moveEvent) => {
            const relX = moveEvent.clientX - containerRect.left;
            const pct = Math.max(0, Math.min(1, relX / containerRect.width));
            const newEndTime = Math.max(chord.startTime + 0.15, pct * totalDuration);
            chord.endTime = parseFloat(newEndTime.toFixed(2));

            // Actualizar estilo en tiempo real
            if (block) {
                const widthPct = Math.max(0.6, ((chord.endTime - chord.startTime) / totalDuration) * 100);
                block.style.width = `${widthPct}%`;
            }

            // Si hay un siguiente acorde, ajustar su inicio
            if (idx < timeline.length - 1) {
                const nextChord = timeline[idx + 1];
                if (nextChord && nextChord.startTime < chord.endTime) {
                    nextChord.startTime = chord.endTime;
                    const nextBlock = document.getElementById(`chord-segment-${idx + 1}`);
                    if (nextBlock) {
                        const nextStartPct = (nextChord.startTime / totalDuration) * 100;
                        const nextWidthPct = Math.max(0.6, ((nextChord.endTime - nextChord.startTime) / totalDuration) * 100);
                        nextBlock.style.left = `${nextStartPct}%`;
                        nextBlock.style.width = `${nextWidthPct}%`;
                    }
                }
            }
        };

        const onMouseUp = () => {
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('mouseup', onMouseUp);

            audioPlayerController.setChordsTimeline(timeline);
            this.renderChordsStrip(timeline, this._onChordMarkerClick);
            this.renderChordProgressBar(timeline, totalDuration);

            if (this._selectedQuickChordIndex === idx) {
                this._updateQuickToolbarDisplay(idx);
            }

            if (this._handlers && this._handlers.onChordTimelineUpdated) {
                this._handlers.onChordTimelineUpdated(timeline);
            }
        };

        window.addEventListener('mousemove', onMouseMove);
        window.addEventListener('mouseup', onMouseUp);
    }

    /**
     * Marca un cambio de acorde en el segundo actual de reproducción:
     * Cierra el acorde actual fijando su punto final, e inicia el nuevo acorde en ese segundo.
     * @private
     */
    _markChordChangeAtCurrentTime() {
        const curTime = audioPlayerController.currentTime || (this._timelineSeeker ? parseFloat(this._timelineSeeker.value) * (audioPlayerController.duration || 16) : 0);
        if (!this._currentAnalysisData) {
            this._currentAnalysisData = { duration: 16, chords: [] };
        }
        if (!this._currentAnalysisData.chords) {
            this._currentAnalysisData.chords = [];
        }
        const timeline = this._currentAnalysisData.chords;

        // Buscar si el tiempo actual cae dentro de un acorde existente
        const chordIdx = timeline.findIndex(c => curTime >= c.startTime && curTime < c.endTime);

        if (chordIdx !== -1) {
            const curChord = timeline[chordIdx];
            const oldEndTime = curChord.endTime;

            // Fijar el final del acorde actual al segundo actual (punto de cambio)
            curChord.endTime = Math.max(curChord.startTime + 0.1, curTime);

            // Crear el nuevo acorde a partir de este segundo hasta el final previo o +3s
            const newEndTime = Math.max(curTime + 0.5, oldEndTime > curTime ? oldEndTime : curTime + 4.0);
            const nextRoot = (curChord.root + 5) % 12; // Cuarta diatónica como sugerencia armónica
            const latinNotes = getNoteNamesList(NOTATION_MODES.LATIN);
            const englishNotes = getNoteNamesList(NOTATION_MODES.ENGLISH);

            const newChord = {
                root: nextRoot,
                chordType: 'major',
                chordName: `${latinNotes[nextRoot] || 'Do'}`,
                chordSymbol: `${englishNotes[nextRoot] || 'C'}`,
                noteMods: [nextRoot, (nextRoot + 4) % 12, (nextRoot + 7) % 12],
                startTime: curTime,
                endTime: newEndTime,
                confidence: 1.0,
                bassNote: nextRoot,
                bellowsAction: 'both'
            };

            timeline.splice(chordIdx + 1, 0, newChord);
            timeline.sort((a, b) => a.startTime - b.startTime);

            audioPlayerController.setChordsTimeline(timeline);
            this.renderChordsStrip(timeline, this._onChordMarkerClick);
            this.renderChordProgressBar(timeline, this._currentAnalysisData.duration);

            if (this._handlers && this._handlers.onChordTimelineUpdated) {
                this._handlers.onChordTimelineUpdated(timeline);
            }

            // Abrir el editor para personalizar de inmediato el nuevo acorde
            const newIdx = timeline.indexOf(newChord);
            this._openChordEditor(newIdx >= 0 ? newIdx : chordIdx + 1);
        } else {
            // Fuera de acorde existente: agregar nuevo acorde en curTime
            this._openChordEditor(-1, curTime);
        }
    }

    /**
     * Abre el modal para editar un acorde existente o agregar uno nuevo.
     * @param {number} idx Índice del acorde (-1 para nuevo)
     * @param {number} [defaultTime=0] Tiempo por defecto para nuevo acorde
     */
    _openChordEditor(idx, defaultTime = 0) {
        if (!this._modal) return;
        this._editingChordIndex = idx;

        const timeline = (this._currentAnalysisData && (this._currentAnalysisData.chords || this._currentAnalysisData.chordsTimeline)) || [];

        let currentSymbol = 'C';
        let currentRoot = 0;
        let currentType = 'major';

        if (idx >= 0 && timeline[idx]) {
            const ch = timeline[idx];
            currentRoot = ch.root ?? 0;
            currentType = ch.chordType || 'major';
            currentSymbol = ch.chordSymbol || '';
            if (this._editorRootSelect) this._editorRootSelect.value = currentRoot;
            if (this._editorTypeSelect) this._editorTypeSelect.value = currentType;
            if (this._editorStartInput) this._editorStartInput.value = (typeof ch.startTime === 'number' ? ch.startTime : 0).toFixed(2);
            if (this._editorEndInput) this._editorEndInput.value = (typeof ch.endTime === 'number' ? ch.endTime : 1).toFixed(2);
            if (this._btnDeleteModal) this._btnDeleteModal.style.display = 'inline-flex';
        } else {
            // Nuevo acorde
            if (this._editorRootSelect) this._editorRootSelect.value = 0;
            if (this._editorTypeSelect) this._editorTypeSelect.value = 'major';
            if (this._editorStartInput) this._editorStartInput.value = defaultTime.toFixed(2);
            const dur = audioPlayerController.duration || (defaultTime + 2.0);
            const end = Math.min(defaultTime + 2.0, dur > 0 ? dur : defaultTime + 2.0);
            if (this._editorEndInput) this._editorEndInput.value = end.toFixed(2);
            if (this._btnDeleteModal) this._btnDeleteModal.style.display = 'none';
        }

        if (this._editorNotationInput) {
            if (!currentSymbol && this._editorRootSelect && this._editorTypeSelect) {
                const tempChord = this._buildChordObject(parseInt(this._editorRootSelect.value, 10), this._editorTypeSelect.value, 0, 1);
                currentSymbol = tempChord.chordSymbol;
            }
            this._editorNotationInput.value = currentSymbol;
            if (this._notationFeedback) {
                const parsed = parseChordNotation(currentSymbol);
                if (parsed) {
                    const latinNotes = getNoteNamesList(NOTATION_MODES.LATINA, 0);
                    this._notationFeedback.style.color = '#15803d';
                    this._notationFeedback.innerHTML = `<i class="fas fa-check-circle"></i> <strong>${parsed.chordSymbol}</strong> (${parsed.chordName}) · Notas: ${parsed.noteMods.map(n => latinNotes[n]).join(', ')}`;
                } else {
                    this._notationFeedback.innerHTML = '';
                }
            }
            setTimeout(() => {
                this._editorNotationInput.focus();
                this._editorNotationInput.select();
            }, 80);
        }

        this._modal.style.display = 'flex';
        this._modal.classList.remove('hidden');

        if (audioEngine) {
            const activeMidis = (idx >= 0 && timeline[idx] && timeline[idx].playbackMidis)
                ? timeline[idx].playbackMidis
                : (this._editorRootSelect && this._editorTypeSelect
                    ? this._buildChordObject(parseInt(this._editorRootSelect.value, 10), this._editorTypeSelect.value, 0, 1).playbackMidis
                    : null);
            if (activeMidis && activeMidis.length > 0) {
                audioEngine.play(activeMidis, "4n");
            }
        }
    }

    /**
     * Cierra el modal de edición de acordes.
     * @private
     */
    _closeChordEditor() {
        if (this._modal) {
            this._modal.style.display = 'none';
            this._modal.classList.add('hidden');
        }
        this._editingChordIndex = -1;
    }

    /**
     * Guarda los cambios del acorde editado o añade uno nuevo.
     * @private
     */
    _saveEditedChord() {
        if (!this._currentAnalysisData) return;
        if (!this._currentAnalysisData.chords) {
            this._currentAnalysisData.chords = [];
        }
        const timeline = this._currentAnalysisData.chords;

        // Si el usuario ingresó una notación escrita, validarla y aplicarla a los campos
        if (this._editorNotationInput && this._editorNotationInput.value.trim() !== '') {
            const parsed = parseChordNotation(this._editorNotationInput.value);
            if (parsed) {
                if (this._editorRootSelect) this._editorRootSelect.value = parsed.root;
                if (this._editorTypeSelect) {
                    this._editorTypeSelect.value = parsed.chordType;
                    if (this._editorTypeSelect.value !== parsed.chordType) {
                        const opt = document.createElement('option');
                        opt.value = parsed.chordType;
                        opt.textContent = parsed.chordName;
                        this._editorTypeSelect.appendChild(opt);
                        this._editorTypeSelect.value = parsed.chordType;
                    }
                }
            }
        }

        const root = parseInt(this._editorRootSelect.value, 10);
        const chordType = this._editorTypeSelect.value;
        const startTime = Math.max(0, parseFloat(this._editorStartInput.value) || 0);
        const endTime = Math.max(startTime + 0.1, parseFloat(this._editorEndInput.value) || (startTime + 1));

        // Conservar preferencia de fuelle si ya existía
        const existingChord = (this._editingChordIndex >= 0 && this._editingChordIndex < timeline.length) ? timeline[this._editingChordIndex] : null;
        const bellowsAction = existingChord ? (existingChord.bellowsAction || 'both') : 'both';

        const updatedChord = this._buildChordObject(root, chordType, startTime, endTime, bellowsAction);

        // Ajuste automático de acordes adyacentes para una transición perfecta sin huecos
        const autoAdjust = this._chkAutoAdjustAdjacent ? this._chkAutoAdjustAdjacent.checked : true;
        if (autoAdjust && this._editingChordIndex >= 0 && this._editingChordIndex < timeline.length) {
            if (this._editingChordIndex > 0) {
                const prev = timeline[this._editingChordIndex - 1];
                if (prev && prev.endTime > startTime) {
                    prev.endTime = startTime;
                }
            }
            if (this._editingChordIndex < timeline.length - 1) {
                const next = timeline[this._editingChordIndex + 1];
                if (next && next.startTime < endTime) {
                    next.startTime = endTime;
                }
            }
        }

        if (this._editingChordIndex >= 0 && this._editingChordIndex < timeline.length) {
            timeline[this._editingChordIndex] = updatedChord;
        } else {
            timeline.push(updatedChord);
        }

        // Ordenar acordes por tiempo de inicio cronológico
        timeline.sort((a, b) => a.startTime - b.startTime);

        // Actualizar timeline sincronizado en el reproductor
        audioPlayerController.setChordsTimeline(timeline);
        this.renderChordsStrip(timeline, this._onChordMarkerClick);
        this.renderChordProgressBar(timeline, this._currentAnalysisData.duration, this.getBPM());
        this.renderMeasureGrid(timeline, this._currentAnalysisData.duration, this.getBPM());

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(timeline);
        }

        // Refrescar acorde activo inmediatamente
        const curTime = audioPlayerController.currentTime || 0;
        const curActive = timeline.find(c => curTime >= c.startTime && curTime < c.endTime);
        if (curActive) {
            const actIdx = timeline.indexOf(curActive);
            this.setActiveChord(curActive, actIdx);
            eventBus.emit('player:chord_active', {
                chord: curActive,
                index: actIdx,
                syncWithDiapason: this.isSyncEnabled()
            });
        }

        this._closeChordEditor();
    }

    /**
     * Elimina el acorde actualmente en edición.
     * @private
     */
    _deleteEditedChord() {
        if (!this._currentAnalysisData || !this._currentAnalysisData.chords) return;
        const timeline = this._currentAnalysisData.chords;

        if (this._editingChordIndex >= 0 && this._editingChordIndex < timeline.length) {
            timeline.splice(this._editingChordIndex, 1);
            audioPlayerController.setChordsTimeline(timeline);
            this.renderChordsStrip(timeline, this._onChordMarkerClick);
            this.renderChordProgressBar(timeline, this._currentAnalysisData.duration, this.getBPM());
            this.renderMeasureGrid(timeline, this._currentAnalysisData.duration, this.getBPM());

            if (this._handlers && this._handlers.onChordTimelineUpdated) {
                this._handlers.onChordTimelineUpdated(timeline);
            }
        }
        this._closeChordEditor();
    }

    /**
     * Renderiza la tira con los bloques de acordes detectados garantizando alto contraste y editabilidad.
     * @param {Array} chords
     * @param {(time: number) => void} onClick
     */
    renderChordsStrip(chords, onClick) {
        if (!this._chordsStrip) return;
        this._chordsStrip.innerHTML = "";
        this._onChordMarkerClick = onClick;

        if (!chords || chords.length === 0) {
            this._chordsStrip.innerHTML = '<span style="color: #64748b; font-size: 0.8rem; padding: 4px 8px;">No hay acordes disponibles</span>';
            return;
        }

        chords.forEach((chord, idx) => {
            const btn = document.createElement('div');
            btn.className = 'chord-timeline-chip';
            btn.id = `chord-marker-${idx}`;
            btn.title = `${chord.chordName} (${this._formatTime(chord.startTime)} - ${this._formatTime(chord.endTime)}) - Clic para reproducir, lápiz para editar`;

            const dirTag = chord.bellowsAction === 'pull'
                ? '<span class="chip-dir-pill pull">Abre</span>'
                : chord.bellowsAction === 'push'
                ? '<span class="chip-dir-pill push">Cierra</span>'
                : '';

            btn.innerHTML = `
                <div style="display: flex; flex-direction: column; align-items: flex-start; pointer-events: none;">
                    <div style="display: flex; align-items: center; gap: 4px;">
                        <strong class="timeline-chord-name">${chord.chordName}</strong>
                        ${dirTag}
                    </div>
                    <div style="display: flex; align-items: center; gap: 4px; margin-top: 2px;">
                        <span class="timeline-chord-time">${this._formatTime(chord.startTime)}</span>
                        <span class="sidebar-change-badge" style="font-size:0.52rem; padding: 1px 4px;" title="Punto de cambio de acorde a los ${this._formatTime(chord.endTime)}">
                            <i class="fas fa-bolt"></i> ${this._formatTime(chord.endTime)}
                        </span>
                    </div>
                </div>
                <button type="button" class="chip-edit-icon" title="Editar este acorde a la derecha" data-idx="${idx}">
                    <i class="fas fa-pencil-alt"></i>
                </button>
            `;

            btn.addEventListener('click', (e) => {
                if (e.target.closest('.chip-edit-icon')) {
                    e.stopPropagation();
                    this._openChordEditor(idx);
                    return;
                }
                if (onClick) onClick(chord.startTime);
            });

            btn.addEventListener('dblclick', (e) => {
                e.stopPropagation();
                this._openChordEditor(idx);
            });

            this._chordsStrip.appendChild(btn);
        });
    }

    /**
     * Resalta el acorde activo en la línea de tiempo y en el badge con alto contraste.
     * @param {Object} chord
     * @param {number} chordIndex
     */
    setActiveChord(chord, chordIndex) {
        if (this._activeChordTitle) {
            this._activeChordTitle.innerHTML = chord
                ? `Acorde: <strong>${chord.chordSymbol}</strong> (${chord.chordName})`
                : '';
        }

        if (this._btnEditActiveChord) {
            this._btnEditActiveChord.style.display = chord ? 'inline-flex' : 'none';
        }

        if (this._chordsStrip) {
            const chips = this._chordsStrip.querySelectorAll('.chord-timeline-chip');
            chips.forEach((c, i) => {
                const isActive = i === chordIndex;
                c.classList.toggle('active-timeline-chord', isActive);
            });
        }
    }

    /**
     * Alias de compatibilidad para actualizar el acorde activo mostrado.
     * @param {Object|null} chord
     * @param {number} [chordIndex=-1]
     */
    _updateActiveChordDisplay(chord, chordIndex = -1) {
        this.setActiveChord(chord, chordIndex);
    }

    /**
     * Actualiza el indicador temporal, barra de progreso y pulso activo en la cuadrícula.
     * @param {number} currentTime
     * @param {number} duration
     * @param {number} progress
     */
    updateTime(currentTime, duration, progress) {
        const timeFormatted = this._formatTime(currentTime);
        const remainingFormatted = '-' + this._formatTime(Math.max(0, duration - currentTime));

        if (this._audioTimeCurrent) {
            this._audioTimeCurrent.innerText = timeFormatted;
        }
        if (this._audioTimeRemaining) {
            this._audioTimeRemaining.innerText = remainingFormatted;
        }
        if (this._timeDisplay) {
            this._timeDisplay.innerText = `${timeFormatted} / ${this._formatTime(duration)}`;
        }
        if (this._timelineSeeker) {
            this._timelineSeeker.value = progress;
        }

        // Resaltar pulso y compás en la cuadrícula de compases
        const bpm = this.getBPM() || 120;
        const beatSec = 60 / bpm;
        const barSec = 4 * beatSec;

        const safeCurTime = (typeof currentTime === 'number' && !isNaN(currentTime) && isFinite(currentTime)) ? Math.max(0, currentTime) : 0;
        const curBar = Math.floor(safeCurTime / barSec);
        const curBeat = Math.min(3, Math.floor((safeCurTime % barSec) / beatSec));

        if (this._activeMeasureBeatInfo) {
            this._activeMeasureBeatInfo.innerText = `Compás ${curBar + 1} · Pulso ${curBeat + 1}`;
        }

        if (this._activeBeatSlot) {
            this._activeBeatSlot.classList.remove('active-beat');
        }
        const newBeatSlot = document.getElementById(`beat-slot-${curBar}-${curBeat}`);
        if (newBeatSlot) {
            newBeatSlot.classList.add('active-beat');
            this._activeBeatSlot = newBeatSlot;
        }

        // Resaltar pulso en cuadrícula de Acordeón 2
        if (this._secActiveBeatSlot) {
            this._secActiveBeatSlot.classList.remove('active-beat');
        }
        const newSecBeatSlot = document.getElementById(`sec-beat-slot-${curBar}-${curBeat}`);
        if (newSecBeatSlot) {
            newSecBeatSlot.classList.add('active-beat');
            this._secActiveBeatSlot = newSecBeatSlot;
        }

        if (this._activeMeasureRow) {
            this._activeMeasureRow.classList.remove('active-measure');
        }
        const newRow = document.getElementById(`measure-row-${curBar}`);
        if (newRow) {
            newRow.classList.add('active-measure');
            this._activeMeasureRow = newRow;

            // Auto-scroll suave para mantener el compás actual a la vista en ambas cuadrículas
            if (this._lastScrollMeasure !== curBar) {
                this._lastScrollMeasure = curBar;
                if (this._measureGridContainer) {
                    const rowTop = newRow.offsetTop - this._measureGridContainer.offsetTop;
                    const targetScroll = Math.max(0, rowTop - 40);
                    this._measureGridContainer.scrollTo({ top: targetScroll, behavior: 'smooth' });
                }
                if (this._secondaryMeasureGridContainer) {
                    const secRow = document.getElementById(`sec-measure-row-${curBar}`);
                    if (secRow) {
                        const secTop = secRow.offsetTop - this._secondaryMeasureGridContainer.offsetTop;
                        const targetScroll = Math.max(0, secTop - 40);
                        this._secondaryMeasureGridContainer.scrollTo({ top: targetScroll, behavior: 'smooth' });
                    }
                }
            }
        }

        if (this._secActiveMeasureRow) {
            this._secActiveMeasureRow.classList.remove('active-measure');
        }
        const newSecRow = document.getElementById(`sec-measure-row-${curBar}`);
        if (newSecRow) {
            newSecRow.classList.add('active-measure');
            this._secActiveMeasureRow = newSecRow;
        }
    }

    /**
     * Dibuja la cuadrícula de compases interactiva (4 pulsos por compás) estilo Moises / Chordify.
     * Permite seleccionar uno o varios cuadros arrastrando (drag) para asignar duración y forzar acordes.
     * @param {Array} chords
     * @param {number} duration
     * @param {number} bpm
     */
    renderMeasureGrid(chords, duration, bpm) {
        if (!this._measureGridContainer) return;
        this._measureGridContainer.innerHTML = '';

        const dur = duration || (this._currentAnalysisData && this._currentAnalysisData.duration) || audioPlayerController.duration || 16;
        const songBpm = bpm || this.getBPM();
        const beatSec = 60 / songBpm;
        const barSec = 4 * beatSec;
        const calculatedBars = Math.max(1, Math.ceil(dur / barSec));
        const totalBars = Math.max(4, this._totalBars || calculatedBars);

        this._barSec = barSec;
        this._beatSec = beatSec;
        this._totalBars = totalBars;

        const fragment = document.createDocumentFragment();
        let lastChordSymbol = null;

        for (let m = 0; m < totalBars; m++) {
            const row = document.createElement('div');
            row.className = 'measure-grid-row';
            row.id = `measure-row-${m}`;
            row.dataset.barIndex = m;

            // Número del compás a la izquierda
            const num = document.createElement('div');
            num.className = 'measure-grid-num';
            num.textContent = (m + 1);
            row.appendChild(num);

            // 4 celdas correspondientes a los 4 pulsos (Beats 1 a 4)
            const beats = document.createElement('div');
            beats.className = 'measure-grid-beats';

            for (let b = 0; b < 4; b++) {
                const globalBeatIndex = (m * 4) + b;
                const beatStart = (m * barSec) + (b * beatSec);
                const beatMid = beatStart + (beatSec * 0.25);
                const chord = (chords || []).find(c => c.startTime <= beatMid && c.endTime > beatMid);

                const slot = document.createElement('button');
                slot.type = 'button';
                slot.className = 'measure-beat-slot';
                slot.id = `beat-slot-${m}-${b}`;
                slot.dataset.barIndex = m;
                slot.dataset.beatIndex = b;
                slot.dataset.globalBeat = globalBeatIndex;
                slot.dataset.startTime = beatStart;

                const currentSymbol = chord ? chord.chordSymbol : '';
                const isChordStart = chord && Math.abs(chord.startTime - beatStart) < 0.05;

                if (currentSymbol) {
                    if (isChordStart || (m === 0 && b === 0) || currentSymbol !== lastChordSymbol) {
                        slot.classList.add('has-chord');
                        slot.innerHTML = `<span class="slot-chord-text" title="Clic o arrastra para editar ${currentSymbol}">${currentSymbol} <i class="fas fa-pen" style="font-size: 0.50rem; opacity: 0.4; margin-left: 2px;"></i></span>`;
                        lastChordSymbol = currentSymbol;
                    } else {
                        slot.classList.add('has-chord-continue');
                        slot.innerHTML = `<span class="slot-chord-text slot-chord-continue" title="Continúa ${currentSymbol}">${currentSymbol}</span>`;
                    }
                } else {
                    slot.innerHTML = `<span class="slot-empty-dot">·</span>`;
                    lastChordSymbol = null;
                }

                slot.title = `Compás ${m + 1}, Pulso ${b + 1} (${this._formatTime(beatStart)})${currentSymbol ? ' - Acorde: ' + currentSymbol : ' (Vacío)'}\nArrastra el ratón por varios cuadros para seleccionar y aplicar duración`;

                // Iniciar arrastre de selección con el ratón
                slot.addEventListener('mousedown', (e) => {
                    if (e.button !== 0) return;
                    e.preventDefault();
                    this._isDraggingGrid = true;
                    this._dragStartBeat = globalBeatIndex;
                    this._dragEndBeat = globalBeatIndex;
                    this._updateDragRangeSelection();
                });

                // Extender rango de selección al pasar por encima
                slot.addEventListener('mouseenter', () => {
                    if (!this._isDraggingGrid) return;
                    this._dragEndBeat = globalBeatIndex;
                    this._updateDragRangeSelection();
                });

                slot.addEventListener('keydown', (e) => {
                    if (e.key === 'Delete' || e.key === 'Del' || e.key === 'Backspace') {
                        e.preventDefault();
                        if (!this._selectedSequence || this._selectedSequence.length === 0) {
                            this._selectedSequence = [{
                                globalBeat: globalBeatIndex,
                                barIndex: m,
                                beatIndex: b,
                                beatStart: beatStart,
                                beatSec: beatSec,
                                slot: slot
                            }];
                        }
                        this._deleteMiniChord();
                    } else if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        this._toggleSlotInSequence(globalBeatIndex, m, b, beatStart, beatSec, slot);
                    }
                });

                beats.appendChild(slot);
            }

            row.appendChild(beats);
            fragment.appendChild(row);
        }

        this._measureGridContainer.appendChild(fragment);

        if (this._secondaryMeasureGridContainer) {
            this._secondaryMeasureGridContainer.innerHTML = '';
            const secFragment = document.createDocumentFragment();
            let secLastChordSymbol = null;

            for (let m = 0; m < totalBars; m++) {
                const secRow = document.createElement('div');
                secRow.className = 'measure-grid-row';
                secRow.id = `sec-measure-row-${m}`;
                secRow.dataset.barIndex = m;

                const secNum = document.createElement('div');
                secNum.className = 'measure-grid-num';
                secNum.textContent = (m + 1);
                secRow.appendChild(secNum);

                const secBeats = document.createElement('div');
                secBeats.className = 'measure-grid-beats';

                for (let b = 0; b < 4; b++) {
                    const globalBeatIndex = (m * 4) + b;
                    const beatStart = (m * barSec) + (b * beatSec);
                    const beatMid = beatStart + (beatSec * 0.25);
                    const chord = (chords || []).find(c => c.startTime <= beatMid && c.endTime > beatMid);

                    const secSlot = document.createElement('button');
                    secSlot.type = 'button';
                    secSlot.className = 'measure-beat-slot';
                    secSlot.id = `sec-beat-slot-${m}-${b}`;
                    secSlot.dataset.barIndex = m;
                    secSlot.dataset.beatIndex = b;
                    secSlot.dataset.globalBeat = globalBeatIndex;
                    secSlot.dataset.startTime = beatStart;

                    const currentSymbol = chord ? chord.chordSymbol : '';
                    const isChordStart = chord && Math.abs(chord.startTime - beatStart) < 0.05;

                    if (currentSymbol) {
                        if (isChordStart || (m === 0 && b === 0) || currentSymbol !== secLastChordSymbol) {
                            secSlot.classList.add('has-chord');
                            secSlot.innerHTML = `<span class="slot-chord-text" title="Clic para saltar a ${currentSymbol}">${currentSymbol}</span>`;
                            secLastChordSymbol = currentSymbol;
                        } else {
                            secSlot.classList.add('has-chord-continue');
                            secSlot.innerHTML = `<span class="slot-chord-text slot-chord-continue" title="Continúa ${currentSymbol}">${currentSymbol}</span>`;
                        }
                    } else {
                        secSlot.innerHTML = `<span class="slot-empty-dot">·</span>`;
                        secLastChordSymbol = null;
                    }

                    secSlot.title = `2do Acordeón: Compás ${m + 1}, Pulso ${b + 1} (${this._formatTime(beatStart)})${currentSymbol ? ' - ' + currentSymbol : ''}`;

                    secSlot.addEventListener('click', (e) => {
                        e.preventDefault();
                        const primSlot = document.getElementById(`beat-slot-${m}-${b}`);
                        this._toggleSlotInSequence(globalBeatIndex, m, b, beatStart, beatSec, primSlot || secSlot);
                    });

                    secBeats.appendChild(secSlot);
                }

                secRow.appendChild(secBeats);
                secFragment.appendChild(secRow);
            }
            this._secondaryMeasureGridContainer.appendChild(secFragment);
        }

        this._refreshSequenceBadges();
    }

    /**
     * Refresca las insignias numéricas de secuencia (1, 2, 3...) y resaltado en las celdas seleccionadas.
     * @private
     */
    _refreshSequenceBadges() {
        if (!this._measureGridContainer) return;
        this._measureGridContainer.querySelectorAll('.slot-seq-badge').forEach(b => b.remove());
        this._measureGridContainer.querySelectorAll('.measure-beat-slot.selected-seq-slot').forEach(s => {
            s.classList.remove('selected-seq-slot');
        });

        this._selectedSequence.forEach((item, index) => {
            const slot = item.slot || document.getElementById(`beat-slot-${item.barIndex}-${item.beatIndex}`);
            if (slot) {
                item.slot = slot;
                slot.classList.add('selected-seq-slot');
                const badge = document.createElement('span');
                badge.className = 'slot-seq-badge';
                badge.textContent = (index + 1);
                badge.title = `Orden de selección: #${index + 1}`;
                slot.appendChild(badge);
            }
        });

        if (this._secondaryMeasureGridContainer) {
            this._secondaryMeasureGridContainer.querySelectorAll('.slot-seq-badge').forEach(b => b.remove());
            this._secondaryMeasureGridContainer.querySelectorAll('.measure-beat-slot.selected-seq-slot').forEach(s => {
                s.classList.remove('selected-seq-slot');
            });
            this._selectedSequence.forEach((item, index) => {
                const secSlot = document.getElementById(`sec-beat-slot-${item.barIndex}-${item.beatIndex}`);
                if (secSlot) {
                    secSlot.classList.add('selected-seq-slot');
                    const badge = document.createElement('span');
                    badge.className = 'slot-seq-badge';
                    badge.textContent = (index + 1);
                    badge.title = `Orden de selección: #${index + 1}`;
                    secSlot.appendChild(badge);
                }
            });
        }

        if (this._btnDeleteSelectedSlots) {
            this._btnDeleteSelectedSlots.style.display = this._selectedSequence.length > 0 ? 'inline-flex' : 'none';
        }
    }

    /**
     * Limpia la selección en secuencia de celdas de la cuadrícula.
     * @private
     */
    _clearSequenceSelection() {
        this._selectedSequence = [];
        if (this._btnDeleteSelectedSlots) {
            this._btnDeleteSelectedSlots.style.display = 'none';
        }
        this._refreshSequenceBadges();
    }

    /**
     * Agrega o remueve un cuadro de la cuadrícula en la secuencia de selección ordenada.
     * @private
     */
    _toggleSlotInSequence(globalBeat, barIndex, beatIndex, beatStart, beatSec, slot) {
        const existingIdx = this._selectedSequence.findIndex(item => item.globalBeat === globalBeat);
        if (existingIdx >= 0) {
            // Si ya estaba seleccionado, se deselecciona y se renumera el resto
            this._selectedSequence.splice(existingIdx, 1);
        } else {
            // Se agrega al final de la secuencia con el número siguiente
            this._selectedSequence.push({
                globalBeat,
                barIndex,
                beatIndex,
                beatStart,
                beatSec,
                slot
            });
        }

        this._refreshSequenceBadges();

        if (this._selectedSequence.length === 0) {
            this._closeMiniChordPopover();
            return;
        }

        // Preescucha del acorde existente en el pulso recién seleccionado
        const currentChord = (this._currentAnalysisData && this._currentAnalysisData.chords || []).find(
            c => c.startTime <= (beatStart + 0.05) && c.endTime > (beatStart + 0.05)
        );
        if (currentChord && audioEngine) {
            const midis = currentChord.playbackMidis || (currentChord.noteMods ? currentChord.noteMods.map(n => 60 + n) : null);
            const chordVol = audioPlayerController.getChordEffectiveVolume();
            if (chordVol > 0 && midis && midis.length > 0) {
                audioEngine.play(midis, "4n", chordVol);
            }
        }
        audioPlayerController.seek(beatStart);

        const lastItem = this._selectedSequence[this._selectedSequence.length - 1];
        this._openMiniChordPopoverForSequence(lastItem ? lastItem.slot : slot);
    }

    /**
     * Actualiza la visualización de cuadros seleccionados durante el arrastre (drag).
     * @private
     */
    _updateDragRangeSelection() {
        if (!this._measureGridContainer || this._dragStartBeat === null || this._dragEndBeat === null) return;
        const minBeat = Math.min(this._dragStartBeat, this._dragEndBeat);
        const maxBeat = Math.max(this._dragStartBeat, this._dragEndBeat);

        const allSlots = this._measureGridContainer.querySelectorAll('.measure-beat-slot');
        allSlots.forEach(s => {
            const g = parseInt(s.dataset.globalBeat, 10);
            if (minBeat !== maxBeat && g >= minBeat && g <= maxBeat) {
                s.classList.add('slot-in-range');
                s.classList.toggle('slot-range-start', g === minBeat);
                s.classList.toggle('slot-range-end', g === maxBeat);
            } else {
                s.classList.remove('slot-in-range', 'slot-range-start', 'slot-range-end');
            }
        });
    }

    /**
     * Inicializa eventos del mini-popover de acordes, drag global y gestión de cuadrícula.
     * @private
     */
    _initMiniChordPopover() {
        // Evento global para soltar el ratón y completar el arrastre o clic
        window.addEventListener('mouseup', () => {
            if (!this._isDraggingGrid) return;
            this._isDraggingGrid = false;

            if (this._dragStartBeat === null || this._dragEndBeat === null) return;
            const minBeat = Math.min(this._dragStartBeat, this._dragEndBeat);
            const maxBeat = Math.max(this._dragStartBeat, this._dragEndBeat);
            const beatSec = this._beatSec || (60 / this.getBPM());
            const barSec = beatSec * 4;

            // Limpiar clases de arrastre continuo
            if (this._measureGridContainer) {
                this._measureGridContainer.querySelectorAll('.measure-beat-slot.slot-in-range').forEach(s => {
                    s.classList.remove('slot-in-range', 'slot-range-start', 'slot-range-end');
                });
            }

            if (minBeat === maxBeat) {
                // Clic en un solo cuadro -> toggle en la secuencia ordenada
                const g = minBeat;
                const barIdx = Math.floor(g / 4);
                const beatIdx = g % 4;
                const bStart = (barIdx * barSec) + (beatIdx * beatSec);
                const slotEl = document.getElementById(`beat-slot-${barIdx}-${beatIdx}`);
                this._toggleSlotInSequence(g, barIdx, beatIdx, bStart, beatSec, slotEl);
            } else {
                // Arrastre por varios cuadros -> agregar todos en el orden de arrastre
                const step = this._dragStartBeat <= this._dragEndBeat ? 1 : -1;
                for (let g = this._dragStartBeat; step > 0 ? g <= this._dragEndBeat : g >= this._dragEndBeat; g += step) {
                    if (!this._selectedSequence.some(item => item.globalBeat === g)) {
                        const barIdx = Math.floor(g / 4);
                        const beatIdx = g % 4;
                        const bStart = (barIdx * barSec) + (beatIdx * beatSec);
                        const s = document.getElementById(`beat-slot-${barIdx}-${beatIdx}`);
                        this._selectedSequence.push({
                            globalBeat: g,
                            barIndex: barIdx,
                            beatIndex: beatIdx,
                            beatStart: bStart,
                            beatSec: beatSec,
                            slot: s
                        });
                    }
                }
                this._refreshSequenceBadges();
                const lastItem = this._selectedSequence[this._selectedSequence.length - 1];
                this._openMiniChordPopoverForSequence(lastItem ? lastItem.slot : null);
            }
        });

        // Botones del Mini-Popover
        if (this._btnMiniClose) {
            this._btnMiniClose.addEventListener('click', () => this._closeMiniChordPopover());
        }
        if (this._btnMiniCancel) {
            this._btnMiniCancel.addEventListener('click', () => this._closeMiniChordPopover());
        }
        if (this._btnMiniDelete) {
            this._btnMiniDelete.addEventListener('click', () => this._deleteMiniChord());
        }
        if (this._btnMiniSave) {
            this._btnMiniSave.addEventListener('click', () => this._saveMiniChord(false));
        }
        if (this._btnMiniNext) {
            this._btnMiniNext.addEventListener('click', () => this._saveMiniChord(true));
        }

        if (this._miniPopoverInput) {
            this._miniPopoverInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this._saveMiniChord(e.shiftKey ? false : true);
                } else if (e.key === 'Tab') {
                    e.preventDefault();
                    this._saveMiniChord(true);
                } else if (e.key === 'Delete' || e.key === 'Del') {
                    if (!this._miniPopoverInput.value) {
                        e.preventDefault();
                        this._deleteMiniChord();
                    }
                }
            });

            this._miniPopoverInput.addEventListener('input', () => {
                const input = this._miniPopoverInput;
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
                this._updateSequenceFeedback();
            });
        }

        // Clic fuera del popover para cerrarlo (sin cerrar al hacer clic en celdas de la cuadrícula)
        document.addEventListener('mousedown', (e) => {
            if (!this._miniPopover || this._miniPopover.style.display === 'none') return;
            if (this._miniPopover.contains(e.target)) return;
            if (e.target.closest('.measure-beat-slot')) return;
            if (e.target.closest('#btnAddChordAtCurrentTime')) return;
            if (e.target.closest('#btnSelectAllGridSlots')) return;
            if (e.target.closest('#btnDeleteSelectedSlots')) return;
            this._closeMiniChordPopover();
        });

        // Botones de cabecera de la cuadrícula
        if (this._btnSelectAllGridSlots) {
            this._btnSelectAllGridSlots.addEventListener('click', () => this.selectAllGridSlots());
        }
        if (this._btnDeleteSelectedSlots) {
            this._btnDeleteSelectedSlots.addEventListener('click', () => this._deleteMiniChord());
        }
        if (this._btnExportChordsCsv) {
            this._btnExportChordsCsv.addEventListener('click', () => this.exportChordsToCSV());
        }
        if (this._btnImportChordsCsv) {
            this._btnImportChordsCsv.addEventListener('click', () => {
                if (this._inputImportChordsCsv) {
                    this._inputImportChordsCsv.value = '';
                    this._inputImportChordsCsv.click();
                }
            });
        }
        if (this._inputImportChordsCsv) {
            this._inputImportChordsCsv.addEventListener('change', (e) => this.handleImportChordsCSV(e));
        }
        if (this._btnClearAllGridChords) {
            this._btnClearAllGridChords.addEventListener('click', () => this.clearAllGridChords());
        }
        if (this._btnAddMeasureRow) {
            this._btnAddMeasureRow.addEventListener('click', () => this.addMeasureRow());
        }
        if (this._btnManualProgressionInput) {
            this._btnManualProgressionInput.addEventListener('click', () => this.openManualProgressionModal());
        }

        // Modal de progresión manual
        if (this._manualProgInput) {
            this._manualProgInput.addEventListener('input', () => {
                const input = this._manualProgInput;
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
            });
        }
        if (this._btnManualProgClose) {
            this._btnManualProgClose.addEventListener('click', () => this.closeManualProgressionModal());
        }
        if (this._btnManualProgCancel) {
            this._btnManualProgCancel.addEventListener('click', () => this.closeManualProgressionModal());
        }
        if (this._btnManualProgApply) {
            this._btnManualProgApply.addEventListener('click', () => this.applyManualProgression());
        }

        // Eventos del modo ventana completa / desacoplado
        if (this._btnUndockChordGrid) {
            this._btnUndockChordGrid.addEventListener('click', () => this.toggleGridUndock());
        }

        const gridHeader = document.querySelector('.chord-measure-grid-header');
        if (gridHeader) {
            gridHeader.addEventListener('dblclick', (e) => {
                if (!e.target.closest('button') && !e.target.closest('input') && !e.target.closest('select')) {
                    this.toggleGridUndock();
                }
            });
        }

        const colButtons = document.querySelectorAll('.btn-col-select');
        colButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                colButtons.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                const cols = btn.dataset.cols || '4';
                this.setGridColumns(cols);
            });
        });

        // Botón y modal de configuración de filas visibles
        if (this._btnConfigGridRows) {
            this._btnConfigGridRows.addEventListener('click', () => this.openGridRowsModal());
        }
        if (this._btnGridRowsModalClose) {
            this._btnGridRowsModalClose.addEventListener('click', () => this.closeGridRowsModal());
        }
        if (this._btnGridRowsModalCancel) {
            this._btnGridRowsModalCancel.addEventListener('click', () => this.closeGridRowsModal());
        }
        if (this._btnGridRowsModalApply) {
            this._btnGridRowsModalApply.addEventListener('click', () => this.applyGridRowsModal());
        }

        // Atajos de selección rápida dentro del modal
        const presetButtons = document.querySelectorAll('.btn-row-preset');
        presetButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const preset = btn.dataset.preset;
                if (this._inputGridRowsCount) {
                    if (preset === 'all') {
                        this._inputGridRowsCount.value = '99';
                    } else {
                        this._inputGridRowsCount.value = preset;
                    }
                }
                presetButtons.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
            });
        });

        if (this._inputGridRowsCount) {
            this._inputGridRowsCount.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.applyGridRowsModal();
                }
            });
        }

        // Aplicar cantidad de filas inicial
        this.setGridRows(this._gridRows || '3');

        // Atajo de teclado: Escape para volver a modo acoplado o cerrar modales
        window.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (this._gridRowsConfigModal && this._gridRowsConfigModal.style.display !== 'none') {
                    this.closeGridRowsModal();
                } else if (this._miniPopover && this._miniPopover.style.display !== 'none') {
                    this._closeMiniChordPopover();
                } else if (this._manualProgModal && this._manualProgModal.style.display !== 'none') {
                    this.closeManualProgressionModal();
                } else if (this._isGridUndocked) {
                    this.toggleGridUndock(false);
                }
            }
        });
    }

    /**
     * Alterna o establece el modo ventana completa / desacoplado de la interfaz de la cuadrícula.
     * @param {boolean} [forceState]
     */
    toggleGridUndock(forceState) {
        const nextState = forceState !== undefined ? forceState : !this._isGridUndocked;
        this._isGridUndocked = nextState;

        const target = this._gridPanel || document.getElementById('primaryChordGridPanel') || this._playbackControls || document.getElementById('trackPlaybackControls');
        if (!target) return;

        if (this._isGridUndocked) {
            target.classList.add('is-undocked');
            document.body.classList.add('grid-undocked-open');

            if (this._lblUndockChordGrid) this._lblUndockChordGrid.textContent = 'Acoplar';
            if (this._iconUndockChordGrid) this._iconUndockChordGrid.className = 'fas fa-down-left-and-up-right-to-center';
            if (this._btnUndockChordGrid) this._btnUndockChordGrid.title = 'Acoplar / Salir de ventana completa (Esc)';
            if (this._gridColsPillGroup) this._gridColsPillGroup.style.display = 'inline-flex';
            if (this._gridRowsPillGroup) this._gridRowsPillGroup.style.display = 'none';

            this.setGridColumns(this._gridCols || '4');
        } else {
            target.classList.remove('is-undocked');
            document.body.classList.remove('grid-undocked-open');

            if (this._lblUndockChordGrid) this._lblUndockChordGrid.textContent = 'Desacoplar';
            if (this._iconUndockChordGrid) this._iconUndockChordGrid.className = 'fas fa-up-right-and-down-left-from-center';
            if (this._btnUndockChordGrid) this._btnUndockChordGrid.title = 'Desacoplar a ventana completa para ver más compases';
            if (this._gridColsPillGroup) this._gridColsPillGroup.style.display = 'none';
            if (this._gridRowsPillGroup) this._gridRowsPillGroup.style.display = 'inline-flex';

            if (this._measureGridContainer) {
                this._measureGridContainer.classList.remove('cols-1', 'cols-2', 'cols-4', 'cols-auto');
            }
        }

        // Reposicionar el popover si estuviera abierto
        if (this._miniPopover && this._miniPopover.style.display !== 'none' && this._selectedSequence && this._selectedSequence.length > 0) {
            const last = this._selectedSequence[this._selectedSequence.length - 1];
            this._openMiniChordPopoverForSequence(last ? last.slot : null);
        }
    }

    /**
     * Abre el modal de configuración de filas visibles.
     */
    openGridRowsModal() {
        if (!this._gridRowsConfigModal) return;
        this._gridRowsConfigModal.style.display = 'flex';
        this._gridRowsConfigModal.classList.remove('hidden');

        if (this._inputGridRowsCount) {
            this._inputGridRowsCount.value = this._gridRows === 'all' ? '99' : (this._gridRows || '3');
            this._inputGridRowsCount.focus();
            this._inputGridRowsCount.select();
        }

        if (this._gridRowsModalFeedback) {
            this._gridRowsModalFeedback.textContent = '';
        }

        const presetButtons = document.querySelectorAll('.btn-row-preset');
        presetButtons.forEach(btn => {
            const p = btn.dataset.preset;
            if (p === this._gridRows || (p === 'all' && this._gridRows === 'all')) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        });
    }

    /**
     * Cierra el modal de configuración de filas visibles.
     */
    closeGridRowsModal() {
        if (!this._gridRowsConfigModal) return;
        this._gridRowsConfigModal.style.display = 'none';
        this._gridRowsConfigModal.classList.add('hidden');
    }

    /**
     * Aplica la cantidad de filas digitada por el usuario en el modal.
     */
    applyGridRowsModal() {
        if (!this._inputGridRowsCount) return;
        const val = parseInt(this._inputGridRowsCount.value, 10);
        if (isNaN(val) || val <= 0) {
            if (this._gridRowsModalFeedback) {
                this._gridRowsModalFeedback.style.color = '#f87171';
                this._gridRowsModalFeedback.textContent = 'Por favor digita un número de filas válido (mayor a 0).';
            }
            return;
        }

        if (val >= 50) {
            this.setGridRows('all');
        } else {
            this.setGridRows(String(val));
        }

        if (this._gridRowsModalFeedback) {
            this._gridRowsModalFeedback.style.color = '#10b981';
            this._gridRowsModalFeedback.textContent = `Configurado a ${val >= 50 ? 'todas las' : val} filas visibles.`;
        }

        setTimeout(() => {
            this.closeGridRowsModal();
        }, 300);
    }

    /**
     * Establece el número de filas visibles en modo estándar / acoplado.
     * @param {string|number} rows Cantidad de filas o 'all'
     */
    setGridRows(rows) {
        this._gridRows = String(rows);
        if (!this._measureGridContainer) return;

        if (this._gridRows === 'all') {
            this._measureGridContainer.style.maxHeight = 'none';
            if (this._secondaryMeasureGridContainer) {
                this._secondaryMeasureGridContainer.style.maxHeight = 'none';
            }
        } else {
            const num = parseInt(this._gridRows, 10) || 3;
            // Cada fila de compás mide aproximadamente 46-52px de altura con padding y gap
            const calculatedHeight = Math.max(52, num * 52);
            this._measureGridContainer.style.maxHeight = `${calculatedHeight}px`;
            if (this._secondaryMeasureGridContainer) {
                this._secondaryMeasureGridContainer.style.maxHeight = `${calculatedHeight}px`;
            }
        }
    }

    /**
     * Establece el número de compases por fila en modo ventana completa.
     * @param {string} cols '1', '2', '4', 'auto'
     */
    setGridColumns(cols) {
        this._gridCols = cols;
        if (!this._measureGridContainer) return;
        this._measureGridContainer.classList.remove('cols-1', 'cols-2', 'cols-4', 'cols-auto');
        this._measureGridContainer.classList.add(`cols-${cols}`);
    }

    /**
     * Selecciona todas las celdas de la cuadrícula en orden secuencial (1 al N).
     */
    selectAllGridSlots() {
        if (!this._measureGridContainer) return;
        const songBpm = this.getBPM();
        const beatSec = 60 / songBpm;
        const barSec = 4 * beatSec;
        const totalBars = this._totalBars || 4;
        const totalBeats = totalBars * 4;

        this._selectedSequence = [];
        for (let g = 0; g < totalBeats; g++) {
            const m = Math.floor(g / 4);
            const b = g % 4;
            const bStart = (m * barSec) + (b * beatSec);
            const slot = document.getElementById(`beat-slot-${m}-${b}`);
            this._selectedSequence.push({
                globalBeat: g,
                barIndex: m,
                beatIndex: b,
                beatStart: bStart,
                beatSec: beatSec,
                slot: slot
            });
        }

        this._refreshSequenceBadges();

        const firstSlot = this._selectedSequence[0]?.slot;
        this._openMiniChordPopoverForSequence(firstSlot);
    }

    /**
     * Abre el mini-popover para la secuencia de cuadros seleccionados en orden.
     * @private
     * @param {HTMLElement} [anchorSlot]
     */
    _openMiniChordPopoverForSequence(anchorSlot) {
        if (!this._miniPopover || !this._chordMeasureGridWrapper || this._selectedSequence.length === 0) return;

        const count = this._selectedSequence.length;
        const first = this._selectedSequence[0];
        const last = this._selectedSequence[count - 1];
        const totalBeats = (this._totalBars || 4) * 4;

        if (this._miniPopoverTitle) {
            if (count === totalBeats && count > 1) {
                this._miniPopoverTitle.innerHTML = `<i class="fas fa-check-double"></i> Todas (${count})`;
            } else if (count === 1) {
                this._miniPopoverTitle.innerHTML = `<i class="fas fa-music"></i> #${1} · C${first.barIndex + 1}.P${first.beatIndex + 1}`;
            } else {
                this._miniPopoverTitle.innerHTML = `<i class="fas fa-list-ol"></i> 1 al ${count}`;
            }
        }

        // Si el usuario no ha escrito nada, sugerir los acordes que ya están presentes
        const currentSymbols = this._selectedSequence.map(item => {
            const c = (this._currentAnalysisData && this._currentAnalysisData.chords || []).find(
                ch => ch.startTime <= (item.beatStart + 0.05) && ch.endTime > (item.beatStart + 0.05)
            );
            return c ? c.chordSymbol : '';
        });

        if (this._miniPopoverInput && !this._miniPopoverInput.value) {
            const nonEmpty = currentSymbols.filter(Boolean);
            if (nonEmpty.length > 0) {
                if (nonEmpty.length === count && currentSymbols.every(s => s === currentSymbols[0])) {
                    this._miniPopoverInput.value = currentSymbols[0];
                } else {
                    this._miniPopoverInput.value = currentSymbols.filter(Boolean).join(', ');
                }
            }
        }

        this._updateSequenceFeedback();

        // Mostrar popover
        this._miniPopover.style.display = 'flex';
        this._miniPopover.classList.remove('hidden');

        // Posicionar popover debajo de la cuadrícula con el mismo ancho que la sección de la cuadrícula
        const targetSlot = anchorSlot || last.slot || document.getElementById(`beat-slot-${last.barIndex}-${last.beatIndex}`);
        const wrapper = targetSlot?.closest('.chord-measure-grid-wrapper') || this._chordMeasureGridWrapper;
        if (wrapper && this._miniPopover.parentElement !== wrapper) {
            wrapper.appendChild(this._miniPopover);
        }
        const wrapperRect = wrapper ? wrapper.getBoundingClientRect() : this._chordMeasureGridWrapper.getBoundingClientRect();

        let arrowX = wrapperRect.width / 2;
        if (targetSlot) {
            const slotRect = targetSlot.getBoundingClientRect();
            const slotCenterX = slotRect.left - wrapperRect.left + (slotRect.width / 2);
            arrowX = Math.max(16, Math.min(wrapperRect.width - 16, slotCenterX));
        }

        const top = wrapperRect.height + 6;

        this._miniPopover.style.left = '0px';
        this._miniPopover.style.width = '100%';
        this._miniPopover.style.boxSizing = 'border-box';
        this._miniPopover.style.top = `${Math.round(top)}px`;
        this._miniPopover.style.setProperty('--popover-arrow-x', `${Math.round(arrowX)}px`);

        if (this._miniPopoverInput) {
            setTimeout(() => {
                this._miniPopoverInput.focus();
                this._miniPopoverInput.select();
            }, 30);
        }
    }

    /**
     * Muestra la previsualización en vivo de cómo se asignarán los acordes a cada cuadro en orden.
     * @private
     */
    _updateSequenceFeedback() {
        if (!this._miniPopoverFeedback) return;
        const count = this._selectedSequence.length;
        if (count === 0) {
            this._miniPopoverFeedback.textContent = '';
            return;
        }

        const raw = (this._miniPopoverInput ? this._miniPopoverInput.value : '').trim();
        if (!raw) {
            this._miniPopoverFeedback.innerHTML = `<span style="color:#94a3b8; font-size:0.68rem;">Escribe acordes separados por comas para asignar en orden (1 al ${count}): ej. <code>G, C, D</code></span>`;
            return;
        }

        const tokens = raw.split(',').map(s => s.trim()).filter(s => s.length > 0);
        if (tokens.length === 0) {
            this._miniPopoverFeedback.innerHTML = `<span style="color:#94a3b8; font-size:0.68rem;">Escribe acordes separados por comas: ej. <code>G, C, D</code></span>`;
            return;
        }

        // Construir chips para cada cuadro de la secuencia
        const chips = this._selectedSequence.map((item, idx) => {
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

        this._miniPopoverFeedback.innerHTML = `<div style="display:flex; flex-wrap:wrap; gap:2px; align-items:center;">${chips}</div>`;
    }

    /**
     * Compatibilidad: Abre el mini-popover para un rango seleccionado.
     * @private
     * @param {Object} range
     */
    _openMiniChordPopoverForRange(range) {
        if (!range) return;
        const beatSec = this._beatSec || (60 / this.getBPM());
        const barSec = beatSec * 4;
        this._selectedSequence = [];
        for (let g = range.minBeat; g <= range.maxBeat; g++) {
            const barIdx = Math.floor(g / 4);
            const beatIdx = g % 4;
            const bStart = (barIdx * barSec) + (beatIdx * beatSec);
            const s = document.getElementById(`beat-slot-${barIdx}-${beatIdx}`);
            this._selectedSequence.push({
                globalBeat: g,
                barIndex: barIdx,
                beatIndex: beatIdx,
                beatStart: bStart,
                beatSec: beatSec,
                slot: s
            });
        }
        this._refreshSequenceBadges();
        this._openMiniChordPopoverForSequence(range.anchorSlot);
    }

    /**
     * Cierra el popover de compases y deselecciona los cuadros y la secuencia.
     * @private
     */
    _closeMiniChordPopover() {
        if (this._miniPopover) {
            this._miniPopover.style.display = 'none';
            this._miniPopover.classList.add('hidden');
        }
        this._clearSequenceSelection();
        if (this._measureGridContainer) {
            const slots = this._measureGridContainer.querySelectorAll('.measure-beat-slot');
            slots.forEach(s => s.classList.remove('slot-in-range', 'slot-range-start', 'slot-range-end', 'selected-slot'));
        }
        this._selectedGridRange = null;
        this._dragStartBeat = null;
        this._dragEndBeat = null;
    }

    /**
     * Resetea / vacía los acordes en todos los cuadros de la secuencia seleccionada.
     * @private
     */
    _deleteMiniChord() {
        if (!this._currentAnalysisData) return;
        const slotsToClear = (this._selectedSequence && this._selectedSequence.length > 0)
            ? this._selectedSequence
            : (this._selectedGridRange ? [{
                beatStart: this._selectedGridRange.startBeatStart,
                beatSec: this._selectedGridRange.endBeatEnd - this._selectedGridRange.startBeatStart
            }] : []);

        if (slotsToClear.length === 0) return;

        let timeline = this._currentAnalysisData.chords || [];

        slotsToClear.forEach(item => {
            const start = item.beatStart;
            const end = item.beatStart + item.beatSec;
            const filtered = [];

            for (const c of timeline) {
                const overlapStart = Math.max(c.startTime, start);
                const overlapEnd = Math.min(c.endTime, end);

                if (overlapEnd - overlapStart > 0.01) {
                    // Hay intersección con el pulso a borrar
                    if (c.startTime < start - 0.02) {
                        filtered.push({ ...c, endTime: start });
                    }
                    if (c.endTime > end + 0.02) {
                        filtered.push({ ...c, startTime: end });
                    }
                } else {
                    // No hay intersección: conservar acorde intacto
                    filtered.push(c);
                }
            }
            timeline = filtered;
        });

        this._currentAnalysisData.chords = timeline.sort((a, b) => a.startTime - b.startTime);
        audioPlayerController.setChordsTimeline(this._currentAnalysisData.chords);

        // Si el cursor de reproducción está en algún cuadro eliminado, actualizar diapasón
        const curTime = audioPlayerController.currentTime || 0;
        const curActive = this._currentAnalysisData.chords.find(c => curTime >= c.startTime && curTime < c.endTime);
        if (curActive) {
            const actIdx = this._currentAnalysisData.chords.indexOf(curActive);
            this.setActiveChord(curActive, actIdx);
            eventBus.emit('player:chord_active', { chord: curActive, index: actIdx, syncWithDiapason: true });
        } else {
            this.setActiveChord(null, -1);
            eventBus.emit('player:chord_active', { chord: null, index: -1, syncWithDiapason: true });
        }

        this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, this.getBPM());
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, this.getBPM());
        this.renderChordsStrip(this._currentAnalysisData.chords, this._onChordMarkerClick);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(this._currentAnalysisData.chords);
        }

        this._closeMiniChordPopover();
    }

    /**
     * Guarda y asigna en orden de secuencia los acordes separados por comas.
     * @private
     * @param {boolean} [advanceToNext=false]
     */
    _saveMiniChord(advanceToNext = false) {
        if (!this._selectedSequence || this._selectedSequence.length === 0) {
            if (this._selectedGridRange) {
                const { startBeatStart, endBeatEnd } = this._selectedGridRange;
                this._selectedSequence = [{
                    globalBeat: this._selectedGridRange.minBeat,
                    barIndex: Math.floor(this._selectedGridRange.minBeat / 4),
                    beatIndex: this._selectedGridRange.minBeat % 4,
                    beatStart: startBeatStart,
                    beatSec: endBeatEnd - startBeatStart,
                    slot: this._selectedGridRange.anchorSlot
                }];
            } else {
                return;
            }
        }

        const rawText = (this._miniPopoverInput ? this._miniPopoverInput.value : '').trim();
        if (!rawText) {
            this._deleteMiniChord();
            return;
        }

        const tokens = rawText.split(',').map(s => s.trim()).filter(s => s.length > 0);
        if (tokens.length === 0) {
            this._deleteMiniChord();
            return;
        }

        if (!this._currentAnalysisData) {
            this._currentAnalysisData = {
                duration: Math.max(16, (this._totalBars || 4) * 4 * (this._beatSec || 0.5)),
                bpm: this.getBPM(),
                chords: []
            };
        }
        if (!this._currentAnalysisData.chords) {
            this._currentAnalysisData.chords = [];
        }

        const count = this._selectedSequence.length;
        let lastParsedMidis = null;

        // Asignar a cada cuadro en el orden de la secuencia
        this._selectedSequence.forEach((item, idx) => {
            let chordStr = '';
            if (tokens.length === 1) {
                chordStr = tokens[0];
            } else if (idx < tokens.length) {
                chordStr = tokens[idx];
            } else if (tokens.length > 1 && count % tokens.length === 0) {
                chordStr = tokens[idx % tokens.length];
            } else {
                return; // Fuera del rango de acordes especificados
            }

            if (!chordStr) return;
            chordStr = formatChordInputString(chordStr);

            let parsed = parseChordNotation(chordStr);
            if (!parsed) {
                parsed = {
                    root: 0,
                    type: 'major',
                    chordSymbol: chordStr,
                    name: chordStr,
                    intervals: [0, 4, 7],
                    noteMods: [0, 4, 7],
                    playbackMidis: [60, 64, 67]
                };
            }

            const baseMidi = 60 + (parsed.root !== undefined ? parsed.root : 0);
            const noteMods = parsed.noteMods || (parsed.intervals || [0, 4, 7]).map(i => ((parsed.root || 0) + i) % 12);
            const playbackMidis = parsed.playbackMidis || (parsed.intervals || [0, 4, 7]).map(i => baseMidi + i);
            lastParsedMidis = playbackMidis;

            const slotStart = item.beatStart;
            const slotEnd = item.beatStart + item.beatSec;

            // Cortar y remover solapamientos en este pulso
            const existing = this._currentAnalysisData.chords || [];
            const filtered = [];

            for (const c of existing) {
                if (c.startTime >= slotStart - 0.02 && c.endTime <= slotEnd + 0.02) {
                    continue;
                }
                if (c.startTime < slotStart - 0.02 && c.endTime > slotEnd + 0.02) {
                    filtered.push({ ...c, endTime: slotStart });
                    filtered.push({ ...c, startTime: slotEnd });
                    continue;
                }
                if (c.startTime < slotStart && c.endTime > slotStart) {
                    filtered.push({ ...c, endTime: slotStart });
                    continue;
                }
                if (c.startTime < slotEnd && c.endTime > slotEnd) {
                    filtered.push({ ...c, startTime: slotEnd });
                    continue;
                }
                filtered.push(c);
            }

            const newChord = {
                root: parsed.root !== undefined ? parsed.root : 0,
                type: parsed.type || 'major',
                chordSymbol: (parsed && parsed.chordSymbol) ? parsed.chordSymbol : chordStr,
                name: (parsed && (parsed.chordName || parsed.name)) ? (parsed.chordName || parsed.name) : chordStr,
                startTime: slotStart,
                endTime: slotEnd,
                noteMods: noteMods,
                playbackMidis: playbackMidis,
                confidence: 1.0,
                forced: true
            };

            filtered.push(newChord);
            this._currentAnalysisData.chords = filtered.sort((a, b) => a.startTime - b.startTime);
        });

        // Unificar acordes contiguos con el mismo símbolo
        const consolidated = [];
        for (const c of this._currentAnalysisData.chords) {
            if (consolidated.length > 0) {
                const prev = consolidated[consolidated.length - 1];
                if (prev.chordSymbol === c.chordSymbol && Math.abs(prev.endTime - c.startTime) < 0.03) {
                    prev.endTime = c.endTime;
                    continue;
                }
            }
            consolidated.push({ ...c });
        }
        this._currentAnalysisData.chords = consolidated;

        audioPlayerController.setChordsTimeline(this._currentAnalysisData.chords);

        // Preescucha con audioEngine
        if (audioEngine && lastParsedMidis && lastParsedMidis.length > 0) {
            const chordVol = audioPlayerController.getChordEffectiveVolume();
            if (chordVol > 0) {
                audioEngine.play(lastParsedMidis, "4n", chordVol);
            }
        }

        // Sincronizar diapasón con el primer acorde modificado
        const firstItem = this._selectedSequence[0];
        const activeChord = this._currentAnalysisData.chords.find(
            c => c.startTime <= (firstItem.beatStart + 0.05) && c.endTime > (firstItem.beatStart + 0.05)
        );
        if (activeChord) {
            eventBus.emit('player:chord_active', {
                chord: activeChord,
                index: this._currentAnalysisData.chords.indexOf(activeChord),
                syncWithDiapason: true
            });
        }

        this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, this.getBPM());
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, this.getBPM());
        this.renderChordsStrip(this._currentAnalysisData.chords, this._onChordMarkerClick);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(this._currentAnalysisData.chords);
        }

        if (advanceToNext) {
            const highestBeat = Math.max(...this._selectedSequence.map(s => s.globalBeat));
            const count = this._selectedSequence.length;
            const nextMinBeat = highestBeat + 1;
            const neededBars = Math.ceil((nextMinBeat + count) / 4);
            while (this._totalBars < neededBars) {
                this.addMeasureRow();
            }

            const beatSec = this._beatSec || (60 / this.getBPM());
            const barSec = beatSec * 4;

            this._selectedSequence = [];
            for (let i = 0; i < count; i++) {
                const g = nextMinBeat + i;
                const barIdx = Math.floor(g / 4);
                const beatIdx = g % 4;
                const bStart = (barIdx * barSec) + (beatIdx * beatSec);
                const s = document.getElementById(`beat-slot-${barIdx}-${beatIdx}`);
                this._selectedSequence.push({
                    globalBeat: g,
                    barIndex: barIdx,
                    beatIndex: beatIdx,
                    beatStart: bStart,
                    beatSec: beatSec,
                    slot: s
                });
            }

            this._refreshSequenceBadges();
            const first = this._selectedSequence[0];
            audioPlayerController.seek(first.beatStart);
            if (this._miniPopoverInput) this._miniPopoverInput.value = '';
            this._openMiniChordPopoverForSequence(first.slot);
        } else {
            this._closeMiniChordPopover();
        }
    }

    /**
     * Borra todos los acordes de la cuadrícula, dejando los compases limpios para digitar.
     */
    clearAllGridChords() {
        const confirmed = confirm('¿Deseas borrar todos los acordes de la cuadrícula?\nPodrás comenzar a digitar nuevos compases manualmente.');
        if (!confirmed) return;

        if (!this._currentAnalysisData) {
            this._currentAnalysisData = {
                duration: 16,
                bpm: this.getBPM(),
                chords: []
            };
        } else {
            this._currentAnalysisData.chords = [];
        }

        audioPlayerController.setChordsTimeline([]);
        this.setActiveChord(null, -1);
        eventBus.emit('player:chord_active', { chord: null, index: -1, syncWithDiapason: true });
        this._clearSequenceSelection();

        this.renderMeasureGrid([], this._currentAnalysisData.duration, this.getBPM());
        this.renderChordProgressBar([], this._currentAnalysisData.duration, this.getBPM());
        this.renderChordsStrip([], this._onChordMarkerClick);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated([]);
        }

        this._closeMiniChordPopover();
    }

    /**
     * Agrega un nuevo compás vacío al final de la cuadrícula.
     */
    addMeasureRow() {
        const songBpm = this.getBPM();
        const beatSec = 60 / songBpm;
        const barSec = 4 * beatSec;
        const curBars = this._totalBars || 4;
        const newTotalBars = curBars + 1;
        this._totalBars = newTotalBars;

        const newDuration = newTotalBars * barSec;
        if (!this._currentAnalysisData) {
            this._currentAnalysisData = {
                duration: newDuration,
                bpm: songBpm,
                chords: []
            };
        } else {
            this._currentAnalysisData.duration = Math.max(this._currentAnalysisData.duration || 0, newDuration);
        }

        this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, songBpm);
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, songBpm);

        const newRow = document.getElementById(`measure-row-${newTotalBars - 1}`);
        if (newRow && this._measureGridContainer) {
            newRow.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }

    /**
     * Exporta los acordes registrados en la cuadrícula a un archivo CSV.
     * Estructura: Compas, Pulso, Tiempo_Seg, Duracion_Pulsos, Acorde
     */
    exportChordsToCSV() {
        let chords = (this._currentAnalysisData && this._currentAnalysisData.chords) || [];

        // Respaldo de escaneo visual si la estructura en memoria estuviera vacía
        if (chords.length === 0 && this._measureGridContainer) {
            const slots = this._measureGridContainer.querySelectorAll('.measure-beat-slot');
            const bpm = this.getBPM() || 120;
            const beatSec = 60 / bpm;
            const barSec = 4 * beatSec;
            const extracted = [];
            slots.forEach(slot => {
                const textEl = slot.querySelector('.slot-chord-text');
                if (textEl && !slot.classList.contains('has-chord-continue')) {
                    const sym = textEl.childNodes[0] ? textEl.childNodes[0].textContent.trim() : textEl.textContent.trim();
                    if (sym && sym !== '·') {
                        const barIdx = parseInt(slot.dataset.barIndex || '0', 10);
                        const beatIdx = parseInt(slot.dataset.beatIndex || '0', 10);
                        const startTime = (barIdx * barSec) + (beatIdx * beatSec);
                        extracted.push({
                            chordSymbol: sym,
                            name: sym,
                            startTime: startTime,
                            endTime: startTime + beatSec
                        });
                    }
                }
            });
            if (extracted.length > 0) {
                chords = extracted;
            }
        }

        if (!chords || chords.length === 0) {
            alert('No hay acordes registrados en la cuadrícula para exportar.');
            return;
        }

        const bpm = this.getBPM() || 120;
        const beatSec = 60 / bpm;

        // Ordenar acordes por tiempo de inicio
        const sortedChords = [...chords].sort((a, b) => a.startTime - b.startTime);

        // Estructura CSV: Compas, Pulso, Tiempo_Seg, Duracion_Pulsos, Acorde
        const rows = [
            ['Compas', 'Pulso', 'Tiempo_Seg', 'Duracion_Pulsos', 'Acorde'].join(',')
        ];

        for (const c of sortedChords) {
            const symbol = (c.chordSymbol || c.name || '').trim();
            if (!symbol) continue;

            const startBeat = Math.max(0, Math.round(c.startTime / beatSec));
            const compas = Math.floor(startBeat / 4) + 1;
            const pulso = (startBeat % 4) + 1;
            const durationBeats = Math.max(1, Math.round((c.endTime - c.startTime) / beatSec));
            const timeSec = (c.startTime || 0).toFixed(2);
            const safeSymbol = symbol.includes(',') ? `"${symbol}"` : symbol;

            rows.push([compas, pulso, timeSec, durationBeats, safeSymbol].join(','));
        }

        const csvContent = rows.join('\r\n');
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');

        let trackName = 'acordes_cuadricula';
        if (this._fileNameLabel && this._fileNameLabel.textContent && this._fileNameLabel.textContent !== '-') {
            trackName = this._fileNameLabel.textContent.replace(/\.[^/.]+$/, '').trim().replace(/[\\/:*?"<>|]/g, '_');
        }

        link.setAttribute('href', url);
        link.setAttribute('download', `${trackName}_acordes.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }

    /**
     * Manejador del input de archivo para importar acordes desde CSV.
     * @param {Event} e
     */
    handleImportChordsCSV(e) {
        const file = e.target && e.target.files && e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            try {
                const text = event.target.result;
                this.importChordsFromCSVText(text, file.name);
            } catch (err) {
                console.error('Error importando CSV:', err);
                alert('Ocurrió un error al procesar el archivo CSV: ' + err.message);
            }
        };
        reader.readAsText(file, 'utf-8');
    }

    /**
     * Parsea e importa acordes desde texto CSV con soporte flexible de columnas y delimitadores.
     * @param {string} csvText
     * @param {string} [fileName]
     */
    importChordsFromCSVText(csvText, fileName = '') {
        if (!csvText || typeof csvText !== 'string') {
            alert('El archivo no contiene texto válido.');
            return;
        }

        const rawLines = csvText.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith('#'));
        if (rawLines.length === 0) {
            alert('El archivo CSV está vacío o no contiene filas con datos.');
            return;
        }

        // Detectar delimitador (; , o tabulador)
        const firstLine = rawLines[0];
        let sep = ',';
        if (firstLine.includes(';') && !firstLine.includes(',')) {
            sep = ';';
        } else if (firstLine.includes('\t')) {
            sep = '\t';
        }

        const splitLine = (line) => {
            const regex = new RegExp(`(?:^|${sep})(\"(?:[^\"]+|\"\")*\"|[^${sep}]*)`, 'g');
            const matches = [];
            let match;
            while ((match = regex.exec(line)) !== null) {
                let val = match[1];
                if (val.startsWith('"') && val.endsWith('"')) {
                    val = val.slice(1, -1).replace(/""/g, '"');
                }
                matches.push(val.trim());
            }
            return matches;
        };

        const headerTokens = splitLine(firstLine).map(h => h.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, ''));
        let isHeader = false;
        let compasCol = -1;
        let pulsoCol = -1;
        let tiempoSegCol = -1;
        let duracionCol = -1;
        let acordeCol = -1;

        headerTokens.forEach((token, idx) => {
            if (/compas|measure|bar/.test(token)) compasCol = idx;
            else if (/pulso|beat/.test(token)) pulsoCol = idx;
            else if (/tiempo_seg|segundo|sec|time/.test(token)) tiempoSegCol = idx;
            else if (/duracion|duration|length/.test(token)) duracionCol = idx;
            else if (/acorde|chord/.test(token)) acordeCol = idx;
        });

        if (compasCol !== -1 || acordeCol !== -1 || pulsoCol !== -1 || tiempoSegCol !== -1) {
            isHeader = true;
        }

        const dataLines = isHeader ? rawLines.slice(1) : rawLines;
        if (dataLines.length === 0) {
            alert('El archivo CSV solo contiene el encabezado pero no tiene filas de acordes.');
            return;
        }

        if (!isHeader) {
            const sample = splitLine(dataLines[0]);
            if (sample.length >= 5) {
                compasCol = 0; pulsoCol = 1; tiempoSegCol = 2; duracionCol = 3; acordeCol = 4;
            } else if (sample.length === 4) {
                compasCol = 0; pulsoCol = 1; duracionCol = 2; acordeCol = 3;
            } else if (sample.length === 3) {
                compasCol = 0; pulsoCol = 1; acordeCol = 2;
            } else if (sample.length === 2) {
                tiempoSegCol = 0; acordeCol = 1;
            }
        } else {
            if (acordeCol === -1) {
                acordeCol = headerTokens.findIndex(t => /chord|acorde|simbolo|nota/.test(t));
                if (acordeCol === -1) acordeCol = headerTokens.length - 1;
            }
        }

        const bpm = this.getBPM() || 120;
        const beatSec = 60 / bpm;
        const barSec = 4 * beatSec;

        const parsedEvents = [];

        dataLines.forEach((line) => {
            const cols = splitLine(line);
            if (cols.length === 0) return;

            let chordSymbol = (acordeCol >= 0 && cols[acordeCol]) ? cols[acordeCol].trim() : '';
            if (!chordSymbol || chordSymbol === '-' || chordSymbol === '.') return;

            let compas = 1;
            let pulso = 1;
            let durBeats = 1;

            if (duracionCol >= 0 && cols[duracionCol]) {
                const parsedDur = parseFloat(cols[duracionCol].replace(',', '.'));
                if (!isNaN(parsedDur) && parsedDur > 0) durBeats = parsedDur;
            }

            if (compasCol >= 0 && cols[compasCol] !== undefined) {
                const parsedCompas = parseInt(cols[compasCol], 10);
                if (!isNaN(parsedCompas)) compas = Math.max(1, parsedCompas);
            }

            if (pulsoCol >= 0 && cols[pulsoCol] !== undefined) {
                const parsedPulso = parseInt(cols[pulsoCol], 10);
                if (!isNaN(parsedPulso)) pulso = Math.max(1, Math.min(4, parsedPulso));
            }

            let startTime = ((compas - 1) * barSec) + ((pulso - 1) * beatSec);

            if (compasCol === -1 && pulsoCol === -1 && tiempoSegCol >= 0 && cols[tiempoSegCol]) {
                const parsedSec = parseFloat(cols[tiempoSegCol].replace(',', '.'));
                if (!isNaN(parsedSec)) {
                    startTime = Math.max(0, parsedSec);
                    const beatIndex = Math.round(startTime / beatSec);
                    compas = Math.floor(beatIndex / 4) + 1;
                    pulso = (beatIndex % 4) + 1;
                }
            }

            const endTime = startTime + (durBeats * beatSec);

            parsedEvents.push({
                compas,
                pulso,
                chordSymbol,
                startTime,
                endTime,
                durBeats
            });
        });

        if (parsedEvents.length === 0) {
            alert('No se pudieron reconocer acordes válidos en las filas del archivo.');
            return;
        }

        parsedEvents.sort((a, b) => a.startTime - b.startTime);

        const generatedChords = [];

        parsedEvents.forEach((ev) => {
            const sym = ev.chordSymbol;
            let parsed = parseChordNotation(sym);
            if (!parsed) {
                parsed = {
                    root: 0,
                    type: 'major',
                    chordSymbol: sym,
                    name: sym,
                    intervals: [0, 4, 7],
                    noteMods: [0, 4, 7],
                    playbackMidis: [60, 64, 67]
                };
            }

            const baseMidi = 60 + (parsed.root !== undefined ? parsed.root : 0);
            const noteMods = parsed.noteMods || (parsed.intervals || [0, 4, 7]).map(i => ((parsed.root || 0) + i) % 12);
            const playbackMidis = parsed.playbackMidis || (parsed.intervals || [0, 4, 7]).map(i => baseMidi + i);

            generatedChords.push({
                root: parsed.root !== undefined ? parsed.root : 0,
                type: parsed.type || 'major',
                chordSymbol: sym,
                name: parsed.name || sym,
                startTime: ev.startTime,
                endTime: ev.endTime,
                noteMods: noteMods,
                playbackMidis: playbackMidis,
                confidence: 1.0,
                forced: true
            });
        });

        const maxEndTime = generatedChords.reduce((max, c) => Math.max(max, c.endTime), 0);
        const totalBars = Math.max(4, Math.ceil(maxEndTime / barSec));
        this._totalBars = totalBars;

        this._currentAnalysisData = {
            duration: Math.max(maxEndTime, totalBars * barSec),
            bpm: bpm,
            chords: generatedChords
        };

        audioPlayerController.setChordsTimeline(this._currentAnalysisData.chords);
        this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, bpm);
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, bpm);

        if (this._measureGridContainer) {
            this._measureGridContainer.scrollTo({ top: 0, behavior: 'smooth' });
        }

        const trackDisplay = fileName ? ` desde "${fileName}"` : '';
        alert(`¡Acordes importados con éxito${trackDisplay}!\nSe cargaron ${generatedChords.length} acordes en ${totalBars} compases.`);
    }

    /**
     * Aplica un arreglo de acordes directamente a la cuadrícula 4/4.
     * @param {Array<Object>} chords
     * @param {number} duration
     * @param {number} bpm
     */
    applyChordsToGrid(chords, duration, bpm) {
        if (!chords || chords.length === 0) return;
        const effectiveBpm = bpm || 70;
        const effectiveDuration = duration || chords[chords.length - 1].endTime;

        this.setBPM(effectiveBpm);

        this._currentAnalysisData = {
            duration: effectiveDuration,
            bpm: effectiveBpm,
            chords: [...chords]
        };

        this.renderMeasureGrid(chords, effectiveDuration, effectiveBpm);
        this.renderChordProgressBar(chords, effectiveDuration, effectiveBpm);

        if (this._measureGridContainer) {
            this._measureGridContainer.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    /**
     * Abre el modal para digitar progresiones armónicas de texto.
     */
    openManualProgressionModal() {
        if (!this._manualProgModal) return;
        this._closeMiniChordPopover();
        this._manualProgModal.style.display = 'flex';
        this._manualProgModal.classList.remove('hidden');
        if (this._manualProgInput) {
            this._manualProgInput.value = '';
            setTimeout(() => this._manualProgInput.focus(), 50);
        }
        if (this._manualProgFeedback) {
            this._manualProgFeedback.textContent = '';
        }
    }

    /**
     * Cierra el modal de progresión manual.
     */
    closeManualProgressionModal() {
        if (!this._manualProgModal) return;
        this._manualProgModal.style.display = 'none';
        this._manualProgModal.classList.add('hidden');
    }

    /**
     * Parsea y carga los acordes de texto a la cuadrícula 4/4.
     */
    applyManualProgression() {
        if (!this._manualProgInput) return;
        const text = this._manualProgInput.value.trim();
        if (!text) {
            if (this._manualProgFeedback) {
                this._manualProgFeedback.textContent = 'Por favor digita al menos un acorde.';
                this._manualProgFeedback.style.color = '#f87171';
            }
            return;
        }

        const rawTokens = text.split(/[\n|,]+/).map(t => t.trim()).filter(Boolean);
        const chordTokens = [];
        for (const tok of rawTokens) {
            const sub = tok.split(/\s+/).filter(Boolean);
            chordTokens.push(...sub);
        }

        if (chordTokens.length === 0) {
            if (this._manualProgFeedback) {
                this._manualProgFeedback.textContent = 'No se reconocieron acordes en el texto.';
                this._manualProgFeedback.style.color = '#f87171';
            }
            return;
        }

        const bpm = this.getBPM();
        const beatSec = 60 / bpm;
        const barSec = 4 * beatSec;

        const durMode = (this._manualProgDurationSelect ? this._manualProgDurationSelect.value : '1bar');
        let chordSec = barSec;
        if (durMode === '2beats') chordSec = 2 * beatSec;
        if (durMode === '1beat') chordSec = beatSec;

        const isReplace = this._chkManualProgReplaceAll ? this._chkManualProgReplaceAll.checked : true;
        let baseTime = 0;
        if (!isReplace && this._currentAnalysisData && this._currentAnalysisData.chords && this._currentAnalysisData.chords.length > 0) {
            const last = this._currentAnalysisData.chords[this._currentAnalysisData.chords.length - 1];
            baseTime = Math.ceil(last.endTime / barSec) * barSec;
        }

        const generatedChords = [];
        chordTokens.forEach((rawSym, idx) => {
            const sym = formatChordInputString(rawSym);
            let parsed = parseChordNotation(sym);
            if (!parsed) {
                parsed = {
                    root: 0,
                    type: 'major',
                    chordSymbol: sym,
                    name: sym,
                    intervals: [0, 4, 7],
                    noteMods: [0, 4, 7],
                    playbackMidis: [60, 64, 67]
                };
            }
            const st = baseTime + (idx * chordSec);
            const et = st + chordSec;
            const baseMidi = 60 + (parsed.root !== undefined ? parsed.root : 0);
            const noteMods = parsed.noteMods || (parsed.intervals || [0, 4, 7]).map(i => ((parsed.root || 0) + i) % 12);
            const playbackMidis = parsed.playbackMidis || (parsed.intervals || [0, 4, 7]).map(i => baseMidi + i);

            generatedChords.push({
                root: parsed.root !== undefined ? parsed.root : 0,
                type: parsed.type || 'major',
                chordSymbol: (parsed && parsed.chordSymbol) ? parsed.chordSymbol : sym,
                name: (parsed && (parsed.chordName || parsed.name)) ? (parsed.chordName || parsed.name) : sym,
                startTime: st,
                endTime: et,
                noteMods: noteMods,
                playbackMidis: playbackMidis,
                confidence: 1.0,
                forced: true
            });
        });

        const totalDuration = generatedChords[generatedChords.length - 1].endTime;
        const totalBars = Math.ceil(totalDuration / barSec);
        this._totalBars = Math.max(4, totalBars);

        if (isReplace) {
            this._currentAnalysisData = {
                duration: totalDuration,
                bpm: bpm,
                chords: generatedChords
            };
        } else {
            if (!this._currentAnalysisData) {
                this._currentAnalysisData = {
                    duration: totalDuration,
                    bpm: bpm,
                    chords: generatedChords
                };
            } else {
                this._currentAnalysisData.chords = [...(this._currentAnalysisData.chords || []), ...generatedChords].sort((a, b) => a.startTime - b.startTime);
                this._currentAnalysisData.duration = Math.max(this._currentAnalysisData.duration || 0, totalDuration);
            }
        }

        audioPlayerController.setChordsTimeline(this._currentAnalysisData.chords);
        this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, bpm);
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, bpm);

        this.closeManualProgressionModal();
    }


    /**
     * Inicializa los eventos de transporte, metrónomo, velocidad y ajuste de tempo.
     * @private
     */
    _initTransportAndMetronome() {
        if (this._btnPrevMeasure) {
            this._btnPrevMeasure.addEventListener('click', () => {
                const bpm = this.getBPM();
                const barSec = (60 / bpm) * 4;
                const curTime = audioPlayerController.currentTime || 0;
                const curBar = Math.floor(curTime / barSec);
                const timeInBar = curTime - (curBar * barSec);
                const targetBar = timeInBar > 0.8 ? curBar : Math.max(0, curBar - 1);
                audioPlayerController.seek(targetBar * barSec);
            });
        }

        if (this._btnNextMeasure) {
            this._btnNextMeasure.addEventListener('click', () => {
                const bpm = this.getBPM();
                const barSec = (60 / bpm) * 4;
                const curTime = audioPlayerController.currentTime || 0;
                const curBar = Math.floor(curTime / barSec);
                audioPlayerController.seek((curBar + 1) * barSec);
            });
        }

        if (this._btnToggleMetronome) {
            this._btnToggleMetronome.addEventListener('click', () => {
                const isEnabled = metronomeEngine.toggle();
                this._updateMetronomeToggleUI(isEnabled);
            });
        }

        if (this._audioSpeedSelect) {
            this._audioSpeedSelect.addEventListener('change', (e) => {
                const rate = parseFloat(e.target.value);
                audioPlayerController.setPlaybackRate(rate);
            });
        }

        if (this._btnBpmMinus) {
            this._btnBpmMinus.addEventListener('click', () => {
                this.setBPM(this.getBPM() - 1);
            });
        }

        if (this._btnBpmPlus) {
            this._btnBpmPlus.addEventListener('click', () => {
                this.setBPM(this.getBPM() + 1);
            });
        }

        if (this._playerBpmInput) {
            const handleBpmInput = (e) => {
                const val = parseInt(e.target.value, 10);
                if (!isNaN(val) && val >= 30 && val <= 280) {
                    this.setBPM(val);
                } else {
                    e.target.value = this.getBPM();
                }
            };
            this._playerBpmInput.addEventListener('change', handleBpmInput);
            this._playerBpmInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    handleBpmInput(e);
                    e.target.blur();
                }
            });
        }

        const audioBpmBadge = document.getElementById('audioBpmBadge');
        if (audioBpmBadge) {
            audioBpmBadge.addEventListener('click', () => {
                if (this._playerBpmInput) {
                    this._playerBpmInput.focus();
                    this._playerBpmInput.select();
                }
            });
        }

        metronomeEngine.onBeat((beat, measure) => {
            if (this._activeMeasureBeatInfo) {
                this._activeMeasureBeatInfo.innerText = `Compás ${measure + 1} · Pulso ${beat}`;
            }
        });

        this._initChordVolumeControls();
        this._initMetronomeVolumeControls();
    }

    /**
     * Inicializa eventos y controles de volumen del metrónomo.
     * @private
     */
    _initMetronomeVolumeControls() {
        if (this._playerMetronomeVolumeSlider) {
            const curVol = Math.round(metronomeEngine.getVolume() * 100);
            this._playerMetronomeVolumeSlider.value = curVol;
            if (this._playerMetronomeVolumeDisplay) {
                this._playerMetronomeVolumeDisplay.textContent = `${curVol}%`;
            }

            this._playerMetronomeVolumeSlider.addEventListener('input', (e) => {
                const val = parseFloat(e.target.value) / 100;
                this._isMetronomeMuted = false;
                metronomeEngine.setVolume(val);
                if (this._playerMetronomeVolumeDisplay) {
                    this._playerMetronomeVolumeDisplay.textContent = `${Math.round(val * 100)}%`;
                }
                if (this._iconMetronomeVolume) {
                    this._iconMetronomeVolume.className = val === 0 ? 'fas fa-volume-xmark' : val < 0.45 ? 'fas fa-volume-low' : 'fas fa-volume-high';
                }
            });
        }

        if (this._btnToggleMetronomeMute) {
            this._btnToggleMetronomeMute.addEventListener('click', () => {
                this._isMetronomeMuted = !this._isMetronomeMuted;
                if (this._isMetronomeMuted) {
                    this._lastMetronomeVolume = metronomeEngine.getVolume() || 0.70;
                    metronomeEngine.setVolume(0);
                    if (this._playerMetronomeVolumeSlider) this._playerMetronomeVolumeSlider.value = 0;
                    if (this._playerMetronomeVolumeDisplay) this._playerMetronomeVolumeDisplay.textContent = 'Mudo';
                    if (this._iconMetronomeVolume) this._iconMetronomeVolume.className = 'fas fa-volume-xmark';
                } else {
                    const restored = this._lastMetronomeVolume || 0.70;
                    metronomeEngine.setVolume(restored);
                    if (this._playerMetronomeVolumeSlider) this._playerMetronomeVolumeSlider.value = Math.round(restored * 100);
                    if (this._playerMetronomeVolumeDisplay) this._playerMetronomeVolumeDisplay.textContent = `${Math.round(restored * 100)}%`;
                    if (this._iconMetronomeVolume) this._iconMetronomeVolume.className = restored < 0.45 ? 'fas fa-volume-low' : 'fas fa-volume-high';
                }
            });
        }
    }

    /**
     * Inicializa eventos y controles de volumen del acorde.
     * @private
     */
    _initChordVolumeControls() {
        this._updateChordVolumeUI(audioPlayerController.chordVolume, audioPlayerController.isChordMuted);

        if (this._playerChordVolumeSlider) {
            this._playerChordVolumeSlider.value = Math.round(audioPlayerController.chordVolume * 100);
            this._playerChordVolumeSlider.addEventListener('input', (e) => {
                const val = parseFloat(e.target.value) / 100;
                audioPlayerController.setChordVolume(val);
            });
        }

        if (this._btnToggleChordMute) {
            this._btnToggleChordMute.addEventListener('click', () => {
                audioPlayerController.toggleChordMute();
            });
        }

        eventBus.on('player:chord_volume_changed', ({ volume, isMuted }) => {
            this._updateChordVolumeUI(volume, isMuted);
        });
    }

    /**
     * Actualiza la interfaz del volumen de acorde en el reproductor.
     * @private
     * @param {number} volume
     * @param {boolean} isMuted
     */
    _updateChordVolumeUI(volume, isMuted) {
        const pct = Math.round(volume * 100);
        if (this._playerChordVolumeSlider) {
            this._playerChordVolumeSlider.value = isMuted ? 0 : pct;
        }
        if (this._playerChordVolumeDisplay) {
            this._playerChordVolumeDisplay.textContent = isMuted ? 'Mudo' : `${pct}%`;
        }
        if (this._iconChordVolume) {
            if (isMuted || volume === 0) {
                this._iconChordVolume.className = 'fas fa-volume-xmark';
                if (this._btnToggleChordMute) this._btnToggleChordMute.classList.add('is-muted');
            } else if (volume < 0.45) {
                this._iconChordVolume.className = 'fas fa-volume-low';
                if (this._btnToggleChordMute) this._btnToggleChordMute.classList.remove('is-muted');
            } else {
                this._iconChordVolume.className = 'fas fa-volume-high';
                if (this._btnToggleChordMute) this._btnToggleChordMute.classList.remove('is-muted');
            }
        }
    }

    /**
     * Ajusta el tempo (BPM) del reproductor, metrónomo y cuadrícula.
     * @param {number} bpm
     */
    setBPM(bpm) {
        const val = Math.max(30, Math.min(260, Math.round(bpm)));
        this._currentBpm = val;
        metronomeEngine.setBPM(val);

        if (this._playerBpmInput) {
            this._playerBpmInput.value = val;
        }
        if (this._playerBpmDisplay) {
            this._playerBpmDisplay.innerText = `${val} BPM`;
        }
        const audioBpmVal = document.getElementById('audioBpmValue');
        if (audioBpmVal) {
            audioBpmVal.innerText = `${val} BPM`;
        }

        if (this._currentAnalysisData && this._currentAnalysisData.chords) {
            this._currentAnalysisData.bpm = val;
            this.renderMeasureGrid(this._currentAnalysisData.chords, this._currentAnalysisData.duration, val);
            this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration, val);
        }
    }

    /**
     * Retorna el BPM actual configurado.
     * @returns {number}
     */
    getBPM() {
        return this._currentBpm || (this._currentAnalysisData && this._currentAnalysisData.bpm) || 120;
    }

    /**
     * Actualiza la interfaz del botón del metrónomo.
     * @private
     * @param {boolean} isEnabled
     */
    _updateMetronomeToggleUI(isEnabled) {
        if (!this._btnToggleMetronome) return;
        this._btnToggleMetronome.classList.toggle('active', isEnabled);
        if (this._metronomeToggleLabel) {
            this._metronomeToggleLabel.innerHTML = isEnabled
                ? 'Metrónomo: <strong>ON</strong>'
                : 'Metrónomo: <strong>OFF</strong>';
        }
    }

    /**
     * Cambia el estado visual del botón Play/Pausa.
     * @param {boolean} isPlaying
     */
    setPlayingState(isPlaying) {
        if (!this._btnPlayPause) return;
        this._btnPlayPause.innerHTML = isPlaying
            ? '<i class="fas fa-pause"></i>'
            : '<i class="fas fa-play"></i>';
    }

    /**
     * Indica si la sincronización con el diapasón está activa.
     * @returns {boolean}
     */
    isSyncEnabled() {
        return this._chkSyncDiapason ? this._chkSyncDiapason.checked : true;
    }

    /**
     * Formatea segundos a mm:ss.
     * @private
     */
    _formatTime(seconds) {
        if (seconds === undefined || seconds === null || isNaN(seconds) || !isFinite(seconds)) {
            return '00:00';
        }
        const safeSeconds = Math.max(0, seconds);
        const mins = Math.floor(safeSeconds / 60);
        const secs = Math.floor(safeSeconds % 60);
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
}

export default AudioTrackView;
