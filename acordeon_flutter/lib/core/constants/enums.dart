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

/// Identifica la hilera melódica objetivo del acordeón diatónico (3 hileras).
enum AccordionRowTarget {
  externalRow,
  middleRow,
  internalRow;

  String get label {
    switch (this) {
      case AccordionRowTarget.externalRow:
        return 'Ext';
      case AccordionRowTarget.middleRow:
        return 'Med';
      case AccordionRowTarget.internalRow:
        return 'Int';
    }
  }

  String get fullName {
    switch (this) {
      case AccordionRowTarget.externalRow:
        return 'Hilera Externa';
      case AccordionRowTarget.middleRow:
        return 'Hilera Media';
      case AccordionRowTarget.internalRow:
        return 'Hilera Interna';
    }
  }
}

/// Filtro de visualización e interacción de columnas en el panel de bajos.
enum BassColumnFilter {
  all,
  externalOnly,
  internalOnly;

  String get label {
    switch (this) {
      case BassColumnFilter.all:
        return 'Todos';
      case BassColumnFilter.externalOnly:
        return 'Externos';
      case BassColumnFilter.internalOnly:
        return 'Internos';
    }
  }
}
