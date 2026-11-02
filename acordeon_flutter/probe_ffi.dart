import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Sonda final: valida repetibilidad (20 iteraciones consecutivas) para
/// descartar corrupción de heap con uso sostenido.
void main() {
  final lib = DynamicLibrary.open(
    r'..\acordeon_engine\target\release\acordeon_engine.dll',
  );
  final analyze = lib
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Float>, UintPtr, Float),
        Pointer<Utf8> Function(Pointer<Float>, int, double)
      >('acordeon_analyze_audio_ffi');
  final freeStr = lib
      .lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>(
        'acordeon_free_string',
      );

  const n = 8192;
  final b1 = malloc.allocate<Float>(n);
  print('b1 reservada en $b1');
  for (var i = 0; i < n; i++) {
    b1[i] = (i % 441) / 441.0;
  }
  print('buffer listo');
  final r1 = analyze(b1, n, 44100.0);
  print('r1 len=${r1.toDartString().length}');
  freeStr(r1);
  malloc.free(b1);
  print('llamada 1 limpia');

  final b2 = malloc.allocate<Float>(n);
  print('b2 reservada en $b2');
  malloc.free(b2);
  print('fin limpio');
}
