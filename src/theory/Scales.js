/**
 * @fileoverview Generación y análisis de escalas y grados diatónicos para acordeón.
 * @module theory/Scales
 */

import { DIATONIC_DEGREES } from '../core/Constants.js';
import { getPitchClass } from './MusicTheory.js';

/** Intervalos estándar de la escala mayor diatónica (8 notas, de tónica a octava) */
export const MAJOR_SCALE_INTERVALS = Object.freeze([0, 2, 4, 5, 7, 9, 11, 12]);

/**
 * @typedef {Object} ScaleStepInfo
 * @property {number} stepIndex Índice de grado (0 = I, 7 = VIII)
 * @property {number} midi Nota MIDI absoluta
 * @property {number} pitchClass Clase de tono (0 a 11)
 * @property {string} degreeNumeral Número romano ('I', 'II', etc.)
 * @property {string} degreeName Nombre del grado ('Tónica', 'Dominante', etc.)
 * @property {string} quality Calidad del acorde del grado ('M', 'm', '7', 'dim')
 * @property {number[]} chordIntervals Intervalos del acorde del grado relativo a este grado
 * @property {number[]} chordPitchClasses Pitch classes de las notas del acorde de este grado
 * @property {number[]} chordAbsoluteMidis Notas MIDI absolutas del acorde de este grado
 * @property {boolean} isMainTriad Si pertenece a los grados pilares I, III, V u VIII
 */

/**
 * Genera la estructura completa de notas y acordes para los 8 grados de la escala mayor.
 * @param {number} rootMidi Tónica base de la escala en formato MIDI (ej: 63 para Mi bemol en Hilera 2)
 * @returns {ScaleStepInfo[]}
 */
export function generateMajorScale(rootMidi) {
    return MAJOR_SCALE_INTERVALS.map((interval, stepIndex) => {
        const midi = rootMidi + interval;
        const pitchClass = getPitchClass(midi);
        const degreeData = DIATONIC_DEGREES[stepIndex];

        const chordAbsoluteMidis = degreeData.intervals.map(i => midi + i);
        const chordPitchClasses = chordAbsoluteMidis.map(m => getPitchClass(m));

        return Object.freeze({
            stepIndex,
            midi,
            pitchClass,
            degreeNumeral: degreeData.num,
            degreeName: degreeData.name,
            quality: degreeData.quality,
            chordIntervals: [...degreeData.intervals],
            chordPitchClasses,
            chordAbsoluteMidis,
            isMainTriad: [0, 2, 4, 7].includes(stepIndex)
        });
    });
}
