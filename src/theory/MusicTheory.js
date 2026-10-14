/**
 * @fileoverview Cálculos y transformaciones de teoría musical pura (Single Responsibility Principle).
 * Funciones puras e inmutables para manipulación de notas, intervalos y clases de tono.
 * @module theory/MusicTheory
 */

import {
    NOTES_ALEMANA_SHARP,
    NOTES_LATINA_SHARP,
    NOTES_ALEMANA_FLAT,
    NOTES_LATINA_FLAT,
    NOTATION_MODES
} from '../core/Constants.js';
import { tuningRegistry } from '../models/Tunings.js';

/**
 * Calcula la clase de tono normalizada (pitch class modulo 12: 0 a 11).
 * Garantiza resultados positivos ante números negativos.
 * @param {number} midi
 * @returns {number} Valor entre 0 y 11 (0 = Do/C).
 */
export function getPitchClass(midi) {
    return ((midi % 12) + 12) % 12;
}

/**
 * Obtiene el número de octava científica para una nota MIDI (ej: 60 -> 4 para C4).
 * @param {number} midi
 * @returns {number}
 */
export function getOctave(midi) {
    return Math.floor(midi / 12) - 1;
}

/**
 * Convierte un número MIDI en su nombre textual (ej: "Do4", "Mi♭5", "C#3"),
 * respetando el modo de notación (latina o alemana) y la preferencia de alteraciones
 * según la afinación actual.
 *
 * @param {number} midi Número MIDI (ej: 60)
 * @param {string} [notation=NOTATION_MODES.LATINA] 'latina' o 'alemana'
 * @param {boolean} [ignoreOctave=false] Si es true, omite el número de octava (ej: "Do" en lugar de "Do4")
 * @param {number} [tuningOffset=0] Desplazamiento de afinación para decidir bemoles vs sostenidos
 * @returns {string}
 */
export function midiToName(midi, notation = NOTATION_MODES.LATINA, ignoreOctave = false, tuningOffset = 0) {
    const pitchClass = getPitchClass(midi);
    const octave = getOctave(midi);
    const useFlat = tuningRegistry.usesFlats(tuningOffset);

    let noteArray;
    if (notation === NOTATION_MODES.LATINA) {
        noteArray = useFlat ? NOTES_LATINA_FLAT : NOTES_LATINA_SHARP;
    } else {
        noteArray = useFlat ? NOTES_ALEMANA_FLAT : NOTES_ALEMANA_SHARP;
    }

    const name = noteArray[pitchClass];
    return ignoreOctave ? name : `${name}${octave}`;
}

/**
 * Obtiene la lista de nombres de notas para una notación y afinación dadas.
 * @param {string} [notation=NOTATION_MODES.LATINA]
 * @param {number} [tuningOffset=0]
 * @returns {string[]}
 */
export function getNoteNamesList(notation = NOTATION_MODES.LATINA, tuningOffset = 0) {
    const useFlat = tuningRegistry.usesFlats(tuningOffset);
    if (notation === NOTATION_MODES.LATINA) {
        return useFlat ? [...NOTES_LATINA_FLAT] : [...NOTES_LATINA_SHARP];
    }
    return useFlat ? [...NOTES_ALEMANA_FLAT] : [...NOTES_ALEMANA_SHARP];
}

/**
 * Calcula el intervalo ascendente normalizado en semitonos entre dos pitch classes (0 a 11).
 * @param {number} fromPitchClass
 * @param {number} toPitchClass
 * @returns {number}
 */
export function getIntervalBetween(fromPitchClass, toPitchClass) {
    return (toPitchClass - fromPitchClass + 12) % 12;
}

/**
 * Genera un conjunto de pitch classes a partir de una tónica y una lista de intervalos.
 * @param {number} rootPitchClass
 * @param {number[]} intervals
 * @returns {number[]}
 */
export function getPitchClassesFromIntervals(rootPitchClass, intervals) {
    return intervals.map(i => (rootPitchClass + i) % 12);
}
