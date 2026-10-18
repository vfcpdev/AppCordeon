/**
 * @fileoverview Estrategia de Análisis Armónico Inteligente (Patrón Strategy).
 * Detecta acordes a partir de notas seleccionadas, analiza el bajo real,
 * calcula inversiones (fundamental, 1ra, 2da, 3ra) y ofrece interpretaciones alternativas.
 * @module strategies/HarmonicAnalysisStrategy
 */

import { CHORD_TEMPLATES } from '../theory/ChordTemplates.js';
import { getPitchClass, getNoteNamesList } from '../theory/MusicTheory.js';
import { NOTATION_MODES } from '../core/Constants.js';

/**
 * @typedef {Object} SelectedNoteItem
 * @property {string} btnId ID del botón
 * @property {string} rowKey Clave de la hilera
 * @property {number} btnIndex Índice del botón (1-11)
 * @property {'push'|'pull'} direction Dirección del botón
 * @property {number} midi Nota MIDI absoluta
 * @property {number} [noteMod] Clase de tono (0-11)
 */

/**
 * @typedef {Object} HarmonicAnalysisResult
 * @property {string} mainNameLat Nombre principal en notación latina
 * @property {string} mainNameAle Nombre principal en notación alemana
 * @property {string} symbol Símbolo del acorde
 * @property {number} rootMod Pitch class de la tónica (0-11)
 * @property {string} rootNameLat Nombre de la tónica en latín
 * @property {string} rootNameAle Nombre de la tónica en alemán
 * @property {string} bassNameLat Nombre del bajo real en latín
 * @property {string} bassNameAle Nombre del bajo real en alemán
 * @property {string} inversionText Descripción de la inversión
 * @property {string} formula Fórmula o intervalos
 * @property {string} family Familia del acorde
 * @property {string[]} alternatives Interpretaciones armónicas alternativas
 * @property {string} bellowsSummary Resumen de dirección de fuelle
 * @property {number} score Puntuación de precisión
 */

export class HarmonicAnalysisStrategy {
    /**
     * Resume la coherencia de fuelle de las notas seleccionadas.
     * @param {SelectedNoteItem[]} notes
     * @returns {string}
     */
    static getBellowsSummary(notes) {
        if (!notes || notes.length === 0) return 'Sin notas';
        const pushes = notes.filter(n => n.direction === 'push').length;
        const pulls = notes.filter(n => n.direction === 'pull').length;
        if (pushes > 0 && pulls === 0) return 'Todos Cerrando';
        if (pulls > 0 && pushes === 0) return 'Todos Abriendo';
        return `Mixto (${pushes} Cerrar / ${pulls} Abrir)`;
    }

    /**
     * Analiza una lista de notas seleccionadas en el diapasón.
     * @param {SelectedNoteItem[]} notesList
     * @param {string} [notation=NOTATION_MODES.LATINA]
     * @param {number} [tuningOffset=0]
     * @returns {HarmonicAnalysisResult|null}
     */
    static analyze(notesList, notation = NOTATION_MODES.LATINA, tuningOffset = 0) {
        if (!notesList || notesList.length === 0) {
            return null;
        }

        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, tuningOffset);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, tuningOffset);

        // 1. Identificar el bajo real (la nota con menor MIDI absoluto)
        const sortedNotes = [...notesList].sort((a, b) => a.midi - b.midi);
        const bassNote = sortedNotes[0];
        const bassMod = getPitchClass(bassNote.midi);
        const bassNameLat = arrLat[bassMod];
        const bassNameAle = arrAle[bassMod];

        // 2. Extraer clases de notas únicas
        const uniqueMods = Array.from(new Set(sortedNotes.map(n => getPitchClass(n.midi))));

        // Caso unísono u octavas de la misma nota
        if (uniqueMods.length === 1) {
            const rootMod = uniqueMods[0];
            const rLat = arrLat[rootMod];
            const rAle = arrAle[rootMod];
            return {
                mainNameLat: `Unísono / Octavas de ${rLat}`,
                mainNameAle: `Unison / Octaves of ${rAle}`,
                symbol: '',
                rootMod,
                rootNameLat: rLat,
                rootNameAle: rAle,
                bassNameLat,
                bassNameAle,
                inversionText: 'Unísono (Misma Nota)',
                formula: '1 (Tónica)',
                family: 'Nota Simple',
                alternatives: [],
                bellowsSummary: this.getBellowsSummary(sortedNotes),
                score: 100
            };
        }

        const candidateMatches = [];

        // 3. Evaluar cada pitch class como posible tónica del acorde
        uniqueMods.forEach(rootCandidate => {
            const intervals = uniqueMods.map(m => (m - rootCandidate + 12) % 12).sort((a, b) => a - b);
            const intervalsSet = new Set(intervals);

            CHORD_TEMPLATES.forEach(tpl => {
                const tplSet = new Set(tpl.intervals);

                const isExact = intervals.length === tpl.intervals.length && intervals.every(i => tplSet.has(i));
                const isSubset = intervals.every(i => tplSet.has(i)) && intervals.length < tpl.intervals.length;
                const isSuperset = tpl.intervals.every(i => intervalsSet.has(i));

                if (isExact || isSubset || isSuperset) {
                    let score = 0;
                    if (isExact) score = 100;
                    else if (isSubset) score = 70 + (intervals.length / tpl.intervals.length) * 15;
                    else if (isSuperset) score = 60;

                    // Bonificación si la tónica coincide con el bajo real
                    if (rootCandidate === bassMod) score += 6;

                    // Bonificación a acordes estándar comunes
                    if (['maj', 'min', 'dom7', 'min7', 'maj7', 'dim', 'aug', 'sus4'].includes(tpl.id)) {
                        score += 4;
                    }

                    let invText = 'Estado Fundamental';
                    let slashLat = '';
                    let slashAle = '';
                    const bassInterval = (bassMod - rootCandidate + 12) % 12;

                    if (bassInterval === 0) {
                        invText = 'Estado Fundamental (Tónica en el Bajo)';
                    } else if (bassInterval === 3 || bassInterval === 4) {
                        invText = '1ra Inversión (3ra en el Bajo)';
                        slashLat = ` / ${bassNameLat}`;
                        slashAle = ` / ${bassNameAle}`;
                    } else if (bassInterval === 6 || bassInterval === 7 || bassInterval === 8) {
                        invText = '2da Inversión (5ta en el Bajo)';
                        slashLat = ` / ${bassNameLat}`;
                        slashAle = ` / ${bassNameAle}`;
                    } else if (bassInterval === 9 || bassInterval === 10 || bassInterval === 11) {
                        invText = '3ra Inversión (7ma en el Bajo)';
                        slashLat = ` / ${bassNameLat}`;
                        slashAle = ` / ${bassNameAle}`;
                    } else {
                        invText = `Bajo en ${notation === NOTATION_MODES.LATINA ? bassNameLat : bassNameAle}`;
                        slashLat = ` / ${bassNameLat}`;
                        slashAle = ` / ${bassNameAle}`;
                    }

                    const rLat = arrLat[rootCandidate];
                    const rAle = arrAle[rootCandidate];

                    const mainNameLat = `${rLat} ${tpl.name}${slashLat}`;
                    const mainNameAle = `${rAle}${tpl.symbol}${slashAle}`;

                    candidateMatches.push({
                        score,
                        template: tpl,
                        rootMod: rootCandidate,
                        rootNameLat: rLat,
                        rootNameAle: rAle,
                        bassNameLat,
                        bassNameAle,
                        mainNameLat,
                        mainNameAle,
                        symbol: tpl.symbol,
                        inversionText: invText,
                        formula: tpl.intervals.join(' - '),
                        family: tpl.family,
                        bellowsSummary: this.getBellowsSummary(sortedNotes)
                    });
                }
            });
        });

        // 4. Si no se encontró plantilla reconocida, retornar armonía libre
        if (candidateMatches.length === 0) {
            const rootMod = uniqueMods[0];
            const rLat = arrLat[rootMod];
            const rAle = arrAle[rootMod];
            return {
                mainNameLat: `Acorde Libre (${uniqueMods.length} notas)`,
                mainNameAle: `Free Chord (${uniqueMods.length} notes)`,
                symbol: '',
                rootMod,
                rootNameLat: rLat,
                rootNameAle: rAle,
                bassNameLat,
                bassNameAle,
                inversionText: 'Armonía Libre',
                formula: `${uniqueMods.length} notas seleccionadas`,
                family: 'Acorde Personalizado',
                alternatives: [],
                bellowsSummary: this.getBellowsSummary(sortedNotes),
                score: 10
            };
        }

        // 5. Ordenar por puntuación descendente para seleccionar el mejor match
        candidateMatches.sort((a, b) => b.score - a.score);
        const bestMatch = candidateMatches[0];

        // 6. Recoger alternativas únicas
        const seenNames = new Set([bestMatch.mainNameLat]);
        const alternatives = [];
        for (let i = 1; i < candidateMatches.length; i++) {
            const m = candidateMatches[i];
            if (!seenNames.has(m.mainNameLat)) {
                seenNames.add(m.mainNameLat);
                alternatives.push(notation === NOTATION_MODES.LATINA ? m.mainNameLat : m.mainNameAle);
                if (alternatives.length >= 3) break;
            }
        }

        return {
            ...bestMatch,
            alternatives
        };
    }
}
