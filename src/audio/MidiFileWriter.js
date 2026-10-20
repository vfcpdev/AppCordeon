/**
 * @fileoverview Generador de archivos MIDI estándar (Standard MIDI File - SMF Format 0)
 * para patrones de bajos y acordes de acordeón diatónico a partir de datos MusicXML.
 * Permite descargar archivos .mid listos para reproducir en reproductores, DAWs o sintetizadores.
 * @module audio/MidiFileWriter
 */

export class MidiFileWriter {
    /**
     * Escribe un valor de longitud variable (Variable-Length Quantity - VLQ) en formato MIDI.
     * @param {number} value
     * @returns {number[]}
     */
    static writeVarLen(value) {
        let buffer = value & 0x7F;
        const bytes = [];
        while ((value >>= 7) > 0) {
            buffer <<= 8;
            buffer |= ((value & 0x7F) | 0x80);
        }
        while (true) {
            bytes.push(buffer & 0xFF);
            if (buffer & 0x80) {
                buffer >>= 8;
            } else {
                break;
            }
        }
        return bytes;
    }

    /**
     * Convierte un número a arreglo de bytes de longitud fija big-endian.
     * @param {number} value
     * @param {number} bytesCount
     * @returns {number[]}
     */
    static writeInt(value, bytesCount) {
        const bytes = [];
        for (let i = bytesCount - 1; i >= 0; i--) {
            bytes.push((value >> (i * 8)) & 0xFF);
        }
        return bytes;
    }

    /**
     * Genera un Uint8Array con los bytes de un archivo MIDI estándar Type 0.
     * @param {Object} pattern Patrón procesado por MusicXMLPatternParser
     * @param {Array<Object>} pattern.notes
     * @param {number} [pattern.tempo=120] Tempo en BPM
     * @param {string} [pattern.title] Nombre de la pista
     * @param {Object} [options]
     * @param {Array<number>} [options.fundamentalMidis] Notas MIDI reales del bajo si se desea mapear al acordeón
     * @param {Array<number>} [options.chordMidis] Notas MIDI reales del acorde si se desea mapear al acordeón
     * @returns {Uint8Array}
     */
    static createMidiFile(pattern, options = {}) {
        const ticksPerQuarter = 480; // Resolución estándar de división temporal
        const tempo = pattern.tempo || 120;
        const microsecondsPerQuarter = Math.round(60000000 / tempo);

        const trackEvents = [];

        // 1. Meta Event: Tempo (0xFF 0x51 0x03 tt tt tt)
        trackEvents.push(...this.writeVarLen(0));
        trackEvents.push(0xFF, 0x51, 0x03, ...this.writeInt(microsecondsPerQuarter, 3));

        // 2. Meta Event: Nombre de la pista (0xFF 0x03 len text...)
        const trackName = (pattern.title || "Ritmo Bajos Acordeón").trim();
        if (trackName.length > 0) {
            const encoder = new TextEncoder();
            const textBytes = Array.from(encoder.encode(trackName));
            trackEvents.push(...this.writeVarLen(0));
            trackEvents.push(0xFF, 0x03, ...this.writeVarLen(textBytes.length), ...textBytes);
        }

        // 3. Program Change: Acordeón (General MIDI 22: Accordion)
        trackEvents.push(...this.writeVarLen(0));
        trackEvents.push(0xC0, 21); // Canal 1, Patch 21 (0-indexed = 21: Accordion)

        // 4. Procesar notas del patrón
        let pendingDeltaTicks = 0;

        for (const note of pattern.notes) {
            const durationTicks = Math.round(note.durationBeats * ticksPerQuarter);

            if (note.isRest || !note.midi) {
                // Silencio: acumular el tiempo en el delta-time para el siguiente evento
                pendingDeltaTicks += durationTicks;
            } else {
                // Determinar si usar notas reales del acordeón diatónico o la nota del MusicXML
                let notesToPlay = [note.midi];

                const isBassNote = note.octave <= 2 || note.step === 'C' || note.step === 'F' || note.step === 'G';
                if (isBassNote && options.fundamentalMidis && options.fundamentalMidis.length > 0) {
                    notesToPlay = options.fundamentalMidis;
                } else if (!isBassNote && options.chordMidis && options.chordMidis.length > 0) {
                    notesToPlay = options.chordMidis;
                }

                // Note-On para cada nota MIDI
                for (let i = 0; i < notesToPlay.length; i++) {
                    const midiPitch = Math.max(0, Math.min(127, notesToPlay[i]));
                    // Solo el primer evento consume el delta acumulado; los simultáneos tienen delta 0
                    trackEvents.push(...this.writeVarLen(i === 0 ? pendingDeltaTicks : 0));
                    trackEvents.push(0x90, midiPitch, isBassNote ? 105 : 90); // Note On canal 1
                }
                pendingDeltaTicks = 0;

                // Esperar la duración de la nota antes del Note-Off (con corte ligeramente articulado)
                const noteGateTicks = Math.max(1, Math.round(durationTicks * 0.90));
                const noteRestTicks = durationTicks - noteGateTicks;

                // Note-Off para cada nota MIDI
                for (let i = 0; i < notesToPlay.length; i++) {
                    const midiPitch = Math.max(0, Math.min(127, notesToPlay[i]));
                    trackEvents.push(...this.writeVarLen(i === 0 ? noteGateTicks : 0));
                    trackEvents.push(0x80, midiPitch, 0); // Note Off canal 1
                }

                pendingDeltaTicks = noteRestTicks;
            }
        }

        // 5. Meta Event: End of Track (0xFF 0x2F 0x00)
        trackEvents.push(...this.writeVarLen(pendingDeltaTicks));
        trackEvents.push(0xFF, 0x2F, 0x00);

        // 6. Construir Header Chunk (MThd)
        // 4 bytes: 'MThd'
        // 4 bytes: length (6)
        // 2 bytes: format (0 = single track)
        // 2 bytes: ntrks (1 track)
        // 2 bytes: division (ticksPerQuarter)
        const header = [
            0x4D, 0x54, 0x68, 0x64, // 'MThd'
            0x00, 0x00, 0x00, 0x06, // Length = 6
            0x00, 0x00,             // Format 0
            0x00, 0x01,             // 1 Track
            ...this.writeInt(ticksPerQuarter, 2)
        ];

        // 7. Construir Track Chunk (MTrk)
        // 4 bytes: 'MTrk'
        // 4 bytes: length
        const trackHeader = [
            0x4D, 0x54, 0x68, 0x6B, // 'MTrk'
            ...this.writeInt(trackEvents.length, 4)
        ];

        const totalBytes = new Uint8Array(header.length + trackHeader.length + trackEvents.length);
        totalBytes.set(header, 0);
        totalBytes.set(trackHeader, header.length);
        totalBytes.set(trackEvents, header.length + trackHeader.length);

        return totalBytes;
    }

    /**
     * Descarga directamente en el navegador el archivo MIDI generado.
     * @param {Uint8Array} midiBytes
     * @param {string} fileName
     */
    static downloadMidi(midiBytes, fileName = "patron_ritmo.mid") {
        const blob = new Blob([midiBytes], { type: "audio/midi" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = fileName.endsWith(".mid") ? fileName : `${fileName}.mid`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
}
