/**
 * @fileoverview Controlador de Reproducción de Audio y Sincronización en Tiempo Real (SRP).
 * Gestiona la reproducción del archivo MP3/WAV y emite eventos de sincronización de acordes.
 * @module audio/AudioPlayerController
 */

import { eventBus } from '../core/EventBus.js';
import { metronomeEngine } from './MetronomeEngine.js';

export class AudioPlayerController {
    constructor() {
        this._audioContext = null;
        this._audioBuffer = null;
        this._sourceNode = null;
        this._gainNode = null;

        this._startTime = 0;
        this._pausedAt = 0;
        this._isPlaying = false;
        this._animationId = null;

        this._playbackRate = 1.0;
        this._chordsTimeline = [];
        this._currentChordIndex = -1;
        this._syncWithDiapason = true;
        this._pitchShift = 0; // Desplazamiento de tono en semitonos (-12 a +12)
    }

    /**
     * @private
     */
    _getAudioContext() {
        if (!this._audioContext) {
            const AudioCtx = window.AudioContext || window.webkitAudioContext;
            this._audioContext = new AudioCtx();
        }
        if (this._audioContext.state === 'suspended') {
            this._audioContext.resume();
        }
        return this._audioContext;
    }

    /**
     * Carga un AudioBuffer y su lista de acordes analizados.
     * @param {AudioBuffer} buffer
     * @param {Array} chordsTimeline
     */
    loadTrack(buffer, chordsTimeline) {
        this.stop();
        this._audioBuffer = buffer;
        this._isSyntheticBuffer = false;
        this._chordsTimeline = chordsTimeline || [];
        this._pausedAt = 0;
        this._currentChordIndex = -1;
        this._pitchShift = 0;

        eventBus.emit('player:loaded', {
            duration: buffer.duration,
            chordsCount: this._chordsTimeline.length
        });
    }

    /**
     * Inicia o reanuda la reproducción.
     */
    play() {
        if (this._isPlaying) return;

        const ctx = this._getAudioContext();
        if (ctx.state === 'suspended') {
            ctx.resume();
        }

        const dur = this.duration;

        if (!this._audioBuffer) {
            // Buffer sintético silencioso para permitir probar la línea de tiempo y sincronización sin archivo
            this._audioBuffer = ctx.createBuffer(1, Math.max(1, Math.floor(ctx.sampleRate * dur)), ctx.sampleRate);
            this._isSyntheticBuffer = true;
        }

        this._sourceNode = ctx.createBufferSource();
        this._sourceNode.buffer = this._audioBuffer;
        this._sourceNode.playbackRate.value = this._playbackRate;

        // El audio SIEMPRE se reproduce en su tono original (sin detune).
        // El ajuste de tono es exclusivamente visual (transposición de acordes).

        this._gainNode = ctx.createGain();
        this._sourceNode.connect(this._gainNode);
        this._gainNode.connect(ctx.destination);

        const bufDur = this._audioBuffer.duration || dur;
        const offset = (this._pausedAt || 0) % bufDur;
        this._startTime = ctx.currentTime - (offset / this._playbackRate);

        this._sourceNode.start(0, offset);
        this._isPlaying = true;

        // Iniciar sincronización de metrónomo con el audio
        metronomeEngine.setAudioContext(ctx);
        metronomeEngine.startAudioSync(() => this.currentTime);

        this._sourceNode.onended = () => {
            if (this._isPlaying && ((ctx.currentTime - this._startTime) * this._playbackRate >= bufDur)) {
                this.stop();
                eventBus.emit('player:ended');
            }
        };

        this._startSyncLoop();
        eventBus.emit('player:state_change', { isPlaying: true });
    }

    /**
     * Pausa la reproducción manteniendo el punto actual.
     */
    pause() {
        if (!this._isPlaying) return;

        const ctx = this._getAudioContext();
        this._pausedAt = (ctx.currentTime - this._startTime) * this._playbackRate;

        metronomeEngine.stopAudioSync();
        this._stopSource();
        this._stopSyncLoop();
        this._isPlaying = false;

        eventBus.emit('player:state_change', { isPlaying: false });
    }

    /**
     * Detiene la reproducción y reinicia la posición al inicio.
     */
    stop() {
        metronomeEngine.stopAudioSync();
        this._stopSource();
        this._stopSyncLoop();
        this._isPlaying = false;
        this._pausedAt = 0;
        this._currentChordIndex = -1;

        eventBus.emit('player:state_change', { isPlaying: false });
        eventBus.emit('player:timeupdate', {
            currentTime: 0,
            duration: this.duration,
            progress: 0
        });
    }

    /**
     * Salta a una posición temporal específica en segundos.
     * @param {number} timeSeconds
     */
    seek(timeSeconds) {
        const dur = this.duration;
        const targetTime = Math.max(0, Math.min(timeSeconds, dur));

        const wasPlaying = this._isPlaying;
        if (wasPlaying) {
            this.pause();
        }

        this._pausedAt = targetTime;
        this._currentChordIndex = -1;
        metronomeEngine.notifySeek(targetTime);
        this._checkCurrentChord(targetTime);

        eventBus.emit('player:timeupdate', {
            currentTime: targetTime,
            duration: dur,
            progress: dur > 0 ? targetTime / dur : 0
        });

        if (wasPlaying) {
            this.play();
        }
    }

    /**
     * Salta relativo (adelante o atrás) en segundos.
     * @param {number} deltaSeconds
     */
    skipSeconds(deltaSeconds) {
        this.seek(this.currentTime + deltaSeconds);
    }

    /**
     * Cambia la velocidad de reproducción (0.25x - 2.0x).
     * @param {number} rate
     */
    setPlaybackRate(rate) {
        const parsed = parseFloat(rate);
        if (isNaN(parsed) || parsed <= 0) return;
        this._playbackRate = Math.max(0.25, Math.min(2.0, parsed));

        if (this._sourceNode && this._audioContext) {
            try {
                this._sourceNode.playbackRate.setValueAtTime(this._playbackRate, this._audioContext.currentTime);
            } catch (e) {}
        }

        if (this._isPlaying && this._audioContext) {
            const now = this._audioContext.currentTime;
            const curAudioTime = this.currentTime;
            this._startTime = now - (curAudioTime / this._playbackRate);
        }

        eventBus.emit('player:rate_change', { playbackRate: this._playbackRate });
    }

    get playbackRate() {
        return this._playbackRate;
    }

    /**
     * @private
     */
    _stopSource() {
        if (this._sourceNode) {
            try {
                this._sourceNode.stop();
                this._sourceNode.disconnect();
            } catch (e) {
                // Ya finalizado
            }
            this._sourceNode = null;
        }
    }

    /**
     * Bucle de sincronización con requestAnimationFrame.
     * @private
     */
    _startSyncLoop() {
        const loop = () => {
            if (!this._isPlaying || !this._audioBuffer) return;

            const ctx = this._getAudioContext();
            const elapsed = (ctx.currentTime - this._startTime) * this._playbackRate;
            const currentTime = Math.min(Math.max(0, elapsed), this._audioBuffer.duration);
            const duration = this._audioBuffer.duration;
            const progress = duration > 0 ? (currentTime / duration) : 0;

            eventBus.emit('player:timeupdate', {
                currentTime,
                duration,
                progress
            });

            this._checkCurrentChord(currentTime);

            this._animationId = requestAnimationFrame(loop);
        };

        this._animationId = requestAnimationFrame(loop);
    }

    /**
     * @private
     */
    _stopSyncLoop() {
        if (this._animationId) {
            cancelAnimationFrame(this._animationId);
            this._animationId = null;
        }
    }

    /**
     * Verifica y emite el acorde correspondiente al tiempo actual.
     * @private
     */
    _checkCurrentChord(currentTime) {
        if (!this._chordsTimeline || this._chordsTimeline.length === 0) return;

        const chordIdx = this._chordsTimeline.findIndex(
            seg => currentTime >= seg.startTime && currentTime < seg.endTime
        );

        if (chordIdx !== -1 && chordIdx !== this._currentChordIndex) {
            this._currentChordIndex = chordIdx;
            const currentChord = this._chordsTimeline[chordIdx];

            eventBus.emit('player:chord_active', {
                chord: currentChord,
                index: chordIdx,
                syncWithDiapason: this._syncWithDiapason
            });
        }
    }

    /**
     * Activa o desactiva la sincronización visual en el diapasón.
     * @param {boolean} enable
     */
    setSyncWithDiapason(enable) {
        this._syncWithDiapason = enable;
    }

    get isPlaying() {
        return this._isPlaying;
    }

    get currentTime() {
        if (!this._isPlaying) return this._pausedAt || 0;
        const ctx = this._getAudioContext();
        const dur = this.duration;
        const elapsed = (ctx.currentTime - this._startTime) * this._playbackRate;
        return Math.min(Math.max(0, elapsed), dur);
    }

    /**
     * Establece el ajuste de tono (pitch shift) en semitonos (-12 a +12).
     * @param {number} semitones
     */
    setPitchShift(semitones) {
        // Solo se guarda el valor para la transposición visual de acordes;
        // no se modifica el sonido original de la canción.
        this._pitchShift = Math.max(-12, Math.min(12, semitones));
        eventBus.emit('player:pitch_shift_changed', { pitchShift: this._pitchShift, visualOnly: true });
    }

    get pitchShift() {
        return this._pitchShift;
    }

    /**
     * Actualiza la línea de tiempo de acordes tras ajuste de tono.
     * @param {Array} chordsTimeline
     */
    setChordsTimeline(chordsTimeline) {
        this._chordsTimeline = chordsTimeline || [];
        this._currentChordIndex = -1;
        // Si se usa el buffer silencioso de prueba (sin archivo), regenerarlo si la línea de tiempo creció
        if (this._isSyntheticBuffer && !this._isPlaying && this._audioBuffer) {
            const maxEnd = Math.max(16, ...this._chordsTimeline.map(c => c.endTime || 0));
            if (maxEnd > this._audioBuffer.duration) {
                this._audioBuffer = null;
                this._isSyntheticBuffer = false;
            }
        }
        if (this._isPlaying && this._audioBuffer) {
            const ctx = this._getAudioContext();
            const currentTime = Math.min(ctx.currentTime - this._startTime, this._audioBuffer.duration);
            this._checkCurrentChord(currentTime);
        }
    }

    get duration() {
        if (this._audioBuffer) return this._audioBuffer.duration;
        if (this._chordsTimeline && this._chordsTimeline.length > 0) {
            return Math.max(...this._chordsTimeline.map(c => c.endTime || 0), 16);
        }
        return 16;
    }
}

export const audioPlayerController = new AudioPlayerController();
export default AudioPlayerController;
