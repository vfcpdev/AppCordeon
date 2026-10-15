/**
 * @fileoverview Interfaz abstracta para sintetizadores de audio (Liskov Substitution Principle).
 * Permite intercambiar el motor de síntesis (Tone.js PolySynth, Web Audio nativo, SoundFonts/Samples)
 * de manera transparente sin alterar el resto de la aplicación.
 * @module audio/IAudioEngine
 */

/**
 * @abstract
 */
export class IAudioEngine {
    /**
     * Inicializa el contexto de audio (tras interacción de usuario).
     * @abstract
     * @returns {Promise<void>}
     */
    async init() {
        throw new Error('El método init() debe ser implementado.');
    }

    /**
     * Toca una nota o acorde por su número MIDI o frecuencia.
     * @abstract
     * @param {number|number[]} midi Nota(s) en formato MIDI (ej: 60 = Do4).
     * @param {string} [duration="8n"] Duración en notación de tiempo.
     * @param {number} [time] Tiempo de disparo.
     */
    triggerAttackRelease(midi, duration = "8n", velocity = 1.0) {
        throw new Error('El método triggerAttackRelease() debe ser implementado.');
    }

    /**
     * Mantiene sonando una nota o acorde indefinidamente hasta releaseAll().
     * @abstract
     * @param {number|number[]} midi
     */
    triggerAttack(midi) {
        throw new Error('El método triggerAttack() debe ser implementado.');
    }

    /**
     * Detiene todas las notas activas inmediatamente.
     * @abstract
     */
    releaseAll() {
        throw new Error('El método releaseAll() debe ser implementado.');
    }

    /**
     * Establece el volumen maestro en decibelios (dB).
     * @abstract
     * @param {number} db
     */
    setVolume(db) {
        throw new Error('El método setVolume() debe ser implementado.');
    }

    /**
     * Verifica si el contexto de audio ya ha sido activado.
     * @abstract
     * @returns {boolean}
     */
    isReady() {
        throw new Error('El método isReady() debe ser implementado.');
    }
}
