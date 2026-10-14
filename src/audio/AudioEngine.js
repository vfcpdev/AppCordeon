/**
 * @fileoverview Gestor de Audio Singleton (Patrón Singleton y DIP).
 * Centraliza las llamadas de sonido de toda la aplicación delegando en un IAudioEngine.
 * @module audio/AudioEngine
 */

import { IAudioEngine } from './IAudioEngine.js';
import { WebAudioSynth } from './WebAudioSynth.js';
import { eventBus } from '../core/EventBus.js';

class AudioEngine {
    constructor() {
        if (AudioEngine._instance) {
            return AudioEngine._instance;
        }

        /**
         * Motor concreto de síntesis.
         * @type {IAudioEngine}
         * @private
         */
        this._engine = new WebAudioSynth();

        AudioEngine._instance = this;
    }

    /**
     * @returns {AudioEngine} Instancia única de AudioEngine.
     */
    static getInstance() {
        if (!AudioEngine._instance) {
            AudioEngine._instance = new AudioEngine();
        }
        return AudioEngine._instance;
    }

    /**
     * Permite intercambiar dinámicamente el motor de síntesis (ej: por SampledSynth en el futuro).
     * Cumple OCP y LSP.
     * @param {IAudioEngine} newEngine
     */
    setEngine(newEngine) {
        if (!(newEngine instanceof IAudioEngine)) {
            throw new TypeError('El nuevo motor debe heredar de IAudioEngine.');
        }
        this._engine.releaseAll();
        this._engine = newEngine;
    }

    /**
     * Inicializa el motor de audio al primer clic o pulsación del usuario.
     * @returns {Promise<void>}
     */
    async init() {
        if (!this._engine.isReady()) {
            await this._engine.init();
            eventBus.emit('audio:ready');
        }
    }

    /**
     * Toca una nota o acorde individual/múltiple.
     * @param {number|number[]} midi Nota(s) MIDI.
     * @param {string} [duration="8n"]
     */
    play(midi, duration = "8n") {
        this.init().then(() => {
            this._engine.triggerAttackRelease(midi, duration);
            eventBus.emit('audio:played', { midi, duration });
        }).catch(err => {
            console.warn('[AudioEngine] No se pudo reproducir audio:', err);
        });
    }

    /**
     * Mantiene sonando un acorde continuo (para el modo de acorde fijo).
     * @param {number|number[]} midi
     */
    hold(midi) {
        this.init().then(() => {
            this._engine.triggerAttack(midi);
            eventBus.emit('audio:holding', { midi });
        }).catch(err => {
            console.warn('[AudioEngine] No se pudo mantener audio:', err);
        });
    }

    /**
     * Detiene todas las notas sonando.
     */
    stopAll() {
        this._engine.releaseAll();
        eventBus.emit('audio:stopped');
    }

    /**
     * Ajusta el volumen maestro en dB.
     * @param {number} db
     */
    setVolume(db) {
        this._engine.setVolume(db);
    }

    /**
     * Indica si el audio ya está listo.
     * @returns {boolean}
     */
    isReady() {
        return this._engine.isReady();
    }
}

export const audioEngine = AudioEngine.getInstance();
export default AudioEngine;
