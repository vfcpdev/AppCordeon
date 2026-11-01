import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef AcordeonInitNative = Void Function(Float sampleRate);
typedef AcordeonInitDart = void Function(double sampleRate);

typedef AcordeonNoteNative = Void Function(Uint8 midiNote);
typedef AcordeonNoteDart = void Function(int midiNote);

typedef AcordeonVoidNative = Void Function();
typedef AcordeonVoidDart = void Function();

typedef AcordeonVolumeNative = Void Function(Float volume);
typedef AcordeonVolumeDart = void Function(double volume);

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
        r'C:\Users\USUARIO\AppCordeon\acordeon_engine\target\release\acordeon_engine.dll',
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
}
