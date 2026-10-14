/**
 * @fileoverview Autómata de Estados para la dirección del fuelle (Patrón State).
 * Evita condicionales anidados y centraliza las transiciones de estado de ejecución.
 * @module core/StateMachine
 */

import { BELLOWS_MODES } from './Constants.js';
import { eventBus } from './EventBus.js';

/**
 * Interfaz base para un estado de fuelle.
 * @abstract
 */
class BellowsState {
    /**
     * @param {BellowsStateMachine} machine
     */
    constructor(machine) {
        this.machine = machine;
    }

    /**
     * @abstract
     * @returns {string} Identificador del modo (push, pull, both).
     */
    getMode() {
        throw new Error('Método abstracto getMode() no implementado.');
    }

    /**
     * Evalúa si una dirección requerida es ejecutable en el estado actual.
     * @param {'push'|'pull'} direction
     * @returns {boolean}
     */
    canExecute(direction) {
        return false;
    }

    /**
     * Resuelve cuál nota MIDI ejecutar según el estado y los datos del botón.
     * @param {{ push: number, pull: number }} button
     * @param {boolean} isSecondaryClick Si se usó clic derecho / acción secundaria.
     * @returns {number}
     */
    resolveMidi(button, isSecondaryClick = false) {
        throw new Error('Método abstracto resolveMidi() no implementado.');
    }
}

/**
 * Estado: Cerrar fuelle (Push)
 */
class PushState extends BellowsState {
    getMode() {
        return BELLOWS_MODES.PUSH;
    }

    canExecute(direction) {
        return direction === 'push';
    }

    resolveMidi(button, isSecondaryClick = false) {
        return isSecondaryClick ? button.pull : button.push;
    }
}

/**
 * Estado: Abrir fuelle (Pull)
 */
class PullState extends BellowsState {
    getMode() {
        return BELLOWS_MODES.PULL;
    }

    canExecute(direction) {
        return direction === 'pull';
    }

    resolveMidi(button, isSecondaryClick = false) {
        return isSecondaryClick ? button.push : button.pull;
    }
}

/**
 * Estado: Ambos (Both / Neutral) - Permite tanto abrir como cerrar
 */
class BothState extends BellowsState {
    getMode() {
        return BELLOWS_MODES.BOTH;
    }

    canExecute(direction) {
        return direction === 'push' || direction === 'pull';
    }

    resolveMidi(button, isSecondaryClick = false) {
        // En modo 'both', el clic primario usa push (cerrar) y el secundario pull (abrir)
        return isSecondaryClick ? button.pull : button.push;
    }
}

/**
 * Máquina de estado para el fuelle del acordeón.
 */
export class BellowsStateMachine {
    constructor(initialMode = BELLOWS_MODES.BOTH) {
        this._states = {
            [BELLOWS_MODES.PUSH]: new PushState(this),
            [BELLOWS_MODES.PULL]: new PullState(this),
            [BELLOWS_MODES.BOTH]: new BothState(this)
        };

        this._currentState = this._states[initialMode] || this._states[BELLOWS_MODES.BOTH];
    }

    /**
     * @returns {string} Modo de fuelle actual ('push', 'pull', 'both').
     */
    get mode() {
        return this._currentState.getMode();
    }

    /**
     * Transiciona a un nuevo modo de fuelle.
     * @param {string} newMode
     */
    setMode(newMode) {
        if (!this._states[newMode]) {
            console.warn(`[StateMachine] Modo de fuelle desconocido: "${newMode}". Se mantiene el actual.`);
            return;
        }

        const prevMode = this.mode;
        if (prevMode !== newMode) {
            this._currentState = this._states[newMode];
            eventBus.emit('bellows:changed', {
                previous: prevMode,
                current: newMode
            });
        }
    }

    /**
     * Verifica si una dirección es ejecutable en el estado actual.
     * @param {'push'|'pull'} direction
     * @returns {boolean}
     */
    canExecute(direction) {
        return this._currentState.canExecute(direction);
    }

    /**
     * Resuelve la nota MIDI de un botón bajo el estado actual.
     * @param {{ push: number, pull: number }} button
     * @param {boolean} [isSecondaryClick=false]
     * @returns {number}
     */
    resolveMidi(button, isSecondaryClick = false) {
        return this._currentState.resolveMidi(button, isSecondaryClick);
    }
}
