import 'dart:io' show Platform;

/// Entorno de ejecución nativo (Windows, Linux, macOS, Android, iOS).
///
/// {P}: se compila en plataformas con `dart:io`.
/// {Q}: `true` cuando el proceso es `flutter_tester`.
bool get isFlutterTestEnvironment =>
    Platform.environment['FLUTTER_TEST'] == 'true';
