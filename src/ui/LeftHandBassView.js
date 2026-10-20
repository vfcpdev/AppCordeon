/**
 * @fileoverview Vista del Simulador de 12 Bajos de la Mano Izquierda (LeftHandBassView).
 * Principio SRP:
 * - Representa físicamente los 12 botones del cabezal izquierdo (6 pares: Bajo Fundamental + Acorde).
 * - Soporta la lógica bisonora (Push = Rojo, Pull = Azul).
 * - Permite practicar el patrón rítmico vallenato tradicional (Bajo - Acorde - Acorde).
 * @module ui/LeftHandBassView
 */

import { getTransposedBasses } from '../models/AccordionData.js';
import { midiToName } from '../theory/MusicTheory.js';
import { NOTATION_MODES, BELLOWS_MODES } from '../core/Constants.js';
import { audioEngine } from '../audio/AudioEngine.js';

export class LeftHandBassView {
    /**
     * @param {Object} elements
     * @param {HTMLElement} elements.container Contenedor del panel de bajos
     * @param {HTMLElement} [elements.gridContainer] Contenedor para los 12 botones
     * @param {HTMLElement} [elements.btnToggleCollapse] Botón para colapsar/expandir el panel
     * @param {HTMLElement} [elements.lblCollapseStatus] Etiqueta de estado
     * @param {HTMLElement} [elements.bellowsToggleGroup] Botones de selección de fuelle
     * @param {HTMLElement} [elements.btnPlayRhythm] Botón para demo rítmica de Paseo Vallenato
     * @param {HTMLElement} [elements.btnToggleExternal] Botón externo en la barra de controles (junto al fuelle)
     * @param {Object} [services]
     * @param {Object} [services.audioEngine]
     */
    constructor(elements, services = {}) {
        this._container = elements.container;
        this._gridContainer = elements.gridContainer;
        this._btnToggleCollapse = elements.btnToggleCollapse;
        this._lblCollapseStatus = elements.lblCollapseStatus;
        this._bellowsToggleGroup = elements.bellowsToggleGroup;
        this._btnPlayRhythm = elements.btnPlayRhythm;
        this._btnToggleExternal = elements.btnToggleExternal;

        this._audio = services.audioEngine || audioEngine;

        this._currentOffset = 0;
        this._currentNotation = NOTATION_MODES.LATINA;
        this._currentBellowsMode = BELLOWS_MODES.BOTH;
        this._isCollapsed = true; // Colapsado por defecto para mantener la vista limpia
        this._activeButtonId = null;
        this._rhythmInterval = null;
        this._isRhythmPlaying = false;

        this._initEvents();
    }

    /**
     * Inicializa eventos del componente.
     * @private
     */
    _initEvents() {
        if (this._btnToggleCollapse) {
            this._btnToggleCollapse.addEventListener('click', () => {
                this.toggleCollapse();
            });
        }

        if (this._btnToggleExternal) {
            this._btnToggleExternal.addEventListener('click', () => {
                this.toggleCollapse();
            });
        }

        if (this._bellowsToggleGroup) {
            const buttons = this._bellowsToggleGroup.querySelectorAll('.bellows-btn, .segment-btn');
            buttons.forEach(btn => {
                btn.addEventListener('click', () => {
                    buttons.forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    this.setBellowsMode(btn.dataset.mode || 'both');
                });
            });
        }

        if (this._btnPlayRhythm) {
            this._btnPlayRhythm.addEventListener('click', () => {
                this.toggleRhythmPattern();
            });
        }
    }

    /**
     * Alterna la visibilidad colapsable del panel de bajos.
     * @param {boolean} [forceState]
     */
    toggleCollapse(forceState) {
        this._isCollapsed = forceState !== undefined ? forceState : !this._isCollapsed;
        if (this._container) {
            this._container.classList.toggle('collapsed', this._isCollapsed);
        }
        if (this._lblCollapseStatus) {
            this._lblCollapseStatus.textContent = this._isCollapsed ? 'Expandir' : 'Colapsar';
        }
        const icon = this._btnToggleCollapse?.querySelector('i');
        if (icon) {
            icon.className = this._isCollapsed ? 'fas fa-chevron-down' : 'fas fa-chevron-up';
        }
        if (this._btnToggleExternal) {
            this._btnToggleExternal.classList.toggle('active', !this._isCollapsed);
            const extLabel = document.getElementById('lblBassToggleStatus');
            if (extLabel) {
                extLabel.textContent = this._isCollapsed ? 'Bajos' : 'Bajos (Activo)';
            }
        }
    }

    /**
     * Configura el desplazamiento de afinación (tuning offset) y redibuja.
     * @param {number} offset
     * @param {string} notation
     */
    updateTuning(offset, notation) {
        this._currentOffset = offset;
        this._currentNotation = notation;
        this.render();
    }

    /**
     * Establece el modo de fuelle ('both', 'pull', 'push') y actualiza la visualización.
     * @param {string} mode
     */
    setBellowsMode(mode) {
        this._currentBellowsMode = mode;
        this.render();
    }

    /**
     * Dibuja los 12 botones organizados en 2 columnas apiladas de 6 filas cada una.
     * Conforme a la distribución física del acordeón diatónico vallenato:
     * - Filas Impares (1, 3, 5): Acordes de acompañamiento (bloque armónico)
     * - Filas Pares (2, 4, 6): Bajos fundamentales (nota individual)
     * Ambas columnas están perfectamente alineadas en paralelo niveladas horizontalmente.
     */
    render() {
        if (!this._gridContainer) return;
        this._gridContainer.innerHTML = '';

        const bassesData = getTransposedBasses(this._currentOffset);

        // Identificar los 6 botones de fundamentales y los 6 de acordes
        const fundButtons = bassesData.filter(b => b.type === 'fundamental');
        const chordButtons = bassesData.filter(b => b.type === 'chord');

        // Mapear los 12 botones en 6 filas x 2 columnas:
        // Columna 1 (Exterior):
        //   Fila 1: Acorde 1 (Par 1)
        //   Fila 2: Bajo 1 (Par 1)
        //   Fila 3: Acorde 3 (Par 3)
        //   Fila 4: Bajo 3 (Par 3)
        //   Fila 5: Acorde 5 (Par 5)
        //   Fila 6: Bajo 5 (Par 5)
        // Columna 2 (Interior):
        //   Fila 1: Acorde 2 (Par 2)
        //   Fila 2: Bajo 2 (Par 2)
        //   Fila 3: Acorde 4 (Par 4)
        //   Fila 4: Bajo 4 (Par 4)
        //   Fila 5: Acorde 6 (Par 6)
        //   Fila 6: Bajo 6 (Par 6)
        const col1Buttons = [
            { ...chordButtons[0], rowIndex: 1, colName: 'col1' },
            { ...fundButtons[0], rowIndex: 2, colName: 'col1' },
            { ...chordButtons[2], rowIndex: 3, colName: 'col1' },
            { ...fundButtons[2], rowIndex: 4, colName: 'col1' },
            { ...chordButtons[4], rowIndex: 5, colName: 'col1' },
            { ...fundButtons[4], rowIndex: 6, colName: 'col1' }
        ];

        const col2Buttons = [
            { ...chordButtons[1], rowIndex: 1, colName: 'col2' },
            { ...fundButtons[1], rowIndex: 2, colName: 'col2' },
            { ...chordButtons[3], rowIndex: 3, colName: 'col2' },
            { ...fundButtons[3], rowIndex: 4, colName: 'col2' },
            { ...chordButtons[5], rowIndex: 5, colName: 'col2' },
            { ...fundButtons[5], rowIndex: 6, colName: 'col2' }
        ];

        const fragment = document.createDocumentFragment();

        // 1. Columna de la izquierda (visual)
        const col1El = document.createElement('div');
        col1El.className = 'row-col bass-col bass-col--col1';

        const header1 = document.createElement('div');
        header1.className = 'row-header bass-header';
        header1.innerHTML = `
            <span class="row-header-title">Columna 2</span>
            <span class="row-header-root">Interior</span>
        `;
        header1.title = 'Columna Interior: Filas Impares = Acorde, Filas Pares = Bajo';
        col1El.appendChild(header1);

        col1Buttons.forEach(btnData => {
            const btnEl = this._createBassButtonElement(btnData);
            col1El.appendChild(btnEl);
        });

        // 2. Columna de la derecha (visual)
        const col2El = document.createElement('div');
        col2El.className = 'row-col bass-col bass-col--col2';

        const header2 = document.createElement('div');
        header2.className = 'row-header bass-header';
        header2.innerHTML = `
            <span class="row-header-title">Columna 1</span>
            <span class="row-header-root">Exterior</span>
        `;
        header2.title = 'Columna Exterior: Filas Impares = Acorde, Filas Pares = Bajo';
        col2El.appendChild(header2);

        col2Buttons.forEach(btnData => {
            const btnEl = this._createBassButtonElement(btnData);
            col2El.appendChild(btnEl);
        });

        // Disposición física según la mano izquierda:
        // Columna Interior a la izquierda, Columna Exterior a la derecha
        fragment.appendChild(col2El);
        fragment.appendChild(col1El);

        this._gridContainer.appendChild(fragment);
    }

    /**
     * Crea un botón idéntico visualmente a los botones del diapasón (.btn-accordion).
     * @private
     * @param {Object} btnData
     * @returns {HTMLElement}
     */
    _createBassButtonElement(btnData) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = `btn-accordion btn-bass-accordion ${btnData.type === 'fundamental' ? 'btn-bass-fund' : 'btn-bass-chord'}`;
        btn.id = `btn_left_${btnData.id}`;

        const isPush = this._currentBellowsMode === BELLOWS_MODES.PUSH;
        const isPull = this._currentBellowsMode === BELLOWS_MODES.PULL;

        let pushLabel = '';
        let pullLabel = '';

        if (btnData.type === 'fundamental') {
            pushLabel = midiToName(btnData.push, this._currentNotation, true, this._currentOffset);
            pullLabel = midiToName(btnData.pull, this._currentNotation, true, this._currentOffset);
        } else {
            // Para acorde compuesto (Filas 1, 3, 5):
            // Obtener el nombre de la fundamental del acorde según la afinación y notación activa
            const rootPush = Array.isArray(btnData.push) ? btnData.push[0] : btnData.push;
            const rootPull = Array.isArray(btnData.pull) ? btnData.pull[0] : btnData.pull;
            const rootPushName = midiToName(rootPush, this._currentNotation, true, this._currentOffset);
            const rootPullName = midiToName(rootPull, this._currentNotation, true, this._currentOffset);

            const isMinorPush = btnData.namePush.includes('min');
            const isMinorPull = btnData.namePull.includes('min');

            pushLabel = `${rootPushName}${isMinorPush ? 'm' : ''}`;
            pullLabel = `${rootPullName}${isMinorPull ? 'm' : ''}`;
        }

        const displayIndex = btnData.rowIndex !== undefined ? btnData.rowIndex : btnData.btnIndex;
        const orderBadgeHtml = `<span class="btn-order-number" aria-hidden="true">${displayIndex}</span>`;

        if (this._currentBellowsMode === BELLOWS_MODES.BOTH) {
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap">
                    <span class="btn-note-push">${pushLabel}</span>
                    <span class="btn-separator">─</span>
                    <span class="btn-note-pull">${pullLabel}</span>
                </span>
            `;
            btn.title = `${btnData.label} | Cerrar (Push): ${pushLabel} | Abrir (Pull): ${pullLabel}`;
        } else if (isPush) {
            btn.classList.add('push');
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap"><span class="btn-note-single">${pushLabel}</span></span>
            `;
            btn.title = `${btnData.label} | Cerrar (Push): ${pushLabel}`;
        } else {
            btn.classList.add('pull');
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap"><span class="btn-note-single">${pullLabel}</span></span>
            `;
            btn.title = `${btnData.label} | Abrir (Pull): ${pullLabel}`;
        }

        const handlePress = (e, forceDirection) => {
            if (e.cancelable) e.preventDefault();
            this.playBassButton(btnData, forceDirection);
            btn.classList.add('is-pressed');
        };

        const handleRelease = () => {
            btn.classList.remove('is-pressed');
        };

        // Clic izquierdo (o mousedown)
        btn.addEventListener('mousedown', (e) => {
            if (e.button === 0) {
                // Si está en modo BOTH, clic normal toca Cerrar (Push)
                const dir = this._currentBellowsMode === BELLOWS_MODES.BOTH ? 'push' : undefined;
                handlePress(e, dir);
            }
        });

        // Clic derecho (en modo BOTH, clic derecho toca Abrir / Pull)
        btn.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            const dir = this._currentBellowsMode === BELLOWS_MODES.BOTH ? 'pull' : undefined;
            handlePress(e, dir);
        });

        btn.addEventListener('click', (e) => {
            // Asegurar que si el navegador no disparó mousedown o es touch simulado, suene
            if (!btn.classList.contains('is-pressed')) {
                const dir = this._currentBellowsMode === BELLOWS_MODES.BOTH ? 'push' : undefined;
                this.playBassButton(btnData, dir);
                btn.classList.add('is-pressed');
                setTimeout(() => btn.classList.remove('is-pressed'), 180);
            }
        });

        btn.addEventListener('touchstart', (e) => {
            handlePress(e);
        }, { passive: false });

        btn.addEventListener('touchend', handleRelease);
        btn.addEventListener('touchcancel', handleRelease);

        window.addEventListener('mouseup', handleRelease);

        return btn;
    }

    /**
     * Reproduce las notas de un botón de bajo o acorde según la dirección activa del fuelle.
     * @param {Object} btnData
     * @param {'push'|'pull'} [directionOverride]
     */
    playBassButton(btnData, directionOverride) {
        let isPull = false;
        if (directionOverride) {
            isPull = directionOverride === 'pull';
        } else if (this._currentBellowsMode === BELLOWS_MODES.PULL) {
            isPull = true;
        } else {
            isPull = false;
        }

        const soundMidis = isPull ? btnData.pull : btnData.push;
        const duration = btnData.type === 'fundamental' ? '4n' : '8n';
        const volume = btnData.type === 'fundamental' ? 0.95 : 0.75;

        if (this._audio) {
            this._audio.play(soundMidis, duration, volume);
        }
    }

    /**
     * Demostración pedagógica del compás vallenato clásico:
     * Patrón Paseo: BAJO (tiempo 1) - ACORDE (tiempo 2) - ACORDE (tiempo 3)
     */
    toggleRhythmPattern() {
        if (this._isRhythmPlaying) {
            this.stopRhythmPattern();
        } else {
            this.startRhythmPattern();
        }
    }

    /**
     * Inicia el patrón rítmico vallenato sincronizado.
     */
    startRhythmPattern() {
        if (this._isRhythmPlaying) return;
        this._isRhythmPlaying = true;
        if (this._btnPlayRhythm) {
            this._btnPlayRhythm.classList.add('btn-action--danger');
            this._btnPlayRhythm.innerHTML = `<i class="fas fa-stop"></i> Detener Ritmo`;
        }

        const bassesData = getTransposedBasses(this._currentOffset);
        // Usar Par 1 (Bb / Tónica principal de hilera 1)
        const bassBtn = bassesData[0];
        const chordBtn = bassesData[1];

        let beat = 0;
        const beatIntervalMs = 280; // Aprox 105 BPM ritmo Paseo

        this._rhythmInterval = setInterval(() => {
            const step = beat % 4;
            const bassEl = document.getElementById(`btn_left_${bassBtn.id}`);
            const chordEl = document.getElementById(`btn_left_${chordBtn.id}`);

            if (step === 0) {
                // Pulso 1: Golpe del Bajo Fundamental
                this.playBassButton(bassBtn);
                if (bassEl) {
                    bassEl.classList.add('is-pressed');
                    setTimeout(() => bassEl.classList.remove('is-pressed'), 140);
                }
            } else if (step === 1 || step === 2) {
                // Pulsos 2 y 3: Acompañamiento de Acorde (Paseo)
                this.playBassButton(chordBtn);
                if (chordEl) {
                    chordEl.classList.add('is-pressed');
                    setTimeout(() => chordEl.classList.remove('is-pressed'), 120);
                }
            }
            beat++;
        }, beatIntervalMs);
    }

    /**
     * Detiene el patrón rítmico vallenato.
     */
    stopRhythmPattern() {
        if (this._rhythmInterval) {
            clearInterval(this._rhythmInterval);
            this._rhythmInterval = null;
        }
        this._isRhythmPlaying = false;
        if (this._btnPlayRhythm) {
            this._btnPlayRhythm.classList.remove('btn-action--danger');
            this._btnPlayRhythm.innerHTML = `<i class="fas fa-drum"></i> Demo Ritmo Vallenato`;
        }
    }
}
