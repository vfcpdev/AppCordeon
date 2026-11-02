/// Abstracción del entorno de ejecución independiente de plataforma.
///
/// Usa conditional imports para evitar `dart:io` en el árbol web.
library;

export 'platform_environment_io.dart'
    if (dart.library.js_interop) 'platform_environment_web.dart';
