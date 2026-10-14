/**
 * @fileoverview Vista de la Barra Lateral de Acordes Identificados en el Audio (SRP).
 * Se ubica a la derecha de cada diapasón (acordeón 1 y 2) mostrando el acorde
 * actual del audio y los botones necesarios tanto para Abrir como para Cerrar el fuelle.
 * @module ui/DiapasonChordSidebarView
 */

import { getAccordionButtonsForChord } from '../theory/Scales.js';
import { getNoteNamesList } from '../theory/MusicTheory.js';
import { NOTATION_MODES } from '../core/Constants.js';
import { audioPlayerController } from '../audio/AudioPlayerController.js';

export class DiapasonChordSidebarView {
    /**
     * @param {Object} elements
     * @param {HTMLElement} elements.primarySidebar Contenedor lateral del diapasón 1
     * @param {HTMLElement} elements.secondarySidebar Contenedor lateral del diapasón 2
     */
    constructor(elements) {
        this._primSidebar = elements.primarySidebar;
        this._secSidebar = elements.secondarySidebar;
        this._currentChord = null;
        this._currentTimeline = null;
        this._activeTimelineIndex = -1;
        this._onTimelineUpdated = null;
        this._editingChordIndex = -1;
        this._activeEditorSidebar = null;
        this._deactivatedButtons = new Set();
        this._collapsedGrids = { pull: false, push: false };
    }

    /**
     * Obtiene el conjunto de claves de botones desactivados en el acorde actual.
     * @returns {Set<string>}
     */
    getDeactivatedButtons() {
        return this._deactivatedButtons;
    }

    /**
     * Registra el callback para cuando un acorde es editado o eliminado en el editor inline.
     * @param {Function} callback
     */
    setTimelineUpdateCallback(callback) {
        this._onTimelineUpdated = callback;
    }

    /**
     * Actualiza el acorde activo y los botones necesarios (Abre / Cierra) en ambos diapasones.
     * @param {Object} chord Objeto de acorde { chordName, chordSymbol, noteMods, ... }
     * @param {Object} primaryAccordionData Datos físicos del acordeón 1
     * @param {Object} secondaryAccordionData Datos físicos del acordeón 2
     * @param {string} [notation='latina']
     * @param {number} [primOffset=0]
     * @param {number} [secOffset=0]
     * @param {Function} [onButtonAction=null]
     */
    renderActiveChord(
        chord,
        primaryAccordionData,
        secondaryAccordionData,
        notation = 'latina',
        primOffset = 0,
        secOffset = 0,
        onButtonAction = null
    ) {
        this._currentChord = chord;
        this._lastPrimaryData = primaryAccordionData;
        this._lastSecondaryData = secondaryAccordionData;
        this._lastNotation = notation;
        this._lastPrimOffset = primOffset;
        this._lastSecOffset = secOffset;
        this._lastOnButtonAction = onButtonAction;

        if (this._primSidebar && primaryAccordionData) {
            this._renderSingleSidebar(
                this._primSidebar,
                chord,
                primaryAccordionData,
                'Acordeón 1',
                notation,
                primOffset,
                'primary',
                onButtonAction
            );
        }

        if (this._secSidebar && secondaryAccordionData) {
            this._renderSingleSidebar(
                this._secSidebar,
                chord,
                secondaryAccordionData,
                '2do Acordeón',
                notation,
                secOffset,
                'secondary',
                onButtonAction
            );
        }
    }

    /**
     * Renderiza el contenido de una barra lateral para un diapasón específico.
     * @private
     */
    _renderSingleSidebar(
        sidebarEl,
        chord,
        accordionData,
        accordionTitle,
        notation,
        tuningOffset,
        targetKey,
        onButtonAction
    ) {
        if (!sidebarEl) return;
        const activeBox = sidebarEl.querySelector('.sidebar-active-chord-box');
        if (!activeBox) return;

        if (!chord || !chord.noteMods || chord.noteMods.length === 0) {
            activeBox.innerHTML = `
                <div class="sidebar-placeholder">
                    <i class="fas fa-headphones"></i>
                    <span>Carga una canción para ver los acordes y digitaciones</span>
                </div>
            `;
            return;
        }

        const buttons = getAccordionButtonsForChord(
            accordionData,
            chord.noteMods,
            notation,
            tuningOffset
        );

        const formatButtons = (btnList, dirClass, dirKey) => {
            if (!btnList || btnList.length === 0) {
                return '<span class="sidebar-empty-msg">No disponible</span>';
            }
            return btnList.map(b => {
                const btnKey = `${dirKey}_${b.id}`;
                const isDeactivated = this._deactivatedButtons.has(btnKey);
                const statusTitle = isDeactivated
                    ? `[DESACTIVADO] ${b.label}: ${b.noteName} - Clic para activar en este acorde`
                    : `[ACTIVO] ${b.label}: ${b.noteName} - Clic para desactivar en este acorde`;

                return `
                    <button type="button" 
                        class="sidebar-btn-badge ${dirClass} ${isDeactivated ? 'is-deactivated' : 'is-active'}" 
                        data-key="${btnKey}"
                        data-id="${b.id}" 
                        data-dir="${b.direction}" 
                        data-midi="${b.midi}" 
                        title="${statusTitle}">
                        <span class="badge-status-dot ${isDeactivated ? 'dot-inactive' : 'dot-active'}">
                            <i class="fas ${isDeactivated ? 'fa-ban' : 'fa-check'}"></i>
                        </span>
                        <strong>${b.label}</strong>
                        <small>${b.noteName}</small>
                    </button>
                `;
            }).join('');
        };

        const currentAction = chord.bellowsAction || 'both';
        const isPullChecked = currentAction === 'both' || currentAction === 'pull';
        const isPushChecked = currentAction === 'both' || currentAction === 'push';

        const isPullCollapsed = !!this._collapsedGrids.pull;
        const isPushCollapsed = !!this._collapsedGrids.push;

        const activePullCount = buttons.pullButtons.filter(b => !this._deactivatedButtons.has(`pull_${b.id}`)).length;
        const activePushCount = buttons.pushButtons.filter(b => !this._deactivatedButtons.has(`push_${b.id}`)).length;
        const hasDeactivated = this._deactivatedButtons.size > 0 || isPullCollapsed || isPushCollapsed;

        activeBox.innerHTML = `
            <div class="sidebar-chord-card-header">
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <span class="sidebar-acc-tag">${accordionTitle}</span>
                    <span class="sidebar-chord-symbol">${chord.chordSymbol || ''}</span>
                </div>
                <div style="display:flex; justify-content:space-between; align-items:center; margin-top:2px; gap:4px;">
                    <strong class="sidebar-chord-name">${chord.chordName}</strong>
                    <div style="display:flex; gap:3px; align-items:center;">
                        <button type="button" class="sidebar-btn-restore-all ${hasDeactivated ? 'has-deactivated' : ''}" title="Mostrar y activar todas las digitaciones de botones (restaurar todas)">
                            <i class="fas fa-check-double"></i> Mostrar todas
                        </button>
                        <button type="button" class="sidebar-card-edit-btn" title="Editar este acorde">
                            <i class="fas fa-pencil-alt"></i> Editar
                        </button>
                    </div>
                </div>
            </div>

            <!-- BOTONES PARA ABRE (PULL) -->
            <div class="sidebar-bellows-block pull-block ${!isPullChecked ? 'action-dimmed' : ''}">
                <div class="sidebar-bellows-header" data-dir="pull">
                    <label class="sidebar-checkbox-label" title="Marcar para ejecutar Abriendo en la melodía">
                        <input type="checkbox" class="sidebar-dir-checkbox" data-dir="pull" ${isPullChecked ? 'checked' : ''}>
                        <span class="sidebar-bellows-title"><i class="fas fa-arrow-left"></i> Abre (Pull)</span>
                    </label>
                    <div style="display:flex; align-items:center; gap:5px;">
                        <span class="sidebar-bellows-count" data-dir="pull">${activePullCount}/${buttons.pullButtons.length} bot.</span>
                        <button type="button" class="sidebar-btn-toggle-bellows-vis" data-dir="pull" title="Visualizar u ocultar los botones de Abre">
                            <i class="fas ${isPullCollapsed ? 'fa-eye-slash' : 'fa-eye'}"></i>
                        </button>
                    </div>
                </div>
                <div class="sidebar-buttons-grid pull-grid ${isPullCollapsed ? 'is-collapsed' : ''}">
                    ${formatButtons(buttons.pullButtons, 'pull-badge', 'pull')}
                </div>
            </div>

            <!-- BOTONES PARA CIERRA (PUSH) -->
            <div class="sidebar-bellows-block push-block ${!isPushChecked ? 'action-dimmed' : ''}">
                <div class="sidebar-bellows-header" data-dir="push">
                    <label class="sidebar-checkbox-label" title="Marcar para ejecutar Cerrando en la melodía">
                        <input type="checkbox" class="sidebar-dir-checkbox" data-dir="push" ${isPushChecked ? 'checked' : ''}>
                        <span class="sidebar-bellows-title"><i class="fas fa-arrow-right"></i> Cierra (Push)</span>
                    </label>
                    <div style="display:flex; align-items:center; gap:5px;">
                        <span class="sidebar-bellows-count" data-dir="push">${activePushCount}/${buttons.pushButtons.length} bot.</span>
                        <button type="button" class="sidebar-btn-toggle-bellows-vis" data-dir="push" title="Visualizar u ocultar los botones de Cierra">
                            <i class="fas ${isPushCollapsed ? 'fa-eye-slash' : 'fa-eye'}"></i>
                        </button>
                    </div>
                </div>
                <div class="sidebar-buttons-grid push-grid ${isPushCollapsed ? 'is-collapsed' : ''}">
                    ${formatButtons(buttons.pushButtons, 'push-badge', 'push')}
                </div>
            </div>
        `;

        // Botón "Mostrar todas" para restaurar y activar todos los botones
        const btnRestore = activeBox.querySelector('.sidebar-btn-restore-all');
        if (btnRestore) {
            btnRestore.addEventListener('click', (e) => {
                e.stopPropagation();
                this._deactivatedButtons.clear();
                this._collapsedGrids = { pull: false, push: false };
                this.renderActiveChord(
                    this._currentChord,
                    this._lastPrimaryData,
                    this._lastSecondaryData,
                    this._lastNotation,
                    this._lastPrimOffset,
                    this._lastSecOffset,
                    this._lastOnButtonAction
                );
                if (onButtonAction) {
                    onButtonAction({
                        type: 'button_toggle_active',
                        target: targetKey,
                        chord,
                        deactivatedButtons: this._deactivatedButtons
                    });
                }
            });
        }

        // Botones para colapsar/expandir toda la cuadrícula de Abre o Cierra
        activeBox.querySelectorAll('.sidebar-btn-toggle-bellows-vis').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const dir = btn.dataset.dir;
                this._collapsedGrids[dir] = !this._collapsedGrids[dir];
                const grid = activeBox.querySelector(`.${dir}-grid`);
                if (grid) {
                    grid.classList.toggle('is-collapsed', this._collapsedGrids[dir]);
                }
                const icon = btn.querySelector('i');
                if (icon) {
                    icon.className = `fas ${this._collapsedGrids[dir] ? 'fa-eye-slash' : 'fa-eye'}`;
                }
            });
        });

        // Botón editar en el header del acorde activo (Sin Ventana Modal)
        const btnEditHeader = activeBox.querySelector('.sidebar-card-edit-btn');
        if (btnEditHeader) {
            btnEditHeader.addEventListener('click', (e) => {
                e.stopPropagation();
                const targetIdx = this._activeTimelineIndex >= 0 ? this._activeTimelineIndex : 0;
                this._openSidebarInlineEditor(sidebarEl, targetIdx);
            });
        }

        // Checkbox events para definir Abre / Cierra en la ejecución
        const dirCheckboxes = activeBox.querySelectorAll('.sidebar-dir-checkbox');
        dirCheckboxes.forEach(chk => {
            chk.addEventListener('click', (e) => e.stopPropagation());
            chk.addEventListener('change', () => {
                const pullChk = activeBox.querySelector('.sidebar-dir-checkbox[data-dir="pull"]');
                const pushChk = activeBox.querySelector('.sidebar-dir-checkbox[data-dir="push"]');
                let newAction = 'both';
                if (pullChk && pushChk) {
                    if (pullChk.checked && !pushChk.checked) {
                        newAction = 'pull';
                    } else if (!pullChk.checked && pushChk.checked) {
                        newAction = 'push';
                    } else if (pullChk.checked && pushChk.checked) {
                        newAction = 'both';
                    } else {
                        chk.checked = true;
                        newAction = chk.dataset.dir;
                    }
                }
                chord.bellowsAction = newAction;

                const pullBlock = activeBox.querySelector('.pull-block');
                const pushBlock = activeBox.querySelector('.push-block');
                if (pullBlock) pullBlock.classList.toggle('action-dimmed', newAction === 'push');
                if (pushBlock) pushBlock.classList.toggle('action-dimmed', newAction === 'pull');

                if (onButtonAction) {
                    onButtonAction({
                        type: 'bellows_preference_change',
                        target: targetKey,
                        bellowsAction: newAction,
                        chord
                    });
                }
            });
        });

        // Eventos al hacer clic en el encabezado de los bloques Abre / Cierra para previsualizar/tocar
        const pullHeader = activeBox.querySelector('.pull-block .sidebar-bellows-header');
        if (pullHeader) {
            pullHeader.addEventListener('click', (e) => {
                if (e.target.closest('.sidebar-dir-checkbox') || e.target.closest('.sidebar-checkbox-label') || e.target.closest('.sidebar-btn-toggle-bellows-vis')) return;
                const activePullButtons = buttons.pullButtons.filter(b => !this._deactivatedButtons.has(`pull_${b.id}`));
                if (onButtonAction) {
                    onButtonAction({
                        target: targetKey,
                        direction: 'pull',
                        chord,
                        buttons: activePullButtons
                    });
                }
            });
        }

        const pushHeader = activeBox.querySelector('.push-block .sidebar-bellows-header');
        if (pushHeader) {
            pushHeader.addEventListener('click', (e) => {
                if (e.target.closest('.sidebar-dir-checkbox') || e.target.closest('.sidebar-checkbox-label') || e.target.closest('.sidebar-btn-toggle-bellows-vis')) return;
                const activePushButtons = buttons.pushButtons.filter(b => !this._deactivatedButtons.has(`push_${b.id}`));
                if (onButtonAction) {
                    onButtonAction({
                        target: targetKey,
                        direction: 'push',
                        chord,
                        buttons: activePushButtons
                    });
                }
            });
        }

        // Clic en un botón de acorde: Activar / Desactivar digitación
        activeBox.querySelectorAll('.sidebar-btn-badge').forEach(badge => {
            badge.addEventListener('click', (e) => {
                e.stopPropagation();
                const btnKey = badge.dataset.key;
                const btnId = badge.dataset.id;
                const dir = badge.dataset.dir;
                const midi = parseInt(badge.dataset.midi, 10);

                const wasDeactivated = this._deactivatedButtons.has(btnKey);
                if (wasDeactivated) {
                    // Activar botón
                    this._deactivatedButtons.delete(btnKey);
                    // Tocar sonido breve al activarse
                    if (onButtonAction) {
                        onButtonAction({
                            target: targetKey,
                            direction: dir,
                            singleButtonId: btnId,
                            midi
                        });
                    }
                } else {
                    // Desactivar botón
                    this._deactivatedButtons.add(btnKey);
                }

                const isNowDeactivated = this._deactivatedButtons.has(btnKey);
                badge.classList.toggle('is-deactivated', isNowDeactivated);
                badge.classList.toggle('is-active', !isNowDeactivated);

                const dot = badge.querySelector('.badge-status-dot');
                if (dot) {
                    dot.className = `badge-status-dot ${isNowDeactivated ? 'dot-inactive' : 'dot-active'}`;
                    dot.innerHTML = `<i class="fas ${isNowDeactivated ? 'fa-ban' : 'fa-check'}"></i>`;
                }

                const labelText = badge.querySelector('strong')?.textContent || '';
                const noteText = badge.querySelector('small')?.textContent || '';
                badge.title = isNowDeactivated
                    ? `[DESACTIVADO] ${labelText}: ${noteText} - Clic para activar en este acorde`
                    : `[ACTIVO] ${labelText}: ${noteText} - Clic para desactivar en este acorde`;

                // Actualizar contadores de botones activos
                const pullCountEl = activeBox.querySelector(`.sidebar-bellows-count[data-dir="pull"]`);
                if (pullCountEl) {
                    const curPull = buttons.pullButtons.filter(b => !this._deactivatedButtons.has(`pull_${b.id}`)).length;
                    pullCountEl.textContent = `${curPull}/${buttons.pullButtons.length} bot.`;
                }
                const pushCountEl = activeBox.querySelector(`.sidebar-bellows-count[data-dir="push"]`);
                if (pushCountEl) {
                    const curPush = buttons.pushButtons.filter(b => !this._deactivatedButtons.has(`push_${b.id}`)).length;
                    pushCountEl.textContent = `${curPush}/${buttons.pushButtons.length} bot.`;
                }

                if (btnRestore) {
                    btnRestore.classList.toggle('has-deactivated', this._deactivatedButtons.size > 0);
                }

                // Sincronizar resaltado del diapasón
                if (onButtonAction) {
                    onButtonAction({
                        type: 'button_toggle_active',
                        target: targetKey,
                        direction: dir,
                        btnId,
                        btnKey,
                        isActive: !isNowDeactivated,
                        chord,
                        deactivatedButtons: this._deactivatedButtons
                    });
                }
            });
        });
    }

    /**
     * Renderiza la lista de acordes detectados directamente debajo de Abre y Cierra.
     * Incluye marca visual de cambio de acorde y botón de edición a la derecha de cada acorde.
     * @param {Array} chords Lista de acordes de la canción
     * @param {number} activeIndex
     * @param {Function} onSelectChord
     */
    renderChordsList(chords, activeIndex = -1, onSelectChord = null) {
        this._currentTimeline = chords;
        this._activeTimelineIndex = activeIndex;
        this._onSelectChord = onSelectChord;

        [this._primSidebar, this._secSidebar].forEach(sidebar => {
            if (!sidebar) return;
            const listEl = sidebar.querySelector('.sidebar-song-chords-container');
            if (!listEl) return;
            listEl.innerHTML = '';

            if (!chords || chords.length === 0) {
                listEl.innerHTML = '<span style="color:#64748b; font-size:0.65rem; padding:4px;">Sin pista cargada</span>';
                return;
            }

            const headerLabel = document.createElement('div');
            headerLabel.className = 'sidebar-song-chords-title';
            headerLabel.innerHTML = `
                <span><i class="fas fa-list-ol"></i> Acordes Canción (${chords.length})</span>
                <span style="font-size:0.52rem; color:#64748b;">⚡ Cambio &amp; Edición</span>
            `;
            listEl.appendChild(headerLabel);

            // Contenedor para el editor inline (Sin ventana modal)
            const editorSlot = document.createElement('div');
            editorSlot.className = 'sidebar-inline-editor-slot';
            listEl.appendChild(editorSlot);

            const scrollBox = document.createElement('div');
            scrollBox.className = 'sidebar-song-chords-scroll';

            chords.forEach((chord, idx) => {
                const row = document.createElement('div');
                row.className = 'sidebar-mini-chord-row';
                if (idx === activeIndex) {
                    row.classList.add('active-mini-chord');
                }

                const changeTime = chord.endTime || chord.startTime;

                row.innerHTML = `
                    <button type="button" class="sidebar-mini-chord-chip" data-idx="${idx}" title="Reproducir acorde: ${chord.chordName} (${this._formatTime(chord.startTime)})">
                        <strong>${chord.chordName}</strong>
                        <div class="sidebar-chord-meta-right">
                            <span class="sidebar-chord-time">${this._formatTime(chord.startTime)}</span>
                            <span class="sidebar-change-badge" title="Cambio de acorde a los ${this._formatTime(changeTime)}">
                                <i class="fas fa-bolt"></i> ${this._formatTime(changeTime)}
                            </span>
                        </div>
                    </button>
                    <button type="button" class="sidebar-btn-edit-chord" data-idx="${idx}" title="Editar este acorde a la derecha">
                        <i class="fas fa-pencil-alt"></i>
                    </button>
                `;

                const chipBtn = row.querySelector('.sidebar-mini-chord-chip');
                chipBtn.addEventListener('click', () => {
                    if (onSelectChord) onSelectChord(chord, idx);
                });

                const editBtn = row.querySelector('.sidebar-btn-edit-chord');
                editBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this._openSidebarInlineEditor(sidebar, idx);
                });

                scrollBox.appendChild(row);
            });

            listEl.appendChild(scrollBox);
        });
    }

    /**
     * Abre el editor inline directamente en el sidebar sin ventana modal.
     * @private
     * @param {HTMLElement} sidebarEl
     * @param {number} idx Índice del acorde a editar
     */
    _openSidebarInlineEditor(sidebarEl, idx) {
        if (!this._currentTimeline || idx < 0 || idx >= this._currentTimeline.length) return;
        this._editingChordIndex = idx;
        this._activeEditorSidebar = sidebarEl;

        const editorSlot = sidebarEl.querySelector('.sidebar-inline-editor-slot');
        if (!editorSlot) return;

        const chord = this._currentTimeline[idx];
        const latinNotes = getNoteNamesList(NOTATION_MODES.LATINA);

        const rootOptions = latinNotes.map((name, i) => `
            <option value="${i}" ${chord.root === i ? 'selected' : ''}>${name}</option>
        `).join('');

        const chordType = chord.chordType || (chord.chordName.toLowerCase().includes('menor') ? 'minor' : 'major');

        editorSlot.innerHTML = `
            <div class="sidebar-inline-editor">
                <div class="sidebar-inline-editor-header">
                    <span><i class="fas fa-sliders-h"></i> Editar: <strong>${chord.chordName}</strong></span>
                    <button type="button" class="btn-close-inline" title="Cerrar editor">&times;</button>
                </div>
                <div class="sidebar-inline-editor-body">
                    <div class="sidebar-editor-field-row">
                        <label>Tónica:</label>
                        <select class="sidebar-editor-select sel-root">${rootOptions}</select>
                    </div>
                    <div class="sidebar-editor-field-row">
                        <label>Cualidad:</label>
                        <select class="sidebar-editor-select sel-type">
                            <option value="major" ${chordType === 'major' ? 'selected' : ''}>Mayor</option>
                            <option value="minor" ${chordType === 'minor' ? 'selected' : ''}>Menor (m)</option>
                            <option value="7" ${chordType === '7' ? 'selected' : ''}>7ma Dominante</option>
                            <option value="m7" ${chordType === 'm7' ? 'selected' : ''}>Menor 7ma (m7)</option>
                            <option value="dim" ${chordType === 'dim' ? 'selected' : ''}>Disminuido</option>
                            <option value="aug" ${chordType === 'aug' ? 'selected' : ''}>Aumentado</option>
                            <option value="sus4" ${chordType === 'sus4' ? 'selected' : ''}>Sus4</option>
                            <option value="sus2" ${chordType === 'sus2' ? 'selected' : ''}>Sus2</option>
                        </select>
                    </div>
                    <div class="sidebar-editor-field-row">
                        <label>Inicio:</label>
                        <input type="number" step="0.1" min="0" class="sidebar-editor-input inp-start" value="${(chord.startTime || 0).toFixed(2)}">
                        <button type="button" class="sidebar-editor-btn-time btn-cur-start" title="Usar tiempo actual del reproductor">⏱️</button>
                    </div>
                    <div class="sidebar-editor-field-row">
                        <label><i class="fas fa-bolt" style="color:#eab308;"></i> Cambio:</label>
                        <input type="number" step="0.1" min="0" class="sidebar-editor-input inp-end" value="${(chord.endTime || chord.startTime + 1).toFixed(2)}">
                        <button type="button" class="sidebar-editor-btn-time btn-cur-end" title="Usar tiempo actual del reproductor">⏱️</button>
                    </div>
                    <div class="sidebar-editor-change-notice">
                        <i class="fas fa-bolt"></i> <span>Al segundo de Cambio se efectúa la transición armónica.</span>
                    </div>
                    <div class="sidebar-editor-actions">
                        <button type="button" class="sidebar-editor-btn sidebar-editor-btn--danger btn-del" title="Eliminar este acorde"><i class="fas fa-trash"></i></button>
                        <div style="display:flex; gap:3px;">
                            <button type="button" class="sidebar-editor-btn sidebar-editor-btn--secondary btn-cancel">Cancelar</button>
                            <button type="button" class="sidebar-editor-btn sidebar-editor-btn--primary btn-save">Guardar</button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Listeners del editor inline
        const closeBtn = editorSlot.querySelector('.btn-close-inline');
        const cancelBtn = editorSlot.querySelector('.btn-cancel');
        const saveBtn = editorSlot.querySelector('.btn-save');
        const delBtn = editorSlot.querySelector('.btn-del');
        const curStartBtn = editorSlot.querySelector('.btn-cur-start');
        const curEndBtn = editorSlot.querySelector('.btn-cur-end');
        const inpStart = editorSlot.querySelector('.inp-start');
        const inpEnd = editorSlot.querySelector('.inp-end');
        const selRoot = editorSlot.querySelector('.sel-root');
        const selType = editorSlot.querySelector('.sel-type');

        const closeInline = () => {
            editorSlot.innerHTML = '';
            this._editingChordIndex = -1;
        };

        if (closeBtn) closeBtn.addEventListener('click', closeInline);
        if (cancelBtn) cancelBtn.addEventListener('click', closeInline);

        if (curStartBtn) {
            curStartBtn.addEventListener('click', () => {
                const cur = audioPlayerController.currentTime || 0;
                inpStart.value = cur.toFixed(2);
            });
        }

        if (curEndBtn) {
            curEndBtn.addEventListener('click', () => {
                const cur = audioPlayerController.currentTime || 0;
                inpEnd.value = cur.toFixed(2);
            });
        }

        if (delBtn) {
            delBtn.addEventListener('click', () => {
                this._currentTimeline.splice(idx, 1);
                closeInline();
                const nextIdx = Math.min(idx, this._currentTimeline.length - 1);
                if (this._onTimelineUpdated) {
                    this._onTimelineUpdated(this._currentTimeline, nextIdx);
                }
                this.renderChordsList(this._currentTimeline, nextIdx, this._onSelectChord);
            });
        }

        if (saveBtn) {
            saveBtn.addEventListener('click', () => {
                const root = parseInt(selRoot.value, 10);
                const type = selType.value;
                const start = Math.max(0, parseFloat(inpStart.value) || 0);
                const end = Math.max(start + 0.1, parseFloat(inpEnd.value) || (start + 1));

                const latList = getNoteNamesList(NOTATION_MODES.LATINA);
                const engList = getNoteNamesList(NOTATION_MODES.ALEMANA);
                const rootLat = latList[root] || 'Do';
                const rootEng = engList[root] || 'C';

                let typeLabel = '';
                let symbolSuffix = '';
                let intervals = [0, 4, 7];

                if (type === 'minor') {
                    typeLabel = 'Menor';
                    symbolSuffix = 'm';
                    intervals = [0, 3, 7];
                } else if (type === '7') {
                    typeLabel = '7ma';
                    symbolSuffix = '7';
                    intervals = [0, 4, 7, 10];
                } else if (type === 'm7') {
                    typeLabel = 'Menor 7ma';
                    symbolSuffix = 'm7';
                    intervals = [0, 3, 7, 10];
                } else if (type === 'dim') {
                    typeLabel = 'Disminuido';
                    symbolSuffix = 'dim';
                    intervals = [0, 3, 6];
                } else if (type === 'aug') {
                    typeLabel = 'Aumentado';
                    symbolSuffix = 'aug';
                    intervals = [0, 4, 8];
                } else if (type === 'sus4') {
                    typeLabel = 'Sus4';
                    symbolSuffix = 'sus4';
                    intervals = [0, 5, 7];
                } else if (type === 'sus2') {
                    typeLabel = 'Sus2';
                    symbolSuffix = 'sus2';
                    intervals = [0, 2, 7];
                }

                const updatedChord = {
                    ...chord,
                    root,
                    chordType: type,
                    chordName: `${rootLat} ${typeLabel}`.trim(),
                    chordSymbol: `${rootEng}${symbolSuffix}`.trim(),
                    noteMods: intervals.map(i => (root + i) % 12),
                    playbackMidis: intervals.map(i => 60 + root + i),
                    startTime: start,
                    endTime: end,
                    confidence: 1.0,
                    bassNote: root
                };

                // Ajuste automático del acorde anterior y posterior para transición limpia
                if (idx > 0) {
                    const prev = this._currentTimeline[idx - 1];
                    if (prev && prev.endTime > start) prev.endTime = start;
                }
                if (idx < this._currentTimeline.length - 1) {
                    const next = this._currentTimeline[idx + 1];
                    if (next && next.startTime < end) next.startTime = end;
                }

                this._currentTimeline[idx] = updatedChord;
                this._currentTimeline.sort((a, b) => a.startTime - b.startTime);
                const newIdx = this._currentTimeline.indexOf(updatedChord);

                closeInline();

                if (this._onTimelineUpdated) {
                    this._onTimelineUpdated(this._currentTimeline, newIdx >= 0 ? newIdx : idx);
                }
                this.renderChordsList(this._currentTimeline, newIdx >= 0 ? newIdx : idx, this._onSelectChord);
            });
        }
    }

    /**
     * Marca el chip activo en la lista de acordes de la canción.
     * @param {number} activeIndex
     */
    setActiveTimelineIndex(activeIndex) {
        this._activeTimelineIndex = activeIndex;
        [this._primSidebar, this._secSidebar].forEach(sidebar => {
            if (!sidebar) return;
            const rows = sidebar.querySelectorAll('.sidebar-mini-chord-row');
            rows.forEach((r, idx) => {
                const isActive = idx === activeIndex;
                r.classList.toggle('active-mini-chord', isActive);
                if (isActive) {
                    r.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                }
            });
        });
    }

    _formatTime(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
}

export default DiapasonChordSidebarView;

