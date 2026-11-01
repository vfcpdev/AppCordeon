import '../../core/audio/audio_engine_bridge.dart';
import '../../core/constants/enums.dart';
import '../../domain/services/grid_metrics_service.dart' as grid_metrics;
import '../../domain/services/hoare_contract.dart';
import '../../domain/theory/chord_catalog.dart';
import '../../domain/theory/music_theory.dart';
import 'accordion_controller.dart';

/// Extracción SRP del bloque "Sección 5: Acorde Libre" de
/// [AccordionSimulatorNotifier].
///
/// Coordina la reproducción (armónica/arpegiada) del acorde libre sobre el
/// motor de audio y el resaltado de botones del diapasón. No duplica el
/// estado: el Notifier inyecta los accesores de lectura/escritura, de modo
/// que widgets y pruebas no cambian y no hay dependencia circular Riverpod.
class FreeChordPlaybackCoordinator with HoareContract {
  /// Fuente de estado y mutador, inyectados por el Notifier propietario para
  /// evitar dependencia circular del provider (Riverpod no permite que un
  /// Ref lea su propio provider).
  final AccordionSimulatorState Function() _readState;
  final void Function(AccordionSimulatorState) _writeState;
  final AudioEngine Function() _readAudio;

  FreeChordPlaybackCoordinator(
    this._readState,
    this._writeState,
    this._readAudio,
  );

  AccordionSimulatorState get _state => _readState();
  set _state(AccordionSimulatorState s) => _writeState(s);

  AudioEngine get _audioBridge => _readAudio();

  /// Delegación: los setters de configuración siguen viviendo en el notifier
  /// principal (mutan estado), pero la reproducción y el resaltado se extraen.
  void playFreeChord({required bool arpeggio, Duration highlight = Duration.zero}) {
    final notes = calculateNotes(_state.freeChord);
    // {P}: el acorde debe tener al menos una nota para producir audio.
    require(
      'playFreeChord',
      'el acorde libre debe tener notas',
      notes.isNotEmpty,
    );
    if (arpeggio) {
      _arpeggio(notes);
    } else {
      _block(notes);
    }
    if (highlight > Duration.zero) {
      highlightDiapasonButtons(notes, highlight);
    }
  }

  /// Notas MIDI del acorde libre según la octava seleccionada.
  List<int> calculateNotes(FreeChordState freeChord) {
    final baseMidi = switch (freeChord.octave) {
      '3' => 48,
      '4' => 60,
      '5' => 72,
      _ => 60,
    };
    return ChordCatalog.notesFor(
      root: freeChord.root,
      type: freeChord.type,
      extension: freeChord.fourth,
      baseMidi: baseMidi,
    );
  }

  /// Reproducción armónica (bloque) con apagado diferido.
  void _block(List<int> notes) {
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      for (final midi in notes) {
        _audioBridge.noteOff(midi);
      }
    });
  }

  /// Reproducción melódica (arpegio) nota por nota.
  Future<void> _arpeggio(List<int> notes) async {
    for (final midi in notes) {
      _audioBridge.noteOn(midi);
      await Future.delayed(const Duration(milliseconds: 220));
      _audioBridge.noteOff(midi);
    }
  }

  /// Resalta los botones del diapasón y los bajos que corresponden al acorde.
  ///
  /// {P}: `notes` no vacío.
  /// {Q}: tras `duration` los botones resaltados vuelven a desmarcarse.
  void highlightDiapasonButtons(List<int> notes, Duration duration) {
    require('highlightDiapasonButtons', 'notes no vacío', notes.isNotEmpty);

    final matchingButtonIds = <String>{};
    final targetMidis = notes.toSet();
    final targetPitchClasses = notes.map((n) => n % 12).toSet();
    final octFilter = _state.freeChord.octave;

    final accordions = [
      (1, _state.trebleData1, _state.bellows1),
      (2, _state.trebleData2, _state.bellows2),
    ];

    for (final (accNum, trebleData, bellows) in accordions) {
      for (final row in trebleData.values) {
        for (final btn in row) {
          final matchesPull = octFilter == 'all'
              ? targetPitchClasses.contains(btn.pull % 12)
              : targetMidis.contains(btn.pull);
          final matchesPush = octFilter == 'all'
              ? targetPitchClasses.contains(btn.push % 12)
              : targetMidis.contains(btn.push);

          final bool isMatch;
          switch (bellows) {
            case BellowsMode.push:
              isMatch = matchesPush;
            case BellowsMode.pull:
              isMatch = matchesPull;
            case BellowsMode.both:
              isMatch = matchesPull || matchesPush;
          }
          if (isMatch) matchingButtonIds.add('a${accNum}_${btn.id}');
        }
      }
    }

    // Bajos de acompañamiento según el fuelle, priorizando coincidencias exactas.
    final chordRoot =
        _state.detectedChord?.rootPitchClass ??
        (notes.isNotEmpty ? notes.first % 12 : _state.freeChord.root);
    final bellows1 = _state.bellows1;
    final exactBassIds = <String>[];
    final closeBassIds = <String>[];

    for (final btn in _state.bassData1) {
      final pushMatch = ChordCatalog.evaluateBassMatch(
        notes: btn.pushNotes,
        type: btn.type,
        chordRoot: chordRoot,
        chordPitchClasses: targetPitchClasses,
        btnIndex: btn.btnIndex,
      );
      final pullMatch = ChordCatalog.evaluateBassMatch(
        notes: btn.pullNotes,
        type: btn.type,
        chordRoot: chordRoot,
        chordPitchClasses: targetPitchClasses,
        btnIndex: btn.btnIndex,
      );

      final BassMatchType match;
      switch (bellows1) {
        case BellowsMode.push:
          match = pushMatch;
        case BellowsMode.pull:
          match = pullMatch;
        case BellowsMode.both:
          if (pushMatch == BassMatchType.exact ||
              pullMatch == BassMatchType.exact) {
            match = BassMatchType.exact;
          } else if (pushMatch == BassMatchType.close ||
              pullMatch == BassMatchType.close) {
            match = BassMatchType.close;
          } else {
            match = BassMatchType.none;
          }
      }

      if (match == BassMatchType.exact) {
        exactBassIds.add(btn.id);
      } else if (match == BassMatchType.close) {
        closeBassIds.add(btn.id);
      }
    }

    if (exactBassIds.isNotEmpty) {
      matchingButtonIds.addAll(exactBassIds);
    } else {
      matchingButtonIds.addAll(closeBassIds);
    }

    if (matchingButtonIds.isEmpty) return;
    final next = Set<String>.from(_state.activeButtons)
      ..addAll(matchingButtonIds);
    _state = _state.copyWith(activeButtons: next);

    Future.delayed(duration, () {
      final remaining = Set<String>.from(_state.activeButtons)
        ..removeAll(matchingButtonIds);
      _state = _state.copyWith(activeButtons: remaining);
    });
  }

  /// Conversión pública reutilizable MIDI → frecuencia (delegación teórica).
  double midiToFrequency(int midi) => MusicTheory.midiToFrequency(midi);

  /// Formateo de tiempo delegado al servicio de dominio (consistencia).
  String formatTime(double seconds) => grid_metrics.formatBeatTime(seconds);
}
