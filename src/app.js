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
import { CadenceView } from './ui/CadenceView.js';
import { DiapasonChordSidebarView } from './ui/DiapasonChordSidebarView.js';
import { SheetMusicModalView } from './ui/SheetMusicModalView.js';
import { AppController } from './controllers/AppController.js';
import { audioEngine } from './audio/AudioEngine.js';

document.addEventListener('DOMContentLoaded', () => {
    // 1. Instanciación de Vistas con referencias a elementos del DOM
    const diapasonView = new DiapasonView(document.getElementById('diapason'), '');
    const secondaryDiapasonView = new DiapasonView(document.getElementById('secondaryDiapason'), 'sec_');

    const cadenceView = new CadenceView({
        container: document.getElementById('cadenceSection'),
        cardsContainer: document.getElementById('cadenceCardsContainer'),
        activeToneLabel: document.getElementById('lblCadenceActiveTone')
    });

    const diapasonChordSidebarView = new DiapasonChordSidebarView({
        primarySidebar: document.getElementById('primaryDiapasonChordSidebar'),
        secondarySidebar: document.getElementById('secondaryDiapasonChordSidebar')
    });

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
        speedLabel: document.getElementById('speedValueLabel'),
        octaveButtons: document.querySelectorAll('#scaleOctaveToggle .segment-btn')
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
        chkFixChord: document.getElementById('chkFixFreeChord'),
        modeButtons: document.querySelectorAll('#freeChordModeToggle .segment-btn'),
        scaleNameLabel: document.getElementById('lblFreeChordScaleName'),
        scaleGrid: document.getElementById('freeChordScaleGrid'),
        btnSyncScale: document.getElementById('btnSyncFreeChordToScale')
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
        audioKeySelect: document.getElementById('audioKeySelect'),
        tuningRecommendation: document.getElementById('audioTuningRecommendation'),
        btnApplyTuning: document.getElementById('btnApplySuggestedTuning'),
        playbackControls: document.getElementById('trackPlaybackControls'),
        btnPlayPause: document.getElementById('btnPlayPauseAudio'),
        btnStop: document.getElementById('btnStopAudio'),
        timeDisplay: document.getElementById('audioTimeDisplay'),
        timelineSeeker: document.getElementById('audioSeeker'),
        activeChordBadge: document.getElementById('audioActiveChordBadge'),
        chkSyncDiapason: document.getElementById('chkSyncDiapason'),
        chordsStrip: document.getElementById('audioChordsStrip'),
        btnPitchDown: document.getElementById('btnPitchDown'),
        btnPitchUp: document.getElementById('btnPitchUp'),
        btnPitchReset: document.getElementById('btnPitchReset'),
        lblPitchShift: document.getElementById('lblPitchShiftValue'),
        audioAccordionSelect: document.getElementById('audioAccordionSelect'),
        audioAccordionRowsContainer: document.getElementById('audioAccordionRowsContainer'),
        btnSyncTuningToDiapason: document.getElementById('btnSyncTuningToDiapason')
    });

    const sheetMusicModalView = new SheetMusicModalView({
        onApplyChords: (timelineChords, bpm, scoreInfo) => {
            appController.applySheetMusicChords(timelineChords, bpm, scoreInfo);
        },
        onChordSelected: (chordItem) => {
            appController.playSheetMusicChord(chordItem);
        }
    });

    const btnOpenSheet = document.getElementById('btnOpenSheetMusic');
    if (btnOpenSheet) {
        btnOpenSheet.addEventListener('click', () => sheetMusicModalView.open());
    }
    const btnTrackSheet = document.getElementById('btnTrackSheetMusic');
    if (btnTrackSheet) {
        btnTrackSheet.addEventListener('click', () => sheetMusicModalView.open());
    }

    // 2. Creación del Controlador Principal
    const appController = new AppController({
        diapasonView,
        secondaryDiapasonView,
        scaleBarView,
        chordView,
        detectorView,
        executionView,
        audioTrackView,
        cadenceView,
        diapasonChordSidebarView,
        sheetMusicModalView
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
                registration.update();
                console.log('[PWA] Service Worker registrado con éxito:', registration.scope);
            }).catch((err) => {
                console.log('[PWA] Registro de Service Worker falló:', err);
            });
        });
    }
});
