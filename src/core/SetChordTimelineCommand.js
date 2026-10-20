/**
 * @fileoverview Comando para Modificación de Línea de Tiempo de Acordes (Command Pattern).
 * Encapsula la transición entre el estado previo de acordes y el nuevo estado.
 * @module core/SetChordTimelineCommand
 */

export class SetChordTimelineCommand {
    /**
     * @param {Object} options
     * @param {Array} options.previousChords Estado anterior de la lista de acordes
     * @param {Array} options.nextChords Nuevo estado de la lista de acordes
     * @param {Function} options.applyFn Callback para aplicar el estado a AudioTrackView y AudioPlayerController
     * @param {string} [options.description='Edición de acordes'] Descripción legible de la acción
     */
    constructor(options) {
        this._previousChords = JSON.parse(JSON.stringify(options.previousChords || []));
        this._nextChords = JSON.parse(JSON.stringify(options.nextChords || []));
        this._applyFn = options.applyFn;
        this.description = options.description || 'Edición de acordes';
    }

    /**
     * Aplica el nuevo conjunto de acordes.
     */
    execute() {
        if (typeof this._applyFn === 'function') {
            this._applyFn(JSON.parse(JSON.stringify(this._nextChords)));
        }
    }

    /**
     * Revierte al conjunto anterior de acordes.
     */
    undo() {
        if (typeof this._applyFn === 'function') {
            this._applyFn(JSON.parse(JSON.stringify(this._previousChords)));
        }
    }
}
