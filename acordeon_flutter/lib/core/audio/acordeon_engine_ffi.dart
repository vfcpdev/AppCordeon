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

/// Reserva de buffer DE RUST (evita el bug del malloc de Dart SDK 3.12).
typedef AcordeonAllocBufferNative = Pointer<Float> Function(UintPtr len);
typedef AcordeonAllocBufferDart = Pointer<Float> Function(int len);

/// Liberación de buffer de Rust.
typedef AcordeonFreeBufferNative = Void Function(Pointer<Float> ptr, UintPtr len);
typedef AcordeonFreeBufferDart = void Function(Pointer<Float> ptr, int len);

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
  AcordeonAllocBufferDart? _allocBufferFn;
  AcordeonFreeBufferDart? _freeBufferFn;
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
        _allocBufferFn = _lib!.lookupFunction<AcordeonAllocBufferNative, AcordeonAllocBufferDart>('acordeon_alloc_buffer');
        _freeBufferFn = _lib!.lookupFunction<AcordeonFreeBufferNative, AcordeonFreeBufferDart>('acordeon_free_buffer');
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

  /// Buffer nativo REUTILIZABLE asignado POR RUST.
  ///
  /// # Por qué Rust asigna (bug crítico del heap de Dart detectado con sondas)
  ///
  /// `malloc.allocate<Float>(n)` del paquete `ffi` 2.x con SDK 3.12 en
  /// Windows crashea (0xC0000005) cuando `n > 4096` y se escribe el buffer:
  /// 4096 OK, 4097 crash — reproducido SIN DLL, es bug del allocator Dart.
  ///
  /// Solución: Rust expone `acordeon_alloc_buffer`/`acordeon_free_buffer`
  /// (allocator del sistema, estable). El buffer vive mientras viva el
  /// singleton; se reutiliza y crece si hace falta; se libera con la función
  /// de Rust correspondiente, NUNCA con `malloc.free` de Dart.
  Pointer<Float>? _sharedAnalysisBuffer;
  int _sharedAnalysisCapacity = 0;

  Pointer<Uint8>? _sharedByteBuffer;
  int _sharedByteCapacity = 0;

  /// Garantiza un buffer de floats nativo DE RUST de al menos [required].
  ///
  /// # Tripla de Hoare
  /// - {P}: `required > 0` y motor disponible.
  /// - {Q}: retorna puntero válido con capacidad ≥ [required]; el buffer
  ///   previo (si era suficiente) se reutiliza SIN reasignar.
  Pointer<Float> _ensureBuffer(int required) {
    final current = _sharedAnalysisBuffer;
    if (current != null && _sharedAnalysisCapacity >= required) {
      return current;
    }
    // {I}: el buffer anterior se libera con la función DE RUST (mismo
    // allocator), nunca con malloc.free de Dart.
    if (current != null) {
      _freeBufferFn?.call(current, _sharedAnalysisCapacity);
    }
    final allocated = _allocBufferFn!(required);
    _sharedAnalysisBuffer = allocated;
    _sharedAnalysisCapacity = required;
    return allocated;
  }

  /// Garantiza un buffer de bytes nativo DE RUST de al menos [required].
  Pointer<Uint8> _ensureUint8Buffer(int required) {
    final current = _sharedByteBuffer;
    if (current != null && _sharedByteCapacity >= required) {
      return current;
    }
    if (current != null) {
      _freeBufferFn?.call(current.cast<Float>(), _sharedByteCapacity);
    }
    final allocated = _allocBufferFn!(required).cast<Uint8>();
    _sharedByteBuffer = allocated;
    _sharedByteCapacity = required;
    return allocated;
  }

  /// Copia [samples] al buffer compartido vía vista TypedData.
  ///
  /// # Por qué este camino y no otro (bug del SDK 3.12, documentado)
  ///
  /// `Pointer[i] = expr(i)` en bucle JIT caliente corrompe el heap del SDK
  /// 3.12 en Windows con allocations grandes (crash 0xC0000005, reproducido
  /// con sondas FFI SIN DLL — es un bug del runtime, no de Rust).
  ///
  /// La copia vía la vista TypedData del pointer (setAll) usa el camino
  /// nativo `_memMove` del runtime, estable y validada con 5 análisis
  /// consecutivos sin crash — AHORA sobre buffers asignados por Rust,
  /// que además eliminaron el crash original del free de malloc Dart.
  void _copyToBuffer(Pointer<Float> buffer, Float32List samples) {
    buffer.asTypedList(samples.length).setAll(0, samples);
  }

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
    final byteBuffer = _ensureUint8Buffer(midiNotes.length);
    for (var i = 0; i < midiNotes.length; i++) {
      byteBuffer[i] = midiNotes[i].clamp(0, 255);
    }
    try {
      final result = _detectChordFn!(byteBuffer, midiNotes.length);
      return _takeCString(result);
    } catch (e) {
      debugPrint('[AcordeonEngineFFI] detectChordJson falló: $e');
      return null;
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
    try {
      final buffer = _ensureBuffer(samples.length);
      _copyToBuffer(buffer, samples);
      final result = _analyzeFn!(buffer, samples.length, sampleRate);
      return _takeCString(result);
    } catch (e) {
      debugPrint('[AcordeonEngineFFI] analyzeAudioJson falló: $e');
      return null;
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
    try {
      final buffer = _ensureBuffer(samples.length);
      _copyToBuffer(buffer, samples);
      final result = _beatChordsFn!(
        buffer,
        samples.length,
        sampleRate,
        bpm,
        startOffset,
      );
      return _takeCString(result);
    } catch (e) {
      debugPrint('[AcordeonEngineFFI] detectBeatChordsJson falló: $e');
      return null;
    }
  }
}
