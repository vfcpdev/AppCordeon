/**
 * @fileoverview Vista del Módulo de Armonía Diatónica: Cuarta y Quinta (SRP).
 * Muestra las posiciones y botones necesarios para ejecutar la Tónica (I),
 * Cuarta (IV) y Quinta (V) en el acordeón principal y secundario.
 * @module ui/CadenceView
 */

import { getAccordionButtonsForChord } from '../theory/Scales.js';

export class CadenceView {
    /**
     * @param {Object} elements Referencias a elementos del DOM
     * @param {HTMLElement} elements.container Contenedor de la sección de cadencia
     * @param {HTMLElement} elements.cardsContainer Contenedor de las 3 tarjetas (I, IV, V)
     * @param {HTMLElement} elements.activeToneLabel Etiqueta de la tónica activa
     */
    constructor(elements) {
        this._container = elements.container;
        this._cardsContainer = elements.cardsContainer;
        this._activeToneLabel = elements.activeToneLabel;
        this._activeChordId = null;
    }

    /**
     * Renderiza las tarjetas de Cuarta y Quinta para la tónica y afinaciones actuales.
     * @param {Array} cadenceChords Lista de acordes [I, IV, V]
     * @param {Object} primaryAccordionData Datos físicos del diapasón principal
     * @param {Object} [secondaryAccordionData=null] Datos físicos del 2do diapasón
     * @param {string} [notation='latina']
     * @param {number} [primaryOffset=0]
     * @param {number} [secondaryOffset=0]
     * @param {Function} onSelectChord Callback al seleccionar un acorde de la cadencia
     */
    render(
        cadenceChords,
        primaryAccordionData,
        secondaryAccordionData = null,
        notation = 'latina',
        primaryOffset = 0,
        secondaryOffset = 0,
        onSelectChord = null
    ) {
        if (!this._cardsContainer) return;
        this._cardsContainer.innerHTML = '';

        if (!cadenceChords || cadenceChords.length === 0) {
            this._cardsContainer.innerHTML = '<span style="color:#64748b; font-size:0.75rem;">No hay acordes de cadencia disponibles</span>';
            return;
        }

        const tonicChord = cadenceChords[0];
        if (this._activeToneLabel && tonicChord) {
            this._activeToneLabel.textContent = `Tónica: ${tonicChord.chordName}`;
        }

        cadenceChords.forEach(chord => {
            const card = document.createElement('div');
            card.className = 'cadence-card';
            card.id = `cadence-${chord.id}`;
            if (this._activeChordId === chord.id) {
                card.classList.add('active-cadence-card');
            }

            // Calcular botones de este acorde en el acordeón principal
            const primButtons = getAccordionButtonsForChord(
                primaryAccordionData,
                chord.noteMods,
                notation,
                primaryOffset
            );

            // Calcular botones de este acorde en el 2do acordeón (si existe)
            let secButtons = null;
            if (secondaryAccordionData) {
                secButtons = getAccordionButtonsForChord(
                    secondaryAccordionData,
                    chord.noteMods,
                    notation,
                    secondaryOffset
                );
            }

            const formatButtonChips = (buttons, directionClass) => {
                if (!buttons || buttons.length === 0) {
                    return '<span class="cadence-btn-empty">No disponible</span>';
                }
                // Tomar los primeros 6 botones más representativos para no saturar
                const displayBtns = buttons.slice(0, 7);
                return displayBtns.map(b => `
                    <span class="cadence-mini-chip ${directionClass}" title="${b.label}: ${b.noteName} (${directionClass === 'pull-chip' ? 'Abrir' : 'Cerrar'})">
                        <strong>${b.label}</strong> <small>${b.noteName}</small>
                    </span>
                `).join('');
            };

            card.innerHTML = `
                <div class="cadence-card-top" style="border-left: 4px solid ${chord.colorBadge};">
                    <div style="display:flex; justify-content:space-between; align-items:center; width:100%;">
                        <span class="cadence-role-badge" style="background:${chord.colorBadge}20; color:${chord.colorBadge}; border: 1px solid ${chord.colorBadge}40;">
                            ${chord.roleName}
                        </span>
                        <span class="cadence-numeral" style="color:${chord.colorBadge};">${chord.numeral}</span>
                    </div>
                    <div style="display:flex; justify-content:space-between; align-items:baseline; margin-top: 3px;">
                        <strong class="cadence-chord-title">${chord.chordName}</strong>
                        <span class="cadence-chord-sym">${chord.chordSymbol}</span>
                    </div>
                    <div class="cadence-notes-row">
                        Notas: <strong>${chord.noteNames.join(' - ')}</strong>
                    </div>
                </div>

                <!-- Botones en Acordeón Principal -->
                <div class="cadence-accordion-section">
                    <span class="cadence-accordion-lbl"><i class="fas fa-keyboard"></i> Acordeón Principal:</span>
                    <div class="cadence-bellows-row">
                        <div class="cadence-bellows-col">
                            <span class="cadence-bellows-tag pull-tag"><i class="fas fa-arrow-left"></i> Abre (${primButtons.pullButtons.length}):</span>
                            <div class="cadence-chips-wrap">
                                ${formatButtonChips(primButtons.pullButtons, 'pull-chip')}
                            </div>
                        </div>
                        <div class="cadence-bellows-col">
                            <span class="cadence-bellows-tag push-tag"><i class="fas fa-arrow-right"></i> Cierra (${primButtons.pushButtons.length}):</span>
                            <div class="cadence-chips-wrap">
                                ${formatButtonChips(primButtons.pushButtons, 'push-chip')}
                            </div>
                        </div>
                    </div>
                </div>

                ${secButtons ? `
                <!-- Botones en 2do Acordeón Comparativo -->
                <div class="cadence-accordion-section cadence-accordion-section--sec">
                    <span class="cadence-accordion-lbl"><i class="fas fa-clone"></i> 2do Acordeón (Equiv.):</span>
                    <div class="cadence-bellows-row">
                        <div class="cadence-bellows-col">
                            <span class="cadence-bellows-tag pull-tag"><i class="fas fa-arrow-left"></i> Abre (${secButtons.pullButtons.length}):</span>
                            <div class="cadence-chips-wrap">
                                ${formatButtonChips(secButtons.pullButtons, 'pull-chip')}
                            </div>
                        </div>
                        <div class="cadence-bellows-col">
                            <span class="cadence-bellows-tag push-tag"><i class="fas fa-arrow-right"></i> Cierra (${secButtons.pushButtons.length}):</span>
                            <div class="cadence-chips-wrap">
                                ${formatButtonChips(secButtons.pushButtons, 'push-chip')}
                            </div>
                        </div>
                    </div>
                </div>
                ` : ''}
            `;

            card.addEventListener('click', () => {
                this._activeChordId = chord.id;
                const all = this._cardsContainer.querySelectorAll('.cadence-card');
                all.forEach(c => c.classList.remove('active-cadence-card'));
                card.classList.add('active-cadence-card');

                if (onSelectChord) {
                    onSelectChord(chord);
                }
            });

            this._cardsContainer.appendChild(card);
        });
    }

    /**
     * Limpia la selección activa.
     */
    clearActive() {
        this._activeChordId = null;
        if (this._cardsContainer) {
            const all = this._cardsContainer.querySelectorAll('.cadence-card');
            all.forEach(c => c.classList.remove('active-cadence-card'));
        }
    }
}

export default CadenceView;
