/**
 * @fileoverview Analizador de Audio, Detección de Acordes y Tonalidad Principal (SRP).
 * Procesa archivos MP3/WAV mediante Web Audio API, genera perfiles cromáticos (Chromagram),
 * detecta acordes en la línea de tiempo y deduce la tonalidad principal (Krumhansl-Schmuckler).
 * @module audio/AudioChordAnalyzer
 */

import { CHORD_TEMPLATES } from '../theory/ChordTemplates.js';
import { getPitchClass, getNoteNamesList } from '../theory/MusicTheory.js';
import { NOTATION_MODES, ROW_BASE_TONICS } from '../core/Constants.js';
import { tuningRegistry } from '../models/Tunings.js';

// Perfiles de clave Krumhansl-Kessler para estimación de tonalidad
const KRUMHANSL_MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
const KRUMHANSL_MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];

/**
 * @typedef {Object} DetectedChordSegment
 * @property {number} startTime Tiempo de inicio en segundos
 * @property {number} endTime Tiempo de fin en segundos
 * @property {number} rootMod Pitch class de la tónica (0-11)
 * @property {string} quality Calidad ('maj', 'min', 'dom7', etc.)
 * @property {string} chordName Nombre en notación latina
 * @property {string} chordSymbol Cifrado anglosajón / alemán
 * @property {number[]} noteMods Pitch classes de las notas del acorde
 * @property {number} confidence Confianza estadística (0.0 a 1.0)
 */

/**
 * @typedef {Object} KeyDetectionResult
 * @property {number} rootMod Pitch class de la tónica
 * @property {string} mode 'major' o 'minor'
 * @property {string} keyNameLat Nombre en español (ej: "Mi♭ Mayor", "Sol Menor")
 * @property {string} keyNameAle Nombre en alemán/cifrado (ej: "Eb Major", "G Minor")
 * @property {string} recommendedTuning Afinación recomendada de acordeón
 * @property {number} recommendedOffset Desplazamiento sugerido
 * @property {string} recommendedRow Hilera principal sugerida ('row1', 'row2', 'row3')
 * @property {number} correlation Coeficiente de correlación
 */

/**
 * @typedef {Object} AudioAnalysisReport
 * @property {number} duration Duración total en segundos
 * @property {KeyDetectionResult} mainKey Tonalidad principal detectada
 * @property {DetectedChordSegment[]} chords Línea de tiempo de acordes
 * @property {number[][]} chromagram Perfiles cromáticos por ventana
 */

export class AudioChordAnalyzer {
    constructor() {
        this._audioContext = null;
    }

    /**
     * Obtiene o crea el AudioContext nativo.
     * @private
     * @returns {AudioContext}
     */
    _getAudioContext() {
        if (!this._audioContext) {
            const AudioCtx = window.AudioContext || window.webkitAudioContext;
            this._audioContext = new AudioCtx();
        }
        if (this._audioContext.state === 'suspended') {
            this._audioContext.resume();
        }
        return this._audioContext;
    }

    /**
     * Decodifica un archivo de audio (File o Blob, ej: MP3/WAV) a AudioBuffer.
     * @param {File|Blob} file
     * @returns {Promise<AudioBuffer>}
     */
    async decodeAudio(file) {
        const ctx = this._getAudioContext();
        const arrayBuffer = await file.arrayBuffer();
        return await ctx.decodeAudioData(arrayBuffer);
    }

    /**
     * Analiza un AudioBuffer y genera la línea de acordes y tonalidad principal.
     * @param {AudioBuffer} audioBuffer
     * @param {(progress: number) => void} [onProgress] Callback de progreso (0 a 100)
     * @returns {Promise<AudioAnalysisReport>}
     */
    async analyze(audioBuffer, onProgress) {
        const sampleRate = audioBuffer.sampleRate;
        const duration = audioBuffer.duration;

        // 1. Mezcla a canal mono
        const channelData = this._mixDownToMono(audioBuffer);

        // 2. Parámetros de ventana para análisis espectral
        // Ventanas de ~250ms con 50% de solapamiento para buena resolución temporal y armónica
        const windowSize = 4096;
        const hopSize = 2048;
        const totalFrames = Math.floor((channelData.length - windowSize) / hopSize);

        if (totalFrames <= 0) {
            throw new Error('El archivo de audio es demasiado corto para el análisis.');
        }

        // 3. Matriz de frecuencias a pitch classes (filtro cromático)
        const chromaWeights = this._buildChromaFilterbank(windowSize, sampleRate);

        const rawChromagram = [];
        const globalChromaSum = new Array(12).fill(0);

        // Ventana Hann
        const hannWindow = new Float32Array(windowSize);
        for (let i = 0; i < windowSize; i++) {
            hannWindow[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (windowSize - 1)));
        }

        const bufferSlice = new Float32Array(windowSize);
        const real = new Float32Array(windowSize);
        const imag = new Float32Array(windowSize);

        for (let frame = 0; frame < totalFrames; frame++) {
            const offset = frame * hopSize;

            for (let i = 0; i < windowSize; i++) {
                real[i] = channelData[offset + i] * hannWindow[i];
                imag[i] = 0;
            }

            // FFT rápida
            this._fft(real, imag);

            // Espectro de magnitud
            const halfSize = windowSize / 2;
            const chroma = new Array(12).fill(0);

            for (let k = 1; k < halfSize; k++) {
                const mag = Math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
                const weights = chromaWeights[k];
                if (weights) {
                    for (let p = 0; p < 12; p++) {
                        chroma[p] += mag * weights[p];
                    }
                }
            }

            // Normalización L2 del vector croma
            const norm = Math.sqrt(chroma.reduce((acc, val) => acc + val * val, 0)) || 1e-6;
            const normalizedChroma = chroma.map(v => v / norm);

            rawChromagram.push(normalizedChroma);

            for (let p = 0; p < 12; p++) {
                globalChromaSum[p] += normalizedChroma[p];
            }

            if (onProgress && frame % 50 === 0) {
                onProgress(Math.round((frame / totalFrames) * 70));
            }
        }

        // 4. Detección de la Tonalidad Principal (Krumhansl-Schmuckler)
        const mainKey = this._detectGlobalKey(globalChromaSum);

        if (onProgress) onProgress(80);

        // 5. Detección de acordes cuadro a cuadro y segmentación
        const chords = this._segmentChords(rawChromagram, hopSize, sampleRate, mainKey);

        if (onProgress) onProgress(100);

        return {
            duration,
            mainKey,
            chords,
            chromagram: rawChromagram
        };
    }

    /**
     * Mezcla los canales de audio a un único arreglo mono Float32.
     * @private
     */
    _mixDownToMono(audioBuffer) {
        const numChannels = audioBuffer.numberOfChannels;
        const length = audioBuffer.length;
        const mono = new Float32Array(length);

        for (let c = 0; c < numChannels; c++) {
            const channel = audioBuffer.getChannelData(c);
            for (let i = 0; i < length; i++) {
                mono[i] += channel[i] / numChannels;
            }
        }
        return mono;
    }

    /**
     * Construye un banco de filtros mapeando cada bin de frecuencia FFT a las 12 clases de tono.
     * @private
     */
    _buildChromaFilterbank(fftSize, sampleRate) {
        const halfSize = fftSize / 2;
        const weights = new Array(halfSize);
        const binHz = sampleRate / fftSize;

        // Rango de análisis: de A0 (27.5 Hz) hasta B6 (~1975 Hz)
        const minFreq = 40;
        const maxFreq = 2200;

        for (let k = 1; k < halfSize; k++) {
            const freq = k * binHz;
            if (freq >= minFreq && freq <= maxFreq) {
                // Cálculo de número MIDI continuo
                const midi = 12 * Math.log2(freq / 440) + 69;
                const pitchClass = ((Math.round(midi) % 12) + 12) % 12;

                const deviation = Math.abs(midi - Math.round(midi));
                const weight = Math.exp(-0.5 * Math.pow(deviation / 0.35, 2));

                const vector = new Float32Array(12);
                vector[pitchClass] = weight;
                weights[k] = vector;
            } else {
                weights[k] = null;
            }
        }

        return weights;
    }

    /**
     * Implementación Cooley-Tukey Radix-2 FFT in-place.
     * @private
     */
    _fft(real, imag) {
        const n = real.length;
        let j = 0;

        for (let i = 0; i < n - 1; i++) {
            if (i < j) {
                const tr = real[i]; real[i] = real[j]; real[j] = tr;
                const ti = imag[i]; imag[i] = imag[j]; imag[j] = ti;
            }
            let k = n >> 1;
            while (k <= j) {
                j -= k;
                k >>= 1;
            }
            j += k;
        }

        for (let len = 2; len <= n; len <<= 1) {
            const half = len >> 1;
            const angle = -2 * Math.PI / len;
            const wStepR = Math.cos(angle);
            const wStepI = Math.sin(angle);

            for (let i = 0; i < n; i += len) {
                let wr = 1;
                let wi = 0;
                for (let k = 0; k < half; k++) {
                    const idxA = i + k;
                    const idxB = i + k + half;
                    const tr = wr * real[idxB] - wi * imag[idxB];
                    const ti = wr * imag[idxB] + wi * real[idxB];

                    real[idxB] = real[idxA] - tr;
                    imag[idxB] = imag[idxA] - ti;
                    real[idxA] += tr;
                    imag[idxA] += ti;

                    const nextWr = wr * wStepR - wi * wStepI;
                    wi = wr * wStepI + wi * wStepR;
                    wr = nextWr;
                }
            }
        }
    }

    /**
     * Deducirá la Tonalidad Principal de la canción mediante Krumhansl-Schmuckler.
     * @private
     */
    _detectGlobalKey(globalChroma) {
        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, 0);

        let bestScore = -Infinity;
        let bestRoot = 0;
        let bestMode = 'major';

        for (let r = 0; r < 12; r++) {
            // Rotar croma para alinear con la tónica candidata
            const rotated = [];
            for (let i = 0; i < 12; i++) {
                rotated.push(globalChroma[(i + r) % 12]);
            }

            const scoreMaj = this._pearsonCorrelation(rotated, KRUMHANSL_MAJOR);
            if (scoreMaj > bestScore) {
                bestScore = scoreMaj;
                bestRoot = r;
                bestMode = 'major';
            }

            const scoreMin = this._pearsonCorrelation(rotated, KRUMHANSL_MINOR);
            if (scoreMin > bestScore) {
                bestScore = scoreMin;
                bestRoot = r;
                bestMode = 'minor';
            }
        }

        const rootLat = arrLat[bestRoot];
        const rootAle = arrAle[bestRoot];
        const modeLabelLat = bestMode === 'major' ? 'Mayor' : 'Menor';
        const modeLabelAle = bestMode === 'major' ? 'Major' : 'Minor';

        // Recomendar hilera o afinación de acordeón adecuada para esta tonalidad
        const recommendation = this._recommendAccordionTuning(bestRoot, bestMode);

        return {
            rootMod: bestRoot,
            mode: bestMode,
            keyNameLat: `${rootLat} ${modeLabelLat}`,
            keyNameAle: `${rootAle} ${modeLabelAle}`,
            recommendedTuning: recommendation.tuningName,
            recommendedOffset: recommendation.offset,
            recommendedRow: recommendation.rowKey,
            correlation: Math.round(bestScore * 100) / 100
        };
    }

    /**
     * Sugiere la afinación e hilera idónea de acordeón vallenato/diatónico para una tonalidad dada.
     * @private
     */
    _recommendAccordionTuning(rootMod, mode) {
        // Mapeo de tónicas de hilera para afinaciones estándar
        // Cinco Letras (offset 0): row1 = Bb (10), row2 = Eb (3), row3 = Ab (8)
        // Rey Vallenato (offset -3): row1 = G (7), row2 = C (0), row3 = F (5)
        // Guacamayo (offset -1): row1 = A (9), row2 = D (2), row3 = G (7)
        // Sabanera (offset 2): row1 = C (0), row2 = F (5), row3 = Bb (10)

        const tunings = tuningRegistry.getAll();
        for (let t of tunings) {
            const r1 = (ROW_BASE_TONICS.row1 + t.offset) % 12;
            const r2 = (ROW_BASE_TONICS.row2 + t.offset) % 12;
            const r3 = (ROW_BASE_TONICS.row3 + t.offset) % 12;

            if (rootMod === r2) {
                return { tuningName: t.name, offset: t.offset, rowKey: 'row2' };
            }
            if (rootMod === r1) {
                return { tuningName: t.name, offset: t.offset, rowKey: 'row1' };
            }
            if (rootMod === r3) {
                return { tuningName: t.name, offset: t.offset, rowKey: 'row3' };
            }
        }

        // Por defecto Cinco Letras
        return { tuningName: 'Cinco Letras (Bb-Eb-Ab)', offset: 0, rowKey: 'row2' };
    }

    /**
     * Calcula el coeficiente de correlación de Pearson entre dos vectores.
     * @private
     */
    _pearsonCorrelation(x, y) {
        const n = x.length;
        let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;

        for (let i = 0; i < n; i++) {
            sumX += x[i];
            sumY += y[i];
            sumXY += x[i] * y[i];
            sumX2 += x[i] * x[i];
            sumY2 += y[i] * y[i];
        }

        const numerator = n * sumXY - sumX * sumY;
        const denominator = Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
        return denominator === 0 ? 0 : numerator / denominator;
    }

    /**
     * Segmenta el chromagram cuadro a cuadro en bloques de acordes audibles.
     * @private
     */
    _segmentChords(chromagram, hopSize, sampleRate, mainKey) {
        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, 0);

        // Definición de perfiles de acordes fundamentales
        const chordProfiles = [
            { type: 'maj', symbol: '', name: 'Mayor', intervals: [0, 4, 7], weightProfile: [1.0, 0, 0, 0, 0.8, 0, 0, 0.7, 0, 0, 0, 0] },
            { type: 'min', symbol: 'm', name: 'Menor', intervals: [0, 3, 7], weightProfile: [1.0, 0, 0, 0.8, 0, 0, 0, 0.7, 0, 0, 0, 0] },
            { type: 'dom7', symbol: '7', name: '7ma', intervals: [0, 4, 7, 10], weightProfile: [1.0, 0, 0, 0, 0.75, 0, 0, 0.65, 0, 0, 0.6, 0] },
            { type: 'dim', symbol: 'dim', name: 'Dism.', intervals: [0, 3, 6], weightProfile: [1.0, 0, 0, 0.8, 0, 0, 0.7, 0, 0, 0, 0, 0] }
        ];

        const frameDuration = hopSize / sampleRate;
        const frameDetections = [];

        for (let i = 0; i < chromagram.length; i++) {
            const chroma = chromagram[i];
            let bestScore = -Infinity;
            let bestRoot = 0;
            let bestProfile = chordProfiles[0];

            for (let root = 0; root < 12; root++) {
                chordProfiles.forEach(prof => {
                    let score = 0;
                    for (let interval = 0; interval < 12; interval++) {
                        const noteIdx = (root + interval) % 12;
                        const weight = prof.weightProfile[interval];
                        score += chroma[noteIdx] * weight;
                    }

                    // Ligera bonificación a acordes que pertenecen a la tonalidad principal
                    if (root === mainKey.rootMod || (root === (mainKey.rootMod + 7) % 12) || (root === (mainKey.rootMod + 5) % 12)) {
                        score *= 1.08;
                    }

                    if (score > bestScore) {
                        bestScore = score;
                        bestRoot = root;
                        bestProfile = prof;
                    }
                });
            }

            frameDetections.push({
                rootMod: bestRoot,
                quality: bestProfile.type,
                chordName: `${arrLat[bestRoot]} ${bestProfile.name}`,
                chordSymbol: `${arrAle[bestRoot]}${bestProfile.symbol}`,
                noteMods: bestProfile.intervals.map(int => (bestRoot + int) % 12),
                confidence: Math.min(1.0, Math.max(0.2, bestScore / 2.5))
            });
        }

        // Filtro de suavizado (mediana temporal sobre ~3-4 frames para evitar oscilaciones)
        const smoothedFrames = this._smoothDetections(frameDetections);

        // Segmentar en bloques con inicio y fin continuos
        const segments = [];
        if (smoothedFrames.length === 0) return segments;

        let currentSegment = {
            ...smoothedFrames[0],
            startTime: 0,
            endTime: frameDuration
        };

        for (let i = 1; i < smoothedFrames.length; i++) {
            const frame = smoothedFrames[i];
            const isSameChord = frame.rootMod === currentSegment.rootMod && frame.quality === currentSegment.quality;

            if (isSameChord) {
                currentSegment.endTime = (i + 1) * frameDuration;
            } else {
                // Descartar segmentos ultra-cortos de ruido (< 0.25s) si hay suficiente contexto
                if (currentSegment.endTime - currentSegment.startTime >= 0.25 || segments.length === 0) {
                    segments.push(currentSegment);
                }
                currentSegment = {
                    ...frame,
                    startTime: i * frameDuration,
                    endTime: (i + 1) * frameDuration
                };
            }
        }

        segments.push(currentSegment);
        return segments;
    }

    /**
     * Aplica suavizado sobre los frames adyacentes.
     * @private
     */
    _smoothDetections(frames) {
        const result = [];
        const windowSize = 3;

        for (let i = 0; i < frames.length; i++) {
            const start = Math.max(0, i - Math.floor(windowSize / 2));
            const end = Math.min(frames.length, i + Math.ceil(windowSize / 2));

            const votes = {};
            for (let j = start; j < end; j++) {
                const key = `${frames[j].rootMod}_${frames[j].quality}`;
                votes[key] = (votes[key] || 0) + 1;
            }

            let maxVotes = 0;
            let winnerKey = `${frames[i].rootMod}_${frames[i].quality}`;
            for (let k in votes) {
                if (votes[k] > maxVotes) {
                    maxVotes = votes[k];
                    winnerKey = k;
                }
            }

            const winnerFrame = frames.slice(start, end).find(f => `${f.rootMod}_${f.quality}` === winnerKey) || frames[i];
            result.push(winnerFrame);
        }

        return result;
    }
}
