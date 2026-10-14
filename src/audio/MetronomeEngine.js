/**
 * @fileoverview Motor de Metrónomo de Alta Precisión con Web Audio API (SRP).
 * Genera pulsos sonoros sintetizados (acento en tiempo 1, clics en tiempos 2-4)
 * perfectamente sincronizados con la reproducción del audio MP3.
 * @module audio/MetronomeEngine
 */

export class MetronomeEngine {
    constructor() {
        this._audioContext = null;
        this._enabled = false;
        this._bpm = 120;
        this._volume = 0.70;
        this._beatsPerMeasure = 4;

        this._isPlaying = false;
        this._getAudioTime = null; // Función para obtener el currentTime del audio
        this._timerId = null;
        this._nextBeatIndex = 0; // Índice acumulativo de pulso
        this._beatCallbacks = [];
    }

    /**
     * Asigna o reutiliza el AudioContext principal.
     * @param {AudioContext} ctx
     */
    setAudioContext(ctx) {
        this._audioContext = ctx;
    }

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
     * Alterna encendido / apagado del metrónomo.
     * @returns {boolean}
     */
    toggle() {
        this._enabled = !this._enabled;
        return this._enabled;
    }

    setEnabled(enabled) {
        this._enabled = Boolean(enabled);
    }

    isEnabled() {
        return this._enabled;
    }

    setBPM(bpm) {
        const val = Math.max(30, Math.min(260, Math.round(bpm)));
        this._bpm = val;
    }

    getBPM() {
        return this._bpm;
    }

    setVolume(vol) {
        this._volume = Math.max(0, Math.min(1, vol));
    }

    getVolume() {
        return this._volume;
    }

    /**
     * Registra un observador que se ejecuta en cada pulso (para animación UI).
     * @param {Function} cb (beatNumber: 1..4, measureIndex: number) => void
     */
    onBeat(cb) {
        if (typeof cb === 'function') {
            this._beatCallbacks.push(cb);
        }
    }

    /**
     * Notifica a los observadores de pulso.
     * @private
     */
    _notifyBeat(beatNumber, measureIndex) {
        this._beatCallbacks.forEach(cb => {
            try {
                cb(beatNumber, measureIndex);
            } catch (e) {
                console.warn('Error en callback de pulso de metrónomo:', e);
            }
        });
    }

    /**
     * Sintetiza un clic de metrónomo con oscilador y envolvente exponencial.
     * @param {number} beat 1 para acento fuerte, 2-4 para clics estándar
     * @param {number} [scheduledTime] Tiempo Web Audio en que debe sonar (opcional)
     */
    playClick(beat = 1, scheduledTime = 0) {
        if (!this._enabled || this._volume <= 0) return;

        try {
            const ctx = this._getAudioContext();
            const now = scheduledTime > 0 ? scheduledTime : ctx.currentTime;

            const osc = ctx.createOscillator();
            const gain = ctx.createGain();

            // Frecuencia: 1200 Hz para el primer pulso (acento), 800 Hz para pulsos secundarios
            const isAccent = (beat === 1);
            osc.type = isAccent ? 'sine' : 'triangle';
            osc.frequency.setValueAtTime(isAccent ? 1200 : 800, now);
            osc.frequency.exponentialRampToValueAtTime(isAccent ? 400 : 250, now + 0.04);

            const peakGain = (isAccent ? 1.0 : 0.65) * this._volume;
            gain.gain.setValueAtTime(peakGain, now);
            gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.05);

            osc.connect(gain);
            gain.connect(ctx.destination);

            osc.start(now);
            osc.stop(now + 0.06);
        } catch (e) {
            // Ignorar errores menores de contexto suspendido
        }
    }

    /**
     * Inicia la sincronización del metrónomo con la reproducción del audio.
     * @param {Function} getAudioTimeFn Función que devuelve el currentTime actual del reproductor
     */
    startAudioSync(getAudioTimeFn) {
        this._getAudioTime = getAudioTimeFn;
        this._isPlaying = true;
        this._stopLoop();

        const beatSec = 60 / this._bpm;
        const currentAudioTime = this._getAudioTime ? this._getAudioTime() : 0;
        // Calcular el próximo pulso entero relativo al tiempo del audio
        this._nextBeatIndex = Math.floor(currentAudioTime / beatSec) + 1;

        this._runSyncLoop();
    }

    /**
     * Bucle de sincronización con intervalos cortos (lookahead scheduling)
     * para asegurar clics precisos sin latencia ni jitter.
     * @private
     */
    _runSyncLoop() {
        if (!this._isPlaying) return;

        const checkIntervalMs = 25; // Comprobación cada 25ms
        this._timerId = setInterval(() => {
            if (!this._isPlaying || !this._getAudioTime) return;

            const audioTime = this._getAudioTime();
            const beatSec = 60 / this._bpm;
            const currentExpectedBeat = Math.floor(audioTime / beatSec);

            // Si el audio saltó hacia atrás o hacia adelante significativamente (seek)
            if (Math.abs(currentExpectedBeat - this._nextBeatIndex) > 2) {
                this._nextBeatIndex = currentExpectedBeat + 1;
            }

            const nextBeatTime = this._nextBeatIndex * beatSec;
            // Si el siguiente pulso ocurre en los próximos 60ms
            if (audioTime >= nextBeatTime - 0.01) {
                const beatInMeasure = (this._nextBeatIndex % this._beatsPerMeasure) + 1;
                const measureIndex = Math.floor(this._nextBeatIndex / this._beatsPerMeasure);

                if (this._enabled) {
                    this.playClick(beatInMeasure);
                }
                this._notifyBeat(beatInMeasure, measureIndex);

                this._nextBeatIndex++;
            }
        }, checkIntervalMs);
    }

    /**
     * Detiene la sincronización del metrónomo.
     */
    stopAudioSync() {
        this._isPlaying = false;
        this._stopLoop();
    }

    _stopLoop() {
        if (this._timerId) {
            clearInterval(this._timerId);
            this._timerId = null;
        }
    }

    /**
     * Notifica un salto temporal (seek) para resincronizar de inmediato.
     * @param {number} newTimeSeconds
     */
    notifySeek(newTimeSeconds) {
        const beatSec = 60 / this._bpm;
        this._nextBeatIndex = Math.floor(newTimeSeconds / beatSec) + 1;
    }
}

export const metronomeEngine = new MetronomeEngine();
export default metronomeEngine;
