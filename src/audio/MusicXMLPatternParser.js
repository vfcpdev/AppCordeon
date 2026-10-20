/**
 * @fileoverview Parser ultraligero y robusto para archivos MusicXML (.xml, .musicxml)
 * orientado a patrones rítmicos de bajos y acompañamiento en acordeón diatónico.
 * @module audio/MusicXMLPatternParser
 */

export class MusicXMLPatternParser {
    /**
     * Parsea una cadena de texto XML de MusicXML y extrae la secuencia de notas/compases.
     * @param {string} xmlString
     * @returns {{ title: string, tempo: number, timeSignature: { beats: number, beatType: number }, notes: Array<{ midi: number, durationBeats: number, type: string, isRest: boolean, step: string, octave: number }> }}
     */
    static parse(xmlString) {
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(xmlString, "application/xml");

        const parseError = xmlDoc.querySelector("parsererror");
        if (parseError) {
            throw new Error(`Error de sintaxis en el archivo MusicXML: ${parseError.textContent}`);
        }

        // Título de la obra o pieza
        let title = "";
        const titleEl = xmlDoc.querySelector("work-title, movement-title, credit-words, part-name");
        if (titleEl && titleEl.textContent.trim()) {
            title = titleEl.textContent.trim();
        }

        // Parámetros de compás y tempo
        let tempo = 120;
        const soundEl = xmlDoc.querySelector("sound[tempo]");
        if (soundEl) {
            tempo = parseFloat(soundEl.getAttribute("tempo")) || 120;
        } else {
            const perMinuteEl = xmlDoc.querySelector("metronome per-minute");
            if (perMinuteEl) {
                tempo = parseFloat(perMinuteEl.textContent) || 120;
            }
        }

        let divisions = 4;
        const divEl = xmlDoc.querySelector("divisions");
        if (divEl) {
            divisions = parseInt(divEl.textContent, 10) || 4;
        }

        let beats = 4;
        let beatType = 4;
        const beatsEl = xmlDoc.querySelector("time beats");
        const beatTypeEl = xmlDoc.querySelector("time beat-type");
        if (beatsEl) beats = parseInt(beatsEl.textContent, 10) || 4;
        if (beatTypeEl) beatType = parseInt(beatTypeEl.textContent, 10) || 4;

        // Extraer notas de todas las medidas
        const noteNodes = xmlDoc.querySelectorAll("measure note");
        const notes = [];

        noteNodes.forEach(noteNode => {
            // Comprobar si es un silencio
            const isRest = noteNode.querySelector("rest") !== null;

            // Duración en divisiones
            const durationEl = noteNode.querySelector("duration");
            const durationDivs = durationEl ? parseInt(durationEl.textContent, 10) : divisions;
            // Duración en pulsos (cuartos/negra = 1.0)
            const durationBeats = Math.max(0.125, durationDivs / divisions);

            // Tipo de figura ('quarter', 'eighth', 'sixteenth', 'half', etc.)
            const typeEl = noteNode.querySelector("type");
            const type = typeEl ? typeEl.textContent.trim() : "quarter";

            if (isRest) {
                notes.push({
                    midi: null,
                    durationBeats,
                    type,
                    isRest: true,
                    step: 'Rest',
                    octave: 0
                });
            } else {
                const pitchNode = noteNode.querySelector("pitch");
                if (pitchNode) {
                    const stepEl = pitchNode.querySelector("step");
                    const alterEl = pitchNode.querySelector("alter");
                    const octaveEl = pitchNode.querySelector("octave");

                    // Detectar si la nota o compás tiene indicación explícita de fuelle (Push/Pull)
                    let bellows = null;
                    const techEl = noteNode.querySelector("technical");
                    if (techEl) {
                        if (techEl.querySelector("down-bow, push")) bellows = 'push';
                        else if (techEl.querySelector("up-bow, pull")) bellows = 'pull';
                    }
                    const wordsEl = noteNode.closest("measure")?.querySelector("direction words");
                    if (!bellows && wordsEl) {
                        const txt = wordsEl.textContent.toLowerCase();
                        if (txt.includes('cierra') || txt.includes('push') || txt.includes('cerrar')) bellows = 'push';
                        else if (txt.includes('abre') || txt.includes('pull') || txt.includes('abrir')) bellows = 'pull';
                    }

                    const midi = MusicXMLPatternParser._pitchToMidi(step, alter, octave);
                    notes.push({
                        midi,
                        durationBeats,
                        type,
                        isRest: false,
                        step,
                        alter,
                        octave,
                        bellows // 'push' | 'pull' | null
                    });
                }
            }
        });

        if (notes.length === 0) {
            throw new Error("No se encontraron notas válidas en el archivo MusicXML.");
        }

        return {
            title,
            tempo,
            timeSignature: { beats, beatType },
            notes
        };
    }

    /**
     * Convierte paso, alteración y octava a número MIDI.
     * @private
     */
    static _pitchToMidi(step, alter, octave) {
        const stepOffsets = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
        const semitone = (stepOffsets[step] ?? 0) + alter;
        return (octave + 1) * 12 + semitone;
    }
}
