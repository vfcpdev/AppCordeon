/// Entorno de ejecución web.
///
/// {P}: se compila en navegador, donde no existe `dart:io`.
/// {Q}: siempre `false`: el analizador Rust no se enlaza en web, por lo que el
///      guard de `flutter_tester` no aplica.
bool get isFlutterTestEnvironment => false;
