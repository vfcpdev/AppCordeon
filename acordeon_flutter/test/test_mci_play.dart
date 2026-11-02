import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef MciSendStringNative = Uint32 Function(
  Pointer<Utf16> lpstrCommand,
  Pointer<Utf16> lpstrReturnString,
  Uint32 uReturnLength,
  IntPtr hwndCallback,
);
typedef MciSendStringDart = int Function(
  Pointer<Utf16> lpstrCommand,
  Pointer<Utf16> lpstrReturnString,
  int uReturnLength,
  int hwndCallback,
);

Uint8List createTestWav(int durationSeconds) {
  const sampleRate = 44100;
  final numSamples = sampleRate * durationSeconds;
  final byteCount = numSamples * 2;
  final data = ByteData(44 + byteCount);

  // RIFF header
  data.setUint8(0, 0x52); // 'R'
  data.setUint8(1, 0x49); // 'I'
  data.setUint8(2, 0x46); // 'F'
  data.setUint8(3, 0x46); // 'F'
  data.setUint32(4, 36 + byteCount, Endian.little);
  data.setUint8(8, 0x57); // 'W'
  data.setUint8(9, 0x41); // 'A'
  data.setUint8(10, 0x56); // 'V'
  data.setUint8(11, 0x45); // 'E'

  // fmt chunk
  data.setUint8(12, 0x66); // 'f'
  data.setUint8(13, 0x6D); // 'm'
  data.setUint8(14, 0x74); // 't'
  data.setUint8(15, 0x20); // ' '
  data.setUint32(16, 16, Endian.little); // Chunk size
  data.setUint16(20, 1, Endian.little); // PCM format
  data.setUint16(22, 1, Endian.little); // 1 channel
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
  data.setUint16(32, 2, Endian.little); // Block align
  data.setUint16(34, 16, Endian.little); // Bits per sample

  // data chunk
  data.setUint8(36, 0x64); // 'd'
  data.setUint8(37, 0x61); // 'a'
  data.setUint8(38, 0x74); // 't'
  data.setUint8(39, 0x61); // 'a'
  data.setUint32(40, byteCount, Endian.little);

  return data.buffer.asUint8List();
}

void main() {
  if (!Platform.isWindows) {
    print('Not Windows');
    return;
  }
  final winmm = DynamicLibrary.open('winmm.dll');
  final mciSendString = winmm
      .lookup<NativeFunction<MciSendStringNative>>('mciSendStringW')
      .asFunction<MciSendStringDart>();

  String sendCmd(String cmd) {
    final cmdPtr = cmd.toNativeUtf16();
    final returnBuf = calloc<Uint16>(256).cast<Utf16>();
    try {
      final code = mciSendString(cmdPtr, returnBuf, 256, 0);
      final res = returnBuf.toDartString();
      print('CMD: "$cmd" -> code: $code, res: "$res"');
      return res;
    } finally {
      calloc.free(cmdPtr);
      calloc.free(returnBuf);
    }
  }

  // Create temporary WAV of 3 seconds
  final tempFile = File('${Directory.systemTemp.path}\\test_appcordeon.wav');
  tempFile.writeAsBytesSync(createTestWav(3));
  print('Wrote temp WAV: ${tempFile.path}');

  sendCmd('close appcordeon_track');
  sendCmd('open "${tempFile.path}" alias appcordeon_track');
  sendCmd('set appcordeon_track time format milliseconds');
  final lengthStr = sendCmd('status appcordeon_track length');
  final posStr = sendCmd('status appcordeon_track position');
  sendCmd('play appcordeon_track');
  sendCmd('stop appcordeon_track');
  sendCmd('close appcordeon_track');

  tempFile.deleteSync();
  print('Duration in ms: $lengthStr, initial pos: $posStr');
}

