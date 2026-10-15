/**
 * @fileoverview Vista del Analizador de Pistas de Audio MP3 y Sincronizador de Acordes (SRP).
 * Gestiona el panel de carga de archivos, visualización de tonalidad principal,
 * barra de progreso, ajuste de tono (pitch shifting / transposición) y acordes en tiempo real.
 * @module ui/AudioTrackView
 */

import { audioChordAnalyzer } from '../audio/AudioChordAnalyzer.js';
import { audioPlayerController } from '../audio/AudioPlayerController.js';
import { metronomeEngine } from '../audio/MetronomeEngine.js';
import { getNoteNamesList, parseChordNotation } from '../theory/MusicTheory.js';
import { NOTATION_MODES, ROW_BASE_TONICS } from '../core/Constants.js';
import { eventBus } from '../core/EventBus.js';
import { tuningRegistry } from '../models/Tunings.js';
import { audioEngine } from '../audio/AudioEngine.js';

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

        this._currentBpm = 120;
        this._activeBeatSlot = null;
        this._activeMeasureRow = null;
        this._lastScrollMeasure = -1;

        // Mini-popover para edición rápida en cuadrícula
        this._chordMeasureGridWrapper = document.getElementById('chordMeasureGridWrapper');
        this._miniPopover = document.getElementById('gridChordMiniPopover');
        this._miniPopoverTitle = document.getElementById('miniPopoverTitle');
        this._miniPopoverInput = document.getElementById('miniPopoverChordInput');
        this._miniPopoverFeedback = document.getElementById('miniPopoverFeedback');
        this._btnMiniDelete = document.getElementById('btnMiniPopoverDelete');
        this._btnMiniCancel = document.getElementById('btnMiniPopoverCancel');
        this._btnMiniSave = document.getElementById('btnMiniPopoverSave');
        this._btnMiniClose = document.getElementById('btnMiniPopoverClose');
        this._activeMiniSlot = null;

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
                    this._openMiniChordPopover(slot, chord, m, b, beatStart, beatSec);
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
     * Inicializa el mini-popover de edición rápida de acordes en la cuadrícula.
     * @private
     */
    _initMiniChordPopover() {
        if (!this._miniPopover) return;

        if (this._btnMiniClose) {
            this._btnMiniClose.addEventListener('click', (e) => {
                e.stopPropagation();
                this._closeMiniChordPopover();
            });
        }
        if (this._btnMiniCancel) {
            this._btnMiniCancel.addEventListener('click', (e) => {
                e.stopPropagation();
                this._closeMiniChordPopover();
            });
        }
        if (this._btnMiniSave) {
            this._btnMiniSave.addEventListener('click', (e) => {
                e.stopPropagation();
                this._saveMiniChord();
            });
        }
        if (this._btnMiniDelete) {
            this._btnMiniDelete.addEventListener('click', (e) => {
                e.stopPropagation();
                this._deleteMiniChord();
            });
        }

        if (this._miniPopoverInput) {
            this._miniPopoverInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this._saveMiniChord();
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    this._closeMiniChordPopover();
                } else if (e.key === 'Delete' || e.key === 'Del') {
                    e.preventDefault();
                    this._deleteMiniChord();
                }
            });

            this._miniPopoverInput.addEventListener('input', () => {
                const val = this._miniPopoverInput.value.trim();
                if (!val) {
                    if (this._miniPopoverFeedback) {
                        this._miniPopoverFeedback.textContent = '';
                    }
                    return;
                }
                const parsed = parseChordNotation(val, this._currentNotation, this._currentOffset);
                if (parsed && this._miniPopoverFeedback) {
                    this._miniPopoverFeedback.style.color = '#38bdf8';
                    this._miniPopoverFeedback.textContent = `${parsed.chordSymbol} (${parsed.chordName})`;
                    if (audioEngine && parsed.playbackMidis) {
                        audioEngine.play(parsed.playbackMidis, "4n");
                    }
                } else if (this._miniPopoverFeedback) {
                    this._miniPopoverFeedback.style.color = '#f59e0b';
                    this._miniPopoverFeedback.textContent = 'Escribe ej: C, Dm, G7, Bb, Em7';
                }
            });
        }

        if (this._measureGridContainer) {
            this._measureGridContainer.addEventListener('scroll', () => {
                if (this._miniPopover && this._miniPopover.style.display !== 'none') {
                    this._closeMiniChordPopover();
                }
            }, { passive: true });
        }

        // Tecla Supr para borrar el acorde seleccionado en la cuadrícula
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Delete' || e.key === 'Del') {
                if (this._activeMiniSlot && this._activeMiniSlot.chord) {
                    const activeEl = document.activeElement;
                    const tag = activeEl ? activeEl.tagName.toLowerCase() : '';
                    const id = activeEl ? activeEl.id : '';
                    if (tag === 'input' && id !== 'miniPopoverChordInput') {
                        return;
                    }
                    if (tag === 'textarea' || tag === 'select') {
                        return;
                    }
                    e.preventDefault();
                    this._deleteMiniChord();
                }
            }
        });

        // Cerrar al hacer clic fuera del popover y de la celda activa
        document.addEventListener('pointerdown', (e) => {
            if (this._miniPopover && this._miniPopover.style.display !== 'none' && !this._miniPopover.classList.contains('hidden')) {
                if (!e.target.closest('#gridChordMiniPopover') && !e.target.closest('.measure-beat-slot') && !e.target.closest('#btnAddChordAtCurrentTime')) {
                    this._closeMiniChordPopover();
                }
            }
        });
    }

    /**
     * Abre el modal/popover de dimensión pequeña para editar o eliminar el acorde directamente bajo la celda.
     * @private
     */
    _openMiniChordPopover(slotElement, chord, barIndex, beatIndex, beatStart, beatSec) {
        if (!this._miniPopover || !slotElement) return;

        // Limpiar selección previa en la cuadrícula y resaltar la celda seleccionada
        if (this._measureGridContainer) {
            this._measureGridContainer.querySelectorAll('.measure-beat-slot.selected-slot').forEach(el => {
                el.classList.remove('selected-slot');
            });
        }
        slotElement.classList.add('selected-slot');

        this._activeMiniSlot = {
            slotElement,
            chord,
            barIndex,
            beatIndex,
            beatStart,
            beatSec
        };

        if (this._miniPopoverTitle) {
            this._miniPopoverTitle.innerHTML = `<i class="fas fa-music"></i> Compás ${barIndex + 1} · Pulso ${beatIndex + 1}`;
        }

        const currentSymbol = chord ? chord.chordSymbol : '';
        if (this._miniPopoverInput) {
            this._miniPopoverInput.value = currentSymbol;
        }

        if (this._miniPopoverFeedback) {
            this._miniPopoverFeedback.textContent = chord ? `${chord.chordSymbol} (${chord.chordName})` : '';
            this._miniPopoverFeedback.style.color = '#38bdf8';
        }

        if (this._btnMiniDelete) {
            this._btnMiniDelete.style.display = chord ? 'inline-flex' : 'none';
        }

        // Posicionar el mini-modal directamente debajo de la celda de la cuadrícula
        const wrapper = this._chordMeasureGridWrapper || document.getElementById('chordMeasureGridWrapper') || this._measureGridContainer;
        if (wrapper) {
            const slotRect = slotElement.getBoundingClientRect();
            const wrapperRect = wrapper.getBoundingClientRect();
            const popoverWidth = 220;

            let top = slotRect.bottom - wrapperRect.top + 6;
            // Si el slot está cerca del borde inferior del wrapper, posicionarlo encima
            if (top + 100 > wrapperRect.height && (slotRect.top - wrapperRect.top) > 110) {
                top = slotRect.top - wrapperRect.top - 105;
            }

            let left = (slotRect.left - wrapperRect.left) + (slotRect.width / 2) - (popoverWidth / 2);
            left = Math.max(8, Math.min(left, wrapperRect.width - popoverWidth - 8));

            this._miniPopover.style.top = `${Math.round(top)}px`;
            this._miniPopover.style.left = `${Math.round(left)}px`;
        }

        this._miniPopover.classList.remove('hidden');
        this._miniPopover.style.display = 'flex';

        setTimeout(() => {
            if (this._miniPopoverInput) {
                this._miniPopoverInput.focus();
                this._miniPopoverInput.select();
            }
        }, 50);
    }

    /**
     * Cierra el popover de edición rápida de cuadrícula.
     * @param {boolean} [keepSlotSelection=false] Si es verdadero, no deselecciona la celda visualmente
     * @private
     */
    _closeMiniChordPopover(keepSlotSelection = false) {
        if (this._miniPopover) {
            this._miniPopover.style.display = 'none';
            this._miniPopover.classList.add('hidden');
        }
        if (!keepSlotSelection) {
            if (this._measureGridContainer) {
                this._measureGridContainer.querySelectorAll('.measure-beat-slot.selected-slot').forEach(el => {
                    el.classList.remove('selected-slot');
                });
            }
            this._activeMiniSlot = null;
        }
    }

    /**
     * Guarda el texto editado del acorde desde el mini-popover.
     * @private
     */
    _saveMiniChord() {
        if (!this._activeMiniSlot) return;
        const text = (this._miniPopoverInput ? this._miniPopoverInput.value : '').trim();

        if (!text) {
            this._deleteMiniChord();
            return;
        }

        const parsed = parseChordNotation(text, this._currentNotation, this._currentOffset);
        if (!parsed) {
            if (this._miniPopoverFeedback) {
                this._miniPopoverFeedback.style.color = '#ef4444';
                this._miniPopoverFeedback.textContent = 'Notación no válida (ej. C, Dm, G7, Bb)';
            }
            if (this._miniPopoverInput) {
                this._miniPopoverInput.focus();
            }
            return;
        }

        if (!this._currentAnalysisData) {
            this._currentAnalysisData = {
                duration: audioPlayerController.duration || 16,
                chords: []
            };
        }
        if (!this._currentAnalysisData.chords) {
            this._currentAnalysisData.chords = [];
        }

        const timeline = this._currentAnalysisData.chords;
        const { chord, beatStart, beatSec } = this._activeMiniSlot;
        let activeTargetChord = chord;
        let targetIndex = -1;

        if (chord) {
            chord.chordSymbol = parsed.chordSymbol;
            chord.chordName = parsed.chordName;
            chord.root = parsed.root;
            chord.noteMods = parsed.noteMods;
            chord.playbackMidis = parsed.playbackMidis;
            chord.chordType = parsed.chordType;
            activeTargetChord = chord;
            targetIndex = timeline.indexOf(chord);
        } else {
            let endTime = beatStart + beatSec;
            const nextChord = timeline.find(c => c.startTime > beatStart);
            if (nextChord && nextChord.startTime < endTime) {
                endTime = nextChord.startTime;
            }
            const newChord = {
                startTime: beatStart,
                endTime: endTime,
                chordSymbol: parsed.chordSymbol,
                chordName: parsed.chordName,
                root: parsed.root,
                noteMods: parsed.noteMods,
                playbackMidis: parsed.playbackMidis,
                chordType: parsed.chordType,
                bellowsAction: 'both'
            };
            timeline.push(newChord);
            timeline.sort((a, b) => a.startTime - b.startTime);
            activeTargetChord = newChord;
            targetIndex = timeline.indexOf(newChord);
        }

        if (audioEngine && parsed.playbackMidis) {
            audioEngine.play(parsed.playbackMidis, "4n");
        }

        audioPlayerController.setChordsTimeline(timeline);
        this.renderChordsStrip(timeline, this._onChordMarkerClick);
        this.renderChordProgressBar(timeline, this._currentAnalysisData.duration, this.getBPM());
        this.renderMeasureGrid(timeline, this._currentAnalysisData.duration, this.getBPM());

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(timeline);
        }

        if (activeTargetChord) {
            eventBus.emit('player:chord_active', {
                chord: activeTargetChord,
                index: targetIndex >= 0 ? targetIndex : 0,
                syncWithDiapason: this.isSyncEnabled()
            });
        }

        this._closeMiniChordPopover();
    }

    /**
     * Elimina el acorde seleccionado en la cuadrícula.
     * @private
     */
    _deleteMiniChord() {
        if (!this._activeMiniSlot) return;
        const { chord, beatStart, beatSec, barIndex, beatIndex } = this._activeMiniSlot;

        if (this._currentAnalysisData && this._currentAnalysisData.chords) {
            const timeline = this._currentAnalysisData.chords;
            let targetIdx = -1;
            if (chord) {
                targetIdx = timeline.indexOf(chord);
            }
            if (targetIdx === -1) {
                const beatMid = beatStart + (beatSec * 0.25);
                targetIdx = timeline.findIndex(c => c.startTime <= beatMid && c.endTime > beatMid);
            }

            if (targetIdx >= 0) {
                timeline.splice(targetIdx, 1);
                audioPlayerController.setChordsTimeline(timeline);
                this.renderChordsStrip(timeline, this._onChordMarkerClick);
                this.renderChordProgressBar(timeline, this._currentAnalysisData.duration, this.getBPM());
                this.renderMeasureGrid(timeline, this._currentAnalysisData.duration, this.getBPM());

                if (this._handlers && this._handlers.onChordTimelineUpdated) {
                    this._handlers.onChordTimelineUpdated(timeline);
                }

                // Actualizar acorde activo en el diapasón si era el que estaba activo
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
                } else {
                    this.setActiveChord(null, -1);
                    eventBus.emit('player:chord_active', {
                        chord: null,
                        index: -1,
                        syncWithDiapason: this.isSyncEnabled()
                    });
                }
            }
        }

        this._closeMiniChordPopover(true);

        if (typeof barIndex === 'number' && typeof beatIndex === 'number') {
            const slotEl = document.getElementById(`beat-slot-${barIndex}-${beatIndex}`);
            if (slotEl) {
                slotEl.classList.add('selected-slot');
                slotEl.focus();
                this._activeMiniSlot = {
                    slotElement: slotEl,
                    chord: null,
                    barIndex,
                    beatIndex,
                    beatStart,
                    beatSec
                };
            }
        }
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
                : 'Presiona reproducir para sincronizar';
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
        const bpm = this.getBPM();
        const beatSec = 60 / bpm;
        const barSec = 4 * beatSec;

        const curBar = Math.floor(currentTime / barSec);
        const curBeat = Math.min(3, Math.floor((currentTime % barSec) / beatSec));

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

        if (this._activeMeasureRow) {
            this._activeMeasureRow.classList.remove('active-measure');
        }
        const newRow = document.getElementById(`measure-row-${curBar}`);
        if (newRow) {
            newRow.classList.add('active-measure');
            this._activeMeasureRow = newRow;

            // Auto-scroll suave para mantener el compás actual a la vista
            if (this._lastScrollMeasure !== curBar && this._measureGridContainer) {
                this._lastScrollMeasure = curBar;
                const rowTop = newRow.offsetTop - this._measureGridContainer.offsetTop;
                const targetScroll = Math.max(0, rowTop - 40);
                this._measureGridContainer.scrollTo({ top: targetScroll, behavior: 'smooth' });
            }
        }
    }

    /**
     * Dibuja la cuadrícula de compases interactiva (4 pulsos por compás) estilo Moises / Chordify.
     * @param {Array} chords
     * @param {number} duration
     * @param {number} bpm
     */
    renderMeasureGrid(chords, duration, bpm) {
        if (!this._measureGridContainer) return;
        this._measureGridContainer.innerHTML = '';

        if (!chords || chords.length === 0) return;

        const dur = duration || (this._currentAnalysisData && this._currentAnalysisData.duration) || audioPlayerController.duration || 16;
        const songBpm = bpm || this.getBPM();
        const beatSec = 60 / songBpm;
        const barSec = 4 * beatSec;
        const totalBars = Math.max(1, Math.ceil(dur / barSec));

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
                const beatStart = (m * barSec) + (b * beatSec);
                const beatMid = beatStart + (beatSec * 0.25);
                const chord = chords.find(c => c.startTime <= beatMid && c.endTime > beatMid);

                const slot = document.createElement('button');
                slot.type = 'button';
                slot.className = 'measure-beat-slot';
                slot.id = `beat-slot-${m}-${b}`;
                slot.dataset.barIndex = m;
                slot.dataset.beatIndex = b;
                slot.dataset.startTime = beatStart;

                const currentSymbol = chord ? chord.chordSymbol : '';
                // Mostrar el acorde solo si hubo cambio respecto al pulso anterior o en el primer compás
                if (currentSymbol && (currentSymbol !== lastChordSymbol || (m === 0 && b === 0))) {
                    slot.classList.add('has-chord');
                    slot.innerHTML = `<span class="slot-chord-text" title="Clic para editar acorde ${currentSymbol}">${currentSymbol} <i class="fas fa-pen" style="font-size: 0.52rem; opacity: 0.5; margin-left: 2px;"></i></span>`;
                    lastChordSymbol = currentSymbol;
                } else {
                    slot.innerHTML = `<span class="slot-empty-dot"></span>`;
                }

                slot.title = `Compás ${m + 1}, Pulso ${b + 1} (${this._formatTime(beatStart)})${currentSymbol ? ' - Acorde: ' + currentSymbol + ' (Clic para editar o eliminar)' : ' (Clic para agregar acorde)'}`;

                slot.addEventListener('click', (e) => {
                    e.stopPropagation();
                    if (chord && audioEngine) {
                        const midis = chord.playbackMidis || (chord.noteMods ? chord.noteMods.map(n => 60 + n) : null);
                        if (midis && midis.length > 0) {
                            audioEngine.play(midis, "4n");
                        }
                    }
                    audioPlayerController.seek(beatStart);
                    this._openMiniChordPopover(slot, chord, m, b, beatStart, beatSec);
                });

                slot.addEventListener('dblclick', (e) => {
                    e.stopPropagation();
                    this._openMiniChordPopover(slot, chord, m, b, beatStart, beatSec);
                });

                slot.addEventListener('keydown', (e) => {
                    if (e.key === 'Delete' || e.key === 'Del') {
                        e.preventDefault();
                        e.stopPropagation();
                        this._deleteMiniChord();
                    } else if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        this._openMiniChordPopover(slot, chord, m, b, beatStart, beatSec);
                    }
                });

                beats.appendChild(slot);
            }

            row.appendChild(beats);
            fragment.appendChild(row);
        }

        this._measureGridContainer.appendChild(fragment);
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
            ? '<i class="fas fa-pause"></i> Pausa'
            : '<i class="fas fa-play"></i> Reproducir';
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
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
}

export default AudioTrackView;
