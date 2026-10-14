/**
 * @fileoverview Implementación concreta de IAudioEngine utilizando Tone.js PolySynth
 * con timbre triangular y envolvente ADSR acústica de lengüeta de acordeón.
 * @module audio/WebAudioSynth
 */

import { IAudioEngine } from './IAudioEngine.js';

export class WebAudioSynth extends IAudioEngine {
    constructor() {
        super();
        this._synth = null;
        this._isInitialized = false;
        this._volumeDb = -4;
    }

    /**
     * Inicializa Tone.js y configura el PolySynth.
     * Envuelta con try/catch para gestión limpia de excepciones en navegadores modernos.
     * @returns {Promise<void>}
     */
    async init() {
        if (this._isInitialized) return;

        try {
            if (typeof Tone === 'undefined') {
                console.warn('[WebAudioSynth] Tone.js no detectado globalmente. Se intentará diferir la inicialización.');
                return;
            }

            await Tone.start();

            // Síntesis polifónica con envolvente adecuada para lengüeta de fuelle
            this._synth = new Tone.PolySynth(Tone.Synth, {
                oscillator: {
                    type: "triangle"
                },
                envelope: {
                    attack: 0.035,
                    decay: 0.18,
                    sustain: 0.50,
                    release: 0.65
                }
            }).toDestination();

            this._synth.volume.value = this._volumeDb;
            this._isInitialized = true;
        } catch (error) {
            console.error('[WebAudioSynth] Error inicializando el contexto de audio:', error);
            throw error;
        }
    }

    /**
     * @param {number|number[]} midi Nota o notas MIDI.
     * @param {string} [duration="8n"]
     */
    triggerAttackRelease(midi, duration = "8n") {
        if (!this._isInitialized || !this._synth) {
            this.init().then(() => this.triggerAttackRelease(midi, duration)).catch(() => {});
            return;
        }

        try {
            if (Array.isArray(midi)) {
                const freqs = midi.map(m => Tone.Frequency(m, "midi").toNote());
                this._synth.triggerAttackRelease(freqs, duration);
            } else {
                const freq = Tone.Frequency(midi, "midi").toNote();
                this._synth.triggerAttackRelease(freq, duration);
            }
        } catch (err) {
            console.error('[WebAudioSynth] Error en triggerAttackRelease:', err);
        }
    }

    /**
     * @param {number|number[]} midi
     */
    triggerAttack(midi) {
        if (!this._isInitialized || !this._synth) return;

        try {
            this.releaseAll();
            if (Array.isArray(midi)) {
                const freqs = midi.map(m => Tone.Frequency(m, "midi").toNote());
                this._synth.triggerAttack(freqs);
            } else {
                const freq = Tone.Frequency(midi, "midi").toNote();
                this._synth.triggerAttack(freq);
            }
        } catch (err) {
            console.error('[WebAudioSynth] Error en triggerAttack:', err);
        }
    }

    /**
     * Libera todas las notas que están sonando.
     */
    releaseAll() {
        if (this._synth && typeof this._synth.releaseAll === 'function') {
            try {
                this._synth.releaseAll();
            } catch (err) {
                console.error('[WebAudioSynth] Error en releaseAll:', err);
            }
        }
    }

    /**
     * Ajusta el volumen del sintetizador.
     * @param {number} db Decibelios (-40 a 0)
     */
    setVolume(db) {
        this._volumeDb = db;
        if (this._synth && this._synth.volume) {
            this._synth.volume.value = db;
        }
    }

    /**
     * @returns {boolean}
     */
    isReady() {
        return this._isInitialized;
    }
}
