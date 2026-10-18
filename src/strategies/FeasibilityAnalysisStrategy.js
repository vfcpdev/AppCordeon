/**
 * @fileoverview Estrategia de Análisis de Factibilidad de Fuelle (Patrón Strategy).
 * Determina si un acorde o secuencia de arpegio es ejecutable en el acordeón
 * según la dirección del fuelle (Cerrar / Abrir / Mixto / No ejecutable).
 * @module strategies/FeasibilityAnalysisStrategy
 */

import { BELLOWS_MODES } from '../core/Constants.js';
import { getPitchClass } from '../theory/MusicTheory.js';

/**
 * @typedef {Object} NoteFeasibilityDetail
 * @property {number} interval
 * @property {number} idx
 * @property {number} target Nota objetivo (pitch class o MIDI absoluto)
 * @property {boolean} canPush
 * @property {boolean} canPull
 * @property {Array} pushButtons Botones donde se encuentra cerrando
 * @property {Array} pullButtons Botones donde se encuentra abriendo
 */

/**
 * @typedef {Object} ChordFeasibilityResult
 * @property {NoteFeasibilityDetail[]} noteDetails
 * @property {boolean} allCanPush
 * @property {boolean} allCanPull
 * @property {boolean} anyMissing
 * @property {'both'|'push'|'pull'|'mixed'|'unavailable'} status
 * @property {string} label Etiqueta para el badge
 * @property {string} description Explicación detallada
 * @property {string} cssClass Clase CSS
 * @property {string} icon HTML del icono FontAwesome
 */

export class FeasibilityAnalysisStrategy {
    /**
     * Evalúa la factibilidad de ejecución del acorde sobre el diapasón transpuesto actual.
     * @param {Object} chordData
     * @param {Object} accordionData Objeto con { row1, row2, row3 }
     * @param {string} bellowsMode Modo de fuelle actual ('both', 'push', 'pull')
     * @returns {ChordFeasibilityResult|null}
     */
    static check(chordData, accordionData, bellowsMode = BELLOWS_MODES.BOTH) {
        if (!chordData || !chordData.intervals || !accordionData) return null;

        const noteDetails = chordData.intervals.map((interval, idx) => {
            const target = chordData.isExactMidi ? chordData.playbackMidis[idx] : chordData.noteMods[idx];
            const pushButtons = [];
            const pullButtons = [];

            ['row3', 'row2', 'row1'].forEach(r => {
                if (!accordionData[r]) return;
                accordionData[r].forEach(b => {
                    const isPush = chordData.isExactMidi ? (b.push === target) : (getPitchClass(b.push) === target);
                    const isPull = chordData.isExactMidi ? (b.pull === target) : (getPitchClass(b.pull) === target);
                    if (isPush) pushButtons.push(b);
                    if (isPull) pullButtons.push(b);
                });
            });

            return {
                interval,
                idx,
                target,
                canPush: pushButtons.length > 0,
                canPull: pullButtons.length > 0,
                pushButtons,
                pullButtons
            };
        });

        const allCanPush = noteDetails.every(n => n.canPush);
        const allCanPull = noteDetails.every(n => n.canPull);
        const anyMissing = noteDetails.some(n => !n.canPush && !n.canPull);

        let status = 'both';
        let label = '';
        let description = '';
        let cssClass = '';
        let icon = '';

        if (bellowsMode === BELLOWS_MODES.PUSH) {
            if (allCanPush) {
                status = 'push';
                cssClass = 'push';
                icon = '<i class="fas fa-check-circle"></i>';
                label = 'Posible Cerrando';
                description = 'Todas las notas del arpegio se pueden ejecutar cerrando el fuelle.';
            } else {
                status = 'unavailable';
                cssClass = 'unavailable';
                icon = '<i class="fas fa-times-circle"></i>';
                label = 'No ejecutable Cerrando';
                description = 'Faltan notas al cerrar el fuelle para este acorde.';
            }
        } else if (bellowsMode === BELLOWS_MODES.PULL) {
            if (allCanPull) {
                status = 'pull';
                cssClass = 'pull';
                icon = '<i class="fas fa-check-circle"></i>';
                label = 'Posible Abriendo';
                description = 'Todas las notas del arpegio se pueden ejecutar abriendo el fuelle.';
            } else {
                status = 'unavailable';
                cssClass = 'unavailable';
                icon = '<i class="fas fa-times-circle"></i>';
                label = 'No ejecutable Abriendo';
                description = 'Faltan notas al abrir el fuelle para este acorde.';
            }
        } else {
            // bellowsMode === 'both'
            if (anyMissing) {
                status = 'unavailable';
                cssClass = 'unavailable';
                icon = '<i class="fas fa-ban"></i>';
                label = 'No disponible';
                description = 'Alguna nota del acorde no se encuentra en esta octava o afinación.';
            } else if (allCanPush && allCanPull) {
                status = 'both';
                cssClass = 'both';
                icon = '<i class="fas fa-arrows-alt-h"></i>';
                label = 'Cerrando o Abriendo';
                description = 'El arpegio es 100% posible tanto cerrando como abriendo el fuelle.';
            } else if (allCanPush && !allCanPull) {
                status = 'push';
                cssClass = 'push';
                icon = '<i class="fas fa-arrow-right"></i>';
                label = 'Solo Cerrando';
                description = 'El arpegio es posible únicamente cerrando el fuelle.';
            } else if (!allCanPush && allCanPull) {
                status = 'pull';
                cssClass = 'pull';
                icon = '<i class="fas fa-arrow-left"></i>';
                label = 'Solo Abriendo';
                description = 'El arpegio es posible únicamente abriendo el fuelle.';
            } else {
                status = 'mixed';
                cssClass = 'mixed';
                icon = '<i class="fas fa-exchange-alt"></i>';
                label = 'Fuelle Mixto (Abrir y Cerrar)';
                description = 'El arpegio requiere alternar entre abrir y cerrar el fuelle.';
            }
        }

        return {
            noteDetails,
            allCanPush,
            allCanPull,
            anyMissing,
            status,
            label,
            description,
            cssClass,
            icon
        };
    }
}
