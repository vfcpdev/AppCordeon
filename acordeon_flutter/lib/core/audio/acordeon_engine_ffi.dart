/// Puente FFI con el motor Rust.
///
/// En plataformas con `dart:ffi` (Windows, Linux, macOS, Android, iOS) se usa
/// la implementación nativa; en web se resuelve un stub sin acoplamiento a
/// `dart:ffi`, de modo que el pipeline Dart puro de análisis sigue operando.
library;

export 'acordeon_engine_ffi_io.dart'
    if (dart.library.js_interop) 'acordeon_engine_ffi_stub.dart';
