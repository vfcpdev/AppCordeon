/**
 * @fileoverview Generación y análisis de escalas diatónicas, grados y familia de tonos relacionados (SRP).
 * Soporta escala Mayor, Menor Natural y Menor Armónica, y calcula todos los tonos relacionados
 * (Tónica, Relativa Menor, Dominante, Subdominante, Disminuido, Aumentado, Paralelo).
 * @module theory/Scales
 */

import { DIATONIC_DEGREES, NOTATION_MODES } from '../core/Constants.js';
import { getPitchClass, getNoteNamesList, midiToName } from './MusicTheory.js';

/** Intervalos estándar de los diferentes tipos de escala */
export const SCALE_DEFINITIONS = Object.freeze({
    major: {
        id: 'major',
        name: 'Mayor',
        intervals: [0, 2, 4, 5, 7, 9, 11, 12],
        degrees: [
            { num: "I",    name: "Tónica",         quality: "M",   intervals: [0, 4, 7] },
            { num: "II",   name: "Supertónica",    quality: "m",   intervals: [0, 3, 7] },
            { num: "III",  name: "Mediante",       quality: "m",   intervals: [0, 3, 7] },
            { num: "IV",   name: "Subdominante",   quality: "M",   intervals: [0, 4, 7] },
            { num: "V",    name: "Dominante",      quality: "7",   intervals: [0, 4, 7, 10] },
            { num: "VI",   name: "Relativa Menor", quality: "m",   intervals: [0, 3, 7] },
            { num: "VII",  name: "Sensible",       quality: "dim", intervals: [0, 3, 6] },
            { num: "VIII", name: "Octava",         quality: "M",   intervals: [0, 4, 7] }
        ]
    },
    minor: {
        id: 'minor',
        name: 'Menor Natural',
        intervals: [0, 2, 3, 5, 7, 8, 10, 12],
        degrees: [
            { num: "i",    name: "Tónica Menor",   quality: "m",   intervals: [0, 3, 7] },
            { num: "ii°",  name: "Disminuida",     quality: "dim", intervals: [0, 3, 6] },
            { num: "III",  name: "Relativa Mayor", quality: "M",   intervals: [0, 4, 7] },
            { num: "iv",   name: "Subdominante",   quality: "m",   intervals: [0, 3, 7] },
            { num: "v",    name: "Dominante Menor",quality: "m",   intervals: [0, 3, 7] },
            { num: "VI",   name: "Submediante",    quality: "M",   intervals: [0, 4, 7] },
            { num: "VII",  name: "Subtónica",      quality: "M",   intervals: [0, 4, 7] },
            { num: "viii", name: "Octava Menor",   quality: "m",   intervals: [0, 3, 7] }
        ]
    },
    harmonic_minor: {
        id: 'harmonic_minor',
        name: 'Menor Armónica',
        intervals: [0, 2, 3, 5, 7, 8, 11, 12],
        degrees: [
            { num: "i",    name: "Tónica Menor",   quality: "m",   intervals: [0, 3, 7] },
            { num: "ii°",  name: "Disminuida",     quality: "dim", intervals: [0, 3, 6] },
            { num: "III+", name: "Aumentada",      quality: "aug", intervals: [0, 4, 8] },
            { num: "iv",   name: "Subdominante",   quality: "m",   intervals: [0, 3, 7] },
            { num: "V",    name: "Dominante Mayor",quality: "7",   intervals: [0, 4, 7, 10] },
            { num: "VI",   name: "Submediante",    quality: "M",   intervals: [0, 4, 7] },
            { num: "vii°", name: "Sensible Dism.", quality: "dim", intervals: [0, 3, 6] },
            { num: "viii", name: "Octava Menor",   quality: "m",   intervals: [0, 3, 7] }
        ]
    }
});

/**
 * @typedef {Object} ScaleStepInfo
 * @property {number} stepIndex Índice de grado (0 a 7)
 * @property {number} midi Nota MIDI absoluta
 * @property {number} pitchClass Clase de tono (0 a 11)
 * @property {string} degreeNumeral Número romano ('I', 'IV', 'V', etc.)
 * @property {string} degreeName Nombre del grado
 * @property {string} quality Calidad ('M', 'm', '7', 'dim', 'aug')
 * @property {number[]} chordIntervals
 * @property {number[]} chordPitchClasses
 * @property {number[]} chordAbsoluteMidis
 * @property {boolean} isMainTriad
 */

/**
 * Genera la estructura completa de notas y acordes para los 8 grados de una escala.
 * @param {number} rootMidi Tónica base en formato MIDI (ej: 60 = Do, 67 = Sol)
 * @param {string} [scaleType='major'] 'major', 'minor', o 'harmonic_minor'
 * @returns {ScaleStepInfo[]}
 */
export function generateScale(rootMidi, scaleType = 'major') {
    const scaleDef = SCALE_DEFINITIONS[scaleType] || SCALE_DEFINITIONS.major;

    return scaleDef.intervals.map((interval, stepIndex) => {
        const midi = rootMidi + interval;
        const pitchClass = getPitchClass(midi);
        const degreeData = scaleDef.degrees[stepIndex];

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

/** Compatibilidad con código anterior */
export const MAJOR_SCALE_INTERVALS = SCALE_DEFINITIONS.major.intervals;
export function generateMajorScale(rootMidi) {
    return generateScale(rootMidi, 'major');
}

/**
 * @typedef {Object} RelatedChordItem
 * @property {string} id ID único
 * @property {string} roleName Función tonal (ej: "Tónica (I)", "Dominante (V7)", "Relativa Menor (vi)")
 * @property {string} chordName Nombre en español (ej: "Sol Mayor", "Mi menor", "Re 7ma")
 * @property {string} chordSymbol Cifrado anglosajón (ej: "G", "Em", "D7", "F#dim")
 * @property {string} category 'tonic' | 'subdominant' | 'dominant' | 'relative' | 'diminished' | 'augmented' | 'parallel'
 * @property {number} rootPitchClass Clase de tono de la tónica del acorde (0 a 11)
 * @property {number[]} intervals Intervalos relativos a su tónica
 * @property {number[]} noteMods Clases de tono que componen el acorde
 * @property {number[]} playbackMidis Notas MIDI de reproducción sugerida (octava 4)
 * @property {string} colorBadge Color temático sugerido
 */

/**
 * Calcula la familia armónica completa de tonos y acordes relacionados a partir de una tónica.
 * (Ejemplo: Para Sol en cualquier acordeón, devuelve Sol Mayor, Mi menor, Do Mayor, Re7, Fa# disminuido, Sol menor, Sol aumentado, etc.)
 *
 * @param {number} rootPitchClass Tónica en pitch class (0 a 11, ej: 7 para Sol)
 * @param {string} [notation=NOTATION_MODES.LATINA]
 * @param {number} [tuningOffset=0]
 * @returns {RelatedChordItem[]}
 */
export function getHarmonicFamilyAndRelatedChords(rootPitchClass, notation = NOTATION_MODES.LATINA, tuningOffset = 0) {
    const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, tuningOffset);
    const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, tuningOffset);

    const r = (rootPitchClass % 12 + 12) % 12;

    // Helper para construir un acorde relacionado
    const buildChord = (id, roleName, category, rootMod, intervals, suffixLat, suffixAle, colorBadge) => {
        const rootNoteLat = arrLat[rootMod];
        const rootNoteAle = arrAle[rootMod];
        const noteMods = intervals.map(i => (rootMod + i) % 12);
        const baseMidi = 60 + rootMod; // Octava 4/Media
        const playbackMidis = intervals.map(i => baseMidi + i);

        return {
            id,
            roleName,
            category,
            rootPitchClass: rootMod,
            chordName: `${rootNoteLat} ${suffixLat}`.trim(),
            chordSymbol: `${rootNoteAle}${suffixAle}`.trim(),
            intervals,
            noteMods,
            playbackMidis,
            colorBadge
        };
    };

    return [
        // 1. Tónica Principal (I Mayor)
        buildChord(
            'tonic_major',
            'Tónica (I)',
            'tonic',
            r,
            [0, 4, 7],
            'Mayor',
            '',
            '#10b981' // Esmeralda
        ),

        // 2. Dominante (V7 - Quinto Grado)
        buildChord(
            'dominant_7',
            'Dominante (V7)',
            'dominant',
            (r + 7) % 12,
            [0, 4, 7, 10],
            '7ma Dominante',
            '7',
            '#ef4444' // Rojo
        ),

        // 3. Subdominante (IV - Cuarto Grado)
        buildChord(
            'subdominant_major',
            'Subdominante (IV)',
            'subdominant',
            (r + 5) % 12,
            [0, 4, 7],
            'Mayor',
            '',
            '#3b82f6' // Azul
        ),

        // 4. Relativa Menor (vi - Sexto Grado)
        buildChord(
            'relative_minor',
            'Relativa Menor (vi)',
            'relative',
            (r + 9) % 12,
            [0, 3, 7],
            'Menor',
            'm',
            '#a855f7' // Púrpura
        ),

        // 5. Supertónica (ii - Segundo Grado)
        buildChord(
            'supertonic_minor',
            'Supertónica (ii)',
            'secondary',
            (r + 2) % 12,
            [0, 3, 7],
            'Menor',
            'm',
            '#6366f1' // Índigo
        ),

        // 6. Mediante (iii - Tercer Grado)
        buildChord(
            'mediant_minor',
            'Mediante (iii)',
            'secondary',
            (r + 4) % 12,
            [0, 3, 7],
            'Menor',
            'm',
            '#06b6d4' // Cian
        ),

        // 7. Sensible Disminuida (vii° - Séptimo Grado)
        buildChord(
            'leading_diminished',
            'Sensible (vii°)',
            'diminished',
            (r + 11) % 12,
            [0, 3, 6],
            'Disminuido',
            'dim',
            '#f59e0b' // Ámbar
        ),

        // 8. Tono Paralelo Menor (i)
        buildChord(
            'parallel_minor',
            'Paralelo Menor (i)',
            'parallel',
            r,
            [0, 3, 7],
            'Menor',
            'm',
            '#ec4899' // Rosa
        ),

        // 9. Acorde Aumentado (I+)
        buildChord(
            'tonic_augmented',
            'Tono Aumentado (I+)',
            'augmented',
            r,
            [0, 4, 8],
            'Aumentado',
            'aug',
            '#f97316' // Naranja
        ),

        // 10. Acorde Suspendido 4 (Isus4)
        buildChord(
            'tonic_sus4',
            'Suspendido (Sus4)',
            'secondary',
            r,
            [0, 5, 7],
            'Sus4',
            'sus4',
            '#14b8a6' // Verde azulado
        )
    ];
}
