/**
 * @fileoverview Vista de la Barra Lateral de Acordes Identificados en el Audio (SRP).
 * Se ubica a la derecha de cada diapasón (acordeón 1 y 2) mostrando el acorde
 * actual del audio y los botones necesarios tanto para Abrir como para Cerrar el fuelle.
 * @module ui/DiapasonChordSidebarView
 */

import { getAccordionButtonsForChord } from '../theory/Scales.js';

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

        const formatButtons = (btnList, dirClass) => {
            if (!btnList || btnList.length === 0) {
                return '<span class="sidebar-empty-msg">No disponible</span>';
            }
            return btnList.map(b => `
                <button type="button" class="sidebar-btn-badge ${dirClass}" data-id="${b.id}" data-dir="${b.direction}" data-midi="${b.midi}" title="${b.label}: ${b.noteName}">
                    <strong>${b.label}</strong>
                    <small>${b.noteName}</small>
                </button>
            `).join('');
        };

        const currentAction = chord.bellowsAction || 'both';
        const isPullChecked = currentAction === 'both' || currentAction === 'pull';
        const isPushChecked = currentAction === 'both' || currentAction === 'push';

        activeBox.innerHTML = `
            <div class="sidebar-chord-card-header">
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <span class="sidebar-acc-tag">${accordionTitle}</span>
                    <span class="sidebar-chord-symbol">${chord.chordSymbol || ''}</span>
                </div>
                <strong class="sidebar-chord-name">${chord.chordName}</strong>
            </div>

            <!-- BOTONES PARA ABRE (PULL) -->
            <div class="sidebar-bellows-block pull-block ${!isPullChecked ? 'action-dimmed' : ''}">
                <div class="sidebar-bellows-header" data-dir="pull">
                    <label class="sidebar-checkbox-label" title="Marcar para ejecutar Abriendo en la melodía">
                        <input type="checkbox" class="sidebar-dir-checkbox" data-dir="pull" ${isPullChecked ? 'checked' : ''}>
                        <span class="sidebar-bellows-title"><i class="fas fa-arrow-left"></i> Abre (Pull)</span>
                    </label>
                    <span class="sidebar-bellows-count">${buttons.pullButtons.length} bot.</span>
                </div>
                <div class="sidebar-buttons-grid">
                    ${formatButtons(buttons.pullButtons, 'pull-badge')}
                </div>
            </div>

            <!-- BOTONES PARA CIERRA (PUSH) -->
            <div class="sidebar-bellows-block push-block ${!isPushChecked ? 'action-dimmed' : ''}">
                <div class="sidebar-bellows-header" data-dir="push">
                    <label class="sidebar-checkbox-label" title="Marcar para ejecutar Cerrando en la melodía">
                        <input type="checkbox" class="sidebar-dir-checkbox" data-dir="push" ${isPushChecked ? 'checked' : ''}>
                        <span class="sidebar-bellows-title"><i class="fas fa-arrow-right"></i> Cierra (Push)</span>
                    </label>
                    <span class="sidebar-bellows-count">${buttons.pushButtons.length} bot.</span>
                </div>
                <div class="sidebar-buttons-grid">
                    ${formatButtons(buttons.pushButtons, 'push-badge')}
                </div>
            </div>
        `;

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
                if (e.target.closest('.sidebar-dir-checkbox') || e.target.closest('.sidebar-checkbox-label')) return;
                if (onButtonAction) {
                    onButtonAction({
                        target: targetKey,
                        direction: 'pull',
                        chord,
                        buttons: buttons.pullButtons
                    });
                }
            });
        }

        const pushHeader = activeBox.querySelector('.push-block .sidebar-bellows-header');
        if (pushHeader) {
            pushHeader.addEventListener('click', (e) => {
                if (e.target.closest('.sidebar-dir-checkbox') || e.target.closest('.sidebar-checkbox-label')) return;
                if (onButtonAction) {
                    onButtonAction({
                        target: targetKey,
                        direction: 'push',
                        chord,
                        buttons: buttons.pushButtons
                    });
                }
            });
        }

        activeBox.querySelectorAll('.sidebar-btn-badge').forEach(badge => {
            badge.addEventListener('click', (e) => {
                e.stopPropagation();
                const btnId = badge.dataset.id;
                const dir = badge.dataset.dir;
                const midi = parseInt(badge.dataset.midi);
                if (onButtonAction) {
                    onButtonAction({
                        target: targetKey,
                        direction: dir,
                        singleButtonId: btnId,
                        midi
                    });
                }
            });
        });
    }

    /**
     * Renderiza la lista compacta de acordes detectados en la canción en ambas barras.
     * @param {Array} chords Lista de acordes de la canción
     * @param {number} activeIndex
     * @param {Function} onSelectChord
     */
    renderChordsList(chords, activeIndex = -1, onSelectChord = null) {
        this._currentTimeline = chords;
        this._activeTimelineIndex = activeIndex;

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
            headerLabel.innerHTML = `<i class="fas fa-list-ol"></i> Acordes de la canción (${chords.length}):`;
            listEl.appendChild(headerLabel);

            const scrollBox = document.createElement('div');
            scrollBox.className = 'sidebar-song-chords-scroll';

            chords.forEach((chord, idx) => {
                const item = document.createElement('button');
                item.type = 'button';
                item.className = 'sidebar-mini-chord-chip';
                if (idx === activeIndex) {
                    item.classList.add('active-mini-chord');
                }

                item.innerHTML = `
                    <strong>${chord.chordName}</strong>
                    <small>${this._formatTime(chord.startTime)}</small>
                `;

                item.addEventListener('click', () => {
                    if (onSelectChord) onSelectChord(chord, idx);
                });

                scrollBox.appendChild(item);
            });

            listEl.appendChild(scrollBox);
        });
    }

    /**
     * Marca el chip activo en la lista de acordes de la canción.
     * @param {number} activeIndex
     */
    setActiveTimelineIndex(activeIndex) {
        this._activeTimelineIndex = activeIndex;
        [this._primSidebar, this._secSidebar].forEach(sidebar => {
            if (!sidebar) return;
            const chips = sidebar.querySelectorAll('.sidebar-mini-chord-chip');
            chips.forEach((c, idx) => {
                const isActive = idx === activeIndex;
                c.classList.toggle('active-mini-chord', isActive);
                if (isActive) {
                    c.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
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
