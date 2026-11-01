import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/audio_file_loader.dart';
import 'package:acordeon_flutter/core/audio/audio_file_player.dart';
import 'package:acordeon_flutter/core/audio/audio_file_loader_interface.dart';
import 'package:acordeon_flutter/core/audio/audio_file_player_interface.dart';
import 'package:acordeon_flutter/core/audio/web_audio_decoder.dart';
import 'package:acordeon_flutter/core/audio/web_audio_decoder_interface.dart';
import 'package:acordeon_flutter/core/audio/web_audio_synth.dart';
import 'package:acordeon_flutter/core/audio/web_audio_synth_interface.dart';

/// Garantiza que las tríadas interfaz/_web/_stub resueltas por
/// importaciones condicionales (`if (dart.library.js_interop)`) mantienen
/// la misma firma: cualquier deriva de firma entre la interfaz y sus
/// implementaciones hace fallar la instanciación aquí.
void main() {
  group('Compatibilidad de firmas interfaz ↔ implementaciones', () {
    test('AudioFileLoader: la fábrica devuelve algo que implementa la interfaz',
        () {
      final loader = createAudioFileLoader();
      expect(loader, isA<AudioFileLoader>());
    });

    test('AudioFilePlayer: la fábrica devuelve algo que implementa la interfaz',
        () {
      final player = createAudioFilePlayer();
      expect(player, isA<AudioFilePlayer>());
      // Verifica todos los miembros de la interfaz son accesibles con las
      // firmas actuales (cualquier cambio de firma rompe esta prueba).
      player.setVolume(0.5);
      expect(player.isLoaded, isA<bool>());
      expect(player.positionSeconds, isA<double>());
      expect(player.durationSeconds, isA<double>());
      player.stop();
      player.pause();
      player.seek(0.0);
    });

    test('AudioDecoder: la fábrica devuelve algo que implementa la interfaz',
        () async {
      final decoder = createAudioDecoder();
      expect(decoder, isA<AudioDecoder>());
      // decode() con bytes vacíos: en la web puede devolver datos o null,
      // en el stub devuelve null. Solo verificamos la firma y el resultado.
      final result = await decoder.decode(Uint8List.fromList(const []));
      expect(result, anyOf(isNull, isA<DecodedAudioData>()));
    });

    test('WebAudioSynth: la fábrica devuelve algo que implementa la interfaz',
        () {
      final synth = createWebAudioSynth();
      expect(synth, isA<WebAudioSynth>());
      // Verifica las firmas de todos los métodos de la interfaz.
      synth.init();
      synth.noteOn(60, 261.63, velocity: 0.8);
      synth.noteOn(60, 261.63); // velocity opcional
      synth.noteOff(60);
      synth.setVolume(0.5);
      synth.playPercussiveClick();
      synth.playPercussiveClick(isDownbeat: false, volume: 0.3);
      synth.allNotesOff();
    });
  });
}
