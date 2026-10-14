/**
 * @fileoverview Event Bus central (Patrón Observer / Pub-Sub) implementado como Singleton.
 * Desacopla las vistas, controladores, el motor de audio y las estrategias de análisis.
 * @module core/EventBus
 */

/**
 * @callback EventCallback
 * @param {*} data Datos transmitidos con el evento.
 */

class EventBus {
    /**
     * @private
     */
    constructor() {
        if (EventBus._instance) {
            return EventBus._instance;
        }

        /**
         * Mapa de eventos a conjuntos de callbacks suscriptores.
         * @type {Map<string, Set<EventCallback>>}
         * @private
         */
        this._listeners = new Map();
        EventBus._instance = this;
    }

    /**
     * Obtiene la instancia única del EventBus (Singleton).
     * @returns {EventBus}
     */
    static getInstance() {
        if (!EventBus._instance) {
            EventBus._instance = new EventBus();
        }
        return EventBus._instance;
    }

    /**
     * Suscribe un callback a un evento específico.
     * @param {string} event Nombre del evento.
     * @param {EventCallback} callback Función a ejecutar cuando se emita el evento.
     * @returns {() => void} Función de desuscripción para limpieza.
     */
    on(event, callback) {
        if (typeof callback !== 'function') {
            throw new TypeError(`El callback para el evento "${event}" debe ser una función.`);
        }
        if (!this._listeners.has(event)) {
            this._listeners.set(event, new Set());
        }
        this._listeners.get(event).add(callback);

        return () => this.off(event, callback);
    }

    /**
     * Desuscribe un callback de un evento.
     * @param {string} event Nombre del evento.
     * @param {EventCallback} callback Función a desuscribir.
     */
    off(event, callback) {
        if (this._listeners.has(event)) {
            this._listeners.get(event).delete(callback);
            if (this._listeners.get(event).size === 0) {
                this._listeners.delete(event);
            }
        }
    }

    /**
     * Suscribe un callback que se ejecutará una única vez y luego se desuscribirá.
     * @param {string} event Nombre del evento.
     * @param {EventCallback} callback Función a ejecutar.
     */
    once(event, callback) {
        const unsubscribe = this.on(event, (data) => {
            unsubscribe();
            callback(data);
        });
    }

    /**
     * Emite un evento síncronamente hacia todos los suscriptores.
     * @param {string} event Nombre del evento.
     * @param {*} [data] Datos a enviar.
     */
    emit(event, data) {
        if (!this._listeners.has(event)) return;
        this._listeners.get(event).forEach(callback => {
            try {
                callback(data);
            } catch (err) {
                console.error(`[EventBus] Error al ejecutar callback para "${event}":`, err);
            }
        });
    }

    /**
     * Limpia todos los suscriptores de todos los eventos o de un evento específico.
     * @param {string} [event]
     */
    clear(event) {
        if (event) {
            this._listeners.delete(event);
        } else {
            this._listeners.clear();
        }
    }
}

/** Instancia Singleton exportada */
export const eventBus = EventBus.getInstance();
export default EventBus;
