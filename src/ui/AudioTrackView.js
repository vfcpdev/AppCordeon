/**
 * @fileoverview Vista del Analizador de Pistas de Audio MP3 y Sincronizador de Acordes (SRP).
 * Gestiona el panel de carga de archivos, visualización de tonalidad principal,
 * barra de progreso y acordes en tiempo real.
 * @module ui/AudioTrackView
 */

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

        this._analysisData = null;
    }

    /**
     * Vincula eventos de la vista de audio.
     * @param {Object} handlers
     */
    bindEvents(handlers) {
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

        if (this._btnApplyTuning) {
            this._btnApplyTuning.addEventListener('click', () => {
                if (this._analysisData && this._analysisData.mainKey && handlers.onApplyTuning) {
                    handlers.onApplyTuning(
                        this._analysisData.mainKey.recommendedOffset,
                        this._analysisData.mainKey.recommendedRow
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
        this._analysisData = analysisData;

        if (this._trackInfoCard) {
            this._trackInfoCard.style.display = 'flex';
        }
        if (this._playbackControls) {
            this._playbackControls.style.display = 'flex';
        }

        if (this._fileNameLabel) {
            this._fileNameLabel.innerText = file.name;
        }

        // Tonalidad Principal
        if (this._mainKeyBadge && analysisData.mainKey) {
            this._mainKeyBadge.innerHTML = `
                <i class="fas fa-key"></i> Tonalidad Principal: <strong>${analysisData.mainKey.keyNameLat}</strong> (${analysisData.mainKey.keyNameAle})
            `;
        }

        // Recomendación de acordeón
        if (this._tuningRecommendation && analysisData.mainKey) {
            this._tuningRecommendation.innerHTML = `
                <i class="fas fa-thumbs-up"></i> Afinación sugerida: <strong>${analysisData.mainKey.recommendedTuning}</strong>
            `;
        }

        // Tira de acordes secuenciales
        this.renderChordsStrip(analysisData.chords, onChordMarkerClick);

        // Actualizar tiempos iniciales
        this.updateTime(0, analysisData.duration, 0);
    }

    /**
     * Renderiza la tira con los bloques de acordes detectados.
     * @param {Array} chords
     * @param {(time: number) => void} onClick
     */
    renderChordsStrip(chords, onClick) {
        if (!this._chordsStrip) return;
        this._chordsStrip.innerHTML = "";

        chords.forEach((chord, idx) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'chord-timeline-chip';
            btn.id = `chord-marker-${idx}`;
            btn.title = `${chord.chordName} (${this._formatTime(chord.startTime)} - ${this._formatTime(chord.endTime)})`;

            btn.innerHTML = `
                <strong style="color: #ffffff;">${chord.chordName}</strong>
                <span style="font-size: 0.60rem; color: #a78bfa;">${this._formatTime(chord.startTime)}</span>
            `;

            btn.addEventListener('click', () => {
                if (onClick) onClick(chord.startTime);
            });

            this._chordsStrip.appendChild(btn);
        });
    }

    /**
     * Resalta el acorde activo en la línea de tiempo y en el badge.
     * @param {Object} chord
     * @param {number} chordIndex
     */
    setActiveChord(chord, chordIndex) {
        if (this._activeChordBadge) {
            this._activeChordBadge.innerHTML = `
                <div style="font-size: 0.70rem; color: #a78bfa; text-transform: uppercase; font-weight: 800;">Acorde Actual en Audio:</div>
                <div style="font-size: 1.25rem; font-weight: 900; color: #facc15; text-shadow: 0 0 10px rgba(250, 204, 21, 0.6);">${chord.chordName}</div>
                <div style="font-size: 0.68rem; color: #cbd5e1;">Cifrado: <strong>${chord.chordSymbol}</strong> · Confianza: ${Math.round(chord.confidence * 100)}%</div>
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
