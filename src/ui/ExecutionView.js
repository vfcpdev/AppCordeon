/**
 * @fileoverview Vista de Formas de Ejecución y Digitaciones (SRP).
 * Muestra las diferentes maneras de tocar una nota en el acordeón según la hilera y dirección del fuelle.
 * @module ui/ExecutionView
 */

export class ExecutionView {
    /**
     * @param {Object} elements Referencias DOM
     */
    constructor(elements) {
        this._noteNameLabel = elements.noteNameLabel;
        this._executionSelect = elements.executionSelect;
    }

    /**
     * Actualiza la etiqueta con el nombre de la nota activa y su rol/grado.
     * @param {string} text (ej: "Mi♭4 (Tónica)")
     */
    setNoteLabel(text) {
        if (this._noteNameLabel) {
            this._noteNameLabel.innerText = text;
        }
    }

    /**
     * Llena el selector con las diferentes formas de ejecución encontradas.
     * @param {Array} forms Lista de formas de ejecución
     * @param {(selectedForm: Object) => void} onSelect Callback al seleccionar una opción
     */
    renderForms(forms, onSelect) {
        if (!this._executionSelect) return;
        this._executionSelect.innerHTML = "";

        if (!forms || forms.length === 0) {
            const opt = document.createElement('option');
            opt.innerText = "No disponible en esta dirección de fuelle";
            this._executionSelect.appendChild(opt);
            return;
        }

        forms.forEach((f, idx) => {
            const opt = document.createElement('option');
            opt.value = idx;
            const tag = idx === 0 ? " (Principal)" : " (Alternativa)";
            opt.innerText = f.customLabel || `${f.rowName} · Botón ${f.btnNum} · ${f.direction}${tag}`;
            this._executionSelect.appendChild(opt);
        });

        this._executionSelect.onchange = () => {
            const selected = forms[parseInt(this._executionSelect.value)];
            if (selected && onSelect) {
                onSelect(selected);
            }
        };
    }
}
