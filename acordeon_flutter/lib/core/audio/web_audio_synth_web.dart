import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'web_audio_synth_stub.dart';

WebAudioSynth getWebAudioSynth() => WebAudioSynthImpl();

class _ActiveNote {
  final web.OscillatorNode osc1;
  final web.OscillatorNode osc2;
  final web.GainNode gainNode;

  _ActiveNote({
    required this.osc1,
    required this.osc2,
    required this.gainNode,
  });
}

class WebAudioSynthImpl implements WebAudioSynth {
  web.AudioContext? _ctx;
  web.GainNode? _masterGain;
  final Map<int, _ActiveNote> _activeNotes = {};
  double _volume = 0.8;

  @override
  void init() {
    _ensureContext();
  }

  void _ensureContext() {
    if (_ctx != null) return;
    try {
      final ctx = web.AudioContext();
      final master = ctx.createGain();
      master.gain.value = _volume.toJS;
      master.connect(ctx.destination);
      _ctx = ctx;
      _masterGain = master;
    } catch (_) {}
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    final master = _masterGain;
    final ctx = _ctx;
    if (master != null && ctx != null) {
      master.gain.setValueAtTime(_volume.toJS, ctx.currentTime);
    }
  }

  @override
  void noteOn(int midiNote, double frequency, {double velocity = 0.8}) {
    _ensureContext();
    final ctx = _ctx;
    final master = _masterGain;
    if (ctx == null || master == null) return;

    if (ctx.state == 'suspended') {
      ctx.resume();
    }

    // Si ya sonaba, silenciarlo primero
    if (_activeNotes.containsKey(midiNote)) {
      noteOff(midiNote);
    }

    try {
      final now = ctx.currentTime;

      // Ganancia individual con envolvente de acordeón (ataque rápido)
      final noteGain = ctx.createGain();
      noteGain.gain.setValueAtTime(0.0001.toJS, now);
      final targetGain = (velocity * 0.45).clamp(0.01, 0.7);
      noteGain.gain.linearRampToValueAtTime(targetGain.toJS, (now + 0.015).toJS);

      // Oscilador 1 (Lengüeta principal: diente de sierra suave)
      final osc1 = ctx.createOscillator();
      osc1.type = 'sawtooth';
      osc1.frequency.setValueAtTime(frequency.toJS, now);

      // Oscilador 2 (Lengüeta vibrato / musette: ligera desafinación típica vallenata +4 cents)
      final osc2 = ctx.createOscillator();
      osc2.type = 'triangle';
      final detunedFreq = frequency * 1.0025; // ~4.3 cents
      osc2.frequency.setValueAtTime(detunedFreq.toJS, now);

      // Filtro pasa-bajas para calidez de fuelle acústico
      final filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      final cutoff = (frequency * 4.5).clamp(800.0, 7500.0);
      filter.frequency.setValueAtTime(cutoff.toJS, now);

      // Conexiones de audio
      osc1.connect(noteGain);
      osc2.connect(noteGain);
      noteGain.connect(filter);
      filter.connect(master);

      osc1.start(now);
      osc2.start(now);

      _activeNotes[midiNote] = _ActiveNote(
        osc1: osc1,
        osc2: osc2,
        gainNode: noteGain,
      );
    } catch (_) {}
  }

  @override
  void noteOff(int midiNote) {
    final note = _activeNotes.remove(midiNote);
    final ctx = _ctx;
    if (note == null || ctx == null) return;

    try {
      final now = ctx.currentTime;
      final releaseTime = 0.06;
      note.gainNode.gain.cancelScheduledValues(now);
      note.gainNode.gain.setValueAtTime(note.gainNode.gain.value, now);
      note.gainNode.gain.linearRampToValueAtTime(0.0001.toJS, (now + releaseTime).toJS);

      note.osc1.stop((now + releaseTime + 0.02).toJS);
      note.osc2.stop((now + releaseTime + 0.02).toJS);
    } catch (_) {}
  }

  @override
  void allNotesOff() {
    final keys = _activeNotes.keys.toList();
    for (final k in keys) {
      noteOff(k);
    }
    _activeNotes.clear();
  }
}
