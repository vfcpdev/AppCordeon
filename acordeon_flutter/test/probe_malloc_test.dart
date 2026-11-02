import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sonda del heap-allocator: el crash ocurre al escribir el elemento con []
/// desde el test runner, pero NO con dart CLI. Vamos a aislar.
void main() {
  test('malloc + escritura básica', () {
    final buf = malloc.allocate<Float>(100);
    buf[0] = 0.5;
    expect(buf[0], 0.5);
    malloc.free(buf);
  });

  test('malloc 8192 + escritura por índice', () {
    final buf = malloc.allocate<Float>(8192);
    for (var i = 0; i < 8192; i++) {
      buf[i] = 0.5;
    }
    expect(buf[8191], 0.5);
    malloc.free(buf);
  });

  test('malloc 8192 + asTypedList + setAll (recomendado)', () {
    final buf = malloc.allocate<Float>(8192);
    final view = buf.asTypedList(8192);
    view.setAll(0, Float32List.fromList(List.generate(8192, (i) => 0.5)));
    expect(view[8191], 0.5);
    malloc.free(buf);
  });
}
