/**
 * @fileoverview Controlador del Escenario de Diapasón (DiapasonStageController).
 * Responsable exclusivo del control de escenario físico:
 * - Volumen y mudo (A1 y A2)
 * - Vinculación / Sincronización de volumen
 * - Modo Espejo (inversión de hileras Af->Ad vs Ad<-Af)
 * - Visibilidad de los diapasones (A1 y A2)
 * Cumple con el principio de responsabilidad única (SRP).
 * @module controllers/DiapasonStageController
 */

import { audioEngine } from '../audio/AudioEngine.js';

export class DiapasonStageController {
    /**
     * @param {Object} options
     * @param {import('../ui/DiapasonView.js').DiapasonView} [options.diapasonView]
     * @param {import('../ui/DiapasonView.js').DiapasonView} [options.secondaryDiapasonView]
     * @param {Function} [options.onStageChanged] Callback invocado cuando cambia el escenario (espejo, visibilidad)
     */
    constructor(options = {}) {
        this._diapasonView = options.diapasonView || null;
        this._secondaryDiapasonView = options.secondaryDiapasonView || null;
        this._onStageChanged = options.onStageChanged || (() => {});

        // Estado de Volumen
        this._isVolumeSynced = typeof localStorage !== 'undefined'
            ? localStorage.getItem('acordeon_volume_synced') !== 'false'
            : true;
        this._diapasonVolume = 80;
        this._isDiapasonMuted = false;
        this._lastDiapasonVolume = 80;
        this._secondaryDiapasonVolume = 80;
        this._isSecondaryDiapasonMuted = false;
        this._lastSecondaryDiapasonVolume = 80;

        // Estado de Visibilidad
        this._isPrimaryDiapasonVisible = typeof localStorage !== 'undefined'
            ? localStorage.getItem('acordeon_primary_visible') !== 'false'
            : true;
        this._isSecondaryDiapasonVisible = typeof localStorage !== 'undefined'
            ? localStorage.getItem('acordeon_secondary_visible') !== 'false'
            : true;

        // Estado Modo Espejo (Intercambiar Hileras 1 y 3)
        this._isDiapasonMirrored = typeof localStorage !== 'undefined' && localStorage.getItem('acordeon_is_mirrored') === 'true';
        this._isSecondaryDiapasonMirrored = typeof localStorage !== 'undefined' && localStorage.getItem('acordeon_secondary_is_mirrored') === 'true';

        if (this._diapasonView) {
            this._diapasonView.setMirrored(this._isDiapasonMirrored);
        }
        if (this._secondaryDiapasonView) {
            this._secondaryDiapasonView.setMirrored(this._isSecondaryDiapasonMirrored);
        }
    }

    get isDiapasonMirrored() {
        return this._isDiapasonMirrored;
    }

    get isSecondaryDiapasonMirrored() {
        return this._isSecondaryDiapasonMirrored;
    }

    get isPrimaryVisible() {
        return this._isPrimaryDiapasonVisible;
    }

    get isSecondaryVisible() {
        return this._isSecondaryDiapasonVisible;
    }

    get diapasonVolume() {
        return this._diapasonVolume;
    }

    get isDiapasonMuted() {
        return this._isDiapasonMuted;
    }

    get secondaryDiapasonVolume() {
        return this._secondaryDiapasonVolume;
    }

    get isSecondaryDiapasonMuted() {
        return this._isSecondaryDiapasonMuted;
    }

    /**
     * Inicializa eventos y estados del DOM correspondientes al escenario.
     */
    init() {
        this._bindVolumeUIEvents();
        this._bindMirrorEvents();
        this._bindVisibilityEvents();

        this.applyPrimaryVolume(this._diapasonVolume, this._isDiapasonMuted, false);
        this.applySecondaryVolume(this._secondaryDiapasonVolume, this._isSecondaryDiapasonMuted, false);
        this.updateVolumeSyncUI();
        this.updateMirrorButtonsUI();
    }

    /**
     * Aplica el volumen del Diapasón 1 y actualiza su interfaz.
     * @param {number} vol Porcentaje (0 a 100)
     * @param {boolean} isMuted
     * @param {boolean} [syncOther=true]
     */
    applyPrimaryVolume(vol, isMuted, syncOther = true) {
        this._diapasonVolume = vol;
        this._isDiapasonMuted = isMuted;

        const effectiveVol = isMuted ? 0 : vol;
        const slider = document.getElementById('diapasonVolumeSlider');
        const lbl = document.getElementById('lblDiapasonVolume');
        const icon = document.getElementById('iconDiapasonVolume');
        const btnMute = document.getElementById('btnDiapasonVolumeMute');
        const chk = document.getElementById('chkDiapasonMute');

        if (slider) slider.value = effectiveVol;
        if (lbl) lbl.textContent = isMuted ? 'Mudo' : `${effectiveVol}%`;
        if (chk) chk.checked = isMuted;

        const iconClass = (isMuted || effectiveVol === 0)
            ? 'fas fa-volume-xmark'
            : (effectiveVol < 45 ? 'fas fa-volume-low' : 'fas fa-volume-high');
        if (icon) icon.className = iconClass;
        if (btnMute) btnMute.classList.toggle('is-muted', isMuted || effectiveVol === 0);

        this.updateMasterAudioVolume();

        if (this._isVolumeSynced && syncOther) {
            this.applySecondaryVolume(vol, isMuted, false);
        }
    }

    /**
     * Aplica el volumen del Diapasón 2 y actualiza su interfaz.
     * @param {number} vol Porcentaje (0 a 100)
     * @param {boolean} [isMuted=false]
     * @param {boolean} [syncOther=true]
     */
    applySecondaryVolume(vol, isMuted, syncOther = true) {
        this._secondaryDiapasonVolume = vol;
        this._isSecondaryDiapasonMuted = isMuted;

        const effectiveVol = isMuted ? 0 : vol;
        const slider = document.getElementById('secondaryDiapasonVolumeSlider');
        const lbl = document.getElementById('lblSecondaryDiapasonVolume');
        const icon = document.getElementById('iconSecondaryDiapasonVolume');
        const btnMute = document.getElementById('btnSecondaryDiapasonVolumeMute');
        const chk = document.getElementById('chkSecondaryDiapasonMute');

        if (slider) slider.value = effectiveVol;
        if (lbl) lbl.textContent = isMuted ? 'Mudo' : `${effectiveVol}%`;
        if (chk) chk.checked = isMuted;

        const iconClass = (isMuted || effectiveVol === 0)
            ? 'fas fa-volume-xmark'
            : (effectiveVol < 45 ? 'fas fa-volume-low' : 'fas fa-volume-high');
        if (icon) icon.className = iconClass;
        if (btnMute) btnMute.classList.toggle('is-muted', isMuted || effectiveVol === 0);

        this.updateMasterAudioVolume();

        if (this._isVolumeSynced && syncOther) {
            this.applyPrimaryVolume(vol, isMuted, false);
        }
    }

    /**
     * Actualiza el volumen maestro en dB para el sintetizador.
     */
    updateMasterAudioVolume() {
        const eff1 = this._isDiapasonMuted ? 0 : this._diapasonVolume;
        const eff2 = this._isSecondaryDiapasonMuted ? 0 : this._secondaryDiapasonVolume;
        const maxEff = Math.max(eff1, eff2);
        const db = maxEff === 0 ? -80 : (20 * Math.log10(maxEff / 100));
        audioEngine.setVolume(db);
    }

    /**
     * Actualiza la interfaz de los botones de vinculación/sincronización de volumen.
     */
    updateVolumeSyncUI() {
        const btn1 = document.getElementById('btnSyncVolumePrimary');
        const btn2 = document.getElementById('btnSyncVolumeSecondary');
        const icon1 = document.getElementById('iconSyncVolumePrimary');
        const icon2 = document.getElementById('iconSyncVolumeSecondary');

        [btn1, btn2].forEach(btn => {
            if (!btn) return;
            btn.classList.toggle('active', this._isVolumeSynced);
            btn.title = this._isVolumeSynced
                ? 'Volumen sincronizado (A1 y A2 vinculados). Clic para independizar controles de volumen.'
                : 'Volumen independiente (A1 y A2 separados). Clic para sincronizar controles de volumen.';
        });

        const iconClass = this._isVolumeSynced ? 'fas fa-link' : 'fas fa-link-slash';
        if (icon1) icon1.className = iconClass;
        if (icon2) icon2.className = iconClass;
    }

    /**
     * Actualiza el estado visual y texto de los botones de Modo Espejo (A1 y A2).
     */
    updateMirrorButtonsUI() {
        const btn1 = document.getElementById('btnToggleMirror');
        const lbl1 = document.getElementById('lblMirrorStatus');
        if (btn1) {
            btn1.classList.toggle('active', this._isDiapasonMirrored);
            if (lbl1) lbl1.textContent = this._isDiapasonMirrored ? 'Af->Ad' : 'Ad<-Af';
            btn1.title = this._isDiapasonMirrored
                ? 'Orientación de hileras: Afuera (1) a la izquierda, Adentro (3) a la derecha (Af->Ad). Clic para alternar a Ad<-Af.'
                : 'Orientación de hileras: Adentro (3) a la izquierda, Afuera (1) a la derecha (Ad<-Af). Clic para alternar a Af->Ad.';
        }

        const btn2 = document.getElementById('btnToggleMirrorSecondary');
        const lbl2 = document.getElementById('lblSecondaryMirrorStatus');
        if (btn2) {
            btn2.classList.toggle('active', this._isSecondaryDiapasonMirrored);
            if (lbl2) lbl2.textContent = this._isSecondaryDiapasonMirrored ? 'Af->Ad' : 'Ad<-Af';
            btn2.title = this._isSecondaryDiapasonMirrored
                ? 'Orientación de hileras (2do Acordeón): Afuera (1) a la izquierda, Adentro (3) a la derecha (Af->Ad). Clic para alternar a Ad<-Af.'
                : 'Orientación de hileras (2do Acordeón): Adentro (3) a la izquierda, Afuera (1) a la derecha (Ad<-Af). Clic para alternar a Af->Ad.';
        }
    }

    /**
     * Alterna el modo espejo del diapasón principal.
     */
    togglePrimaryMirror() {
        this._isDiapasonMirrored = !this._isDiapasonMirrored;
        try {
            localStorage.setItem('acordeon_is_mirrored', this._isDiapasonMirrored.toString());
        } catch (e) {
            console.warn('[DiapasonStageController] No se pudo persistir modo espejo:', e);
        }
        if (this._diapasonView) {
            this._diapasonView.setMirrored(this._isDiapasonMirrored);
        }
        this.updateMirrorButtonsUI();
        this._onStageChanged({ type: 'primary_mirror', isMirrored: this._isDiapasonMirrored });
    }

    /**
     * Alterna el modo espejo del diapasón secundario.
     */
    toggleSecondaryMirror() {
        this._isSecondaryDiapasonMirrored = !this._isSecondaryDiapasonMirrored;
        try {
            localStorage.setItem('acordeon_secondary_is_mirrored', this._isSecondaryDiapasonMirrored.toString());
        } catch (e) {
            console.warn('[DiapasonStageController] No se pudo persistir modo espejo secundario:', e);
        }
        if (this._secondaryDiapasonView) {
            this._secondaryDiapasonView.setMirrored(this._isSecondaryDiapasonMirrored);
        }
        this.updateMirrorButtonsUI();
        this._onStageChanged({ type: 'secondary_mirror', isMirrored: this._isSecondaryDiapasonMirrored });
    }

    /**
     * Vincula los controles de volumen (sliders, mutes, sync).
     * @private
     */
    _bindVolumeUIEvents() {
        const slider1 = document.getElementById('diapasonVolumeSlider');
        if (slider1) {
            slider1.addEventListener('input', (e) => {
                const vol = parseInt(e.target.value);
                this.applyPrimaryVolume(vol, vol === 0, true);
            });
        }

        const slider2 = document.getElementById('secondaryDiapasonVolumeSlider');
        if (slider2) {
            slider2.addEventListener('input', (e) => {
                const vol = parseInt(e.target.value);
                this.applySecondaryVolume(vol, vol === 0, true);
            });
        }

        const btnMute1 = document.getElementById('btnDiapasonVolumeMute');
        if (btnMute1) {
            btnMute1.addEventListener('click', () => {
                const willMute = !this._isDiapasonMuted;
                if (willMute) {
                    this._lastDiapasonVolume = this._diapasonVolume > 0 ? this._diapasonVolume : 80;
                    this.applyPrimaryVolume(0, true, true);
                } else {
                    const restored = this._lastDiapasonVolume > 0 ? this._lastDiapasonVolume : 80;
                    this.applyPrimaryVolume(restored, false, true);
                }
            });
        }

        const btnMute2 = document.getElementById('btnSecondaryDiapasonVolumeMute');
        if (btnMute2) {
            btnMute2.addEventListener('click', () => {
                const willMute = !this._isSecondaryDiapasonMuted;
                if (willMute) {
                    this._lastSecondaryDiapasonVolume = this._secondaryDiapasonVolume > 0 ? this._secondaryDiapasonVolume : 80;
                    this.applySecondaryVolume(0, true, true);
                } else {
                    const restored = this._lastSecondaryDiapasonVolume > 0 ? this._lastSecondaryDiapasonVolume : 80;
                    this.applySecondaryVolume(restored, false, true);
                }
            });
        }

        const chk1 = document.getElementById('chkDiapasonMute');
        if (chk1) {
            chk1.addEventListener('change', (e) => {
                const willMute = e.target.checked;
                if (willMute) {
                    this._lastDiapasonVolume = this._diapasonVolume > 0 ? this._diapasonVolume : 80;
                    this.applyPrimaryVolume(0, true, true);
                } else {
                    const restored = this._lastDiapasonVolume > 0 ? this._lastDiapasonVolume : 80;
                    this.applyPrimaryVolume(restored, false, true);
                }
            });
        }

        const chk2 = document.getElementById('chkSecondaryDiapasonMute');
        if (chk2) {
            chk2.addEventListener('change', (e) => {
                const willMute = e.target.checked;
                if (willMute) {
                    this._lastSecondaryDiapasonVolume = this._secondaryDiapasonVolume > 0 ? this._secondaryDiapasonVolume : 80;
                    this.applySecondaryVolume(0, true, true);
                } else {
                    const restored = this._lastSecondaryDiapasonVolume > 0 ? this._lastSecondaryDiapasonVolume : 80;
                    this.applySecondaryVolume(restored, false, true);
                }
            });
        }

        const toggleVolumeSync = () => {
            this._isVolumeSynced = !this._isVolumeSynced;
            try {
                localStorage.setItem('acordeon_volume_synced', this._isVolumeSynced.toString());
            } catch (e) {
                console.warn('[DiapasonStageController] No se pudo guardar sync de volumen:', e);
            }
            this.updateVolumeSyncUI();
            if (this._isVolumeSynced) {
                this.applySecondaryVolume(this._diapasonVolume, this._isDiapasonMuted, false);
            }
        };

        const btnSync1 = document.getElementById('btnSyncVolumePrimary');
        if (btnSync1) btnSync1.addEventListener('click', toggleVolumeSync);
        const btnSync2 = document.getElementById('btnSyncVolumeSecondary');
        if (btnSync2) btnSync2.addEventListener('click', toggleVolumeSync);
    }

    /**
     * Vincula los botones de alternancia de modo espejo.
     * @private
     */
    _bindMirrorEvents() {
        const btn1 = document.getElementById('btnToggleMirror');
        if (btn1) {
            btn1.addEventListener('click', () => this.togglePrimaryMirror());
        }

        const btn2 = document.getElementById('btnToggleMirrorSecondary');
        if (btn2) {
            btn2.addEventListener('click', () => this.toggleSecondaryMirror());
        }
    }

    /**
     * Vincula los botones de alternancia de visibilidad de diapasones.
     * @private
     */
    _bindVisibilityEvents() {
        const btnTogglePrimary = document.getElementById('btnTogglePrimaryDiapason');
        const primaryCol = document.getElementById('primaryDiapasonCol');

        const updatePrimaryToggleBtnState = () => {
            if (!btnTogglePrimary || !primaryCol) return;
            if (this._isPrimaryDiapasonVisible) {
                btnTogglePrimary.classList.add('active');
                primaryCol.classList.remove('hidden');
                primaryCol.style.display = '';
            } else {
                btnTogglePrimary.classList.remove('active');
                primaryCol.classList.add('hidden');
                primaryCol.style.display = 'none';
            }
        };

        if (btnTogglePrimary && primaryCol) {
            updatePrimaryToggleBtnState();
            btnTogglePrimary.addEventListener('click', () => {
                this._isPrimaryDiapasonVisible = !this._isPrimaryDiapasonVisible;
                try {
                    localStorage.setItem('acordeon_primary_visible', this._isPrimaryDiapasonVisible.toString());
                } catch (e) {
                    console.warn('[DiapasonStageController] No se pudo persistir visibilidad 1er diapasón:', e);
                }
                updatePrimaryToggleBtnState();
                this._onStageChanged({ type: 'primary_visibility', visible: this._isPrimaryDiapasonVisible });
            });
        }

        const btnToggle = document.getElementById('btnToggleSecondaryDiapason');
        const secondaryCol = document.getElementById('secondaryDiapasonCol');

        const updateToggleBtnState = () => {
            if (!btnToggle || !secondaryCol) return;
            if (this._isSecondaryDiapasonVisible) {
                btnToggle.classList.add('active');
                secondaryCol.classList.remove('hidden');
                secondaryCol.style.display = '';
            } else {
                btnToggle.classList.remove('active');
                secondaryCol.classList.add('hidden');
                secondaryCol.style.display = 'none';
            }
        };

        if (btnToggle && secondaryCol) {
            updateToggleBtnState();
            btnToggle.addEventListener('click', () => {
                this._isSecondaryDiapasonVisible = !this._isSecondaryDiapasonVisible;
                try {
                    localStorage.setItem('acordeon_secondary_visible', this._isSecondaryDiapasonVisible.toString());
                } catch (e) {
                    console.warn('[DiapasonStageController] No se pudo persistir visibilidad 2do diapasón:', e);
                }
                updateToggleBtnState();
                this._onStageChanged({ type: 'secondary_visibility', visible: this._isSecondaryDiapasonVisible });
            });
        }
    }
}
