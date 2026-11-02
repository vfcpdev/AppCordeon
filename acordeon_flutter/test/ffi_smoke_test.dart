import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

typedef AnalyzeNative = Pointer<Utf8> Function(
    Pointer<Float>, UintPtr, Float);
typedef AnalyzeDart = Pointer<Utf8> Function(Pointer<Float>, int, double);

typedef DetectNative = Pointer<Utf8> Function(Pointer<Uint8>, UintPtr);
typedef DetectDart = Pointer<Utf8> Function(Pointer<Uint8>, int);

typedef FreeStrNative = Void Function(Pointer<Utf8>);
typedef FreeStrDart = void Function(Pointer<Utf8>);

/// Sonda incremental: identifica la función exacta que corrompe el heap en el
/// runner de flutter_test.
void main() {
  late DynamicLibrary lib;
  late AnalyzeDart analyze;
  late DetectDart detect;
  late FreeStrDart freeStr;

  setUpAll(() {
    lib = DynamicLibrary.open(
      r'..\acordeon_engine\target\release\acordeon_engine.dll',
    );
    analyze = lib.lookupFunction<AnalyzeNative, AnalyzeDart>(
        'acordeon_analyze_audio_ffi');
    detect = lib.lookupFunction<DetectNative, DetectDart>(
        'acordeon_detect_chord_ffi');
    freeStr = lib
        .lookupFunction<FreeStrNative, FreeStrDart>('acordeon_free_string');
  });

  test('detect_chord (nota aislada)', () {
    final ptr = malloc.allocate<Uint8>(3);
    ptr.asTypedList(3).setAll(0, [60, 64, 67]);
    final r = detect(ptr, 3);
    final s = r.toDartString();
    freeStr(r);
    malloc.free(ptr);
    print('detect -> $s');
    expect(s, contains('{'));
  });

  test('analyze con 4096 muestras (borde mínimo)', () {
    const n = 4096;
    final buf = malloc.allocate<Float>(n);
    buf.asTypedList(n).setAll(0, Float32List.fromList(List.generate(n, (i) => 0.5)));
    final r = analyze(buf, n, 44100.0);
    final s = r.toDartString();
    freeStr(r);
    malloc.free(buf);
    print('analyze 4096 -> len ${s.length}');
  });

  test('analyze con 8192 muestras (2 ventanas)', () {
    const n = 8192;
    final buf = malloc.allocate<Float>(n);
    final view = buf.asTypedList(n);
    for (var i = 0; i < n; i++) {
      view[i] = (i % 441) / 441.0;
    }
    final r = analyze(buf, n, 44100.0);
    final s = r.toDartString();
    freeStr(r);
    malloc.free(buf);
    print('analyze 8192 -> len ${s.length}');
    expect(s, contains('duration'));
  });
}
