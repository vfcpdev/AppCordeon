/**
 * @fileoverview Vista del Analizador de Pistas de Audio MP3 y Sincronizador de Acordes (SRP).
 * Gestiona el panel de carga de archivos, visualización de tonalidad principal,
 * barra de progreso, ajuste de tono (pitch shifting / transposición) y acordes en tiempo real.
 * @module ui/AudioTrackView
 */

import { audioChordAnalyzer } from '../audio/AudioChordAnalyzer.js';
import { audioPlayerController } from '../audio/AudioPlayerController.js';
import { getNoteNamesList } from '../theory/MusicTheory.js';
import { NOTATION_MODES, ROW_BASE_TONICS } from '../core/Constants.js';
import { tuningRegistry } from '../models/Tunings.js';

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

        // Progresión predeterminada (Cinco Letras / Vallenato tradicional) para que la línea de tiempo
        // sea visible, interactiva y editable inmediatamente desde la carga inicial de la página
        const defaultChords = [
            { root: 10, chordType: 'major', chordName: 'Si♭ (Bb)', chordSymbol: 'Bb', noteMods: [10, 2, 5], startTime: 0, endTime: 4, confidence: 1.0, bassNote: 10, bellowsAction: 'both' },
            { root: 3, chordType: 'major', chordName: 'Mi♭ (Eb)', chordSymbol: 'Eb', noteMods: [3, 7, 10], startTime: 4, endTime: 8, confidence: 1.0, bassNote: 3, bellowsAction: 'both' },
            { root: 5, chordType: '7', chordName: 'Fa 7 (F7)', chordSymbol: 'F7', noteMods: [5, 9, 0, 3], startTime: 8, endTime: 12, confidence: 1.0, bassNote: 5, bellowsAction: 'both' },
            { root: 10, chordType: 'major', chordName: 'Si♭ (Bb)', chordSymbol: 'Bb', noteMods: [10, 2, 5], startTime: 12, endTime: 16, confidence: 1.0, bassNote: 10, bellowsAction: 'both' }
        ];

        this._currentAnalysisData = {
            duration: 16,
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

        // Renderizar la tira de acordes y la barra de desplazamiento visual inmediatamente en la carga
        this.renderChordsStrip(this._currentAnalysisData.chords, this._onChordMarkerClick);
        this.renderChordProgressBar(this._currentAnalysisData.chords, this._currentAnalysisData.duration);
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

        // Selector manual de tonalidad para cambiar el tono detectado
        if (this._audioKeySelect) {
            this._audioKeySelect.addEventListener('change', (e) => {
                if (!this._originalAnalysisData) return;
                const [targetRootStr, targetMode] = e.target.value.split('_');
                const targetRoot = parseInt(targetRootStr);
                const originalRoot = this._originalAnalysisData.mainKey.rootMod;

                let diff = (targetRoot - originalRoot + 12) % 12;
                if (diff > 6) diff -= 12; // Transposición más cercana (-6 a +6)

                this.setPitchShift(diff, handlers);
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
        if (analysisData.bpm) {
            const bpmVal = document.getElementById('audioBpmValue');
            if (bpmVal) bpmVal.innerText = `${analysisData.bpm} BPM`;
        }

        // Tira de acordes secuenciales con alto contraste
        this.renderChordsStrip(analysisData.chords, onChordMarkerClick);
        this.renderChordProgressBar(analysisData.chords, analysisData.duration, analysisData.bpm);

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
     * Llena el combobox con las 24 tonalidades mayores y menores.
     * @private
     */
    _populateKeySelect(currentKey) {
        if (!this._audioKeySelect) return;
        this._audioKeySelect.innerHTML = "";
        this._audioKeySelect.style.display = 'inline-block';

        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);

        for (let r = 0; r < 12; r++) {
            const optMaj = document.createElement('option');
            optMaj.value = `${r}_major`;
            optMaj.innerText = `${arrLat[r]} Mayor`;
            if (r === currentKey.rootMod && currentKey.mode === 'major') optMaj.selected = true;
            this._audioKeySelect.appendChild(optMaj);
        }

        for (let r = 0; r < 12; r++) {
            const optMin = document.createElement('option');
            optMin.value = `${r}_minor`;
            optMin.innerText = `${arrLat[r]} Menor`;
            if (r === currentKey.rootMod && currentKey.mode === 'minor') optMin.selected = true;
            this._audioKeySelect.appendChild(optMin);
        }
    }

    /**
     * Aplica un desplazamiento de tono VISUAL en semitonos (-12 a +12).
     * El audio de la canción NO se modifica: solo se transponen los acordes,
     * la tonalidad mostrada y las digitaciones en los diapasones.
     * @param {number} semitones
     * @param {Object} [handlers]
     */
    setPitchShift(semitones, handlers) {
        if (!this._originalAnalysisData) return;

        // Conservar ediciones manuales y preferencias Abre/Cierra hechas sobre la vista transpuesta
        this._syncOriginalFromCurrent();

        const clamped = Math.max(-12, Math.min(12, semitones));
        this._currentPitchShift = clamped;

        if (this._lblPitchShift) {
            this._lblPitchShift.innerText = `${clamped > 0 ? '+' : ''}${clamped} st`;
        }

        // 1. Transponer reporte con audioChordAnalyzer (solo datos visuales)
        const transposedReport = audioChordAnalyzer.transposeReport(this._originalAnalysisData, clamped);
        this._currentAnalysisData = transposedReport;

        // 2. El audio conserva su tono original; solo se actualiza la línea de acordes sincronizada
        audioPlayerController.setPitchShift(clamped);
        audioPlayerController.setChordsTimeline(transposedReport.chords);

        // 3. Actualizar información visual de tonalidad
        this._updateKeyDisplay(transposedReport.mainKey);

        // 4. Sincronizar selector de tonalidad
        if (this._audioKeySelect) {
            this._audioKeySelect.value = `${transposedReport.mainKey.rootMod}_${transposedReport.mainKey.mode}`;
        }

        // 5. Re-renderizar tira de acordes con alto contraste
        this.renderChordsStrip(transposedReport.chords, this._onChordMarkerClick);
        this.renderChordProgressBar(transposedReport.chords, this._currentAnalysisData.duration, this._currentAnalysisData.bpm);

        // 6. Actualizar estado visual de los botones de las hileras del acordeón
        this._renderAccordionRowButtons(handlers || this._handlers);
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
     * Actualiza las insignias de tonalidad y recomendación de acordeón.
     * @private
     */
    _updateKeyDisplay(mainKey) {
        if (this._mainKeyBadge && mainKey) {
            const shiftTag = this._currentPitchShift !== 0
                ? `<span style="font-size: 0.65rem; color: #7c3aed; font-weight: 800; margin-left: 4px;" title="Transposición visual: el audio conserva su tono original">(${this._currentPitchShift > 0 ? '+' : ''}${this._currentPitchShift} st · visual)</span>`
                : '';

            this._mainKeyBadge.innerHTML = `
                <i class="fas fa-key"></i> Tonalidad: <strong>${mainKey.keyNameLat}</strong> (${mainKey.keyNameAle})${shiftTag}
            `;
        }

        if (this._tuningRecommendation && mainKey) {
            this._tuningRecommendation.innerHTML = `
                <i class="fas fa-thumbs-up"></i> Afinación sugerida: <strong>${mainKey.recommendedTuning}</strong>
            `;
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
            this._btnAddChord.addEventListener('click', () => {
                const curTime = audioPlayerController.currentTime || 0;
                this._openChordEditor(-1, curTime);
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
        const latinNotes = getNoteNamesList(NOTATION_MODES.LATIN);
        const englishNotes = getNoteNamesList(NOTATION_MODES.ENGLISH);
        const rootNameLat = latinNotes[root] || 'Do';
        const rootNameEng = englishNotes[root] || 'C';

        let typeLabel = '';
        let symbolSuffix = '';
        let noteIntervals = [0, 4, 7]; // Triada Mayor por defecto

        if (chordType === 'minor') {
            typeLabel = 'm';
            symbolSuffix = 'm';
            noteIntervals = [0, 3, 7];
        } else if (chordType === '7') {
            typeLabel = '7';
            symbolSuffix = '7';
            noteIntervals = [0, 4, 7, 10];
        } else if (chordType === 'm7') {
            typeLabel = 'm7';
            symbolSuffix = 'm7';
            noteIntervals = [0, 3, 7, 10];
        } else if (chordType === 'dim') {
            typeLabel = 'dim';
            symbolSuffix = 'dim';
            noteIntervals = [0, 3, 6];
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
        }

        const chordName = `${rootNameLat} ${typeLabel}`.trim();
        const chordSymbol = `${rootNameEng}${symbolSuffix}`.trim();
        const noteMods = noteIntervals.map(interval => (root + interval) % 12);

        return {
            root,
            chordType,
            chordName,
            chordSymbol,
            noteMods,
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

        if (idx >= 0 && timeline[idx]) {
            const ch = timeline[idx];
            if (this._editorRootSelect) this._editorRootSelect.value = ch.root ?? 0;
            if (this._editorTypeSelect) this._editorTypeSelect.value = ch.chordType || 'major';
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

        this._modal.style.display = 'flex';
        this._modal.classList.remove('hidden');
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
        this.renderChordProgressBar(timeline, this._currentAnalysisData.duration);

        if (this._handlers && this._handlers.onChordTimelineUpdated) {
            this._handlers.onChordTimelineUpdated(timeline);
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
            this.renderChordProgressBar(timeline, this._currentAnalysisData.duration);

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
        if (this._activeChordBadge) {
            this._activeChordBadge.innerHTML = `
                <div style="display: flex; flex-direction: column; gap: 2px;">
                    <span style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">Acorde Detectado</span>
                    <strong style="font-size: 1.10rem; font-weight: 900; color: #4338ca; line-height: 1.1;">${chord.chordName}</strong>
                </div>
                <div style="display: flex; align-items: center; gap: 6px;">
                    <span style="font-size: 0.72rem; font-weight: 800; background: #ede9fe; color: #6d28d9; padding: 2px 8px; border-radius: 4px; border: 1px solid #c4b5fd;">${chord.chordSymbol}</span>
                    <span style="font-size: 0.65rem; color: #64748b; font-weight: 700;">${Math.round(chord.confidence * 100)}% conf.</span>
                </div>
            `;
        }

        if (this._chordsStrip) {
            const chips = this._chordsStrip.querySelectorAll('.chord-timeline-chip');
            chips.forEach((c, i) => {
                const isActive = i === chordIndex;
                c.classList.toggle('active-timeline-chord', isActive);
                if (isActive) {
                    c.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
                }
            });
        }

        if (this._chordProgressBarTrack) {
            const blocks = this._chordProgressBarTrack.querySelectorAll('.chord-segment-block');
            blocks.forEach((blk, i) => {
                blk.classList.toggle('active', i === chordIndex);
            });
        }
    }

    /**
     * Actualiza el indicador temporal y la barra de progreso.
     * @param {number} currentTime
     * @param {number} duration
     * @param {number} progress
     */
    updateTime(currentTime, duration, progress) {
        if (this._timeDisplay) {
            this._timeDisplay.innerText = `${this._formatTime(currentTime)} / ${this._formatTime(duration)}`;
        }
        if (this._timelineSeeker) {
            this._timelineSeeker.value = progress;
        }
        if (this._chordTrackPlayhead) {
            this._chordTrackPlayhead.style.left = `${(progress * 100).toFixed(2)}%`;
        }

        // Resaltar el cuadro (compás) activo en tiempo real
        if (this._barSec && this._chordProgressBarTrack) {
            const activeBarIdx = Math.floor(currentTime / this._barSec);
            const boxes = this._chordProgressBarTrack.querySelectorAll('.track-bpm-box');
            boxes.forEach((bx, idx) => {
                bx.classList.toggle('active-bar', idx === activeBarIdx);
            });
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
