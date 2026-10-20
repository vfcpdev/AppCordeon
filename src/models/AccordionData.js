/**
 * @fileoverview Modelo físico del diapasón de 31 botones (3 hileras 10-11-10 botones)
 * basado en el acordeón diatónico profesional 5 Letras (Bb-Eb-Ab).
 * Principio SRP: exclusivamente mapeos físicos y cálculo de transposición.
 * @module models/AccordionData
 */

/**
 * Mapa físico base del diapasón en afinación Cinco Letras (Bb - Eb - Ab).
 * Cada botón contiene:
 *  - p: nota MIDI al cerrar fuelle (Push)
 *  - pl: nota MIDI al abrir fuelle (Pull)
 */
export const BASE_CINCO_LETRAS_TREBLE = Object.freeze({
    row1: Object.freeze([ // Hilera Afuera (Bb / Si bemol) - 10 botones
        { p: 64, pl: 66 }, // B1:  Push Mi4 (64),  Pull Sol♭4 (66)
        { p: 58, pl: 60 }, // B2:  Push Si♭3 (58), Pull Do4 (60)
        { p: 62, pl: 63 }, // B3:  Push Re4 (62),  Pull Mi♭4 (63)
        { p: 65, pl: 67 }, // B4:  Push Fa4 (65),  Pull Sol4 (67)
        { p: 70, pl: 69 }, // B5:  Push Si♭4 (70), Pull La4 (69)
        { p: 74, pl: 72 }, // B6:  Push Re5 (74),  Pull Do5 (72)
        { p: 77, pl: 75 }, // B7:  Push Fa5 (77),  Pull Mi♭5 (75)
        { p: 82, pl: 79 }, // B8:  Push Si♭5 (82), Pull Sol5 (79)
        { p: 86, pl: 81 }, // B9:  Push Re6 (86),  Pull La5 (81)
        { p: 89, pl: 84 }  // B10: Push Fa6 (89),  Pull Do6 (84)
    ]),
    row2: Object.freeze([ // Hilera Medio (Eb / Mi bemol) - 11 botones
        { p: 57, pl: 59 }, // B1:  Push La3 (57),  Pull Si3 (59)
        { p: 58, pl: 62 }, // B2:  Push Si♭3 (58), Pull Re4 (62)
        { p: 63, pl: 65 }, // B3:  Push Mi♭4 (63), Pull Fa4 (65)
        { p: 67, pl: 68 }, // B4:  Push Sol4 (67), Pull La♭4 (68)
        { p: 70, pl: 72 }, // B5:  Push Si♭4 (70), Pull Do5 (72)
        { p: 75, pl: 74 }, // B6:  Push Mi♭5 (75), Pull Re5 (74)
        { p: 79, pl: 77 }, // B7:  Push Sol5 (79), Pull Fa5 (77)
        { p: 82, pl: 80 }, // B8:  Push Si♭5 (82), Pull La♭5 (80)
        { p: 87, pl: 84 }, // B9:  Push Mi♭6 (87), Pull Do6 (84)
        { p: 91, pl: 86 }, // B10: Push Sol6 (91), Pull Re6 (86)
        { p: 94, pl: 89 }  // B11: Push Si♭6 (94), Pull Fa6 (89)
    ]),
    row3: Object.freeze([ // Hilera Adentro (Ab / La bemol) - 10 botones
        { p: 66, pl: 64 }, // B1:  Push Sol♭4 (66), Pull Mi4 (64)
        { p: 63, pl: 67 }, // B2:  Push Mi♭4 (63),  Pull Sol4 (67)
        { p: 68, pl: 70 }, // B3:  Push La♭4 (68),  Pull Si♭4 (70)
        { p: 72, pl: 73 }, // B4:  Push Do5 (72),   Pull Re♭5 (73)
        { p: 75, pl: 77 }, // B5:  Push Mi♭5 (75),  Pull Fa5 (77)
        { p: 80, pl: 79 }, // B6:  Push La♭5 (80),  Pull Sol5 (79)
        { p: 84, pl: 82 }, // B7:  Push Do6 (84),   Pull Si♭5 (82)
        { p: 87, pl: 85 }, // B8:  Push Mi♭6 (87),  Pull Re♭6 (85)
        { p: 92, pl: 89 }, // B9:  Push La♭6 (92),  Pull Fa6 (89)
        { p: 96, pl: 91 }  // B10: Push Do7 (96),   Pull Sol6 (91)
    ])
});

/**
 * @typedef {Object} AccordionButtonModel
 * @property {string} id ID único del botón (ej: 'row1_0')
 * @property {string} rowKey Clave de la hilera ('row1', 'row2', 'row3')
 * @property {number} btnIndex Número ordinal del botón en su hilera (1 a 11)
 * @property {number} push Nota MIDI al cerrar fuelle
 * @property {number} pull Nota MIDI al abrir fuelle
 */

/**
 * @typedef {Object} TransposedAccordionData
 * @property {AccordionButtonModel[]} row1
 * @property {AccordionButtonModel[]} row2
 * @property {AccordionButtonModel[]} row3
 */

/**
 * Mapa físico base de los 12 botones de bajos (Mano Izquierda)
 * en afinación Cinco Letras (Bb - Eb - Ab) para acordeón Hohner Corona III / Rey Vallenato.
 * Organizado en 2 columnas verticales apiladas de 6 botones cada una:
 *  - Columna 1 (Exterior): Bajos Fundamentales (1 al 6)
 *  - Columna 2 (Interior): Acordes de Acompañamiento (1 al 6)
 */
export const BASE_CINCO_LETRAS_BASS = Object.freeze([
    // Par 1 (Columna 2 / Hilera 1: Cerrar = Bb Maj, Abrir = F Maj)
    { id: 'bass_1', type: 'fundamental', colKey: 'fund', btnIndex: 1, label: 'Bajo 1 (Bb/F)', push: 46, pull: 41, namePush: 'Bb', namePull: 'F' },
    { id: 'chord_1', type: 'chord', colKey: 'chord', btnIndex: 1, label: 'Acorde 1 (Bb/F)', push: [58, 62, 65], pull: [53, 57, 60], namePush: 'Bb Maj', namePull: 'F Maj' },

    // Par 2 (Columna 1 / Bajos 1 y 2: Cerrar = Sol Mayor / G Maj, Abrir = Do menor / C min)
    { id: 'bass_2', type: 'fundamental', colKey: 'fund', btnIndex: 2, label: 'Bajo 2 (G/C)', push: 43, pull: 48, namePush: 'G', namePull: 'C' },
    { id: 'chord_2', type: 'chord', colKey: 'chord', btnIndex: 2, label: 'Acorde 2 (G/Cm)', push: [55, 59, 62], pull: [60, 63, 67], namePush: 'G Maj', namePull: 'C min' },

    // Par 3 (Columna 2 / Hilera 2: Cerrar = Eb Maj, Abrir = Bb Maj)
    { id: 'bass_3', type: 'fundamental', colKey: 'fund', btnIndex: 3, label: 'Bajo 3 (Eb/Bb)', push: 51, pull: 46, namePush: 'Eb', namePull: 'Bb' },
    { id: 'chord_3', type: 'chord', colKey: 'chord', btnIndex: 3, label: 'Acorde 3 (Eb/Bb)', push: [63, 67, 70], pull: [58, 62, 65], namePush: 'Eb Maj', namePull: 'Bb Maj' },

    // Par 4 (Columna 1 / Bajos 3 y 4: Cerrar = Do Mayor / C Maj, Abrir = Fa menor / F min)
    { id: 'bass_4', type: 'fundamental', colKey: 'fund', btnIndex: 4, label: 'Bajo 4 (C/F)', push: 48, pull: 41, namePush: 'C', namePull: 'F' },
    { id: 'chord_4', type: 'chord', colKey: 'chord', btnIndex: 4, label: 'Acorde 4 (C/Fm)', push: [60, 64, 67], pull: [53, 56, 60], namePush: 'C Maj', namePull: 'F min' },

    // Par 5 (Columna 2 / Hilera 3: Cerrar = Ab Maj, Abrir = Eb Maj)
    { id: 'bass_5', type: 'fundamental', colKey: 'fund', btnIndex: 5, label: 'Bajo 5 (Ab/Eb)', push: 44, pull: 51, namePush: 'Ab', namePull: 'Eb' },
    { id: 'chord_5', type: 'chord', colKey: 'chord', btnIndex: 5, label: 'Acorde 5 (Ab/Eb)', push: [56, 60, 63], pull: [63, 67, 70], namePush: 'Ab Maj', namePull: 'Eb Maj' },

    // Par 6 (Columna 1 / Bajos 5 y 6: Cerrar y Abrir = Re bemol / Db Maj)
    { id: 'bass_6', type: 'fundamental', colKey: 'fund', btnIndex: 6, label: 'Bajo 6 (Db/Db)', push: 49, pull: 49, namePush: 'Db', namePull: 'Db' },
    { id: 'chord_6', type: 'chord', colKey: 'chord', btnIndex: 6, label: 'Acorde 6 (Db/Db)', push: [61, 65, 68], pull: [61, 65, 68], namePush: 'Db Maj', namePull: 'Db Maj' }
]);

/**
 * Genera el mapa transpuesto de los 31 botones aplicando un desplazamiento de semitonos (offset).
 * Método puro e inmutable.
 * @param {number} offset Desplazamiento en semitonos (ej: 0 para Cinco Letras, -3 para Rey Vallenato).
 * @returns {TransposedAccordionData}
 */
export function getTransposedAccordion(offset = 0) {
    const data = { row1: [], row2: [], row3: [] };
    const rowKeys = ['row1', 'row2', 'row3'];

    rowKeys.forEach(rowKey => {
        data[rowKey] = BASE_CINCO_LETRAS_TREBLE[rowKey].map((btn, index) => Object.freeze({
            id: `${rowKey}_${index}`,
            rowKey,
            btnIndex: index + 1,
            push: btn.p + offset,
            pull: btn.pl + offset
        }));
    });

    return Object.freeze(data);
}

/**
 * Genera el mapa transpuesto de los 12 botones de bajos aplicando el desplazamiento.
 * @param {number} offset
 * @returns {Array}
 */
export function getTransposedBasses(offset = 0) {
    return BASE_CINCO_LETRAS_BASS.map(btn => {
        if (btn.type === 'fundamental') {
            return Object.freeze({
                ...btn,
                push: btn.push + offset,
                pull: btn.pull + offset
            });
        } else {
            return Object.freeze({
                ...btn,
                push: btn.push.map(m => m + offset),
                pull: btn.pull.map(m => m + offset)
            });
        }
    });
}
