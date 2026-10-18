/**
 * @fileoverview Puente de integración WebAssembly para el motor de detección de acordes en Rust.
 * Carga el módulo WASM compilado desde `src/audio/wasm_pkg/` y expone métodos de alta velocidad
 * para análisis FFT, cromagrama, tonalidad y acordes.
 * @module audio/WasmChordBridge
 */

export class WasmChordBridge {
    constructor() {
        this._isReady = false;
        this._wasmModule = null;
        this._initPromise = null;
    }

    /**
     * Intenta inicializar el módulo WASM de Rust.
     * Si no está compilado aún, retorna false para permitir fallback transparente a JS.
     * @returns {Promise<boolean>}
     */
    async init() {
        if (this._isReady) return true;
        if (this._initPromise) return this._initPromise;

        this._initPromise = (async () => {
            try {
                // Import dinámico del archivo generado por wasm-pack
                const wasmPkg = await import('./wasm_pkg/chord_detector.js');
                if (wasmPkg && typeof wasmPkg.default === 'function') {
                    // Inicializar el WebAssembly binario (.wasm)
                    await wasmPkg.default();
                    if (typeof wasmPkg.is_wasm_ready === 'function' && wasmPkg.is_wasm_ready()) {
                        this._wasmModule = wasmPkg;
                        this._isReady = true;
                        console.info('🚀 [Rust WASM] Motor de detección de acordes en Rust cargado y activo con éxito.');
                        return true;
                    }
                }
            } catch (err) {
                // No se encontró el binario o no ha sido compilado con wasm-pack
                console.warn('ℹ️ [Rust WASM] El módulo WebAssembly no está presente o no ha sido compilado. Se utilizará el motor JS integrado como fallback.', err.message || err);
            }
            this._isReady = false;
            return false;
        })();

        return this._initPromise;
    }

    /**
     * Indica si el motor de Rust (WebAssembly) está listo para ejecutar.
     * @returns {boolean}
     */
    isReady() {
        return this._isReady;
    }

    /**
     * Ejecuta el análisis completo del audio en Rust (WASM).
     * @param {Float32Array} channelData Muestras de audio mono
     * @param {number} sampleRate Frecuencia de muestreo (ej: 44100)
     * @returns {Object} Reporte armónico completo
     */
    analyze(channelData, sampleRate) {
        if (!this._isReady || !this._wasmModule) {
            throw new Error('El módulo WebAssembly en Rust no está inicializado.');
        }

        // Llamada directa a Rust mediante wasm-bindgen
        const report = this._wasmModule.analyze_audio(channelData, sampleRate);
        return report;
    }

    /**
     * Detección directa de BPM en Rust.
     * @param {Float32Array} channelData
     * @param {number} sampleRate
     * @returns {number} BPM
     */
    detectBpm(channelData, sampleRate) {
        if (!this._isReady || !this._wasmModule) {
            return 120;
        }
        return this._wasmModule.detect_bpm_wasm(channelData, sampleRate);
    }
}

export const wasmChordBridge = new WasmChordBridge();
