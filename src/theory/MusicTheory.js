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

/**
 * Analiza e interpreta una cadena de texto con notación de acorde (ej: "CM7", "Esus4", "Bbm", "F#7", "Solm", "Ddim").
 * Soporta cifrado anglosajón y notación latina con sostenidos (#, ♯) y bemoles (b, ♭).
 *
 * @param {string} notation Cadena con la notación del acorde
 * @returns {Object|null} Objeto con { root, chordType, chordSymbol, chordName, intervals, noteMods, playbackMidis } o null si no es válido
 */
export function parseChordNotation(notation) {
    if (!notation || typeof notation !== 'string') return null;
    let s = notation.trim();
    if (!s) return null;

    const LATIN_ROOTS = [
        { name: 'sol', pc: 7 },
        { name: 'la', pc: 9 },
        { name: 'si', pc: 11 },
        { name: 'do', pc: 0 },
        { name: 're', pc: 2 },
        { name: 'mi', pc: 4 },
        { name: 'fa', pc: 5 }
    ];
    const ANGLO_ROOTS = [
        { name: 'c', pc: 0 },
        { name: 'd', pc: 2 },
        { name: 'e', pc: 4 },
        { name: 'f', pc: 5 },
        { name: 'g', pc: 7 },
        { name: 'a', pc: 9 },
        { name: 'b', pc: 11 }
    ];

    let root = null;
    let remainder = '';
    const lower = s.toLowerCase();

    // 1. Probar notas latinas primero
    for (const item of LATIN_ROOTS) {
        if (lower.startsWith(item.name)) {
            root = item.pc;
            remainder = s.slice(item.name.length).trim();
            break;
        }
    }

    // 2. Si no es latina, probar notas anglosajonas
    if (root === null) {
        for (const item of ANGLO_ROOTS) {
            if (lower.startsWith(item.name)) {
                root = item.pc;
                remainder = s.slice(item.name.length).trim();
                break;
            }
        }
    }

    if (root === null) return null;

    let isSharp = /^[#♯]|(sostenido|sharp)/i.test(remainder);
    let isFlat = /^[♭b]|(bemol|flat)/i.test(remainder);

    // 3. Revisar alteración sobre la nota fundamental (# / b)
    if (/^[#♯]/.test(remainder)) {
        root = (root + 1) % 12;
        remainder = remainder.slice(1).trim();
    } else if (/^(sostenido|sharp)/i.test(remainder)) {
        root = (root + 1) % 12;
        remainder = remainder.replace(/^(sostenido|sharp)/i, '').trim();
    } else if (/^[♭]/.test(remainder)) {
        root = (root + 11) % 12;
        remainder = remainder.slice(1).trim();
    } else if (/^(bemol|flat)/i.test(remainder)) {
        root = (root + 11) % 12;
        remainder = remainder.replace(/^(bemol|flat)/i, '').trim();
    } else if (/^b/i.test(remainder)) {
        const remLower = remainder.toLowerCase();
        // Si es 'b' sola, o 'b' seguida de sufijo como 'm', 'maj', 'sus', 'dim', '7'
        if (remLower.length === 1 || !/^[0-9]/.test(remLower.slice(1))) {
            root = (root + 11) % 12;
            remainder = remainder.slice(1).trim();
        } else if (/^b[0-9]/.test(remLower) && ['b', 'e', 'a', 'd', 'g', 'c'].includes(lower[0])) {
            root = (root + 11) % 12;
            remainder = remainder.slice(1).trim();
        }
    }

    // 4. Analizar la cualidad/estructura en el remanente
    let qual = remainder.toLowerCase().replace(/[\s\-_()]/g, '');

    let chordType = 'major';
    let intervals = [0, 4, 7];
    let symbolSuffix = '';
    let nameSuffix = 'Mayor';

    if (/^(m7b5|ø|semidisminuido)$/.test(qual)) {
        chordType = 'm7b5';
        intervals = [0, 3, 6, 10];
        symbolSuffix = 'm7(♭5)';
        nameSuffix = 'm7(♭5)';
    } else if (/^(maj7|major7|7m|delta7|δ7|Δ7|delta|δ|Δ|mayor7|mayor7ma)$/.test(qual) || remainder === 'M7' || remainder === 'Maj7' || remainder.startsWith('M7')) {
        chordType = 'maj7';
        intervals = [0, 4, 7, 11];
        symbolSuffix = 'Maj7';
        nameSuffix = 'Mayor 7ma';
    } else if (/^(min7|m7|-7|menor7|menor7ma)$/.test(qual) || remainder === 'm7' || remainder.startsWith('m7')) {
        chordType = 'm7';
        intervals = [0, 3, 7, 10];
        symbolSuffix = 'm7';
        nameSuffix = 'Menor 7ma';
    } else if (/^(7sus4|7sus)$/.test(qual)) {
        chordType = '7sus4';
        intervals = [0, 5, 7, 10];
        symbolSuffix = '7sus4';
        nameSuffix = '7ma Sus4';
    } else if (/^(7|dom7|dominante7|7ma)$/.test(qual)) {
        chordType = '7';
        intervals = [0, 4, 7, 10];
        symbolSuffix = '7';
        nameSuffix = '7ma';
    } else if (/^(sus4|4|sus)$/.test(qual)) {
        chordType = 'sus4';
        intervals = [0, 5, 7];
        symbolSuffix = 'sus4';
        nameSuffix = 'Sus4';
    } else if (/^(sus2|2)$/.test(qual)) {
        chordType = 'sus2';
        intervals = [0, 2, 7];
        symbolSuffix = 'sus2';
        nameSuffix = 'Sus2';
    } else if (/^(dim7|dism7|°7|o7)$/.test(qual)) {
        chordType = 'dim7';
        intervals = [0, 3, 6, 9];
        symbolSuffix = 'dim7';
        nameSuffix = 'Disminuido 7';
    } else if (/^(dim|dism|°|o)$/.test(qual)) {
        chordType = 'dim';
        intervals = [0, 3, 6];
        symbolSuffix = 'dim';
        nameSuffix = 'Disminuido';
    } else if (/^(aug7|\+7|aum7)$/.test(qual)) {
        chordType = 'aug7';
        intervals = [0, 4, 8, 10];
        symbolSuffix = '7(♯5)';
        nameSuffix = '7ma Aumentada';
    } else if (/^(aug|\+|aum)$/.test(qual)) {
        chordType = 'aug';
        intervals = [0, 4, 8];
        symbolSuffix = 'aug';
        nameSuffix = 'Aumentado';
    } else if (/^(add9|9add|\+9)$/.test(qual)) {
        chordType = 'add9';
        intervals = [0, 2, 4, 7];
        symbolSuffix = 'add9';
        nameSuffix = 'Add9';
    } else if (/^(maj9|mayor9)$/.test(qual) || remainder === 'M9' || remainder.startsWith('M9')) {
        chordType = 'maj9';
        intervals = [0, 2, 4, 7, 11];
        symbolSuffix = 'Maj9';
        nameSuffix = 'Mayor 9na';
    } else if (/^(min9|m9|menor9)$/.test(qual) || remainder === 'm9' || remainder.startsWith('m9')) {
        chordType = 'min9';
        intervals = [0, 2, 3, 7, 10];
        symbolSuffix = 'm9';
        nameSuffix = 'Menor 9na';
    } else if (/^(9|dom9|9na)$/.test(qual)) {
        chordType = '9';
        intervals = [0, 2, 4, 7, 10];
        symbolSuffix = '9';
        nameSuffix = '9na Dominante';
    } else if (/^(6|maj6|mayor6|6ta)$/.test(qual)) {
        chordType = 'maj6';
        intervals = [0, 4, 7, 9];
        symbolSuffix = '6';
        nameSuffix = '6ta Mayor';
    } else if (/^(m6|min6|menor6)$/.test(qual)) {
        chordType = 'min6';
        intervals = [0, 3, 7, 9];
        symbolSuffix = 'm6';
        nameSuffix = 'Menor 6ta';
    } else if (/^(5|power)$/.test(qual)) {
        chordType = '5';
        intervals = [0, 7];
        symbolSuffix = '5';
        nameSuffix = '5ta (Power Chord)';
    } else if (/^(m|min|minor|-|menor)$/.test(qual) || remainder === 'm' || remainder.startsWith('m')) {
        chordType = 'minor';
        intervals = [0, 3, 7];
        symbolSuffix = 'm';
        nameSuffix = 'Menor';
    } else if (!qual || /^(maj|major|mayor)$/.test(qual) || remainder === 'M') {
        chordType = 'major';
        intervals = [0, 4, 7];
        symbolSuffix = '';
        nameSuffix = 'Mayor';
    } else {
        return null;
    }

    const latNames = isFlat ? NOTES_LATINA_FLAT : NOTES_LATINA_SHARP;
    const engNames = isFlat ? NOTES_ALEMANA_FLAT : NOTES_ALEMANA_SHARP;
    const rootLat = latNames[root];
    const rootEng = engNames[root];

    const chordSymbol = `${rootEng}${symbolSuffix}`;
    const chordName = `${rootLat} ${nameSuffix}`.trim();
    const noteMods = intervals.map(i => (root + i) % 12);

    return {
        root,
        chordType,
        chordSymbol,
        chordName,
        intervals,
        noteMods,
        playbackMidis: intervals.map(i => 60 + root + i)
    };
}
