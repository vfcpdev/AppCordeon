import { parseChordNotation } from '../theory/MusicTheory.js';

/**
 * Compases, acordes y letra analizados de la partitura:
 * "COMO ZAQUEO - HAZ UN MILAGRO EN MI" (Regis Danese)
 * Tonalidad: Sol Mayor (G) - 1 sostenido (Fa#)
 * Métrica: 4/4 - Tempo sugerido: 70 BPM
 */
export const COMO_ZAQUEO_SCORE_INFO = {
    title: 'Como Zaqueo - Haz un milagro en mí',
    artist: 'Regis Danese',
    sourceFile: 'COMO ZAQUEO - HAZ UN MILAGRO EN MI.musicxml',
    key: 'G',
    keyName: 'Sol Mayor',
    bpm: 70,
    meter: '4/4',
    totalBars: 74
};

export const COMO_ZAQUEO_BARS = [
    // INTRO (c. 1 - 7)
    { bar: 1, chord: 'G', section: 'Intro', lyrics: '' },
    { bar: 2, chord: 'D/F#', section: 'Intro', lyrics: '' },
    { bar: 3, chord: 'Em7', section: 'Intro', lyrics: '' },
    { bar: 4, chord: 'C', section: 'Intro', lyrics: '' },
    { bar: 5, chord: 'G/B', section: 'Intro', lyrics: '' },
    { bar: 6, chord: 'Am7', section: 'Intro', lyrics: '' },
    { bar: 7, chord: 'D', section: 'Intro', lyrics: '' },

    // ESTROFA 1 (c. 8 - 15)
    { bar: 8, chord: 'G', section: 'Estrofa 1', lyrics: 'Como Zaqueo yo quiero subir' },
    { bar: 9, chord: 'D/F#', section: 'Estrofa 1', lyrics: 'A lo más alto que yo pueda' },
    { bar: 10, chord: 'Em7', section: 'Estrofa 1', lyrics: 'Solo para verte mirar hacia ti' },
    { bar: 11, chord: 'C', section: 'Estrofa 1', lyrics: 'Y llamar tu atención hacia mí' },
    { bar: 12, chord: 'G/B', section: 'Estrofa 1', lyrics: 'Necesito de ti Señor' },
    { bar: 13, chord: 'Am7', section: 'Estrofa 1', lyrics: 'Necesito de ti oh Padre' },
    { bar: 14, chord: 'D', section: 'Estrofa 1', lyrics: 'Soy tan pequeño y nada más' },
    { bar: 15, chord: 'D', section: 'Estrofa 1', lyrics: 'Dame tu paz' },

    // PRE-CORO (c. 16 - 24)
    { bar: 16, chord: 'G', section: 'Pre-coro', lyrics: 'Dejo todo para seguirte' },
    { bar: 17, chord: 'D/F#', section: 'Pre-coro', lyrics: 'Entra en mi casa' },
    { bar: 18, chord: 'Em7', section: 'Pre-coro', lyrics: 'Entra en mi vida' },
    { bar: 19, chord: 'C', section: 'Pre-coro', lyrics: 'Toca mi estructura' },
    { bar: 20, chord: 'Bm7', section: 'Pre-coro', lyrics: 'Sana todas las heridas' },
    { bar: 21, chord: 'Em7', section: 'Pre-coro', lyrics: 'Dame de tu amor' },
    { bar: 22, chord: 'C', section: 'Pre-coro', lyrics: 'Que me santifica' },
    { bar: 23, chord: 'Am7', section: 'Pre-coro', lyrics: 'Quiero estar a tus pies' },
    { bar: 24, chord: 'D', section: 'Pre-coro', lyrics: 'Día y noche' },

    // CORO 1 (c. 25 - 33)
    { bar: 25, chord: 'G', section: 'Coro', lyrics: 'Haz un milagro en mí' },
    { bar: 26, chord: 'G', section: 'Coro', lyrics: 'Haz un milagro en mí' },
    { bar: 27, chord: 'D/F#', section: 'Coro', lyrics: 'Entra en mi casa Señor' },
    { bar: 28, chord: 'Em7', section: 'Coro', lyrics: 'Entra en mi vida' },
    { bar: 29, chord: 'Em7', section: 'Coro', lyrics: 'Muda mi historia' },
    { bar: 30, chord: 'C', section: 'Coro', lyrics: 'Sana todas las heridas' },
    { bar: 31, chord: 'G/B', section: 'Coro', lyrics: 'Enséñame a tener santidad' },
    { bar: 32, chord: 'Am7', section: 'Coro', lyrics: 'Quiero amarte más' },
    { bar: 33, chord: 'D', section: 'Coro', lyrics: 'Haz un milagro en mí' },

    // INTERLUDIO / RE-INTRO (c. 34 - 40)
    { bar: 34, chord: 'G', section: 'Interludio', lyrics: '' },
    { bar: 35, chord: 'D/F#', section: 'Interludio', lyrics: '' },
    { bar: 36, chord: 'Em7', section: 'Interludio', lyrics: '' },
    { bar: 37, chord: 'C', section: 'Interludio', lyrics: '' },
    { bar: 38, chord: 'G/B', section: 'Interludio', lyrics: '' },
    { bar: 39, chord: 'Am7', section: 'Interludio', lyrics: '' },
    { bar: 40, chord: 'D', section: 'Interludio', lyrics: '' },

    // ESTROFA 2 (c. 41 - 48)
    { bar: 41, chord: 'G', section: 'Estrofa 2', lyrics: 'Como Zaqueo yo quiero subir' },
    { bar: 42, chord: 'D/F#', section: 'Estrofa 2', lyrics: 'A lo más alto que yo pueda' },
    { bar: 43, chord: 'Em7', section: 'Estrofa 2', lyrics: 'Solo para verte mirar hacia ti' },
    { bar: 44, chord: 'C', section: 'Estrofa 2', lyrics: 'Y llamar tu atención hacia mí' },
    { bar: 45, chord: 'G/B', section: 'Estrofa 2', lyrics: 'Necesito de ti Señor' },
    { bar: 46, chord: 'Am7', section: 'Estrofa 2', lyrics: 'Necesito de ti oh Padre' },
    { bar: 47, chord: 'D', section: 'Estrofa 2', lyrics: 'Soy tan pequeño y nada más' },
    { bar: 48, chord: 'D', section: 'Estrofa 2', lyrics: 'Dame tu paz' },

    // PRE-CORO 2 (c. 49 - 56)
    { bar: 49, chord: 'G', section: 'Pre-coro', lyrics: 'Dejo todo para seguirte' },
    { bar: 50, chord: 'D/F#', section: 'Pre-coro', lyrics: 'Entra en mi casa' },
    { bar: 51, chord: 'Em7', section: 'Pre-coro', lyrics: 'Entra en mi vida' },
    { bar: 52, chord: 'C', section: 'Pre-coro', lyrics: 'Toca mi estructura' },
    { bar: 53, chord: 'Bm7', section: 'Pre-coro', lyrics: 'Sana todas las heridas' },
    { bar: 54, chord: 'Em7', section: 'Pre-coro', lyrics: 'Dame de tu amor' },
    { bar: 55, chord: 'C', section: 'Pre-coro', lyrics: 'Que me santifica' },
    { bar: 56, chord: 'D', section: 'Pre-coro', lyrics: 'Día y noche' },

    // CORO 2 (c. 57 - 65)
    { bar: 57, chord: 'G', section: 'Coro', lyrics: 'Haz un milagro en mí' },
    { bar: 58, chord: 'G', section: 'Coro', lyrics: 'Haz un milagro en mí' },
    { bar: 59, chord: 'D/F#', section: 'Coro', lyrics: 'Entra en mi casa Señor' },
    { bar: 60, chord: 'Em7', section: 'Coro', lyrics: 'Entra en mi vida' },
    { bar: 61, chord: 'Em7', section: 'Coro', lyrics: 'Muda mi historia' },
    { bar: 62, chord: 'C', section: 'Coro', lyrics: 'Sana todas las heridas' },
    { bar: 63, chord: 'G/B', section: 'Coro', lyrics: 'Enséñame a tener santidad' },
    { bar: 64, chord: 'Am7', section: 'Coro', lyrics: 'Quiero amarte más' },
    { bar: 65, chord: 'D', section: 'Coro', lyrics: 'Haz un milagro en mí' },

    // CORO CLÍMAX / FINAL (c. 66 - 74)
    { bar: 66, chord: 'G', section: 'Coro', lyrics: 'Haz un milagro en mí' },
    { bar: 67, chord: 'D/F#', section: 'Coro', lyrics: 'Entra en mi casa' },
    { bar: 68, chord: 'Em7', section: 'Coro', lyrics: 'Entra en mi vida' },
    { bar: 69, chord: 'C', section: 'Coro', lyrics: 'Toca mi estructura' },
    { bar: 70, chord: 'G/B', section: 'Coro', lyrics: 'Sana todas las heridas' },
    { bar: 71, chord: 'Am7', section: 'Coro', lyrics: 'Quiero estar a tus pies' },
    { bar: 72, chord: 'D', section: 'Coro', lyrics: 'Haz un milagro en mí' },
    { bar: 73, chord: 'C', section: 'Outro', lyrics: 'Haz un milagro en mí' },
    { bar: 74, chord: 'G', section: 'Final', lyrics: 'Amén' }
];

/**
 * Convierte un símbolo de acorde en elementos MusicXML <harmony>.
 * @param {string} chordSymbol
 * @returns {string} XML string para <harmony>
 */
export function chordSymbolToMusicXmlHarmony(chordSymbol) {
    if (!chordSymbol || chordSymbol === '-' || chordSymbol === 'NC') return '';
    const parsed = parseChordNotation(chordSymbol);
    if (!parsed) return '';

    let rootStep = 'C';
    let rootAlter = 0;
    const ROOT_NAMES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
    const ROOT_STEPS = ['C', 'C', 'D', 'E', 'E', 'F', 'F', 'G', 'A', 'A', 'B', 'B'];
    const ROOT_ALTERS = [0, 1, 0, -1, 0, 0, 1, 0, -1, 0, -1, 0];

    const pc = parsed.root;
    if (typeof pc === 'number') {
        rootStep = ROOT_STEPS[pc] || 'C';
        rootAlter = ROOT_ALTERS[pc] || 0;
    }

    let kind = 'major';
    let kindText = '';
    switch (parsed.chordType) {
        case 'minor':
        case 'm':
            kind = 'minor';
            kindText = 'm';
            break;
        case '7':
            kind = 'dominant';
            kindText = '7';
            break;
        case 'maj7':
            kind = 'major-seventh';
            kindText = 'Maj7';
            break;
        case 'm7':
            kind = 'minor-seventh';
            kindText = 'm7';
            break;
        case 'sus4':
            kind = 'suspended-fourth';
            kindText = 'sus4';
            break;
        case 'sus2':
            kind = 'suspended-second';
            kindText = 'sus2';
            break;
        case 'dim':
            kind = 'diminished';
            kindText = 'dim';
            break;
        case 'dim7':
            kind = 'diminished-seventh';
            kindText = 'dim7';
            break;
        case 'aug':
            kind = 'augmented';
            kindText = 'aug';
            break;
        default:
            kind = 'major';
            kindText = '';
            break;
    }

    let bassXml = '';
    if (chordSymbol.includes('/')) {
        const parts = chordSymbol.split('/');
        const bassStr = parts[1].trim().toUpperCase();
        if (bassStr) {
            let bStep = bassStr[0];
            let bAlter = 0;
            if (bassStr.includes('#') || bassStr.includes('♯')) bAlter = 1;
            else if (bassStr.includes('B') && bassStr.length > 1) bAlter = -1;
            bassXml = `
      <bass>
        <bass-step>${bStep}</bass-step>
        ${bAlter !== 0 ? `<bass-alter>${bAlter}</bass-alter>` : ''}
      </bass>`;
        }
    }

    return `
    <harmony print-frame="no">
      <root>
        <root-step>${rootStep}</root-step>
        ${rootAlter !== 0 ? `<root-alter>${rootAlter}</root-alter>` : ''}
      </root>
      <kind text="${kindText}">${kind}</kind>${bassXml}
    </harmony>`;
}

/**
 * Genera el documento MusicXML 3.1 completo para "Como Zaqueo" o cualquier lista de compases.
 * @param {Object} [scoreInfo=COMO_ZAQUEO_SCORE_INFO]
 * @param {Array<Object>} [bars=COMO_ZAQUEO_BARS]
 * @returns {string} XML string válido para OpenSheetMusicDisplay
 */
export function generateComoZaqueoMusicXml(scoreInfo = COMO_ZAQUEO_SCORE_INFO, bars = COMO_ZAQUEO_BARS) {
    const title = scoreInfo.title || 'Como Zaqueo - Haz un milagro en mí';
    const artist = scoreInfo.artist || 'Regis Danese';
    const bpm = scoreInfo.bpm || 70;

    let measuresXml = '';
    const totalBars = bars.length;

    bars.forEach((item, index) => {
        const barNum = item.bar || (index + 1);
        const isFirst = index === 0;
        const harmonyXml = chordSymbolToMusicXmlHarmony(item.chord);
        const section = item.section ? `<direction placement="above"><direction-type><words font-weight="bold" font-size="10">${item.section}</words></direction-type></direction>` : '';

        // Tonalidad diatónica y notas sugeridas por compás
        const parsed = parseChordNotation(item.chord);
        const rootMidi = parsed && typeof parsed.root === 'number' ? 60 + parsed.root : 67; // default G4
        const noteMidis = parsed && parsed.playbackMidis && parsed.playbackMidis.length >= 3 
            ? parsed.playbackMidis.slice(0, 4) 
            : [rootMidi, rootMidi + 4, rootMidi + 7, rootMidi + 12];

        // Mapear cada midi a pitch XML
        const PITCH_NAMES = ['C', 'C', 'D', 'E', 'E', 'F', 'F', 'G', 'A', 'A', 'B', 'B'];
        const PITCH_ALTERS = [0, 1, 0, -1, 0, 0, 1, 0, -1, 0, -1, 0];

        // Letra dividida en palabras si existe
        const lyricsWords = item.lyrics ? item.lyrics.trim().split(/\s+/) : [];

        let notesXml = '';
        for (let beat = 0; beat < 4; beat++) {
            const m = noteMidis[beat % noteMidis.length];
            const pc = ((m % 12) + 12) % 12;
            const oct = Math.floor(m / 12) - 1;
            const step = PITCH_NAMES[pc] || 'G';
            const alter = PITCH_ALTERS[pc] || 0;

            let lyricXml = '';
            if (lyricsWords.length > 0 && beat < lyricsWords.length) {
                lyricXml = `
        <lyric number="1">
          <syllabic>single</syllabic>
          <text>${lyricsWords[beat]}</text>
        </lyric>`;
            } else if (lyricsWords.length > 0 && beat === 0) {
                lyricXml = `
        <lyric number="1">
          <syllabic>single</syllabic>
          <text>${item.lyrics}</text>
        </lyric>`;
            }

            notesXml += `
      <note>
        <pitch>
          <step>${step}</step>
          ${alter !== 0 ? `<alter>${alter}</alter>` : ''}
          <octave>${Math.min(5, Math.max(4, oct))}</octave>
        </pitch>
        <duration>4</duration>
        <voice>1</voice>
        <type>quarter</type>${lyricXml}
      </note>`;
        }

        measuresXml += `
    <measure number="${barNum}">
      ${isFirst ? `
      <attributes>
        <divisions>4</divisions>
        <key>
          <fifths>1</fifths>
          <mode>major</mode>
        </key>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef>
          <sign>G</sign>
          <line>2</line>
        </clef>
      </attributes>
      <direction placement="above">
        <direction-type>
          <metronome parentheses="no">
            <beat-unit>quarter</beat-unit>
            <per-minute>${bpm}</per-minute>
          </metronome>
        </direction-type>
        <sound tempo="${bpm}"/>
      </direction>` : ''}
      ${section}
      ${harmonyXml}
      ${notesXml}
      ${barNum === totalBars ? `
      <barline location="right">
        <bar-style>light-heavy</bar-style>
      </barline>` : ''}
    </measure>`;
    });

    return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work>
    <work-title>${title}</work-title>
  </work>
  <identification>
    <creator type="composer">${artist}</creator>
    <creator type="arranger">Acordeón Diatónico Pro</creator>
    <encoding>
      <software>Acordeón Diatónico Pro - MusicXML Engine</software>
      <encoding-date>${new Date().toISOString().slice(0, 10)}</encoding-date>
    </encoding>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Acordeón</part-name>
      <score-instrument id="P1-I1">
        <instrument-name>Acordeón</instrument-name>
      </score-instrument>
      <midi-instrument id="P1-I1">
        <midi-program>22</midi-program>
      </midi-instrument>
    </score-part>
  </part-list>
  <part id="P1">
${measuresXml}
  </part>
</score-partwise>`;
}

/**
 * Parser de archivos MusicXML (.xml, .musicxml)
 * Extrae título, compases, armonía/acordes, tempo y métrica para sincronizar
 * con el diapasón y la cuadrícula de reproducción del acordeón.
 * @param {string} xmlText
 * @returns {Object} { title, bpm, key, meter, bars: Array<{ bar, chord, section, lyrics }> }
 */
export function parseMusicXml(xmlText) {
    if (!xmlText || typeof xmlText !== 'string') return null;
    const parser = new DOMParser();
    const doc = parser.parseFromString(xmlText, 'application/xml');

    const parserError = doc.querySelector('parsererror');
    if (parserError) {
        console.warn('[MusicXmlParser] Error parseando XML:', parserError.textContent);
        return null;
    }

    // Título
    const titleEl = doc.querySelector('work-title') || doc.querySelector('movement-title');
    const title = titleEl ? titleEl.textContent.trim() : 'Partitura MusicXML';

    // Tempo BPM
    let bpm = 70;
    const soundEl = doc.querySelector('sound[tempo]');
    if (soundEl && soundEl.getAttribute('tempo')) {
        bpm = Math.round(parseFloat(soundEl.getAttribute('tempo')));
    } else {
        const perMinEl = doc.querySelector('per-minute');
        if (perMinEl) bpm = Math.round(parseFloat(perMinEl.textContent.trim()));
    }

    // Métrica
    const beatsEl = doc.querySelector('beats');
    const beatTypeEl = doc.querySelector('beat-type');
    const meter = beatsEl && beatTypeEl ? `${beatsEl.textContent.trim()}/${beatTypeEl.textContent.trim()}` : '4/4';

    // Compases
    const measureEls = doc.querySelectorAll('measure');
    const bars = [];

    measureEls.forEach((mEl, idx) => {
        const numAttr = mEl.getAttribute('number');
        const barNum = numAttr ? parseInt(numAttr, 10) : (idx + 1);

        // Extraer acorde <harmony>
        let chordSymbol = '-';
        const harmonyEl = mEl.querySelector('harmony');
        if (harmonyEl) {
            const rootStepEl = harmonyEl.querySelector('root-step');
            const rootAlterEl = harmonyEl.querySelector('root-alter');
            const kindEl = harmonyEl.querySelector('kind');
            const bassStepEl = harmonyEl.querySelector('bass-step');
            const bassAlterEl = harmonyEl.querySelector('bass-alter');

            if (rootStepEl) {
                let r = rootStepEl.textContent.trim();
                if (rootAlterEl) {
                    const alt = parseInt(rootAlterEl.textContent.trim(), 10);
                    if (alt === 1) r += '#';
                    else if (alt === -1) r += 'b';
                }

                let k = '';
                if (kindEl) {
                    const kindText = kindEl.getAttribute('text');
                    const kindVal = kindEl.textContent.trim().toLowerCase();
                    if (kindText) {
                        k = kindText;
                    } else if (kindVal.includes('minor') && !kindVal.includes('seventh')) {
                        k = 'm';
                    } else if (kindVal.includes('minor-seventh')) {
                        k = 'm7';
                    } else if (kindVal.includes('major-seventh')) {
                        k = 'Maj7';
                    } else if (kindVal.includes('dominant')) {
                        k = '7';
                    } else if (kindVal.includes('suspended-fourth')) {
                        k = 'sus4';
                    } else if (kindVal.includes('suspended-second')) {
                        k = 'sus2';
                    } else if (kindVal.includes('diminished-seventh')) {
                        k = 'dim7';
                    } else if (kindVal.includes('diminished')) {
                        k = 'dim';
                    } else if (kindVal.includes('augmented')) {
                        k = 'aug';
                    }
                }

                let b = '';
                if (bassStepEl) {
                    let bs = bassStepEl.textContent.trim();
                    if (bassAlterEl) {
                        const ba = parseInt(bassAlterEl.textContent.trim(), 10);
                        if (ba === 1) bs += '#';
                        else if (ba === -1) bs += 'b';
                    }
                    b = '/' + bs;
                }

                chordSymbol = `${r}${k}${b}`.trim();
            }
        }

        // Extraer letra <lyric>
        const lyricEls = mEl.querySelectorAll('lyric text');
        let lyrics = '';
        if (lyricEls && lyricEls.length > 0) {
            const words = Array.from(lyricEls).map(el => el.textContent.trim()).filter(Boolean);
            lyrics = words.join(' ');
        }

        // Extraer sección / words
        const wordsEl = mEl.querySelector('direction-type words');
        const section = wordsEl ? wordsEl.textContent.trim() : `Compás ${barNum}`;

        bars.push({
            bar: barNum,
            chord: chordSymbol,
            section,
            lyrics
        });
    });

    return {
        title,
        bpm,
        meter,
        totalBars: bars.length,
        bars
    };
}

/**
 * Genera la lista de acordes temporizados para el reproductor y la cuadrícula 4/4
 * calculando los tiempos de inicio y fin a partir del BPM.
 * @param {number} [bpm=70]
 * @param {Array<Object>} [bars=COMO_ZAQUEO_BARS]
 * @returns {Array<Object>}
 */
export function buildComoZaqueoTimelineChords(bpm = 70, bars = COMO_ZAQUEO_BARS) {
    const beatSec = 60 / bpm;
    const barSec = 4 * beatSec;
    const timeline = [];

    bars.forEach((item, index) => {
        const barIndex = (item.bar ? item.bar : index + 1) - 1;
        const startTime = barIndex * barSec;
        const endTime = (barIndex + 1) * barSec;

        const parsed = parseChordNotation(item.chord);
        if (parsed) {
            timeline.push({
                startTime,
                endTime,
                chordSymbol: parsed.chordSymbol,
                chordName: parsed.chordName,
                root: parsed.root,
                chordType: parsed.chordType,
                intervals: parsed.intervals,
                noteMods: parsed.noteMods,
                playbackMidis: parsed.playbackMidis,
                bellowsAction: 'both',
                section: item.section || `Compás ${barIndex + 1}`,
                barNumber: item.bar || (barIndex + 1),
                lyrics: item.lyrics || ''
            });
        }
    });

    return timeline;
}
