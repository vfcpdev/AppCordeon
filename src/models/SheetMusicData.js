import { parseChordNotation } from '../theory/MusicTheory.js';

/**
 * Compases y acordes analizados de la partitura:
 * "COMO ZAQUEO - HAZ UN MILAGRO EN MI" (Regis Danese)
 * Tonalidad: Sol Mayor (G) - 1 sostenido (Fa#)
 * Métrica: 4/4 - Tempo sugerido: 70 BPM
 */
export const COMO_ZAQUEO_SCORE_INFO = {
    title: 'Como Zaqueo - Haz un milagro en mí',
    artist: 'Regis Danese',
    sourceFile: 'COMO ZAQUEO - HAZ UN MILAGRO EN MI.pdf',
    key: 'G',
    keyName: 'Sol Mayor',
    bpm: 70,
    meter: '4/4',
    totalScorePages: 48,
    totalBars: 74
};

export const COMO_ZAQUEO_BARS = [
    // INTRO (c. 1 - 7)
    { bar: 1, chord: 'G', section: 'Intro', page: 1 },
    { bar: 2, chord: 'D/F#', section: 'Intro', page: 1 },
    { bar: 3, chord: 'Em7', section: 'Intro', page: 1 },
    { bar: 4, chord: 'C', section: 'Intro', page: 2 },
    { bar: 5, chord: 'G/B', section: 'Intro', page: 2 },
    { bar: 6, chord: 'Am7', section: 'Intro', page: 2 },
    { bar: 7, chord: 'D', section: 'Intro', page: 2 },

    // ESTROFA 1 (c. 8 - 15) "Como Zaqueo yo quiero subir..."
    { bar: 8, chord: 'G', section: 'Estrofa 1', page: 2 },
    { bar: 9, chord: 'D/F#', section: 'Estrofa 1', page: 3 },
    { bar: 10, chord: 'Em7', section: 'Estrofa 1', page: 3 },
    { bar: 11, chord: 'C', section: 'Estrofa 1', page: 3 },
    { bar: 12, chord: 'G/B', section: 'Estrofa 1', page: 3 },
    { bar: 13, chord: 'Am7', section: 'Estrofa 1', page: 4 },
    { bar: 14, chord: 'D', section: 'Estrofa 1', page: 4 },
    { bar: 15, chord: 'D', section: 'Estrofa 1', page: 4 },

    // PRE-CORO (c. 16 - 24) "Dejo todo para seguirte..."
    { bar: 16, chord: 'G', section: 'Pre-coro', page: 4 },
    { bar: 17, chord: 'D/F#', section: 'Pre-coro', page: 4 },
    { bar: 18, chord: 'Em7', section: 'Pre-coro', page: 5 },
    { bar: 19, chord: 'C', section: 'Pre-coro', page: 5 },
    { bar: 20, chord: 'Bm7', section: 'Pre-coro', page: 5 },
    { bar: 21, chord: 'Em7', section: 'Pre-coro', page: 5 },
    { bar: 22, chord: 'C', section: 'Pre-coro', page: 6 },
    { bar: 23, chord: 'Am7', section: 'Pre-coro', page: 6 },
    { bar: 24, chord: 'D', section: 'Pre-coro', page: 6 },

    // CORO 1 (c. 25 - 33) "Entra en mi casa, entra en mi vida..."
    { bar: 25, chord: 'G', section: 'Coro', page: 7 },
    { bar: 26, chord: 'G', section: 'Coro', page: 7 },
    { bar: 27, chord: 'D/F#', section: 'Coro', page: 7 },
    { bar: 28, chord: 'Em7', section: 'Coro', page: 7 },
    { bar: 29, chord: 'Em7', section: 'Coro', page: 8 },
    { bar: 30, chord: 'C', section: 'Coro', page: 8 },
    { bar: 31, chord: 'G/B', section: 'Coro', page: 8 },
    { bar: 32, chord: 'Am7', section: 'Coro', page: 8 },
    { bar: 33, chord: 'D', section: 'Coro', page: 9 },

    // INTERLUDIO / RE-INTRO (c. 34 - 40)
    { bar: 34, chord: 'G', section: 'Interludio', page: 9 },
    { bar: 35, chord: 'D/F#', section: 'Interludio', page: 9 },
    { bar: 36, chord: 'Em7', section: 'Interludio', page: 9 },
    { bar: 37, chord: 'C', section: 'Interludio', page: 10 },
    { bar: 38, chord: 'G/B', section: 'Interludio', page: 10 },
    { bar: 39, chord: 'Am7', section: 'Interludio', page: 10 },
    { bar: 40, chord: 'D', section: 'Interludio', page: 10 },

    // ESTROFA 2 (c. 41 - 48)
    { bar: 41, chord: 'G', section: 'Estrofa 2', page: 11 },
    { bar: 42, chord: 'D/F#', section: 'Estrofa 2', page: 11 },
    { bar: 43, chord: 'Em7', section: 'Estrofa 2', page: 11 },
    { bar: 44, chord: 'C', section: 'Estrofa 2', page: 12 },
    { bar: 45, chord: 'G/B', section: 'Estrofa 2', page: 12 },
    { bar: 46, chord: 'Am7', section: 'Estrofa 2', page: 12 },
    { bar: 47, chord: 'D', section: 'Estrofa 2', page: 13 },
    { bar: 48, chord: 'D', section: 'Estrofa 2', page: 13 },

    // PRE-CORO (c. 49 - 56)
    { bar: 49, chord: 'G', section: 'Pre-coro', page: 13 },
    { bar: 50, chord: 'D/F#', section: 'Pre-coro', page: 14 },
    { bar: 51, chord: 'Em7', section: 'Pre-coro', page: 14 },
    { bar: 52, chord: 'C', section: 'Pre-coro', page: 14 },
    { bar: 53, chord: 'Bm7', section: 'Pre-coro', page: 15 },
    { bar: 54, chord: 'Em7', section: 'Pre-coro', page: 15 },
    { bar: 55, chord: 'C', section: 'Pre-coro', page: 15 },
    { bar: 56, chord: 'D', section: 'Pre-coro', page: 16 },

    // CORO 2 (c. 57 - 65)
    { bar: 57, chord: 'G', section: 'Coro', page: 16 },
    { bar: 58, chord: 'G', section: 'Coro', page: 16 },
    { bar: 59, chord: 'D/F#', section: 'Coro', page: 17 },
    { bar: 60, chord: 'Em7', section: 'Coro', page: 17 },
    { bar: 61, chord: 'Em7', section: 'Coro', page: 17 },
    { bar: 62, chord: 'C', section: 'Coro', page: 18 },
    { bar: 63, chord: 'G/B', section: 'Coro', page: 18 },
    { bar: 64, chord: 'Am7', section: 'Coro', page: 18 },
    { bar: 65, chord: 'D', section: 'Coro', page: 19 },

    // CORO CLÍMAX / OUTRO (c. 66 - 74)
    { bar: 66, chord: 'G', section: 'Coro', page: 19 },
    { bar: 67, chord: 'D/F#', section: 'Coro', page: 20 },
    { bar: 68, chord: 'Em7', section: 'Coro', page: 20 },
    { bar: 69, chord: 'C', section: 'Coro', page: 20 },
    { bar: 70, chord: 'G/B', section: 'Coro', page: 21 },
    { bar: 71, chord: 'Am7', section: 'Coro', page: 21 },
    { bar: 72, chord: 'D', section: 'Coro', page: 22 },
    { bar: 73, chord: 'C', section: 'Outro', page: 22 },
    { bar: 74, chord: 'G', section: 'Final', page: 23 }
];

/**
 * Genera la lista de acordes temporizados para el reproductor y la cuadrícula 4/4
 * calculando los tiempos de inicio y fin a partir del BPM.
 * @param {number} [bpm=70]
 * @returns {Array<Object>}
 */
export function buildComoZaqueoTimelineChords(bpm = 70) {
    const beatSec = 60 / bpm;
    const barSec = 4 * beatSec;
    const timeline = [];

    COMO_ZAQUEO_BARS.forEach((item) => {
        const barIndex = item.bar - 1;
        const startTime = barIndex * barSec;
        const endTime = (barIndex + 1) * barSec;

        const parsed = parseChordNotation(item.chord);
        if (parsed) {
            timeline.push({
                startTime,
                endTime,
                chordSymbol: parsed.chordSymbol,
                chordName: parsed.chordName,
                root: parsed.root,
                chordType: parsed.chordType,
                intervals: parsed.intervals,
                noteMods: parsed.noteMods,
                playbackMidis: parsed.playbackMidis,
                bellowsAction: 'both',
                section: item.section,
                page: item.page,
                barNumber: item.bar
            });
        }
    });

    return timeline;
}
