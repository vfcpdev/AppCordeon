/**
 * @fileoverview Plantillas de acordes, fórmulas e intervalos armónicos.
 * Utilizado por el analizador armónico y por el selector de acordes libres.
 * @module theory/ChordTemplates
 */

/**
 * @typedef {Object} ChordTemplate
 * @property {string} id Identificador único
 * @property {string} name Nombre descriptivo en español
 * @property {string} symbol Símbolo o cifrado anglosajón / alemán
 * @property {number[]} intervals Intervalos en semitonos relativos a la tónica
 * @property {string[]} roles Función o nombre de cada intervalo (ej: 'Tónica', '3ra Mayor')
 * @property {string} family Familia armónica del acorde
 */

/**
 * Catálogo completo de plantillas de acordes diatónicos, extendidos y modernos.
 * @type {ChordTemplate[]}
 */
export const CHORD_TEMPLATES = Object.freeze([
    // Tríadas Estándar
    { id: 'maj', name: 'Mayor', symbol: '', intervals: [0, 4, 7], roles: ['1 (Tónica)', '3ra Mayor', '5ta Justa'], family: 'Tríada Mayor' },
    { id: 'min', name: 'Menor', symbol: 'm', intervals: [0, 3, 7], roles: ['1 (Tónica)', '3ra Menor', '5ta Justa'], family: 'Tríada Menor' },
    { id: 'dim', name: 'Disminuido', symbol: 'dim', intervals: [0, 3, 6], roles: ['1 (Tónica)', '3ra Menor', '5ta Disminuida'], family: 'Tríada Disminuida' },
    { id: 'aug', name: 'Aumentado', symbol: 'aug', intervals: [0, 4, 8], roles: ['1 (Tónica)', '3ra Mayor', '5ta Aumentada'], family: 'Tríada Aumentada' },
    { id: 'sus4', name: 'Suspendido 4', symbol: 'sus4', intervals: [0, 5, 7], roles: ['1 (Tónica)', '4ta Justa', '5ta Justa'], family: 'Acorde Suspendido' },
    { id: 'sus2', name: 'Suspendido 2', symbol: 'sus2', intervals: [0, 2, 7], roles: ['1 (Tónica)', '2da Mayor', '5ta Justa'], family: 'Acorde Suspendido' },
    { id: '5', name: 'Quinta (Power Chord)', symbol: '5', intervals: [0, 7], roles: ['1 (Tónica)', '5ta Justa'], family: 'Power Chord' },

    // Acordes de 7ma y 6ta (Cuatríadas)
    { id: 'dom7', name: '7ma Dominante', symbol: '7', intervals: [0, 4, 7, 10], roles: ['1 (Tónica)', '3ra Mayor', '5ta Justa', '7ma Menor'], family: 'Séptima Dominante' },
    { id: 'maj7', name: 'Mayor 7ma', symbol: 'Maj7', intervals: [0, 4, 7, 11], roles: ['1 (Tónica)', '3ra Mayor', '5ta Justa', '7ma Mayor'], family: 'Séptima Mayor' },
    { id: 'min7', name: 'Menor 7ma', symbol: 'm7', intervals: [0, 3, 7, 10], roles: ['1 (Tónica)', '3ra Menor', '5ta Justa', '7ma Menor'], family: 'Séptima Menor' },
    { id: 'minMaj7', name: 'Menor Maj7', symbol: 'm(Maj7)', intervals: [0, 3, 7, 11], roles: ['1 (Tónica)', '3ra Menor', '5ta Justa', '7ma Mayor'], family: 'Menor con Séptima Mayor' },
    { id: 'm7b5', name: 'Semidisminuido', symbol: 'm7(♭5)', intervals: [0, 3, 6, 10], roles: ['1 (Tónica)', '3ra Menor', '5ta Disminuida', '7ma Menor'], family: 'Semidisminuido' },
    { id: 'dim7', name: 'Disminuido 7', symbol: 'dim7', intervals: [0, 3, 6, 9], roles: ['1 (Tónica)', '3ra Menor', '5ta Disminuida', '7ma Disminuida'], family: 'Disminuido Completo' },
    { id: 'maj6', name: '6ta Mayor', symbol: '6', intervals: [0, 4, 7, 9], roles: ['1 (Tónica)', '3ra Mayor', '5ta Justa', '6ta Mayor'], family: 'Sexta Mayor' },
    { id: 'min6', name: 'Menor 6ta', symbol: 'm6', intervals: [0, 3, 7, 9], roles: ['1 (Tónica)', '3ra Menor', '5ta Justa', '6ta Mayor'], family: 'Sexta Menor' },
    { id: '7sus4', name: '7ma Sus4', symbol: '7sus4', intervals: [0, 5, 7, 10], roles: ['1 (Tónica)', '4ta Justa', '5ta Justa', '7ma Menor'], family: 'Séptima Suspendida' },
    { id: 'add9', name: 'Add9', symbol: '(add9)', intervals: [0, 2, 4, 7], roles: ['1 (Tónica)', '9na/2da', '3ra Mayor', '5ta Justa'], family: 'Add9' },
    { id: 'madd9', name: 'Menor Add9', symbol: 'm(add9)', intervals: [0, 2, 3, 7], roles: ['1 (Tónica)', '9na/2da', '3ra Menor', '5ta Justa'], family: 'Menor Add9' },
    { id: 'aug7', name: '7ma Aumentada', symbol: '7(♯5)', intervals: [0, 4, 8, 10], roles: ['1 (Tónica)', '3ra Mayor', '5ta Aumentada', '7ma Menor'], family: 'Séptima Aumentada' },

    // Acordes de 5 notas (9nas)
    { id: 'dom9', name: '9na Dominante', symbol: '9', intervals: [0, 2, 4, 7, 10], roles: ['1 (Tónica)', '9na', '3ra Mayor', '5ta Justa', '7ma Menor'], family: 'Novena Dominante' },
    { id: 'maj9', name: 'Mayor 9na', symbol: 'Maj9', intervals: [0, 2, 4, 7, 11], roles: ['1 (Tónica)', '9na', '3ra Mayor', '5ta Justa', '7ma Mayor'], family: 'Novena Mayor' },
    { id: 'min9', name: 'Menor 9na', symbol: 'm9', intervals: [0, 2, 3, 7, 10], roles: ['1 (Tónica)', '9na', '3ra Menor', '5ta Justa', '7ma Menor'], family: 'Novena Menor' },

    // Tríadas incompletas / sin 5ta
    { id: 'maj_no5', name: 'Mayor (sin 5ta)', symbol: '(no5)', intervals: [0, 4], roles: ['1 (Tónica)', '3ra Mayor'], family: 'Tercera Mayor (Tríada Incompleta)' },
    { id: 'min_no5', name: 'Menor (sin 5ta)', symbol: 'm(no5)', intervals: [0, 3], roles: ['1 (Tónica)', '3ra Menor'], family: 'Tercera Menor (Tríada Incompleta)' },
    { id: '7_no5', name: '7ma (sin 5ta)', symbol: '7(no5)', intervals: [0, 4, 10], roles: ['1 (Tónica)', '3ra Mayor', '7ma Menor'], family: 'Séptima sin 5ta' },
    { id: 'm7_no5', name: 'Menor 7ma (sin 5ta)', symbol: 'm7(no5)', intervals: [0, 3, 10], roles: ['1 (Tónica)', '3ra Menor', '7ma Menor'], family: 'Séptima Menor sin 5ta' }
]);
