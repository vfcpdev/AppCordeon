/**
 * @fileoverview Constantes globales y definiciones del simulador de acordeón diatónico.
 * @module core/Constants
 */

/**
 * Escalas cromáticas de nombres de notas en notación alemana (anglosajona) y latina,
 * tanto con sostenidos (♯) como con bemoles (♭).
 */
export const NOTES_ALEMANA_SHARP = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
export const NOTES_LATINA_SHARP  = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"];

export const NOTES_ALEMANA_FLAT  = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
export const NOTES_LATINA_FLAT   = ["Do", "Re♭", "Re", "Mi♭", "Mi", "Fa", "Sol♭", "Sol", "La♭", "La", "Si♭", "Si"];

/**
 * Nombres de las 3 hileras físicas del acordeón diatónico.
 * row1 = Hilera exterior (10 botones)
 * row2 = Hilera del medio (11 botones)
 * row3 = Hilera interior (10 botones)
 */
export const ROW_NAMES = Object.freeze({
    row1: "Hilera 1 (Afuera)",
    row2: "Hilera 2 (Medio)",
    row3: "Hilera 3 (Adentro)"
});

export const ROW_HEADER_LABELS = Object.freeze({
    row1: "Hilera 1\nAfuera",
    row2: "Hilera 2\nMedio",
    row3: "Hilera 3\nAdentro"
});

/**
 * Tónicas MIDI base exactas para cada hilera en afinación Cinco Letras (Bb - Eb - Ab).
 * Hilera 1 = Bb3 (58)
 * Hilera 2 = Eb4 (63)
 * Hilera 3 = Ab4 (68)
 */
export const ROW_BASE_TONICS = Object.freeze({
    row1: 58,
    row2: 63,
    row3: 68
});

/**
 * Definición de grados diatónicos (I al VIII) con sus intervalos y calidades triádicas.
 */
export const DIATONIC_DEGREES = Object.freeze([
    { num: "I",    name: "Tónica",         quality: "M",   intervals: [0, 4, 7] },
    { num: "II",   name: "Supertónica",    quality: "m",   intervals: [0, 3, 7] },
    { num: "III",  name: "Mediante",       quality: "m",   intervals: [0, 3, 7] },
    { num: "IV",   name: "Subdominante",   quality: "M",   intervals: [0, 4, 7] },
    { num: "V",    name: "Dominante",      quality: "7",   intervals: [0, 4, 7, 10] },
    { num: "VI",   name: "Relativa Menor", quality: "m",   intervals: [0, 3, 7] },
    { num: "VII",  name: "Sensible",       quality: "dim", intervals: [0, 3, 6] },
    { num: "VIII", name: "Octava",         quality: "M",   intervals: [0, 4, 7] }
]);

/**
 * Modos de dirección del fuelle.
 * @enum {string}
 */
export const BELLOWS_MODES = Object.freeze({
    BOTH: 'both',
    PUSH: 'push',
    PULL: 'pull'
});

/**
 * Modos de notación musical.
 * @enum {string}
 */
export const NOTATION_MODES = Object.freeze({
    LATINA: 'latina',
    ALEMANA: 'alemana'
});

/**
 * Configuración predeterminada de la aplicación.
 */
export const DEFAULT_CONFIG = Object.freeze({
    tuningOffset: 0,
    notation: NOTATION_MODES.LATINA,
    bellowsMode: BELLOWS_MODES.BOTH,
    defaultRow: 'row2',
    tempoMs: 350,
    volumeDb: -4
});
