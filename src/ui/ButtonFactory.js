/**
 * @fileoverview Factory Pattern para la creación de elementos de botón de acordeón.
 * Encapsula la lógica de renderizado del DOM de cada botón del diapasón.
 * @module ui/ButtonFactory
 */

import { BELLOWS_MODES, NOTATION_MODES } from '../core/Constants.js';
import { midiToName } from '../theory/MusicTheory.js';

export class ButtonFactory {
    /**
     * Crea un elemento HTML <button> configurado para el diapasón.
     * @param {Object} buttonData Datos del botón { id, rowKey, btnIndex, push, pull }
     * @param {string} bellowsMode Modo de fuelle activo ('both', 'push', 'pull')
     * @param {string} notation Modo de notación ('latina', 'alemana')
     * @param {number} tuningOffset Desplazamiento de afinación
     * @param {Object} handlers Callbacks { onClick, onRightClick }
     * @returns {HTMLButtonElement}
     */
    static createButton(buttonData, bellowsMode = BELLOWS_MODES.BOTH, notation = NOTATION_MODES.LATINA, tuningOffset = 0, handlers = {}) {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "btn-accordion";
        const prefix = handlers.idPrefix || '';
        btn.id = prefix + buttonData.id;
        btn.dataset.rawId = buttonData.id;
        btn.dataset.pushMidi = buttonData.push;
        btn.dataset.pullMidi = buttonData.pull;
        btn.dataset.rowKey = buttonData.rowKey;
        btn.dataset.btnIndex = buttonData.btnIndex;

        const lblPush = midiToName(buttonData.push, notation, true, tuningOffset);
        const lblPull = midiToName(buttonData.pull, notation, true, tuningOffset);
        const orderBadgeHtml = `<span class="btn-order-number" aria-hidden="true">${buttonData.btnIndex}</span>`;

        if (bellowsMode === BELLOWS_MODES.BOTH) {
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap" style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:0px;line-height:1;">
                    <span class="btn-note-push">${lblPush}</span>
                    <span class="btn-separator">─</span>
                    <span class="btn-note-pull">${lblPull}</span>
                </span>
            `;
            btn.title = `Botón ${buttonData.btnIndex} (${buttonData.rowKey}) | Cerrar: ${lblPush} | Abrir: ${lblPull}`;
        } else if (bellowsMode === BELLOWS_MODES.PUSH) {
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap"><span class="btn-note-single">${lblPush}</span></span>
            `;
            btn.title = `Botón ${buttonData.btnIndex} (${buttonData.rowKey}) | Cerrar: ${lblPush}`;
        } else {
            // BELLOWS_MODES.PULL
            btn.innerHTML = `
                ${orderBadgeHtml}
                <span class="btn-notes-wrap"><span class="btn-note-single">${lblPull}</span></span>
            `;
            btn.title = `Botón ${buttonData.btnIndex} (${buttonData.rowKey}) | Abrir: ${lblPull}`;
        }

        if (handlers.onClick) {
            btn.addEventListener('mousedown', (e) => {
                if (e.button === 0) { // Clic izquierdo
                    handlers.onClick(buttonData, btn, e);
                }
            });
            // Soporte táctil móvil / híbrido
            btn.addEventListener('touchstart', (e) => {
                handlers.onClick(buttonData, btn, e);
            }, { passive: true });
        }

        if (handlers.onRightClick) {
            btn.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                handlers.onRightClick(buttonData, btn, e);
            });
        }

        return btn;
    }
}
