/**
 * @fileoverview Puente de integración WebAssembly para el motor de extracción melódica en Rust.
 * Permite extraer secuencias de notas de partituras MusicXML a velocidad nativa con WebAssembly,
 * y provee un motor fallback nativo en JavaScript de alto rendimiento si WASM no está presente.
 * @module audio/WasmMelodyBridge
 */

export class WasmMelodyBridge {
    constructor() {
        this._isReady = false;
        this._wasmModule = null;
        this._initPromise = null;
        this._engineName = 'JavaScript (Nativo)';
    }

    /**
     * Intenta inicializar el módulo WASM de Rust.
     * @returns {Promise<boolean>}
     */
    async init() {
        if (this._isReady) return true;
        if (this._initPromise) return this._initPromise;

        this._initPromise = (async () => {
            try {
                const wasmPkg = await import('./wasm_melody_pkg/melody_extractor.js');
                if (wasmPkg && typeof wasmPkg.default === 'function') {
                    await wasmPkg.default();
                    if (typeof wasmPkg.is_melody_wasm_ready === 'function' && wasmPkg.is_melody_wasm_ready()) {
                        this._wasmModule = wasmPkg;
                        this._isReady = true;
                        this._engineName = 'Rust (WebAssembly)';
                        console.info('🚀 [Rust WASM Melody] Motor de extracción melódica en Rust cargado y activo con éxito.');
                        return true;
                    }
                }
            } catch (err) {
                this._engineName = 'JavaScript (Fallback)';
                console.info('ℹ️ [Melody Extractor] Ejecutando motor de extracción melódica en JavaScript integrado (WASM opcional no compilado).');
            }
            this._isReady = false;
            return false;
        })();

        return this._initPromise;
    }

    /**
     * Retorna el motor activo ('Rust (WebAssembly)' o 'JavaScript (Fallback)').
     * @returns {string}
     */
    getEngineName() {
        return this._engineName;
    }

    /**
     * Extrae la secuencia de notas melódicas desde una cadena MusicXML.
     * @param {string} xmlText Contenido XML de la partitura
     * @returns {Object} Reporte melódico con notas secuenciadas
     */
    extractMelody(xmlText) {
        if (!xmlText || typeof xmlText !== 'string') {
            return {
                title: 'Partitura Vacía',
                bpm: 70,
                meter: '4/4',
                total_bars: 0,
                total_notes: 0,
                notes: [],
                engine: this._engineName
            };
        }

        // Si el módulo WASM en Rust está listo, ejecutar en Rust
        if (this._isReady && this._wasmModule && typeof this._wasmModule.extract_melody_from_musicxml === 'function') {
            try {
                const rustReport = this._wasmModule.extract_melody_from_musicxml(xmlText);
                if (rustReport && rustReport.notes) {
                    rustReport.engine = 'Rust (WebAssembly)';
                    return rustReport;
                }
            } catch (e) {
                console.warn('⚠️ [WasmMelodyBridge] Error en ejecución de WASM en Rust, usando motor JS:', e);
            }
        }

        // Motor JavaScript nativo (fallback de alto rendimiento)
        return this._parseMelodyJs(xmlText);
    }

    /**
     * Parser DOM nativo en JavaScript para extracción melódica.
     * @private
     * @param {string} xmlText
     * @returns {Object}
     */
    _parseMelodyJs(xmlText) {
        const parser = new DOMParser();
        const doc = parser.parseFromString(xmlText, 'application/xml');

        const titleEl = doc.querySelector('work-title') || doc.querySelector('movement-title');
        const title = titleEl ? titleEl.textContent.trim() : 'Melodía MusicXML';

        let bpm = 70;
        const soundEl = doc.querySelector('sound[tempo]');
        if (soundEl && soundEl.getAttribute('tempo')) {
            bpm = Math.round(parseFloat(soundEl.getAttribute('tempo')));
        } else {
            const perMinEl = doc.querySelector('per-minute');
            if (perMinEl) bpm = Math.round(parseFloat(perMinEl.textContent.trim()));
        }

        const beatsEl = doc.querySelector('beats');
        const beatTypeEl = doc.querySelector('beat-type');
        const meter = beatsEl && beatTypeEl ? `${beatsEl.textContent.trim()}/${beatTypeEl.textContent.trim()}` : '4/4';

        const measureEls = doc.querySelectorAll('measure');
        const notes = [];
        let noteId = 1;

        const SPANISH_STEPS = {
            'C': 'Do', 'D': 'Re', 'E': 'Mi', 'F': 'Fa', 'G': 'Sol', 'A': 'La', 'B': 'Si'
        };
        const BASE_SEMITONES = {
            'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11
        };

        measureEls.forEach((mEl, mIdx) => {
            const numAttr = mEl.getAttribute('number');
            const barNum = numAttr ? parseInt(numAttr, 10) : (mIdx + 1);

            let currentBeat = 1.0;
            const noteEls = mEl.querySelectorAll('note');

            noteEls.forEach((nEl) => {
                const isRest = Boolean(nEl.querySelector('rest'));
                const isChord = Boolean(nEl.querySelector('chord'));

                const typeEl = nEl.querySelector('type');
                const noteType = typeEl ? typeEl.textContent.trim() : 'quarter';

                let durationBeats = 1.0;
                switch (noteType) {
                    case 'whole': durationBeats = 4.0; break;
                    case 'half': durationBeats = 2.0; break;
                    case 'quarter': durationBeats = 1.0; break;
                    case 'eighth': durationBeats = 0.5; break;
                    case '16th': durationBeats = 0.25; break;
                    case '32nd': durationBeats = 0.125; break;
                    default: durationBeats = 1.0; break;
                }

                const lyricEl = nEl.querySelector('lyric text');
                const lyric = lyricEl ? lyricEl.textContent.trim() : '';

                if (isRest) {
                    notes.push({
                        id: noteId++,
                        bar: barNum,
                        beat: currentBeat,
                        step: 'R',
                        alter: 0,
                        octave: 0,
                        pitch_name: 'Silencio',
                        scientific: 'Rest',
                        midi: 0,
                        duration_beats: durationBeats,
                        note_type: noteType,
                        is_rest: true,
                        is_chord_note: isChord,
                        lyric
                    });
                } else {
                    const stepEl = nEl.querySelector('pitch step');
                    const alterEl = nEl.querySelector('pitch alter');
                    const octEl = nEl.querySelector('pitch octave');

                    if (stepEl && octEl) {
                        const step = stepEl.textContent.trim().toUpperCase();
                        const alter = alterEl ? parseInt(alterEl.textContent.trim(), 10) : 0;
                        const octave = parseInt(octEl.textContent.trim(), 10);

                        const baseSemi = BASE_SEMITONES[step] ?? 0;
                        const midi = Math.max(0, Math.min(127, (octave + 1) * 12 + baseSemi + alter));

                        const spanishStep = SPANISH_STEPS[step] || step;
                        const alterEs = alter === 1 ? '♯' : alter === -1 ? '♭' : '';
                        const alterSci = alter === 1 ? '#' : alter === -1 ? 'b' : '';

                        const pitch_name = `${spanishStep}${alterEs}${octave}`;
                        const scientific = `${step}${alterSci}${octave}`;

                        notes.push({
                            id: noteId++,
                            bar: barNum,
                            beat: currentBeat,
                            step,
                            alter,
                            octave,
                            pitch_name,
                            scientific,
                            midi,
                            duration_beats: durationBeats,
                            note_type: noteType,
                            is_rest: false,
                            is_chord_note: isChord,
                            lyric
                        });
                    }
                }

                if (!isChord) {
                    currentBeat += durationBeats;
                }
            });
        });

        return {
            title,
            bpm,
            meter,
            total_bars: measureEls.length,
            total_notes: notes.length,
            notes,
            engine: 'JavaScript (Nativo)'
        };
    }
}

export const wasmMelodyBridge = new WasmMelodyBridge();
