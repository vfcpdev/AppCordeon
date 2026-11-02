import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef AcordeonInitNative = Void Function(Float sampleRate);
typedef AcordeonInitDart = void Function(double sampleRate);

typedef AcordeonNoteNative = Void Function(Uint8 midiNote);
typedef AcordeonNoteDart = void Function(int midiNote);

typedef AcordeonVoidNative = Void Function();
typedef AcordeonVoidDart = void Function();

typedef AcordeonVolumeNative = Void Function(Float volume);
typedef AcordeonVolumeDart = void Function(double volume);

/// Render de buffer PCM mono (render en hilo WASAPI).
typedef AcordeonProcessNative = Void Function(Pointer<Float> buffer, UintPtr length);
typedef AcordeonProcessDart = void Function(Pointer<Float> buffer, int length);

/// Detección de acorde desde notas MIDI → CString JSON.
typedef AcordeonDetectChordNative = Pointer<Utf8> Function(
    Pointer<Uint8> notes, UintPtr count);
typedef AcordeonDetectChordDart = Pointer<Utf8> Function(
    Pointer<Uint8> notes, int count);

/// Análisis completo de audio Float32 → CString JSON.
typedef AcordeonAnalyzeNative = Pointer<Utf8> Function(
    Pointer<Float> data, UintPtr length, Float sampleRate);
typedef AcordeonAnalyzeDart = Pointer<Utf8> Function(
    Pointer<Float> data, int length, double sampleRate);

/// Acordes sincronizados por compás → CString JSON.
typedef AcordeonBeatChordsNative = Pointer<Utf8> Function(
    Pointer<Float> data, UintPtr length, Float sampleRate, Float bpm, Float startOffset);
typedef AcordeonBeatChordsDart = Pointer<Utf8> Function(
    Pointer<Float> data, int length, double sampleRate, double bpm, double startOffset);

/// Liberación de cadenas asignadas por Rust.
typedef AcordeonFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef AcordeonFreeStringDart = void Function(Pointer<Utf8> ptr);

/// Puente FFI con la librería dinámica en Rust `acordeon_engine.dll`
///
/// # Estado y contrato (Mejora 5 del informe de arquitectura)
///
/// **División de responsabilidades Dart/Rust** (regla acordada):
/// - **Rust** (`acordeon_engine` crate): síntesis DSP y análisis pesado
///   (FFT, chromagrama, detección de tonalidad/BPM/acordes) expuestos vía
///   C ABI estable.
/// - **Dart**: orquestación, estado de UI, y pipeline de análisis puro
///   (`core/audio/analysis/*`) como fallback cuando la DLL no está disponible.
///
/// **Carga**: se intentan las rutas candidatas en orden; si ninguna existe
/// (`_isAvailable == false`) el bridge degrada silenciosamente y la UI usa el
/// fallback Dart. No se lanza excepción para no romper el arranque en
/// entornos sin la DLL compilada (web, CI).
///
/// **Para habilitar**: compilar `cargo build --release` en `acordeon_engine/`
/// y copiar `target/release/acordeon_engine.dll` junto al ejecutable o en una
/// de las rutas candidatas de abajo.
class AcordeonEngineFFI {
  static AcordeonEngineFFI? _instance;
  static AcordeonEngineFFI get instance => _instance ??= AcordeonEngineFFI._();

  DynamicLibrary? _lib;
  AcordeonInitDart? _initFn;
  AcordeonNoteDart? _noteOnFn;
  AcordeonNoteDart? _noteOffFn;
  AcordeonVoidDart? _allNotesOffFn;
  AcordeonVolumeDart? _setVolumeFn;
  AcordeonDetectChordDart? _detectChordFn;
  AcordeonAnalyzeDart? _analyzeFn;
  AcordeonBeatChordsDart? _beatChordsFn;
  AcordeonFreeStringDart? _freeStringFn;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  AcordeonEngineFFI._() {
    _loadLibrary();
  }

  void _loadLibrary() {
    if (kIsWeb) return;

    final candidates = [
      'acordeon_engine.dll',
      if (Platform.isWindows) ...[
        '${File(Platform.resolvedExecutable).parent.path}\\acordeon_engine.dll',
        r'..\acordeon_engine\target\release\acordeon_engine.dll',
        r'C:\Users\vfcp1\Documents\SideProjects\AppCordeon\acordeon_engine\target\release\acordeon_engine.dll',
        // Ruta absoluta derivada del proyecto para tests y CLI.
        r'd:\Documents\SideProjects\AppCordeon\acordeon_engine\target\release\acordeon_engine.dll',
      ],
    ];

    for (final path in candidates) {
      try {
        _lib = DynamicLibrary.open(path);
        debugPrint('[AcordeonEngineFFI] DLL de Rust cargada exitosamente desde: $path');
        break;
      } catch (e) {
        // Intenta la siguiente ruta candidata
      }
    }

    if (_lib != null) {
      try {
        _initFn = _lib!.lookupFunction<AcordeonInitNative, AcordeonInitDart>('acordeon_engine_init');
        _noteOnFn = _lib!.lookupFunction<AcordeonNoteNative, AcordeonNoteDart>('acordeon_engine_note_on');
        _noteOffFn = _lib!.lookupFunction<AcordeonNoteNative, AcordeonNoteDart>('acordeon_engine_note_off');
        _allNotesOffFn = _lib!.lookupFunction<AcordeonVoidNative, AcordeonVoidDart>('acordeon_engine_all_notes_off');
        _setVolumeFn = _lib!.lookupFunction<AcordeonVolumeNative, AcordeonVolumeDart>('acordeon_engine_set_volume');
        _detectChordFn = _lib!.lookupFunction<AcordeonDetectChordNative, AcordeonDetectChordDart>('acordeon_detect_chord_ffi');
        _analyzeFn = _lib!.lookupFunction<AcordeonAnalyzeNative, AcordeonAnalyzeDart>('acordeon_analyze_audio_ffi');
        _beatChordsFn = _lib!.lookupFunction<AcordeonBeatChordsNative, AcordeonBeatChordsDart>('acordeon_detect_beat_chords_ffi');
        _freeStringFn = _lib!.lookupFunction<AcordeonFreeStringNative, AcordeonFreeStringDart>('acordeon_free_string');
        _isAvailable = true;
      } catch (e) {
        debugPrint('[AcordeonEngineFFI] Error al vincular símbolos C ABI: $e');
      }
    } else {
      debugPrint('[AcordeonEngineFFI] Advertencia: No se encontró acordeon_engine.dll');
    }
  }

  void init({double sampleRate = 44100.0}) {
    if (_isAvailable && _initFn != null) {
      _initFn!(sampleRate);
    }
  }

  void noteOn(int midiNote) {
    if (_isAvailable && _noteOnFn != null) {
      _noteOnFn!(midiNote);
    }
  }

  void noteOff(int midiNote) {
    if (_isAvailable && _noteOffFn != null) {
      _noteOffFn!(midiNote);
    }
  }

  void allNotesOff() {
    if (_isAvailable && _allNotesOffFn != null) {
      _allNotesOffFn!();
    }
  }

  void setVolume(double volume) {
    if (_isAvailable && _setVolumeFn != null) {
      _setVolumeFn!(volume);
    }
  }

  /// Indica si las funciones de análisis Rust están vinculadas.
  bool get analysisAvailable => _isAvailable && _analyzeFn != null;

  /// Helper: convierte el CString JSON de Rust a String Dart y libera la
  /// memoria nativa con `acordeon_free_string` (evita fugas).
  String? _takeCString(Pointer<Utf8>? ptr) {
    if (ptr == null || ptr == nullptr) return null;
    final value = ptr.toDartString();
    _freeStringFn?.call(ptr);
    return value;
  }

  /// Detección de acorde desde notas MIDI vía Rust.
  ///
  /// # Tripla de Hoare
  /// - {P}: `midiNotes` no vacío; el motor está disponible.
  /// - {Q}: retorna el JSON del acorde detectado (`"{}"` si no hay match).
  String? detectChordJson(List<int> midiNotes) {
    if (!analysisAvailable || midiNotes.isEmpty) return null;
    final ptr = malloc.allocate<Uint8>(midiNotes.length);
    try {
      ptr.asTypedList(midiNotes.length)
          .setAll(0, midiNotes.map((n) => n.clamp(0, 255)).toList());
      final result = _detectChordFn!(ptr, midiNotes.length);
      return _takeCString(result);
    } catch (e) {
      debugPrint('[AcordeonEngineFFI] detectChordJson falló: $e');
      return null;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Análisis completo de audio (tonalidad, BPM, acordes) vía Rust.
  ///
  /// # Tripla de Hoare
  /// - {P}: `samples.length >= 4096` y `sampleRate > 0`.
  /// - {Q}: retorna JSON válido o `null` si el motor llama con datos
  ///        insuficientes (fallback a Dart en el llamador).
  String? analyzeAudioJson(Float32List samples, double sampleRate) {
    if (!analysisAvailable || samples.length < 4096 || sampleRate <= 0) {
      return null;
    }
    Pointer<Float>? copied;
    try {
      copied = malloc.allocate<Float>(samples.length);
      copied.asTypedList(samples.length).setAll(0, samples);
      final result = _analyzeFn!(copied, samples.length, sampleRate);
      return _takeCString(result);
    } catch (e) {
      debugPrint('[AcordeonEngineFFI] analyzeAudioJson falló: $e');
      return null;
    } finally {
      if (copied != null) malloc.free(copied);
    }
  }

  /// Acordes sincronizados por compás vía Rust.
  String? detectBeatChordsJson(
    Float32List samples,
    double sampleRate, {
    required double bpm,
    required double startOffset,
  }) {
    if (!analysisAvailable || samples.length < 4096 || sampleRate <= 0) {
      return null;
    }
    Pointer<Float>? copied;
    try {
      copied = malloc.allocate<Float>(samples.length);
      copied.asTypedList(samples.length).setAll(0, samples);
      final result = _beatChordsFn!(
        copied,
        samples.length,
        sampleRate,
        bpm,
        startOffset,
      );
      return _takeCString(result);
    } catch (e) {
      debugPrint('[AcordeonEngineFFI] detectBeatChordsJson falló: $e');
      return null;
    } finally {
      if (copied != null) malloc.free(copied);
    }
  }
}
