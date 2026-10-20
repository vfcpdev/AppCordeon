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
 * Permite conmutar pedagógicamente entre Tríadas puras (I, ii, iii, IV, V, vi, vii°) y Cuatríadas/Séptimas (Imaj7, ii7, V7...).
 * @param {number} rootMidi Tónica base en formato MIDI (ej: 60 = Do, 67 = Sol)
 * @param {string} [scaleType='major'] 'major', 'minor', o 'harmonic_minor'
 * @param {string} [octaveMode='progressive'] 'progressive' o 'same_octave'
 * @param {string} [harmonicMode='triad'] 'triad' (tríadas puras) o 'seventh' (cuatríadas con 7ma)
 * @returns {ScaleStepInfo[]}
 */
export function generateScale(rootMidi, scaleType = 'major', octaveMode = 'progressive', harmonicMode = 'triad') {
    const scaleDef = SCALE_DEFINITIONS[scaleType] || SCALE_DEFINITIONS.major;
    const isSameOctave = octaveMode === 'same_octave';

    return scaleDef.intervals.map((rawInterval, stepIndex) => {
        const interval = isSameOctave ? (rawInterval % 12) : rawInterval;
        const midi = rootMidi + interval;
        const pitchClass = getPitchClass(midi);
        const degreeData = scaleDef.degrees[stepIndex];

        // Definición de intervalos según tríada vs séptima
        let degreeIntervals = [...degreeData.intervals];
        let numeral = degreeData.num;
        let quality = degreeData.quality;

        if (harmonicMode === 'triad') {
            // En modo tríadas puras, el grado V se expresa como tríada mayor [0, 4, 7]
            if (stepIndex === 4 && degreeIntervals.length > 3) {
                degreeIntervals = [0, 4, 7];
                quality = 'M';
            }
        } else if (harmonicMode === 'seventh') {
            // En modo séptimas/cuatríadas, agregar séptima diatónica según el modo
            if (scaleType === 'major') {
                const seventhTable = {
                    0: { intervals: [0, 4, 7, 11], num: "Imaj7", quality: "maj7" },
                    1: { intervals: [0, 3, 7, 10], num: "ii7", quality: "m7" },
                    2: { intervals: [0, 3, 7, 10], num: "iii7", quality: "m7" },
                    3: { intervals: [0, 4, 7, 11], num: "IVmaj7", quality: "maj7" },
                    4: { intervals: [0, 4, 7, 10], num: "V7", quality: "7" },
                    5: { intervals: [0, 3, 7, 10], num: "vi7", quality: "m7" },
                    6: { intervals: [0, 3, 6, 10], num: "viiø7", quality: "m7b5" },
                    7: { intervals: [0, 4, 7, 11], num: "VIIImaj7", quality: "maj7" }
                };
                if (seventhTable[stepIndex]) {
                    degreeIntervals = seventhTable[stepIndex].intervals;
                    numeral = seventhTable[stepIndex].num;
                    quality = seventhTable[stepIndex].quality;
                }
            } else if (scaleType === 'minor') {
                const seventhTable = {
                    0: { intervals: [0, 3, 7, 10], num: "i7", quality: "m7" },
                    1: { intervals: [0, 3, 6, 10], num: "iiø7", quality: "m7b5" },
                    2: { intervals: [0, 4, 7, 11], num: "IIImaj7", quality: "maj7" },
                    3: { intervals: [0, 3, 7, 10], num: "iv7", quality: "m7" },
                    4: { intervals: [0, 3, 7, 10], num: "v7", quality: "m7" },
                    5: { intervals: [0, 4, 7, 11], num: "VImaj7", quality: "maj7" },
                    6: { intervals: [0, 4, 7, 10], num: "VII7", quality: "7" },
                    7: { intervals: [0, 3, 7, 10], num: "viii7", quality: "m7" }
                };
                if (seventhTable[stepIndex]) {
                    degreeIntervals = seventhTable[stepIndex].intervals;
                    numeral = seventhTable[stepIndex].num;
                    quality = seventhTable[stepIndex].quality;
                }
            } else if (scaleType === 'harmonic_minor') {
                const seventhTable = {
                    0: { intervals: [0, 3, 7, 11], num: "i(maj7)", quality: "mmaj7" },
                    1: { intervals: [0, 3, 6, 10], num: "iiø7", quality: "m7b5" },
                    2: { intervals: [0, 4, 8, 11], num: "III+maj7", quality: "augmaj7" },
                    3: { intervals: [0, 3, 7, 10], num: "iv7", quality: "m7" },
                    4: { intervals: [0, 4, 7, 10], num: "V7", quality: "7" },
                    5: { intervals: [0, 4, 7, 11], num: "VImaj7", quality: "maj7" },
                    6: { intervals: [0, 3, 6, 9], num: "vii°7", quality: "dim7" },
                    7: { intervals: [0, 3, 7, 11], num: "viii(maj7)", quality: "mmaj7" }
                };
                if (seventhTable[stepIndex]) {
                    degreeIntervals = seventhTable[stepIndex].intervals;
                    numeral = seventhTable[stepIndex].num;
                    quality = seventhTable[stepIndex].quality;
                }
            }
        }

        const chordAbsoluteMidis = degreeIntervals.map(i => {
            if (isSameOctave) {
                return rootMidi + ((interval + i) % 12);
            }
            return midi + i;
        });
        const chordPitchClasses = chordAbsoluteMidis.map(m => getPitchClass(m));

        return Object.freeze({
            stepIndex,
            midi,
            pitchClass,
            degreeNumeral: numeral,
            degreeName: degreeData.name,
            quality,
            chordIntervals: degreeIntervals,
            chordPitchClasses,
            chordAbsoluteMidis,
            isMainTriad: [0, 2, 4, 7].includes(stepIndex)
        });
    });
}

/** Compatibilidad con código anterior */
export const MAJOR_SCALE_INTERVALS = SCALE_DEFINITIONS.major.intervals;
export function generateMajorScale(rootMidi, octaveMode = 'progressive') {
    return generateScale(rootMidi, 'major', octaveMode);
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

/**
 * Obtiene los botones físicos de un acordeón que ejecutan las notas de un acorde,
 * diferenciando entre los que suenan al abrir (pull) y los que suenan al cerrar (push).
 * @param {Object} accordionData Objeto { row1, row2, row3 }
 * @param {number[]} noteMods Clases de tono del acorde (0-11)
 * @param {string} [notation=NOTATION_MODES.LATINA]
 * @param {number} [tuningOffset=0]
 * @returns {{ pullButtons: Array, pushButtons: Array }}
 */
export function getAccordionButtonsForChord(accordionData, noteMods, notation = NOTATION_MODES.LATINA, tuningOffset = 0) {
    if (!accordionData || !noteMods || noteMods.length === 0) {
        return { pullButtons: [], pushButtons: [] };
    }

    const pullButtons = [];
    const pushButtons = [];

    const rowLabels = {
        row1: 'H1',
        row2: 'H2',
        row3: 'H3'
    };

    ['row1', 'row2', 'row3'].forEach(rowKey => {
        if (!accordionData[rowKey]) return;
        accordionData[rowKey].forEach(btn => {
            const pullMod = getPitchClass(btn.pull);
            const pushMod = getPitchClass(btn.push);

            if (noteMods.includes(pullMod)) {
                pullButtons.push({
                    id: btn.id,
                    rowKey: btn.rowKey,
                    btnIndex: btn.btnIndex,
                    rowLabel: rowLabels[btn.rowKey] || btn.rowKey,
                    label: `${rowLabels[btn.rowKey] || btn.rowKey}·B${btn.btnIndex}`,
                    noteName: midiToName(btn.pull, notation, true, tuningOffset),
                    midi: btn.pull,
                    noteMod: pullMod,
                    direction: 'pull'
                });
            }

            if (noteMods.includes(pushMod)) {
                pushButtons.push({
                    id: btn.id,
                    rowKey: btn.rowKey,
                    btnIndex: btn.btnIndex,
                    rowLabel: rowLabels[btn.rowKey] || btn.rowKey,
                    label: `${rowLabels[btn.rowKey] || btn.rowKey}·B${btn.btnIndex}`,
                    noteName: midiToName(btn.push, notation, true, tuningOffset),
                    midi: btn.push,
                    noteMod: pushMod,
                    direction: 'push'
                });
            }
        });
    });

    return { pullButtons, pushButtons };
}

/**
 * Genera la cadencia diatónica principal de Cuarta y Quinta (I - IV - V) para una tónica dada.
 * @param {number} rootPitchClass Clase de tono base (0 a 11)
 * @param {string} [scaleType='major'] 'major', 'minor', o 'harmonic_minor'
 * @param {string} [notation=NOTATION_MODES.LATINA]
 * @param {number} [tuningOffset=0]
 * @returns {Array}
 */
export function getCadenceChords(rootPitchClass, scaleType = 'major', notation = NOTATION_MODES.LATINA, tuningOffset = 0) {
    const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, tuningOffset);
    const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, tuningOffset);
    const isMinor = scaleType === 'minor' || scaleType === 'harmonic_minor';

    const r = getPitchClass(rootPitchClass);

    // 1. Tónica (I)
    const tonicIntervals = isMinor ? [0, 3, 7] : [0, 4, 7];
    const tonicSuffixLat = isMinor ? 'Menor' : 'Mayor';
    const tonicSuffixAle = isMinor ? 'm' : '';
    const tonicNoteMods = tonicIntervals.map(i => (r + i) % 12);
    const tonicMidis = tonicIntervals.map(i => 60 + r + i);

    // 2. Cuarta (IV / Subdominante)
    const ivRoot = (r + 5) % 12;
    const ivIntervals = isMinor ? [0, 3, 7] : [0, 4, 7];
    const ivSuffixLat = isMinor ? 'Menor' : 'Mayor';
    const ivSuffixAle = isMinor ? 'm' : '';
    const ivNoteMods = ivIntervals.map(i => (ivRoot + i) % 12);
    const ivMidis = ivIntervals.map(i => 60 + ivRoot + i);

    // 3. Quinta (V / Dominante)
    const vRoot = (r + 7) % 12;
    const vIntervals = [0, 4, 7, 10]; // Dominante 7ma
    const vSuffixLat = '7ma Dominante';
    const vSuffixAle = '7';
    const vNoteMods = vIntervals.map(i => (vRoot + i) % 12);
    const vMidis = vIntervals.map(i => 60 + vRoot + i);

    const formatNoteNames = (mods) => mods.map(m => (notation === NOTATION_MODES.LATINA ? arrLat[m] : arrAle[m]));

    return [
        {
            id: 'cadence_tonic',
            numeral: isMinor ? 'i' : 'I',
            roleName: 'Tónica (Primera)',
            rootPitchClass: r,
            chordName: `${arrLat[r]} ${tonicSuffixLat}`.trim(),
            chordSymbol: `${arrAle[r]}${tonicSuffixAle}`.trim(),
            intervals: tonicIntervals,
            noteMods: tonicNoteMods,
            noteNames: formatNoteNames(tonicNoteMods),
            playbackMidis: tonicMidis,
            colorBadge: '#10b981' // Verde esmeralda
        },
        {
            id: 'cadence_fourth',
            numeral: isMinor ? 'iv' : 'IV',
            roleName: 'Cuarta (Subdominante)',
            rootPitchClass: ivRoot,
            chordName: `${arrLat[ivRoot]} ${ivSuffixLat}`.trim(),
            chordSymbol: `${arrAle[ivRoot]}${ivSuffixAle}`.trim(),
            intervals: ivIntervals,
            noteMods: ivNoteMods,
            noteNames: formatNoteNames(ivNoteMods),
            playbackMidis: ivMidis,
            colorBadge: '#3b82f6' // Azul
        },
        {
            id: 'cadence_fifth',
            numeral: 'V',
            roleName: 'Quinta (Dominante)',
            rootPitchClass: vRoot,
            chordName: `${arrLat[vRoot]} ${vSuffixLat}`.trim(),
            chordSymbol: `${arrAle[vRoot]}${vSuffixAle}`.trim(),
            intervals: vIntervals,
            noteMods: vNoteMods,
            noteNames: formatNoteNames(vNoteMods),
            playbackMidis: vMidis,
            colorBadge: '#ef4444' // Rojo
        }
    ];
}
