/**
 * @fileoverview Registro extensible de afinaciones para acordeón diatónico (Open/Closed Principle).
 * Permite incorporar nuevas afinaciones (Sabanera, Anisada, etc.) sin modificar el código interno.
 * @module models/Tunings
 */

/**
 * @typedef {Object} TuningDefinition
 * @property {string} id Identificador único de la afinación
 * @property {string} name Nombre representativo
 * @property {string} rowsDescription Descripción de las 3 hileras
 * @property {number} offset Desplazamiento en semitonos respecto a Cinco Letras (Bb-Eb-Ab = 0)
 * @property {boolean} preferFlats Si debe preferir notación de bemoles (b) en lugar de sostenidos (#)
 */

class TuningRegistry {
    constructor() {
        /**
         * @type {Map<string, TuningDefinition>}
         * @private
         */
        this._tunings = new Map();

        this._registerDefaults();
    }

    /**
     * Registra las afinaciones vallenatas y diatónicas tradicionales por defecto.
     * @private
     */
    _registerDefaults() {
        const defaults = [
            {
                id: 'cinco_letras',
                name: 'Cinco Letras (Bb - Eb - Ab)',
                rowsDescription: 'Si♭ - Mi♭ - La♭',
                offset: 0,
                preferFlats: true
            },
            {
                id: 'rey_vallenato',
                name: 'Rey Vallenato (G - C - F)',
                rowsDescription: 'Sol - Do - Fa',
                offset: -3,
                preferFlats: false
            },
            {
                id: 'guacamayo',
                name: 'Guacamayo (A - D - G)',
                rowsDescription: 'La - Re - Sol',
                offset: -1,
                preferFlats: false
            },
            {
                id: 'simila',
                name: 'Simila (B - E - A)',
                rowsDescription: 'Si - Mi - La',
                offset: 1,
                preferFlats: false
            },
            {
                id: 'cuatro_letras',
                name: 'Cuatro Letras (F - Bb - Eb)',
                rowsDescription: 'Fa - Si♭ - Mi♭',
                offset: -5,
                preferFlats: true
            },
            {
                id: 'sabanera',
                name: 'Sabanera (C - F - Bb)',
                rowsDescription: 'Do - Fa - Si♭',
                offset: 2,
                preferFlats: true
            },
            {
                id: 'anisada',
                name: 'Anisada (E - A - D)',
                rowsDescription: 'Mi - La - Re',
                offset: -7,
                preferFlats: false
            }
        ];

        defaults.forEach(t => this.register(t));
    }

    /**
     * Registra una nueva afinación en el sistema (OCP).
     * @param {TuningDefinition} tuning
     */
    register(tuning) {
        if (!tuning || typeof tuning.id !== 'string' || typeof tuning.offset !== 'number') {
            throw new Error('La afinación debe incluir al menos "id" y "offset" numérico.');
        }
        this._tunings.set(tuning.id, Object.freeze({ ...tuning }));
    }

    /**
     * Retorna todas las afinaciones registradas.
     * @returns {TuningDefinition[]}
     */
    getAll() {
        return Array.from(this._tunings.values());
    }

    /**
     * Obtiene una afinación por su ID.
     * @param {string} id
     * @returns {TuningDefinition|undefined}
     */
    getById(id) {
        return this._tunings.get(id);
    }

    /**
     * Obtiene una afinación por su desplazamiento en semitonos.
     * @param {number} offset
     * @returns {TuningDefinition|undefined}
     */
    getByOffset(offset) {
        return this.getAll().find(t => t.offset === offset);
    }

    /**
     * Determina si una afinación dada usa preferentemente bemoles.
     * @param {number} offset
     * @returns {boolean}
     */
    usesFlats(offset) {
        const tuning = this.getByOffset(offset);
        if (tuning) return tuning.preferFlats;
        return [0, -5, 2].includes(offset);
    }
}

export const tuningRegistry = new TuningRegistry();
export default TuningRegistry;
