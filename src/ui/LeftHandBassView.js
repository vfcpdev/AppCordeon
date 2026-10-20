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
import { MusicXMLPatternParser } from '../audio/MusicXMLPatternParser.js';

export class LeftHandBassView {
    /**
     * @param {Object} elements
     * @param {HTMLElement} elements.container Contenedor del panel de bajos
     * @param {HTMLElement} [elements.headerElement] Barra de cabecera arrastrable
     * @param {HTMLElement} [elements.gridContainer] Contenedor para los 12 botones
     * @param {HTMLElement} [elements.btnToggleCollapse] Botón para colapsar/cerrar el panel
     * @param {HTMLElement} [elements.lblCollapseStatus] Etiqueta de estado
     * @param {HTMLElement} [elements.bellowsToggleGroup] Botones de selección de fuelle
     * @param {HTMLElement} [elements.btnPlayRhythm] Botón para reproducir el patrón rítmico
     * @param {HTMLElement} [elements.btnStopRhythm] Botón para pausar/detener el patrón rítmico
     * @param {HTMLElement} [elements.btnResetRhythm] Botón para reiniciar patrón rítmico
     * @param {HTMLElement} [elements.btnClearPattern] Botón para quitar/vaciar patrón cargado
     * @param {HTMLInputElement} [elements.fileMusicXML] Input file para cargar archivo MusicXML
     * @param {HTMLElement} [elements.lblPatternName] Etiqueta con el nombre del patrón activo
     * @param {HTMLElement} [elements.beatDot] Indicador visual de beat (punto rojo con glow)
     * @param {HTMLElement} [elements.btnToggleMetronome] Botón toggle del metrónomo de bajos (solo ícono)
     * @param {HTMLElement} [elements.lblMetronomeBpm] Etiqueta de BPM del metrónomo (solo valor, editable al clic)
     * @param {HTMLElement} [elements.btnToggleMirror] Botón para alternar modo espejo
     * @param {HTMLElement} [elements.btnToggleExternal] Botón externo en la barra de controles (junto al fuelle)
     * @param {HTMLElement} [elements.targetDiapason] Elemento del diapasón para anclar la posición inicial a su derecha
     * @param {Object} [options]
     * @param {number} [options.accordionIndex=1] Número del acordeón (1 o 2)
     * @param {Object} [services]
     * @param {Object} [services.audioEngine]
     */
    constructor(elements, options = {}, services = {}) {
        this._container = elements.container;
        this._headerElement = elements.headerElement || this._container?.querySelector('.left-hand-bass-header');
        this._gridContainer = elements.gridContainer;
        this._btnToggleCollapse = elements.btnToggleCollapse;
        this._lblCollapseStatus = elements.lblCollapseStatus;
        this._bellowsToggleGroup = elements.bellowsToggleGroup;
        this._btnPlayRhythm = elements.btnPlayRhythm;
        this._btnStopRhythm = elements.btnStopRhythm;
        this._btnResetRhythm = elements.btnResetRhythm;
        this._btnClearPattern = elements.btnClearPattern;
        this._fileMusicXML = elements.fileMusicXML;
        this._lblPatternName = elements.lblPatternName;
        this._beatDot = elements.beatDot;
        this._btnToggleMetronome = elements.btnToggleMetronome;
        this._lblMetronomeBpm = elements.lblMetronomeBpm;
        this._btnToggleMirror = elements.btnToggleMirror;
        this._btnToggleExternal = elements.btnToggleExternal;
        this._targetDiapason = elements.targetDiapason || (options.accordionIndex === 2 ? document.getElementById('secondaryDiapason') : document.getElementById('diapason'));

        this._accordionIndex = options.accordionIndex || 1;
        this._audio = services.audioEngine || audioEngine;

        this._currentOffset = 0;
        this._currentNotation = NOTATION_MODES.LATINA;
        this._currentBellowsMode = BELLOWS_MODES.BOTH;
        this._isMirrored = false; // Intercambiar columnas Interior / Exterior
        this._isCollapsed = true; // Colapsado/oculto por defecto
        this._hasBeenPositioned = false;
        this._activeButtonId = null;
        this._rhythmInterval = null;
        this._isRhythmPlaying = false;
        this._currentPattern = null; // Patrón cargado (MusicXML) o null (vacío)
        this._currentPatternStep = 0;

        // Metrónomo para bajos
        this._isMetronomeActive = false;
        this._bpm = 120;

        // Selección manual de botones para ejecución del patrón rítmico (Par activo por defecto: Par 1 / Hilera 1)
        this._selectedBassId = 'bass_1';
        this._selectedChordId = 'chord_1';

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
                this.startRhythmPattern();
            });
        }

        if (this._btnStopRhythm) {
            this._btnStopRhythm.addEventListener('click', () => {
                this.stopRhythmPattern();
            });
        }

        if (this._btnResetRhythm) {
            this._btnResetRhythm.addEventListener('click', () => {
                this.resetRhythmPattern();
            });
        }

        if (this._btnClearPattern) {
            this._btnClearPattern.addEventListener('click', () => {
                this.clearRhythmPattern();
            });
        }

        if (this._fileMusicXML) {
            this._fileMusicXML.addEventListener('change', (e) => {
                const file = e.target.files?.[0];
                if (file) {
                    this.loadMusicXMLFile(file);
                }
            });
        }

        if (this._btnToggleMetronome) {
            this._btnToggleMetronome.addEventListener('click', () => {
                this.toggleMetronome();
            });
        }

        if (this._lblMetronomeBpm) {
            this._lblMetronomeBpm.addEventListener('click', () => {
                this.promptSetBpm();
            });
        }

        if (this._btnToggleMirror) {
            this._btnToggleMirror.addEventListener('click', () => {
                this.toggleMirrored();
            });
        }
    }

    /**
     * Establece el estado de inversión de columnas (modo espejo en bajos).
     * @param {boolean} value
     */
    setMirrored(value) {
        this._isMirrored = Boolean(value);
        if (this._btnToggleMirror) {
            this._btnToggleMirror.classList.toggle('active', this._isMirrored);
        }
        this.render();
    }

    /**
     * Alterna la orientación / inversión de las columnas de bajos.
     * @returns {boolean}
     */
    toggleMirrored() {
        this.setMirrored(!this._isMirrored);
        return this._isMirrored;
    }

    /**
     * Alterna la visibilidad colapsable del panel de bajos incrustado.
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
            icon.className = this._isCollapsed ? 'fas fa-chevron-down' : 'fas fa-times';
        }
        if (this._btnToggleExternal) {
            this._btnToggleExternal.classList.toggle('active', !this._isCollapsed);
            const extLabel = this._btnToggleExternal.querySelector('span');
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

        // Columna Interior (izquierda): toma los botones pares (chordButtons[1], fundButtons[1], etc.)
        const col1Buttons = [
            { ...chordButtons[1], rowIndex: 1, colName: 'col1' },
            { ...fundButtons[1], rowIndex: 2, colName: 'col1' },
            { ...chordButtons[3], rowIndex: 3, colName: 'col1' },
            { ...fundButtons[3], rowIndex: 4, colName: 'col1' },
            { ...chordButtons[5], rowIndex: 5, colName: 'col1' },
            { ...fundButtons[5], rowIndex: 6, colName: 'col1' }
        ];

        // Columna Exterior (derecha): toma los botones impares (chordButtons[0], fundButtons[0], etc.)
        const col2Buttons = [
            { ...chordButtons[0], rowIndex: 1, colName: 'col2' },
            { ...fundButtons[0], rowIndex: 2, colName: 'col2' },
            { ...chordButtons[2], rowIndex: 3, colName: 'col2' },
            { ...fundButtons[2], rowIndex: 4, colName: 'col2' },
            { ...chordButtons[4], rowIndex: 5, colName: 'col2' },
            { ...fundButtons[4], rowIndex: 6, colName: 'col2' }
        ];

        const fragment = document.createDocumentFragment();

        // 1. Columna de la izquierda (visual: Interior)
        const col1El = document.createElement('div');
        col1El.className = 'row-col bass-col bass-col--col1';

        const header1 = document.createElement('div');
        header1.className = 'row-header bass-header';
        header1.innerHTML = `
            <span class="row-header-root">Interior</span>
        `;
        header1.title = 'Columna Interior: Filas Impares = Acorde, Filas Pares = Bajo';
        col1El.appendChild(header1);

        col1Buttons.forEach(btnData => {
            const btnEl = this._createBassButtonElement(btnData);
            col1El.appendChild(btnEl);
        });

        // 2. Columna de la derecha (visual: Exterior)
        const col2El = document.createElement('div');
        col2El.className = 'row-col bass-col bass-col--col2';

        const header2 = document.createElement('div');
        header2.className = 'row-header bass-header';
        header2.innerHTML = `
            <span class="row-header-root">Exterior</span>
        `;
        header2.title = 'Columna Exterior: Filas Impares = Acorde, Filas Pares = Bajo';
        col2El.appendChild(header2);

        col2Buttons.forEach(btnData => {
            const btnEl = this._createBassButtonElement(btnData);
            col2El.appendChild(btnEl);
        });

        // Disposición física según la mano izquierda:
        // Normal: Izquierda = col2El (Exterior), Derecha = col1El (Interior)
        // Espejo (Invertido): Izquierda = col1El (Interior), Derecha = col2El (Exterior)
        if (this._isMirrored) {
            fragment.appendChild(col1El);
            fragment.appendChild(col2El);
        } else {
            fragment.appendChild(col2El);
            fragment.appendChild(col1El);
        }

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
        const isSelected = (btnData.type === 'fundamental' && this._selectedBassId === btnData.id) ||
                              (btnData.type === 'chord' && this._selectedChordId === btnData.id);

        btn.className = `btn-accordion btn-bass-accordion ${btnData.type === 'fundamental' ? 'btn-bass-fund' : 'btn-bass-chord'} ${isSelected ? 'is-selected-for-rhythm' : ''}`;
        btn.id = `btn_left_acc${this._accordionIndex}_${btnData.id}`;

        const isPush = this._currentBellowsMode === BELLOWS_MODES.PUSH;
        const isPull = this._currentBellowsMode === BELLOWS_MODES.PULL;

        let pushLabel = '';
        let pullLabel = '';

        if (btnData.type === 'fundamental') {
            pushLabel = midiToName(btnData.push, this._currentNotation, true, this._currentOffset);
            pullLabel = midiToName(btnData.pull, this._currentNotation, true, this._currentOffset);
        } else {
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
            btn.title = `${btnData.label} | Cerrar (Push): ${pushLabel} | Abrir (Pull): ${pullLabel} (Clic para seleccionar para patrón)`;
        } else if (isPush) {
            btn.classList.add('push');
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap"><span class="btn-note-single">${pushLabel}</span></span>
            `;
            btn.title = `${btnData.label} | Cerrar (Push): ${pushLabel} (Clic para seleccionar para patrón)`;
        } else {
            btn.classList.add('pull');
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap"><span class="btn-note-single">${pullLabel}</span></span>
            `;
            btn.title = `${btnData.label} | Abrir (Pull): ${pullLabel} (Clic para seleccionar para patrón)`;
        }

        const selectForRhythm = () => {
            if (btnData.type === 'fundamental') {
                this._selectedBassId = btnData.id;
            } else {
                this._selectedChordId = btnData.id;
            }
            // Actualizar clase visual en todos los botones del panel
            const allBassButtons = this._gridContainer?.querySelectorAll('.btn-bass-accordion');
            allBassButtons?.forEach(b => {
                const isBtnSelected = (btnData.type === 'fundamental' && b.id.endsWith(this._selectedBassId)) ||
                                      (btnData.type === 'chord' && b.id.endsWith(this._selectedChordId));
                if (isBtnSelected) {
                    b.classList.add('is-selected-for-rhythm');
                } else if ((btnData.type === 'fundamental' && b.classList.contains('btn-bass-fund')) ||
                           (btnData.type === 'chord' && b.classList.contains('btn-bass-chord'))) {
                    b.classList.remove('is-selected-for-rhythm');
                }
            });
        };

        const handlePress = (e, forceDirection) => {
            if (e.cancelable) e.preventDefault();
            selectForRhythm();
            this.playBassButton(btnData, forceDirection);
            btn.classList.add('is-pressed');
        };

        const handleRelease = () => {
            btn.classList.remove('is-pressed');
        };

        // Clic izquierdo (o mousedown)
        btn.addEventListener('mousedown', (e) => {
            if (e.button === 0) {
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
            selectForRhythm();
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
    /**
     * Alterna la activación del metrónomo sonoro en la sección de bajos.
     * @param {boolean} [forceState]
     * @returns {boolean}
     */
     toggleMetronome(forceState) {
        this._isMetronomeActive = forceState !== undefined ? forceState : !this._isMetronomeActive;
        if (this._btnToggleMetronome) {
            this._btnToggleMetronome.classList.toggle('active', this._isMetronomeActive);
            this._btnToggleMetronome.title = this._isMetronomeActive
                ? 'Metrónomo de bajos: ACTIVO (Clic para desactivar)'
                : 'Metrónomo de bajos: INACTIVO (Clic para activar)';
        }
        return this._isMetronomeActive;
    }

    /**
     * Establece el tempo en BPM para el metrónomo y el patrón rítmico.
     * @param {number} bpm
     */
    setBpm(bpm) {
        const val = Math.max(30, Math.min(280, Math.round(bpm)));
        this._bpm = val;
        if (this._lblMetronomeBpm) {
            this._lblMetronomeBpm.textContent = val;
        }
        if (this._currentPattern) {
            this._currentPattern.tempo = val;
            if (this._lblPatternName) {
                this._lblPatternName.title = `Patrón: ${this._currentPattern.title} (${val} BPM, ${this._currentPattern.timeSignature.beats}/${this._currentPattern.timeSignature.beatType})`;
            }
        }
    }

    /**
     * Solicita al usuario un nuevo valor de BPM de manera interactiva.
     */
    promptSetBpm() {
        const current = this._bpm || (this._currentPattern?.tempo || 120);
        const input = window.prompt('Ajustar BPM del metrónomo / patrón rítmico (30 - 280):', current);
        if (input !== null) {
            const parsed = parseInt(input, 10);
            if (!isNaN(parsed) && parsed >= 30 && parsed <= 280) {
                this.setBpm(parsed);
                // Si está reproduciendo, reiniciar para aplicar el nuevo tempo al instante
                if (this._isRhythmPlaying) {
                    this.stopRhythmPattern();
                    this.startRhythmPattern();
                }
            }
        }
    }

    /**
     * Hace destellar el punto rojo con glow que indica el beat.
     * @param {number} [durationMs=120]
     */
    flashBeatDot(durationMs = 120) {
        if (!this._beatDot) return;
        this._beatDot.classList.add('glow-active');
        setTimeout(() => {
            if (this._beatDot) {
                this._beatDot.classList.remove('glow-active');
            }
        }, durationMs);
    }

    /**
     * Carga un archivo MusicXML y actualiza el patrón rítmico del acordeón.
     * @param {File} file
     */
    async loadMusicXMLFile(file) {
        try {
            const text = await file.text();
            const pattern = MusicXMLPatternParser.parse(text);
            this._currentPattern = pattern;
            this._currentPatternStep = 0;

            if (pattern.tempo) {
                this.setBpm(pattern.tempo);
            }

            if (this._lblPatternName) {
                this._lblPatternName.textContent = pattern.title || file.name.replace(/\.[^/.]+$/, "");
                this._lblPatternName.title = `Patrón: ${pattern.title} (${pattern.tempo} BPM, ${pattern.timeSignature.beats}/${pattern.timeSignature.beatType})`;
            }

            if (this._btnClearPattern) {
                this._btnClearPattern.style.display = 'inline-flex';
            }

            // Si está reproduciendo, reiniciar con el nuevo patrón
            if (this._isRhythmPlaying) {
                this.stopRhythmPattern();
                this.startRhythmPattern();
            }
        } catch (err) {
            console.error('[LeftHandBassView] Error al cargar MusicXML:', err);
            alert(`No se pudo cargar el archivo MusicXML: ${err.message}`);
        }
    }

    /**
     * Limpia o resetea el patrón rítmico cargado, dejándolo totalmente vacío.
     */
    clearRhythmPattern() {
        this.stopRhythmPattern();
        this._currentPattern = null;
        this._currentPatternStep = 0;

        if (this._lblPatternName) {
            this._lblPatternName.textContent = 'Sin patrón cargado';
            this._lblPatternName.title = 'No hay patrón rítmico cargado. Carga un archivo MusicXML.';
        }

        if (this._btnClearPattern) {
            this._btnClearPattern.style.display = 'none';
        }

        if (this._fileMusicXML) {
            this._fileMusicXML.value = '';
        }

        if (this._beatDot) {
            this._beatDot.classList.remove('glow-active');
        }
    }

    /**
     * Reinicia el patrón rítmico al primer compás/pulso.
     */
    resetRhythmPattern() {
        this._currentPatternStep = 0;
        if (this._isRhythmPlaying) {
            this.stopRhythmPattern();
            this.startRhythmPattern();
        }
    }

    /**
     * Alterna la reproducción del patrón rítmico vallenato o MusicXML.
     */
    toggleRhythmPattern() {
        if (this._isRhythmPlaying) {
            this.stopRhythmPattern();
        } else {
            this.startRhythmPattern();
        }
    }

    /**
     * Inicia el patrón rítmico (únicamente si hay un patrón MusicXML cargado).
     */
    startRhythmPattern() {
        if (!this._currentPattern || !this._currentPattern.notes || this._currentPattern.notes.length === 0) {
            alert('No hay ningún patrón rítmico cargado. Por favor, pulsa el botón de carga (ícono con flecha) y selecciona un archivo MusicXML (.xml, .musicxml).');
            return;
        }

        if (this._isRhythmPlaying) return;
        this._isRhythmPlaying = true;
        if (this._btnPlayRhythm) {
            this._btnPlayRhythm.classList.add('active');
            this._btnPlayRhythm.title = 'Reproduciendo patrón MusicXML (activo)';
        }
        if (this._btnStopRhythm) {
            this._btnStopRhythm.classList.remove('active');
        }

        const bassesData = getTransposedBasses(this._currentOffset);
        // Buscar el bajo y acorde seleccionados por el usuario (o caer en el primer par por defecto)
        const bassBtn = bassesData.find(b => b.id === this._selectedBassId) || bassesData.find(b => b.type === 'fundamental') || bassesData[0];
        const chordBtn = bassesData.find(b => b.id === this._selectedChordId) || bassesData.find(b => b.type === 'chord') || bassesData[1];

        // Determinar dirección del fuelle actual
        const getActiveDirection = (noteBellows) => {
            if (noteBellows) return noteBellows;
            if (this._currentBellowsMode === BELLOWS_MODES.PULL) return 'pull';
            if (this._currentBellowsMode === BELLOWS_MODES.PUSH) return 'push';
            return 'push'; // Por defecto cerrar en modo BOTH
        };

        const tempo = this._currentPattern.tempo || this._bpm || 120;
        const msPerBeat = (60 / tempo) * 1000;

        const playNextMusicXMLStep = () => {
            if (!this._isRhythmPlaying) return;

            const note = this._currentPattern.notes[this._currentPatternStep];
            const noteDurationMs = note.durationBeats * msPerBeat;

            // Destello visual de Beat con Glow Rojo en cada evento
            this.flashBeatDot(Math.min(140, Math.max(60, noteDurationMs * 0.4)));

            // Reproducir clic de metrónomo si está activado
            if (this._isMetronomeActive) {
                // Sonido de clic con oscilador sintetizado
                this._playMetronomeClick(this._currentPatternStep === 0 ? 1 : 2);
            }

            if (!note.isRest) {
                const direction = getActiveDirection(note.bellows);
                // Clasificar si la nota de la partitura corresponde a la ejecución del bajo fundamental o acorde
                const isBassNote = note.octave <= 2 || note.step === 'C' || note.step === 'F' || note.step === 'G';
                const targetBtn = isBassNote ? bassBtn : chordBtn;
                const btnEl = document.getElementById(`btn_left_acc${this._accordionIndex}_${targetBtn.id}`);

                if (this._audio) {
                    const soundMidis = direction === 'pull' ? targetBtn.pull : targetBtn.push;
                    this._audio.play(soundMidis, `${Math.max(0.1, note.durationBeats * 0.45)}s`, targetBtn.type === 'fundamental' ? 0.95 : 0.8);
                }

                if (btnEl) {
                    btnEl.classList.add('is-pressed');
                    setTimeout(() => btnEl.classList.remove('is-pressed'), Math.min(220, noteDurationMs * 0.75));
                }
            }

            this._currentPatternStep = (this._currentPatternStep + 1) % this._currentPattern.notes.length;
            this._rhythmInterval = setTimeout(playNextMusicXMLStep, noteDurationMs);
        };

        playNextMusicXMLStep();
    }

    /**
     * Emite un clic sintético para el metrónomo de los bajos.
     * @private
     * @param {number} beat
     */
    _playMetronomeClick(beat = 1) {
        try {
            const audioCtx = this._audio?.getContext?.() || (window.AudioContext ? new (window.AudioContext || window.webkitAudioContext)() : null);
            if (!audioCtx) return;
            if (audioCtx.state === 'suspended') {
                audioCtx.resume();
            }

            const now = audioCtx.currentTime;
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();

            const isAccent = (beat === 1);
            osc.type = isAccent ? 'sine' : 'triangle';
            osc.frequency.setValueAtTime(isAccent ? 1200 : 850, now);
            osc.frequency.exponentialRampToValueAtTime(isAccent ? 400 : 260, now + 0.04);

            gain.gain.setValueAtTime(isAccent ? 0.6 : 0.4, now);
            gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.045);

            osc.connect(gain);
            gain.connect(audioCtx.destination);

            osc.start(now);
            osc.stop(now + 0.05);
        } catch (e) {
            // Ignorar errores menores
        }
    }

    /**
     * Detiene el patrón rítmico vallenato / MusicXML.
     */
    stopRhythmPattern() {
        if (this._rhythmInterval) {
            clearTimeout(this._rhythmInterval);
            clearInterval(this._rhythmInterval);
            this._rhythmInterval = null;
        }
        this._isRhythmPlaying = false;
        if (this._beatDot) {
            this._beatDot.classList.remove('glow-active');
        }
        if (this._btnPlayRhythm) {
            this._btnPlayRhythm.classList.remove('active');
            this._btnPlayRhythm.title = 'Reproducir ritmo MusicXML / Paseo';
        }
        if (this._btnStopRhythm) {
            this._btnStopRhythm.classList.add('active');
            setTimeout(() => this._btnStopRhythm?.classList.remove('active'), 350);
        }
    }
}
