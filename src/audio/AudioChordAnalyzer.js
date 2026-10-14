/**
 * @fileoverview Analizador de Audio, Detección de Acordes y Tonalidad Principal (SRP).
 * Procesa archivos MP3/WAV mediante Web Audio API, genera perfiles cromáticos de doble banda (Chromagram),
 * detecta acordes en la línea de tiempo con supresión de armónicos parásitos y deduce la tonalidad
 * principal mediante correlación dual (Krumhansl-Kessler & Temperley).
 * @module audio/AudioChordAnalyzer
 */

import { CHORD_TEMPLATES } from '../theory/ChordTemplates.js';
import { getPitchClass, getNoteNamesList } from '../theory/MusicTheory.js';
import { NOTATION_MODES, ROW_BASE_TONICS } from '../core/Constants.js';
import { tuningRegistry } from '../models/Tunings.js';

// Perfiles Krumhansl-Kessler para estimación de tonalidad
const KRUMHANSL_MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
const KRUMHANSL_MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];

// Perfiles David Temperley (1999) para validación armónica cruzada
const TEMPERLEY_MAJOR = [5.0, 2.0, 3.5, 2.0, 4.5, 4.0, 2.0, 4.5, 2.0, 3.5, 1.5, 4.0];
const TEMPERLEY_MINOR = [5.0, 2.0, 3.5, 4.5, 2.0, 4.0, 2.0, 4.5, 3.5, 2.0, 1.5, 4.0];

/**
 * @typedef {Object} DetectedChordSegment
 * @property {number} startTime Tiempo de inicio en segundos
 * @property {number} endTime Tiempo de fin en segundos
 * @property {number} rootMod Pitch class de la tónica (0-11)
 * @property {string} quality Calidad ('maj', 'min', 'dom7', etc.)
 * @property {string} chordName Nombre en notación latina
 * @property {string} chordSymbol Cifrado anglosajón / alemán
 * @property {number[]} noteMods Pitch classes de las notas del acorde
 * @property {number[]} playbackMidis Notas MIDI sintetizadas para reproducción
 * @property {number} confidence Confianza estadística (0.0 a 1.0)
 */

/**
 * @typedef {Object} KeyDetectionResult
 * @property {number} rootMod Pitch class de la tónica (0-11)
 * @property {string} mode 'major' o 'minor'
 * @property {string} keyNameLat Nombre en español (ej: "Sol Mayor", "La Menor")
 * @property {string} keyNameAle Nombre en cifrado (ej: "G Major", "A Minor")
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
     * Analiza un AudioBuffer y genera la línea de acordes y tonalidad principal con precisión avanzada.
     * @param {AudioBuffer} audioBuffer
     * @param {(progress: number) => void} [onProgress] Callback de progreso (0 a 100)
     * @returns {Promise<AudioAnalysisReport>}
     */
    async analyze(audioBuffer, onProgress) {
        const sampleRate = audioBuffer.sampleRate;
        const duration = audioBuffer.duration;

        // 1. Mezcla a canal mono Float32
        const channelData = this._mixDownToMono(audioBuffer);

        // 2. Parámetros de ventana para análisis espectral (alta resolución)
        const windowSize = 4096;
        const hopSize = 2048;
        const totalFrames = Math.floor((channelData.length - windowSize) / hopSize);

        if (totalFrames <= 0) {
            throw new Error('El archivo de audio es demasiado corto para el análisis.');
        }

        // 3. Matriz de filtros cromáticos dividida en Bajo (50-260Hz) y Armonía (260-2200Hz)
        const filterbank = this._buildChromaFilterbank(windowSize, sampleRate);

        const rawChromagram = [];
        const rawBassChromagram = [];
        const rawHarmonyChromagram = [];
        const globalChromaSum = new Array(12).fill(0);

        // Ventana Hann precalculada
        const hannWindow = new Float32Array(windowSize);
        for (let i = 0; i < windowSize; i++) {
            hannWindow[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (windowSize - 1)));
        }

        const real = new Float32Array(windowSize);
        const imag = new Float32Array(windowSize);
        const halfSize = windowSize / 2;

        for (let frame = 0; frame < totalFrames; frame++) {
            const offset = frame * hopSize;

            for (let i = 0; i < windowSize; i++) {
                real[i] = channelData[offset + i] * hannWindow[i];
                imag[i] = 0;
            }

            // FFT rápida Radix-2
            this._fft(real, imag);

            const frameBass = new Float32Array(12);
            const frameHarmony = new Float32Array(12);

            for (let k = 1; k < halfSize; k++) {
                const mag = Math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
                // Compresión logarítmica de magnitud (spectral whitening)
                // Evita que percusión o transitorios ruidosos apaguen notas musicales
                const logMag = Math.log1p(75 * mag);

                const binInfo = filterbank[k];
                if (binInfo) {
                    const energy = logMag * binInfo.weight;
                    if (binInfo.isBass) {
                        frameBass[binInfo.pitchClass] += energy;
                    } else {
                        frameHarmony[binInfo.pitchClass] += energy;
                    }
                }
            }

            // Normalización L2 de cada vector
            const normBass = Math.sqrt(frameBass.reduce((acc, v) => acc + v * v, 0)) || 1e-6;
            const normHarm = Math.sqrt(frameHarmony.reduce((acc, v) => acc + v * v, 0)) || 1e-6;

            const normBassVector = Array.from(frameBass).map(v => v / normBass);
            const normHarmVector = Array.from(frameHarmony).map(v => v / normHarm);

            // Vector cromático compuesto: 35% peso de bajo + 65% armonía
            const combinedChroma = new Array(12);
            for (let p = 0; p < 12; p++) {
                combinedChroma[p] = (0.35 * normBassVector[p]) + (0.65 * normHarmVector[p]);
                globalChromaSum[p] += combinedChroma[p];
            }

            rawChromagram.push(combinedChroma);
            rawBassChromagram.push(normBassVector);
            rawHarmonyChromagram.push(normHarmVector);

            if (onProgress && frame % 40 === 0) {
                onProgress(Math.round((frame / totalFrames) * 65));
            }
        }

        // 4. Detección automática de BPM (Tempo) mediante análisis espectral y autocorrelación
        const bpm = this._detectBPM(channelData, sampleRate);

        // 5. Detección de la Tonalidad Principal mediante Correlación Dual (Krumhansl + Temperley)
        const mainKey = this._detectGlobalKey(globalChromaSum);

        if (onProgress) onProgress(80);

        // 6. Detección de acordes cuadro a cuadro con refuerzo de bajo y supresión de notas ajenas
        const chords = this._segmentChords(
            rawChromagram,
            rawBassChromagram,
            rawHarmonyChromagram,
            hopSize,
            sampleRate,
            mainKey
        );

        if (onProgress) onProgress(100);

        return {
            duration,
            bpm,
            mainKey,
            chords,
            chromagram: rawChromagram
        };
    }

    /**
     * Transpone matemáticamente un reporte de análisis musical por un desplazamiento de semitonos.
     * Permite cambiar la tonalidad y los acordes instantáneamente sin reprocesar el audio.
     * @param {AudioAnalysisReport} report
     * @param {number} semitoneShift (-12 a +12)
     * @returns {AudioAnalysisReport}
     */
    transposeReport(report, semitoneShift) {
        if (!report || semitoneShift === 0) return report;

        const shift = ((semitoneShift % 12) + 12) % 12;
        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, 0);

        // 1. Transponer tonalidad principal
        const newRoot = (report.mainKey.rootMod + shift) % 12;
        const mode = report.mainKey.mode;
        const modeLabelLat = mode === 'major' ? 'Mayor' : 'Menor';
        const modeLabelAle = mode === 'major' ? 'Major' : 'Minor';

        const recommendation = this._recommendAccordionTuning(newRoot, mode);

        const newMainKey = {
            rootMod: newRoot,
            mode,
            keyNameLat: `${arrLat[newRoot]} ${modeLabelLat}`,
            keyNameAle: `${arrAle[newRoot]} ${modeLabelAle}`,
            recommendedTuning: recommendation.tuningName,
            recommendedOffset: recommendation.offset,
            recommendedRow: recommendation.rowKey,
            correlation: report.mainKey.correlation,
            originalKeyLat: report.mainKey.originalKeyLat || report.mainKey.keyNameLat,
            pitchShift: semitoneShift
        };

        // 2. Transponer cada segmento de acorde cronológico (incluye acordes editados manualmente)
        const editorTypeToQuality = { minor: 'min', '7': 'dom7', m7: 'min7', dim: 'dim', aug: 'aug', sus4: 'sus4', sus2: 'sus2', major: 'maj' };
        const transposedChords = report.chords.map(seg => {
            const baseRoot = typeof seg.rootMod === 'number' ? seg.rootMod : (typeof seg.root === 'number' ? seg.root : 0);
            const rootTransposed = (baseRoot + shift) % 12;
            const noteModsTransposed = (seg.noteMods || []).map(n => (n + shift) % 12);
            const playbackMidisTransposed = (seg.playbackMidis || []).map(m => m + semitoneShift);
            const quality = seg.quality || editorTypeToQuality[seg.chordType] || 'maj';

            // Reconstruir nombre y símbolo
            let qualitySuffix = '';
            let symbolSuffix = '';
            switch (quality) {
                case 'min': qualitySuffix = 'Menor'; symbolSuffix = 'm'; break;
                case 'dom7': qualitySuffix = '7ma'; symbolSuffix = '7'; break;
                case 'min7': qualitySuffix = 'Menor 7ma'; symbolSuffix = 'm7'; break;
                case 'maj7': qualitySuffix = 'Mayor 7ma'; symbolSuffix = 'Maj7'; break;
                case 'dim': qualitySuffix = 'Dism.'; symbolSuffix = 'dim'; break;
                case 'aug': qualitySuffix = 'Aum.'; symbolSuffix = 'aug'; break;
                case 'sus4': qualitySuffix = 'Sus4'; symbolSuffix = 'sus4'; break;
                case 'sus2': qualitySuffix = 'Sus2'; symbolSuffix = 'sus2'; break;
                default: qualitySuffix = 'Mayor'; symbolSuffix = ''; break;
            }

            const transposed = {
                ...seg,
                rootMod: rootTransposed,
                chordName: `${arrLat[rootTransposed]} ${qualitySuffix}`,
                chordSymbol: `${arrAle[rootTransposed]}${symbolSuffix}`,
                noteMods: noteModsTransposed,
                playbackMidis: playbackMidisTransposed
            };
            if (typeof seg.root === 'number') transposed.root = rootTransposed;
            if (typeof seg.bassNote === 'number') transposed.bassNote = (seg.bassNote + shift) % 12;
            return transposed;
        });

        return {
            duration: report.duration,
            bpm: report.bpm,
            mainKey: newMainKey,
            chords: transposedChords,
            chromagram: report.chromagram
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
     * Construye un banco de filtros mapeando cada bin de frecuencia FFT a las 12 clases de tono
     * con clasificación de banda de bajo vs armonía.
     * @private
     */
    _buildChromaFilterbank(fftSize, sampleRate) {
        const halfSize = fftSize / 2;
        const bank = new Array(halfSize);
        const binHz = sampleRate / fftSize;

        const minFreq = 45; // ~F#1
        const maxFreq = 2400; // ~D7
        const bassCutoff = 260; // Separación de bajo (C4)

        for (let k = 1; k < halfSize; k++) {
            const freq = k * binHz;
            if (freq >= minFreq && freq <= maxFreq) {
                const midi = 12 * Math.log2(freq / 440) + 69;
                const roundedMidi = Math.round(midi);
                const pitchClass = ((roundedMidi % 12) + 12) % 12;

                const deviation = Math.abs(midi - roundedMidi);
                // Campana gaussiana alrededor del semitono exacto
                const weight = Math.exp(-0.5 * Math.pow(deviation / 0.32, 2));

                bank[k] = {
                    pitchClass,
                    weight,
                    isBass: freq < bassCutoff
                };
            } else {
                bank[k] = null;
            }
        }

        return bank;
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
     * Deducirá la Tonalidad Principal mediante Correlación Dual (Krumhansl-Schmuckler + Temperley).
     * @private
     */
    _detectGlobalKey(globalChroma) {
        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, 0);

        let bestScore = -Infinity;
        let bestRoot = 0;
        let bestMode = 'major';

        for (let r = 0; r < 12; r++) {
            const rotated = [];
            for (let i = 0; i < 12; i++) {
                rotated.push(globalChroma[(i + r) % 12]);
            }

            // 1. Correlación Krumhansl
            const scoreKrumMaj = this._pearsonCorrelation(rotated, KRUMHANSL_MAJOR);
            const scoreKrumMin = this._pearsonCorrelation(rotated, KRUMHANSL_MINOR);

            // 2. Correlación Temperley
            const scoreTempMaj = this._pearsonCorrelation(rotated, TEMPERLEY_MAJOR);
            const scoreTempMin = this._pearsonCorrelation(rotated, TEMPERLEY_MINOR);

            // Puntuación combinada (promedio ponderado de ambos modelos)
            const combinedMaj = (0.55 * scoreKrumMaj) + (0.45 * scoreTempMaj);
            const combinedMin = (0.55 * scoreKrumMin) + (0.45 * scoreTempMin);

            // Bonificación por energía en tríada de tónica (I) y dominante (V)
            const tonicEnergy = rotated[0] + rotated[4] + rotated[7];
            const tonicBonus = tonicEnergy / (rotated.reduce((a, b) => a + b, 0) || 1);

            const totalScoreMaj = combinedMaj + (tonicBonus * 0.15);
            const totalScoreMin = combinedMin + ((rotated[0] + rotated[3] + rotated[7]) / (rotated.reduce((a, b) => a + b, 0) || 1) * 0.15);

            if (totalScoreMaj > bestScore) {
                bestScore = totalScoreMaj;
                bestRoot = r;
                bestMode = 'major';
            }

            if (totalScoreMin > bestScore) {
                bestScore = totalScoreMin;
                bestRoot = r;
                bestMode = 'minor';
            }
        }

        const rootLat = arrLat[bestRoot];
        const rootAle = arrAle[bestRoot];
        const modeLabelLat = bestMode === 'major' ? 'Mayor' : 'Menor';
        const modeLabelAle = bestMode === 'major' ? 'Major' : 'Minor';

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
    _segmentChords(chromagram, bassChromagram, harmonyChromagram, hopSize, sampleRate, mainKey) {
        const arrLat = getNoteNamesList(NOTATION_MODES.LATINA, 0);
        const arrAle = getNoteNamesList(NOTATION_MODES.ALEMANA, 0);

        // Perfiles de acordes con pesos positivos para notas del acorde y penalizaciones para notas disonantes
        const chordProfiles = [
            { type: 'maj', symbol: '', name: 'Mayor', intervals: [0, 4, 7], nonIntervals: [1, 2, 3, 5, 6, 8, 9, 10, 11] },
            { type: 'min', symbol: 'm', name: 'Menor', intervals: [0, 3, 7], nonIntervals: [1, 2, 4, 5, 6, 8, 9, 10, 11] },
            { type: 'dom7', symbol: '7', name: '7ma', intervals: [0, 4, 7, 10], nonIntervals: [1, 2, 3, 5, 6, 8, 9, 11] },
            { type: 'min7', symbol: 'm7', name: 'Menor 7ma', intervals: [0, 3, 7, 10], nonIntervals: [1, 2, 4, 5, 6, 8, 9, 11] },
            { type: 'maj7', symbol: 'Maj7', name: 'Mayor 7ma', intervals: [0, 4, 7, 11], nonIntervals: [1, 2, 3, 5, 6, 8, 9, 10] },
            { type: 'sus4', symbol: 'sus4', name: 'Sus4', intervals: [0, 5, 7], nonIntervals: [1, 2, 3, 4, 6, 8, 9, 10, 11] },
            { type: 'dim', symbol: 'dim', name: 'Dism.', intervals: [0, 3, 6], nonIntervals: [1, 2, 4, 5, 7, 8, 9, 10, 11] }
        ];

        const frameDuration = hopSize / sampleRate;
        const frameDetections = [];

        for (let i = 0; i < chromagram.length; i++) {
            const chroma = chromagram[i];
            const bass = bassChromagram[i] || chroma;
            const harmony = harmonyChromagram[i] || chroma;

            let bestScore = -Infinity;
            let bestRoot = 0;
            let bestProfile = chordProfiles[0];

            for (let root = 0; root < 12; root++) {
                chordProfiles.forEach(prof => {
                    let harmonyScore = 0;

                    // Energía en las notas del acorde
                    prof.intervals.forEach((interval, idx) => {
                        const noteIdx = (root + interval) % 12;
                        const weight = idx === 0 ? 1.3 : (idx === 1 ? 1.1 : 0.95);
                        harmonyScore += harmony[noteIdx] * weight;
                    });

                    // Penalización por energía en notas disonantes fuera del acorde
                    let penalty = 0;
                    prof.nonIntervals.forEach(interval => {
                        const noteIdx = (root + interval) % 12;
                        penalty += harmony[noteIdx] * 0.38;
                    });

                    // Refuerzo del bajo (la tónica en el registro grave tiene un valor fundamental)
                    const bassMatch = (bass[root] * 0.70) + (bass[(root + 7) % 12] * 0.20);

                    let score = harmonyScore - penalty + bassMatch;

                    // Bonificación armónica según grados tonales (I, IV, V, vi, ii)
                    const isTonic = root === mainKey.rootMod;
                    const isDominant = root === (mainKey.rootMod + 7) % 12;
                    const isSubdominant = root === (mainKey.rootMod + 5) % 12;
                    const isRelative = root === (mainKey.rootMod + 9) % 12;

                    if (isTonic) score *= 1.15;
                    else if (isDominant || isSubdominant) score *= 1.10;
                    else if (isRelative) score *= 1.06;

                    if (score > bestScore) {
                        bestScore = score;
                        bestRoot = root;
                        bestProfile = prof;
                    }
                });
            }

            // Construir voicings completos para reproducción fluida: Bajo en octava 3 + tríada/cuatríada en octava 4
            const bassMidi = 48 + bestRoot;
            const upperMidis = bestProfile.intervals.map(int => 60 + bestRoot + int);
            const playbackMidis = [bassMidi, ...upperMidis];

            frameDetections.push({
                rootMod: bestRoot,
                quality: bestProfile.type,
                chordName: `${arrLat[bestRoot]} ${bestProfile.name}`,
                chordSymbol: `${arrAle[bestRoot]}${bestProfile.symbol}`,
                noteMods: bestProfile.intervals.map(int => (bestRoot + int) % 12),
                playbackMidis,
                confidence: Math.min(1.0, Math.max(0.2, bestScore / 2.6))
            });
        }

        // Suavizado temporal mejorado (ventana mediana de 7 frames ~350ms)
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
                // Filtrar micro-oscilaciones de ruido (< 0.35s) para garantizar bloques armónicos estables
                if (currentSegment.endTime - currentSegment.startTime >= 0.35 || segments.length === 0) {
                    segments.push(currentSegment);
                } else if (segments.length > 0) {
                    segments[segments.length - 1].endTime = currentSegment.endTime;
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
     * Aplica filtro de mayoría sobre los frames adyacentes para una línea armónica fluida.
     * @private
     */
    _smoothDetections(frames) {
        const result = [];
        const windowSize = 7;

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

    /**
     * Identifica el tempo (BPM) del audio mediante análisis de envolvente espectral,
     * picos de energía (onsets) y autocorrelación en el rango musical de 60 a 190 BPM.
     * @private
     * @param {Float32Array} channelData
     * @param {number} sampleRate
     * @returns {number} BPM detectado
     */
    _detectBPM(channelData, sampleRate) {
        if (!channelData || channelData.length === 0) return 120;

        // Tamaño de bloque para la envolvente de energía: ~23ms (1024 muestras a 44.1kHz)
        const frameSize = 1024;
        const numFrames = Math.floor(channelData.length / frameSize);
        if (numFrames < 60) return 120;

        const energy = new Float32Array(numFrames);
        for (let i = 0; i < numFrames; i++) {
            let sum = 0;
            const offset = i * frameSize;
            for (let j = 0; j < frameSize; j += 4) {
                const val = channelData[offset + j];
                sum += val * val;
            }
            energy[i] = Math.sqrt(sum);
        }

        // Onset envelope (diferencia positiva de energía)
        const onsets = new Float32Array(numFrames);
        for (let i = 1; i < numFrames; i++) {
            const diff = energy[i] - energy[i - 1];
            onsets[i] = diff > 0 ? diff : 0;
        }

        // Normalizar onsets
        let maxOnset = 0;
        for (let i = 0; i < numFrames; i++) {
            if (onsets[i] > maxOnset) maxOnset = onsets[i];
        }
        if (maxOnset > 0) {
            for (let i = 0; i < numFrames; i++) onsets[i] /= maxOnset;
        }

        const framesPerSec = sampleRate / frameSize;
        const minBpm = 65;
        const maxBpm = 185;
        const minLag = Math.floor((60 / maxBpm) * framesPerSec);
        const maxLag = Math.ceil((60 / minBpm) * framesPerSec);

        // Muestrear hasta 90 segundos para alta representatividad rítmica sin demora
        const maxAnalysisFrames = Math.min(numFrames - maxLag, Math.floor(framesPerSec * 90));
        if (maxAnalysisFrames <= 0) return 120;

        let bestLag = minLag;
        let bestCorr = -Infinity;

        for (let lag = minLag; lag <= maxLag; lag++) {
            let corr = 0;
            for (let i = 0; i < maxAnalysisFrames; i++) {
                corr += onsets[i] * onsets[i + lag];
            }
            if (corr > bestCorr) {
                bestCorr = corr;
                bestLag = lag;
            }
        }

        let bpm = Math.round((60 * framesPerSec) / bestLag);

        // Ajuste armónico de octava rítmica al rango de canciones vallenatas / populares (75 - 165 BPM)
        if (bpm < 70) bpm *= 2;
        if (bpm > 180) bpm = Math.round(bpm / 2);

        return bpm || 120;
    }
}

export const audioChordAnalyzer = new AudioChordAnalyzer();
export default AudioChordAnalyzer;
