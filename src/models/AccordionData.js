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
