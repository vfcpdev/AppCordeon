import 'dart:math' as math;
import 'dart:typed_data';

/// Genera la pista demo (WAV PCM 16-bit mono) con progresión Paseo Vallenato
/// (C - F - G - C a 128 BPM). Separado del controlador por SRP.
class DemoTrackGenerator {
  static const String demoFileName = 'La Gota Fría - Demo Vallenato.wav';

  const DemoTrackGenerator();

  Uint8List generate() {
    const sampleRate = 44100;
    const durationSeconds = 4.0;
    const numSamples = (sampleRate * durationSeconds);
    final int byteLength = (numSamples * 2).toInt();

    final buffer = ByteData(44 + byteLength);

    void writeTag(int offset, String tag) {
      for (int i = 0; i < 4; i++) {
        buffer.setUint8(offset + i, tag.codeUnitAt(i));
      }
    }

    // RIFF Header
    writeTag(0, 'RIFF');
    buffer.setUint32(4, 36 + byteLength, Endian.little);
    writeTag(8, 'WAVE');

    // 'fmt ' Subchunk
    writeTag(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little); // 16 bits

    // 'data' Subchunk
    writeTag(36, 'data');
    buffer.setUint32(40, byteLength, Endian.little);

    // Sintetizar muestras armónicas Vallenato (C, F, G, C) con pulso a 128 BPM
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final chordPhase = (t % 4.0);

      // Frecuencias fundamentales de cada acorde
      double f1, f2, f3;
      if (chordPhase < 1.0) {
        // Do Mayor: C4, E4, G4
        f1 = 261.63; f2 = 329.63; f3 = 392.00;
      } else if (chordPhase < 2.0) {
        // Fa Mayor: F4, A4, C5
        f1 = 349.23; f2 = 440.00; f3 = 523.25;
      } else if (chordPhase < 3.0) {
        // Sol Mayor: G4, B4, D5
        f1 = 392.00; f2 = 493.88; f3 = 587.33;
      } else {
        // Do Mayor resolutivo
        f1 = 261.63; f2 = 329.63; f3 = 392.00;
      }

      // Envolvente de pulso rítmico a 128 BPM (período ~0.46875s)
      final beatPhase = (t * (128.0 / 60.0)) % 1.0;
      final beatEnv = math.exp(-beatPhase * 4.0);

      // Onda acústica combinada
      final s = (math.sin(2 * math.pi * f1 * t) * 0.4 +
                 math.sin(2 * math.pi * f2 * t) * 0.3 +
                 math.sin(2 * math.pi * f3 * t) * 0.3) * (0.6 + 0.4 * beatEnv);

      final sampleInt16 = (s * 24000).clamp(-32767, 32767).toInt();
      buffer.setInt16(44 + (i * 2), sampleInt16, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
