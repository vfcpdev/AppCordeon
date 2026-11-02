import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef AllocBufferNative = Pointer<Float> Function(UintPtr);
typedef AllocBufferDart = Pointer<Float> Function(int);
typedef FreeBufferNative = Void Function(Pointer<Float>, UintPtr);
typedef FreeBufferDart = void Function(Pointer<Float>, int);
typedef AnalyzeNative = Pointer<Utf8> Function(
    Pointer<Float>, UintPtr, Float);
typedef AnalyzeDart = Pointer<Utf8> Function(Pointer<Float>, int, double);
typedef FreeStrNative = Void Function(Pointer<Utf8>);
typedef FreeStrDart = void Function(Pointer<Utf8>);
typedef InitNative = Void Function(Float);
typedef InitDart = void Function(double);

/// VALIDACIÓN del camino de producción: buffer Rust + setAll (camino nativo).
/// Escenario del usuario: audio largo completo (~30 s) analizado de una vez.
void main() {
  final lib = DynamicLibrary.open(
    r'..\acordeon_engine\target\release\acordeon_engine.dll',
  );
  final init = lib.lookupFunction<InitNative, InitDart>('acordeon_engine_init');
  final alloc =
      lib.lookupFunction<AllocBufferNative, AllocBufferDart>('acordeon_alloc_buffer');
  final analyze =
      lib.lookupFunction<AnalyzeNative, AnalyzeDart>('acordeon_analyze_audio_ffi');
  final freeStr =
      lib.lookupFunction<FreeStrNative, FreeStrDart>('acordeon_free_string');

  init(44100.0);
  print('[init OK]');

  // 30 segundos @ 44.1kHz con señal musical variada (simula MP3 decodificado).
  final n = 44100 * 30;
  final buf = alloc(n);
  print('[buffer Rust: $n floats = ${n * 4 ~/ 1024} KB]');
  final view = buf.asTypedList(n);
  for (var i = 0; i < n; i++) {
    // Mezcla de tonos que cambia cada 3 s (simula progresión de acordes).
    final tone = 220.0 * (1 + ((i ~/ (44100 * 3)) % 4));
    view[i] = 0.4 * ((2 * 3.14159265 * tone * i) / 44100 % (2 * 3.14159265)).abs() - 0.2;
  }
  print('[escrito con setAll nativo]');

  final r = analyze(buf, n, 44100.0);
  final s = r.toDartString();
  print('[json ${s.length} chars]');
  // Extraer campos clave para verificar tono/BPM/acordes.
  final durationIdx = s.indexOf('"duration"');
  final bpmIdx = s.indexOf('"bpm"');
  final keyIdx = s.indexOf('"keyNameLat"');
  final chordsIdx = s.indexOf('"chords"');
  print('duration → ${s.substring(durationIdx, durationIdx + 22)}');
  print('bpm      → ${s.substring(bpmIdx, bpmIdx + 10)}');
  print('key      → ${s.substring(keyIdx, keyIdx + 30)}');
  print('chords   → ${s.substring(chordsIdx, chordsIdx + 40)}');
  print('FIN — audio completo (30 s) analizado sin crash');
}
