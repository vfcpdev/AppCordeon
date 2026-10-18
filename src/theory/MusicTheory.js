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

    let slashBass = null;
    let bassPc = null;
    if (s.includes('/')) {
        const parts = s.split('/');
        s = parts[0].trim();
        const rawBass = parts.slice(1).join('/').trim();
        if (rawBass) {
            slashBass = rawBass;
            // Parsear nota de bajo (Latina o Alemana)
            const bassLower = rawBass.toLowerCase();
            const BASS_MAP = {
                'do': 0, 'c': 0,
                're': 2, 'd': 2,
                'mi': 4, 'e': 4,
                'fa': 5, 'f': 5,
                'sol': 7, 'g': 7,
                'la': 9, 'a': 9,
                'si': 11, 'b': 11
            };
            for (const [k, v] of Object.entries(BASS_MAP)) {
                if (bassLower.startsWith(k)) {
                    let pc = v;
                    const rem = bassLower.slice(k.length);
                    if (rem.includes('#') || rem.includes('♯')) pc = (pc + 1) % 12;
                    else if (rem.includes('b') || rem.includes('♭')) pc = (pc + 11) % 12;
                    bassPc = pc;
                    break;
                }
            }
        }
    }

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
    const rawRemainder = remainder.trim();

    let chordType = 'major';
    let intervals = [0, 4, 7];
    let symbolSuffix = '';
    let nameSuffix = 'Mayor';

    if (/^(m7b5|ø|semidisminuido)$/.test(qual)) {
        chordType = 'm7b5';
        intervals = [0, 3, 6, 10];
        symbolSuffix = 'm7(♭5)';
        nameSuffix = 'm7(♭5)';
    } else if (/^(maj7|major7|7m|delta7|δ7|Δ7|delta|δ|Δ|mayor7|mayor7ma)$/.test(qual) || rawRemainder === 'M7' || rawRemainder === 'Maj7' || rawRemainder.startsWith('M7')) {
        chordType = 'maj7';
        intervals = [0, 4, 7, 11];
        symbolSuffix = 'Maj7';
        nameSuffix = 'Mayor 7ma';
    } else if (/^(min7|m7|-7|menor7|menor7ma)$/.test(qual) || rawRemainder === 'm7' || rawRemainder.startsWith('m7')) {
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
    } else if (/^(maj9|mayor9)$/.test(qual) || rawRemainder === 'M9' || rawRemainder.startsWith('M9')) {
        chordType = 'maj9';
        intervals = [0, 2, 4, 7, 11];
        symbolSuffix = 'Maj9';
        nameSuffix = 'Mayor 9na';
    } else if (/^(min9|m9|menor9)$/.test(qual) || rawRemainder === 'm9' || rawRemainder.startsWith('m9')) {
        chordType = 'min9';
        intervals = [0, 2, 3, 7, 10];
        symbolSuffix = 'm9';
        nameSuffix = 'Menor 9na';
    } else if (/^(9|dom9|9na)$/.test(qual)) {
        chordType = '9';
        intervals = [0, 2, 4, 7, 10];
        symbolSuffix = '9';
        nameSuffix = '9na Dominante';
    } else if (/^(6|maj6|mayor6|6ta)$/.test(qual) || rawRemainder === 'M6' || rawRemainder.startsWith('M6')) {
        chordType = 'maj6';
        intervals = [0, 4, 7, 9];
        symbolSuffix = '6';
        nameSuffix = '6ta Mayor';
    } else if (/^(m6|min6|menor6)$/.test(qual) || rawRemainder === 'm6' || rawRemainder.startsWith('m6')) {
        chordType = 'min6';
        intervals = [0, 3, 7, 9];
        symbolSuffix = 'm6';
        nameSuffix = 'Menor 6ta';
    } else if (/^(5|power)$/.test(qual)) {
        chordType = '5';
        intervals = [0, 7];
        symbolSuffix = '5';
        nameSuffix = '5ta (Power Chord)';
    } else if (rawRemainder === 'M' || /^(maj|major|mayor)$/i.test(rawRemainder)) {
        // Explícitamente 'M' mayúscula para Mayor
        chordType = 'major';
        intervals = [0, 4, 7];
        symbolSuffix = (rawRemainder === 'M') ? 'M' : '';
        nameSuffix = 'Mayor';
    } else if (rawRemainder === 'm' || /^(min|minor|-|menor)$/i.test(rawRemainder)) {
        // Explícitamente 'm' minúscula para Menor
        chordType = 'minor';
        intervals = [0, 3, 7];
        symbolSuffix = 'm';
        nameSuffix = 'Menor';
    } else if (!qual) {
        // Sin cualidad (ej. "C", "Sol", "Eb") -> Mayor por defecto
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

    let chordSymbol = `${rootEng}${symbolSuffix}`;
    let chordName = `${rootLat} ${nameSuffix}`.trim();
    if (slashBass) {
        chordSymbol += `/${slashBass}`;
        chordName += `/${slashBass}`;
    }
    const noteMods = intervals.map(i => (root + i) % 12);
    let playbackMidis = intervals.map(i => 60 + root + i);
    if (bassPc !== null) {
        const bassMidi = 48 + bassPc;
        if (!playbackMidis.includes(bassMidi)) {
            playbackMidis = [bassMidi, ...playbackMidis];
        }
    }

    return {
        root,
        chordType,
        chordSymbol,
        chordName,
        intervals,
        noteMods,
        playbackMidis,
        bass: bassPc
    };
}

/**
 * Formatea un token individual de acorde asegurando que las notas de la notación
 * alemana (A, B, C, D, E, F, G) queden siempre en mayúscula, respetando 'M' para mayor
 * y 'm' para menor, y bemoles como 'b' minúscula.
 *
 * @param {string} token
 * @returns {string}
 */
export function autoFormatChordToken(token) {
    if (!token || typeof token !== 'string') return token;

    if (token.includes('/')) {
        const parts = token.split('/');
        return parts.map(p => autoFormatChordToken(p)).join('/');
    }

    const t = token.trim();
    if (!t) return token;

    // 1. Raíces latinas (Sol, La, Si, Do, Re, Mi, Fa)
    const latinRoots = [
        { re: /^sol/i, name: 'Sol' },
        { re: /^la/i, name: 'La' },
        { re: /^si/i, name: 'Si' },
        { re: /^do/i, name: 'Do' },
        { re: /^re/i, name: 'Re' },
        { re: /^mi/i, name: 'Mi' },
        { re: /^fa/i, name: 'Fa' }
    ];

    for (const lat of latinRoots) {
        if (lat.re.test(t)) {
            const rem = t.slice(lat.name.length);
            return lat.name + formatChordRemainder(rem);
        }
    }

    // 2. Raíces anglosajonas / alemanas (A, B, C, D, E, F, G)
    const angloMatch = t.match(/^([a-gA-G])(.*)$/);
    if (angloMatch) {
        const root = angloMatch[1].toUpperCase();
        const rem = angloMatch[2];
        return root + formatChordRemainder(rem);
    }

    return token;
}

/**
 * Formatea el remanente de alteración y cualidad de un acorde.
 * @private
 * @param {string} rem
 * @returns {string}
 */
function formatChordRemainder(rem) {
    if (!rem) return '';
    let res = '';
    let idx = 0;

    // Alteración (#, ♯, b, ♭)
    if (rem[idx] === '#' || rem[idx] === '♯') {
        res += rem[idx];
        idx++;
    } else if (rem[idx] === '♭') {
        res += rem[idx];
        idx++;
    } else if (rem[idx] === 'b' || rem[idx] === 'B') {
        // En alteración de bemol siempre es 'b' minúscula
        res += 'b';
        idx++;
    }

    const rest = rem.slice(idx);
    if (!rest) return res;

    // Si es exactamente 'm' o 'M'
    if (rest === 'm' || rest === 'M') {
        return res + rest;
    }

    // Si empieza por 'M' mayúscula (ej. M7, Maj, Maj7, M9, M6)
    if (rest.startsWith('M') && !/^min/i.test(rest)) {
        return res + rest;
    }

    // Si empieza por 'm' minúscula (ej. m7, min, min7, m6, m7b5)
    if (rest.startsWith('m') && !/^maj/i.test(rest)) {
        return res + rest;
    }

    // Si es solo números (ej. 7, 9, 6)
    if (/^[0-9]/.test(rest)) {
        return res + rest;
    }

    return res + rest;
}

/**
 * Ajusta y formatea automáticamente una cadena de texto completa que contenga acordes
 * separados por comas, espacios o barras (ej: "c, cm, cM" -> "C, Cm, CM").
 * Mantiene intactos delimitadores, espacios y cursores de edición.
 *
 * @param {string} text
 * @returns {string}
 */
export function formatChordInputString(text) {
    if (!text || typeof text !== 'string') return text;
    return text.replace(/([^\s,;|]+)/g, (match) => {
        return autoFormatChordToken(match);
    });
}
