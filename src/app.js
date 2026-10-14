/**
 * @fileoverview Punto de entrada de la aplicación modular ESM.
 * Inicializa las vistas, las inyecta en AppController y registra el Service Worker para PWA.
 * @module app
 */

import { DiapasonView } from './ui/DiapasonView.js';
import { ScaleBarView } from './ui/ScaleBarView.js';
import { ChordView } from './ui/ChordView.js';
import { DetectorView } from './ui/DetectorView.js';
import { ExecutionView } from './ui/ExecutionView.js';
import { AudioTrackView } from './ui/AudioTrackView.js';
import { AppController } from './controllers/AppController.js';
import { audioEngine } from './audio/AudioEngine.js';

document.addEventListener('DOMContentLoaded', () => {
    // 1. Instanciación de Vistas con referencias a elementos del DOM
    const diapasonView = new DiapasonView(document.getElementById('diapason'));

    const scaleBarView = new ScaleBarView({
        titleEl: document.getElementById('lblScaleTitle'),
        gridEl: document.getElementById('scaleGrid'),
        scaleRootSelect: document.getElementById('scaleRootSelect'),
        scaleTypeSelect: document.getElementById('scaleTypeSelect'),
        relatedChordsStrip: document.getElementById('relatedChordsStrip'),
        fixChordCheckbox: document.getElementById('chkFixGradeChord'),
        btnPrev: document.getElementById('btnPrevNote'),
        btnNext: document.getElementById('btnNextNote'),
        btnPlay: document.getElementById('btnPlayScale'),
        btnReset: document.getElementById('btnResetScale'),
        btnLoop: document.getElementById('btnToggleLoop'),
        loopStartInput: document.getElementById('loopStart'),
        loopEndInput: document.getElementById('loopEnd'),
        speedSlider: document.getElementById('speedSlider'),
        speedLabel: document.getElementById('speedValueLabel')
    });

    const chordView = new ChordView({
        rootSelect: document.getElementById('chordRoot'),
        typeSelect: document.getElementById('chordType'),
        fourthSelect: document.getElementById('chord4thNote'),
        octaveSelect: document.getElementById('chordOctave'),
        bellowsButtons: document.querySelectorAll('#chordBellowsToggle .segment-btn'),
        notesDisplay: document.getElementById('chordNotesDisplay'),
        feasibilityBadge: document.getElementById('chordBellowsFeasibilityBadge'),
        strip: document.getElementById('freeChordNotesStrip'),
        btnPlay: document.getElementById('btnPlayFreeChord'),
        btnArpeggio: document.getElementById('btnArpeggioFreeChord'),
        btnPrevNote: document.getElementById('btnPrevChordNote'),
        btnNextNote: document.getElementById('btnNextChordNote'),
        btnClear: document.getElementById('btnClearChord'),
        chkFixChord: document.getElementById('chkFixFreeChord')
    });

    const detectorView = new DetectorView({
        btnToggleMode: document.getElementById('btnToggleDetectorMode'),
        lblModeStatus: document.getElementById('lblDetectorModeStatus'),
        dirButtons: document.querySelectorAll('#detectorDirectionToggle .segment-btn'),
        lblCount: document.getElementById('lblDetectorCount'),
        strip: document.getElementById('detectorSelectedStrip'),
        btnPlay: document.getElementById('btnPlayDetectorChord'),
        btnArpeggio: document.getElementById('btnArpeggioDetectorChord'),
        btnClear: document.getElementById('btnClearDetector'),
        mainNameEl: document.getElementById('detectorChordMainName'),
        inversionBadgeEl: document.getElementById('detectorInversionBadge'),
        rootEl: document.getElementById('detectorRootNote'),
        bassEl: document.getElementById('detectorBassNote'),
        formulaEl: document.getElementById('detectorFormula'),
        typeEl: document.getElementById('detectorType'),
        altRow: document.getElementById('detectorAlternativesRow'),
        altText: document.getElementById('detectorAlternativesText')
    });

    const executionView = new ExecutionView({
        noteNameLabel: document.getElementById('lblActiveNoteName'),
        executionSelect: document.getElementById('executionModeSelect')
    });

    const dropZone = document.getElementById('audioDropZone');
    const fileInput = document.getElementById('audioFileInput');
    if (dropZone && fileInput) {
        dropZone.addEventListener('click', () => fileInput.click());
    }

    const audioTrackView = new AudioTrackView({
        container: document.getElementById('audioAnalysisSection'),
        fileInput,
        dropZone,
        progressContainer: document.getElementById('audioProgressContainer'),
        progressBar: document.getElementById('audioProgressBar'),
        progressText: document.getElementById('audioProgressText'),
        trackInfoCard: document.getElementById('trackInfoCard'),
        fileNameLabel: document.getElementById('audioFileName'),
        mainKeyBadge: document.getElementById('audioMainKeyBadge'),
        tuningRecommendation: document.getElementById('audioTuningRecommendation'),
        btnApplyTuning: document.getElementById('btnApplySuggestedTuning'),
        playbackControls: document.getElementById('trackPlaybackControls'),
        btnPlayPause: document.getElementById('btnPlayPauseAudio'),
        btnStop: document.getElementById('btnStopAudio'),
        timeDisplay: document.getElementById('audioTimeDisplay'),
        timelineSeeker: document.getElementById('audioSeeker'),
        activeChordBadge: document.getElementById('audioActiveChordBadge'),
        chkSyncDiapason: document.getElementById('chkSyncDiapason'),
        chordsStrip: document.getElementById('audioChordsStrip')
    });

    // 2. Creación del Controlador Principal
    const appController = new AppController({
        diapasonView,
        scaleBarView,
        chordView,
        detectorView,
        executionView,
        audioTrackView
    });

    // 3. Inicialización
    appController.init();

    // 4. Inicializar contexto de audio en el primer gesto de usuario en la ventana
    const initAudioOnFirstUserAction = () => {
        audioEngine.init();
        window.removeEventListener('pointerdown', initAudioOnFirstUserAction);
        window.removeEventListener('keydown', initAudioOnFirstUserAction);
    };
    window.addEventListener('pointerdown', initAudioOnFirstUserAction, { once: true });
    window.addEventListener('keydown', initAudioOnFirstUserAction, { once: true });

    // 5. Registro de Service Worker para PWA
    if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
            navigator.serviceWorker.register('./sw.js').then((registration) => {
                console.log('[PWA] Service Worker registrado con éxito:', registration.scope);
            }).catch((err) => {
                console.log('[PWA] Registro de Service Worker falló:', err);
            });
        });
    }
});
