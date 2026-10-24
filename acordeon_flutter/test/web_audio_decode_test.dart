@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:acordeon_flutter/core/audio/audio_file_player.dart';
import 'package:acordeon_flutter/core/audio/web_audio_decoder.dart';

/// Genera un WAV PCM 16-bit mono muy corto para decodificarlo en el navegador.
Uint8List _wavBytes({int sampleRate = 8000, double seconds = 0.25}) {
  final numSamples = (sampleRate * seconds).round();
  final dataSize = numSamples * 2;
  final data = ByteData(44 + dataSize);

  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < numSamples; i++) {
    final sample = (0.3 * 32767 * (i % 40 < 20 ? 1 : -1)).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }

  return data.buffer.asUint8List();
}

void main() {
  test('decodeAudioData no invalida los bytes originales', () async {
    final wav = _wavBytes();

    final decoded = await createAudioDecoder().decode(wav);

    expect(decoded, isNotNull, reason: 'El navegador debería decodificar el WAV');
    expect(decoded!.samples, isNotEmpty);
    expect(decoded.sampleRate, greaterThan(0));

    // Regresión: `decodeAudioData` desacopla el ArrayBuffer que recibe. Si el
    // decodificador usara el buffer original, estas lecturas lanzarían un
    // TypeError y la pista ya no podría reproducirse.
    expect(wav[0], 0x52); // 'R'
    expect(wav[8], 0x57); // 'W'
    expect(Uint8List.fromList(wav).length, wav.length);
  });

  test('el reproductor carga los bytes originales tras el análisis', () async {
    final wav = _wavBytes();

    await createAudioDecoder().decode(wav);

    final player = createAudioFilePlayer();
    player.load(wav, 'audio/wav');
    expect(player.isLoaded, isTrue);
  });
}
