/**
 * @fileoverview Gestor de Comandos para Deshacer / Rehacer (Command Pattern).
 * Mantiene un historial de acciones reversibles aplicadas sobre la cuadrícula de compases
 * o el estado de la aplicación.
 * @module core/CommandManager
 */

export class CommandManager {
    /**
     * @param {number} [maxHistory=50] Límite de acciones en la pila de historial
     */
    constructor(maxHistory = 50) {
        this._undoStack = [];
        this._redoStack = [];
        this._maxHistory = maxHistory;
        this._onStateChange = null;
    }

    /**
     * Registra un listener al cambiar la disponibilidad de undo/redo.
     * @param {Function} callback
     */
    setOnStateChange(callback) {
        this._onStateChange = callback;
    }

    /**
     * Ejecuta un comando y lo apila en el historial de deshacer.
     * @param {Object} command Objeto comando con métodos execute() y undo()
     */
    execute(command) {
        if (!command || typeof command.execute !== 'function' || typeof command.undo !== 'function') {
            throw new Error('El comando debe implementar execute() y undo()');
        }

        command.execute();
        this._undoStack.push(command);
        if (this._undoStack.length > this._maxHistory) {
            this._undoStack.shift();
        }
        this._redoStack = []; // Se limpia la pila de rehacer ante una nueva acción
        this._notify();
    }

    /**
     * Deshace la última acción ejecutada.
     * @returns {boolean} True si se pudo deshacer, false si no hay historial
     */
    undo() {
        if (!this.canUndo()) return false;
        const command = this._undoStack.pop();
        command.undo();
        this._redoStack.push(command);
        this._notify();
        return true;
    }

    /**
     * Rehace la última acción deshecha.
     * @returns {boolean} True si se pudo rehacer, false si no hay acciones
     */
    redo() {
        if (!this.canRedo()) return false;
        const command = this._redoStack.pop();
        command.execute();
        this._undoStack.push(command);
        this._notify();
        return true;
    }

    /**
     * @returns {boolean}
     */
    canUndo() {
        return this._undoStack.length > 0;
    }

    /**
     * @returns {boolean}
     */
    canRedo() {
        return this._redoStack.length > 0;
    }

    /**
     * Limpia ambas pilas de comandos.
     */
    clear() {
        this._undoStack = [];
        this._redoStack = [];
        this._notify();
    }

    /**
     * @private
     */
    _notify() {
        if (typeof this._onStateChange === 'function') {
            this._onStateChange({
                canUndo: this.canUndo(),
                canRedo: this.canRedo(),
                undoCount: this._undoStack.length,
                redoCount: this._redoStack.length
            });
        }
    }
}

export const commandManager = new CommandManager();
