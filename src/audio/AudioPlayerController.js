/**
 * @fileoverview Controlador de Reproducción de Audio y Sincronización en Tiempo Real (SRP).
 * Gestiona la reproducción del archivo MP3/WAV y emite eventos de sincronización de acordes.
 * @module audio/AudioPlayerController
 */

import { eventBus } from '../core/EventBus.js';

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

        this._chordsTimeline = [];
        this._currentChordIndex = -1;
        this._syncWithDiapason = true;
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
        this._chordsTimeline = chordsTimeline || [];
        this._pausedAt = 0;
        this._currentChordIndex = -1;

        eventBus.emit('player:loaded', {
            duration: buffer.duration,
            chordsCount: this._chordsTimeline.length
        });
    }

    /**
     * Inicia o reanuda la reproducción.
     */
    play() {
        if (!this._audioBuffer || this._isPlaying) return;

        const ctx = this._getAudioContext();
        this._sourceNode = ctx.createBufferSource();
        this._sourceNode.buffer = this._audioBuffer;

        this._gainNode = ctx.createGain();
        this._sourceNode.connect(this._gainNode);
        this._gainNode.connect(ctx.destination);

        const offset = this._pausedAt % this._audioBuffer.duration;
        this._startTime = ctx.currentTime - offset;

        this._sourceNode.start(0, offset);
        this._isPlaying = true;

        this._sourceNode.onended = () => {
            if (this._isPlaying && (ctx.currentTime - this._startTime >= this._audioBuffer.duration)) {
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
        this._pausedAt = ctx.currentTime - this._startTime;

        this._stopSource();
        this._stopSyncLoop();
        this._isPlaying = false;

        eventBus.emit('player:state_change', { isPlaying: false });
    }

    /**
     * Detiene la reproducción y reinicia la posición al inicio.
     */
    stop() {
        this._stopSource();
        this._stopSyncLoop();
        this._isPlaying = false;
        this._pausedAt = 0;
        this._currentChordIndex = -1;

        eventBus.emit('player:state_change', { isPlaying: false });
        eventBus.emit('player:timeupdate', {
            currentTime: 0,
            duration: this._audioBuffer ? this._audioBuffer.duration : 0,
            progress: 0
        });
    }

    /**
     * Salta a una posición temporal específica en segundos.
     * @param {number} timeSeconds
     */
    seek(timeSeconds) {
        if (!this._audioBuffer) return;
        const targetTime = Math.max(0, Math.min(timeSeconds, this._audioBuffer.duration));

        const wasPlaying = this._isPlaying;
        if (wasPlaying) {
            this.pause();
        }

        this._pausedAt = targetTime;
        this._currentChordIndex = -1;
        this._checkCurrentChord(targetTime);

        eventBus.emit('player:timeupdate', {
            currentTime: targetTime,
            duration: this._audioBuffer.duration,
            progress: targetTime / this._audioBuffer.duration
        });

        if (wasPlaying) {
            this.play();
        }
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
            const currentTime = Math.min(ctx.currentTime - this._startTime, this._audioBuffer.duration);
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
        if (!this._audioBuffer) return 0;
        if (!this._isPlaying) return this._pausedAt;
        const ctx = this._getAudioContext();
        return Math.min(ctx.currentTime - this._startTime, this._audioBuffer.duration);
    }

    get duration() {
        return this._audioBuffer ? this._audioBuffer.duration : 0;
    }
}

export const audioPlayerController = new AudioPlayerController();
export default AudioPlayerController;
