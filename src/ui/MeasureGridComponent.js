/**
 * @fileoverview Componente de Cuadrícula de Compases (MeasureGridComponent).
 * Responsable exclusivo de:
 * - Renderizado de filas de compases 4/4 y pulsos interactivos
 * - Selección de secuencias y rangos de arrastre
 * - Indicadores visuales de compás/pulso activo en tiempo real
 * Cumple con el principio de responsabilidad única (SRP).
 * @module ui/MeasureGridComponent
 */

export class MeasureGridComponent {
    /**
     * @param {Object} options
     * @param {HTMLElement} options.primaryContainer Contenedor principal de la cuadrícula
     * @param {HTMLElement} [options.secondaryContainer] Contenedor secundario (Acordeón 2)
     * @param {Function} options.onSlotSelected Callback al interactuar con una celda
     * @param {Function} options.onDeleteRequested Callback al solicitar borrado
     * @param {Function} options.formatTime Función utilitaria de formato de tiempo
     */
    constructor(options) {
        this._container = options.primaryContainer;
        this._secContainer = options.secondaryContainer || null;
        this._onSlotSelected = options.onSlotSelected || (() => {});
        this._onDeleteRequested = options.onDeleteRequested || (() => {});
        this._formatTime = options.formatTime || ((s) => `${Math.floor(s / 60)}:${Math.floor(s % 60).toString().padStart(2, '0')}`);

        this._isDraggingGrid = false;
        this._dragStartBeat = null;
        this._dragEndBeat = null;
        this._selectedSequence = [];
        this._totalBars = 4;
        this._barSec = 2;
        this._beatSec = 0.5;

        this._activeBeatSlot = null;
        this._activeMeasureRow = null;
        this._secActiveBeatSlot = null;
        this._secActiveMeasureRow = null;
        this._lastScrollMeasure = -1;
    }

    get selectedSequence() {
        return this._selectedSequence;
    }

    set selectedSequence(seq) {
        this._selectedSequence = seq;
    }

    get isDraggingGrid() {
        return this._isDraggingGrid;
    }

    set isDraggingGrid(val) {
        this._isDraggingGrid = val;
    }

    get dragStartBeat() {
        return this._dragStartBeat;
    }

    get dragEndBeat() {
        return this._dragEndBeat;
    }

    get totalBars() {
        return this._totalBars;
    }

    set totalBars(val) {
        this._totalBars = val;
    }

    get beatSec() {
        return this._beatSec;
    }

    get barSec() {
        return this._barSec;
    }

    /**
     * Dibuja la cuadrícula de compases 4/4 completa.
     * @param {Array} chords Lista de acordes de la línea de tiempo
     * @param {number} duration Duración total en segundos
     * @param {number} bpm Tempo en BPM
     */
    render(chords, duration, bpm) {
        if (!this._container) return;
        this._container.innerHTML = '';

        const dur = duration || 16;
        const songBpm = bpm || 120;
        const beatSec = 60 / songBpm;
        const barSec = 4 * beatSec;
        const calculatedBars = Math.max(1, Math.ceil(dur / barSec));
        const totalBars = Math.max(4, this._totalBars || calculatedBars);

        this._barSec = barSec;
        this._beatSec = beatSec;
        this._totalBars = totalBars;

        const fragment = document.createDocumentFragment();
        let lastChordSymbol = null;

        for (let m = 0; m < totalBars; m++) {
            const row = document.createElement('div');
            row.className = 'measure-grid-row';
            row.id = `measure-row-${m}`;
            row.dataset.barIndex = m;

            const num = document.createElement('div');
            num.className = 'measure-grid-num';
            num.textContent = (m + 1);
            row.appendChild(num);

            const beats = document.createElement('div');
            beats.className = 'measure-grid-beats';

            for (let b = 0; b < 4; b++) {
                const globalBeatIndex = (m * 4) + b;
                const beatStart = (m * barSec) + (b * beatSec);
                const beatMid = beatStart + (beatSec * 0.25);
                const chord = (chords || []).find(c => c.startTime <= beatMid && c.endTime > beatMid);

                const slot = document.createElement('button');
                slot.type = 'button';
                slot.className = 'measure-beat-slot';
                slot.id = `beat-slot-${m}-${b}`;
                slot.dataset.barIndex = m;
                slot.dataset.beatIndex = b;
                slot.dataset.globalBeat = globalBeatIndex;
                slot.dataset.startTime = beatStart;

                const currentSymbol = chord ? chord.chordSymbol : '';
                const isChordStart = chord && Math.abs(chord.startTime - beatStart) < 0.05;

                if (currentSymbol) {
                    if (isChordStart || (m === 0 && b === 0) || currentSymbol !== lastChordSymbol) {
                        slot.classList.add('has-chord');
                        slot.innerHTML = `<span class="slot-chord-text" title="Clic o arrastra para editar ${currentSymbol}">${currentSymbol} <i class="fas fa-pen" style="font-size: 0.50rem; opacity: 0.4; margin-left: 2px;"></i></span>`;
                        lastChordSymbol = currentSymbol;
                    } else {
                        slot.classList.add('has-chord-continue');
                        slot.innerHTML = `<span class="slot-chord-text slot-chord-continue" title="Continúa ${currentSymbol}">${currentSymbol}</span>`;
                    }
                } else {
                    slot.innerHTML = `<span class="slot-empty-dot">·</span>`;
                    lastChordSymbol = null;
                }

                slot.title = `Compás ${m + 1}, Pulso ${b + 1} (${this._formatTime(beatStart)})${currentSymbol ? ' - Acorde: ' + currentSymbol : ' (Vacío)'}\nArrastra el ratón por varios cuadros para seleccionar y aplicar duración`;

                slot.addEventListener('mousedown', (e) => {
                    if (e.button !== 0) return;
                    e.preventDefault();
                    this._isDraggingGrid = true;
                    this._dragStartBeat = globalBeatIndex;
                    this._dragEndBeat = globalBeatIndex;
                    this.updateDragRangeSelection();
                });

                slot.addEventListener('mouseenter', () => {
                    if (!this._isDraggingGrid) return;
                    this._dragEndBeat = globalBeatIndex;
                    this.updateDragRangeSelection();
                });

                slot.addEventListener('keydown', (e) => {
                    if (e.key === 'Delete' || e.key === 'Del' || e.key === 'Backspace') {
                        e.preventDefault();
                        this._onDeleteRequested(globalBeatIndex, m, b, beatStart, beatSec, slot);
                    } else if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        this._onSlotSelected(globalBeatIndex, m, b, beatStart, beatSec, slot);
                    }
                });

                beats.appendChild(slot);
            }

            row.appendChild(beats);
            fragment.appendChild(row);
        }

        this._container.appendChild(fragment);

        if (this._secContainer) {
            this._renderSecondaryGrid(chords, totalBars, barSec, beatSec);
        }
    }

    /**
     * Dibuja la cuadrícula complementaria en el acordeón secundario.
     * @private
     */
    _renderSecondaryGrid(chords, totalBars, barSec, beatSec) {
        if (!this._secContainer) return;
        this._secContainer.innerHTML = '';
        const secFragment = document.createDocumentFragment();
        let secLastChordSymbol = null;

        for (let m = 0; m < totalBars; m++) {
            const secRow = document.createElement('div');
            secRow.className = 'measure-grid-row';
            secRow.id = `sec-measure-row-${m}`;
            secRow.dataset.barIndex = m;

            const secNum = document.createElement('div');
            secNum.className = 'measure-grid-num';
            secNum.textContent = (m + 1);
            secRow.appendChild(secNum);

            const secBeats = document.createElement('div');
            secBeats.className = 'measure-grid-beats';

            for (let b = 0; b < 4; b++) {
                const globalBeatIndex = (m * 4) + b;
                const beatStart = (m * barSec) + (b * beatSec);
                const beatMid = beatStart + (beatSec * 0.25);
                const chord = (chords || []).find(c => c.startTime <= beatMid && c.endTime > beatMid);

                const secSlot = document.createElement('button');
                secSlot.type = 'button';
                secSlot.className = 'measure-beat-slot';
                secSlot.id = `sec-beat-slot-${m}-${b}`;
                secSlot.dataset.barIndex = m;
                secSlot.dataset.beatIndex = b;
                secSlot.dataset.globalBeat = globalBeatIndex;
                secSlot.dataset.startTime = beatStart;

                const currentSymbol = chord ? chord.chordSymbol : '';
                const isChordStart = chord && Math.abs(chord.startTime - beatStart) < 0.05;

                if (currentSymbol) {
                    if (isChordStart || (m === 0 && b === 0) || currentSymbol !== secLastChordSymbol) {
                        secSlot.classList.add('has-chord');
                        secSlot.innerHTML = `<span class="slot-chord-text" title="Clic para saltar a ${currentSymbol}">${currentSymbol}</span>`;
                        secLastChordSymbol = currentSymbol;
                    } else {
                        secSlot.classList.add('has-chord-continue');
                        secSlot.innerHTML = `<span class="slot-chord-text slot-chord-continue" title="Continúa ${currentSymbol}">${currentSymbol}</span>`;
                    }
                } else {
                    secSlot.innerHTML = `<span class="slot-empty-dot">·</span>`;
                    secLastChordSymbol = null;
                }

                secBeats.appendChild(secSlot);
            }

            secRow.appendChild(secBeats);
            secFragment.appendChild(secRow);
        }

        this._secContainer.appendChild(secFragment);
    }

    /**
     * Actualiza el rango visual resaltado durante el arrastre interactivo.
     */
    updateDragRangeSelection() {
        if (!this._container || this._dragStartBeat === null || this._dragEndBeat === null) return;
        const minBeat = Math.min(this._dragStartBeat, this._dragEndBeat);
        const maxBeat = Math.max(this._dragStartBeat, this._dragEndBeat);

        this._container.querySelectorAll('.measure-beat-slot').forEach(s => {
            const g = parseInt(s.dataset.globalBeat, 10);
            if (g >= minBeat && g <= maxBeat) {
                s.classList.add('slot-in-range');
                s.classList.toggle('slot-range-start', g === minBeat);
                s.classList.toggle('slot-range-end', g === maxBeat);
            } else {
                s.classList.remove('slot-in-range', 'slot-range-start', 'slot-range-end');
            }
        });
    }

    /**
     * Refresca las etiquetas visuales de orden en la secuencia seleccionada.
     */
    refreshSequenceBadges() {
        if (!this._container) return;
        this._container.querySelectorAll('.measure-beat-slot').forEach(s => {
            s.classList.remove('slot-in-sequence');
            const badge = s.querySelector('.slot-seq-badge');
            if (badge) badge.remove();
        });

        this._selectedSequence.forEach((item, idx) => {
            const slot = item.slot || document.getElementById(`beat-slot-${item.barIndex}-${item.beatIndex}`);
            if (slot) {
                slot.classList.add('slot-in-sequence');
                const badge = document.createElement('span');
                badge.className = 'slot-seq-badge';
                badge.textContent = `${idx + 1}`;
                slot.appendChild(badge);
            }
        });
    }

    /**
     * Limpia la selección activa de secuencias.
     */
    clearSequenceSelection() {
        this._selectedSequence = [];
        this.refreshSequenceBadges();
    }

    /**
     * Actualiza los resaltados de reproducción en tiempo real.
     * @param {number} currentTime
     */
    updatePlaybackHighlights(currentTime) {
        if (!this._container) return;
        const barSec = this._barSec || 2;
        const beatSec = this._beatSec || 0.5;

        const curBar = Math.floor(currentTime / barSec);
        const curBeat = Math.floor((currentTime % barSec) / beatSec);

        // Desactivar slot anterior
        if (this._activeBeatSlot) {
            this._activeBeatSlot.classList.remove('is-active-beat');
            this._activeBeatSlot = null;
        }
        if (this._activeMeasureRow) {
            this._activeMeasureRow.classList.remove('is-active-measure');
            this._activeMeasureRow = null;
        }

        const slot = document.getElementById(`beat-slot-${curBar}-${curBeat}`);
        const row = document.getElementById(`measure-row-${curBar}`);

        if (slot) {
            slot.classList.add('is-active-beat');
            this._activeBeatSlot = slot;
        }
        if (row) {
            row.classList.add('is-active-measure');
            this._activeMeasureRow = row;
        }

        // Actualizar cuadrícula secundaria
        if (this._secActiveBeatSlot) {
            this._secActiveBeatSlot.classList.remove('is-active-beat');
            this._secActiveBeatSlot = null;
        }
        if (this._secActiveMeasureRow) {
            this._secActiveMeasureRow.classList.remove('is-active-measure');
            this._secActiveMeasureRow = null;
        }

        const secSlot = document.getElementById(`sec-beat-slot-${curBar}-${curBeat}`);
        const secRow = document.getElementById(`sec-measure-row-${curBar}`);
        if (secSlot) {
            secSlot.classList.add('is-active-beat');
            this._secActiveBeatSlot = secSlot;
        }
        if (secRow) {
            secRow.classList.add('is-active-measure');
            this._secActiveMeasureRow = secRow;
        }

        // Scroll automático suave cada compás
        if (row && curBar !== this._lastScrollMeasure) {
            this._lastScrollMeasure = curBar;
            row.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }
}
