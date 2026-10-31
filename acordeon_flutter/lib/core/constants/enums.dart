/// Enumeraciones globales para el simulador de acordeón diatónico.
enum BellowsMode {
  both,
  pull,
  push;

  String get label {
    switch (this) {
      case BellowsMode.both:
        return 'Ambos';
      case BellowsMode.pull:
        return 'Abre';
      case BellowsMode.push:
        return 'Cierra';
    }
  }
}

enum NotationMode {
  latina,
  alemana;

  String get label => this == NotationMode.latina ? 'Latina' : 'Alemana';
}

enum ButtonType {
  treble,
  fundamental,
  chord,
}

enum BassMatchType {
  none,
  exact,
  close;

  bool get isMatch => this != BassMatchType.none;
}
