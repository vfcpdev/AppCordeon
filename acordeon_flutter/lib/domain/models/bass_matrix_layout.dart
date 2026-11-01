import 'dart:math' as math;

import 'bass_rhythm_pattern.dart';

/// Disposición de la matriz 2×2 de captura de bajos.
///
/// La matriz relaciona sus cuatro cajas con los botones físicos del panel:
///
/// |            | Externos (col 0) | Internos (col 1) |
/// |------------|------------------|------------------|
/// | Fila 1     | botón 7          | botón 4          |
/// | Fila 2     | botón 8          | botón 5          |
///
/// Vive en `domain/models` para que la presentación sólo consuma el mapeo
/// (bajo acoplamiento) y las pruebas puedan verificarlo sin widgets.
abstract final class BassMatrixLayout {
  static const int rows = 2;
  static const int columns = 2;

  static const String exteriorLabel = 'Bajos externos';
  static const String interiorLabel = 'Bajos internos';

  /// Número de botón físico para una caja de la matriz.
  ///
  /// # Triplas de Hoare
  /// - {P}: `row ∈ {0, 1} ∧ column ∈ {0, 1}`.
  /// - {Q}: retorna uno de `{7, 8, 4, 5}` según la tabla de disposición.
  static int buttonNumberFor({required int row, required int column}) {
    if (row < 0 || row >= rows || column < 0 || column >= columns) {
      throw ArgumentError.value(
        (row, column),
        'BassMatrixLayout.buttonNumberFor',
        'Precondición {P}: (row, column) debe estar dentro de la matriz 2×2',
      );
    }
    return _lookup[row][column];
  }

  /// Etiqueta de la columna (`Externos` / `Internos`).
  static String columnLabelFor(int column) =>
      column == 0 ? exteriorLabel : interiorLabel;

  /// Números de botón en el orden de recorrido de la matriz.
  static const List<int> buttonNumbers = [7, 8, 4, 5];

  /// Tabla fila-mayor: `_lookup[fila][columna]`.
  static const List<List<int>> _lookup = [
    [7, 4], // Fila 1: externo 7, interno 4
    [8, 5], // Fila 2: externo 8, interno 5
  ];
}

/// Captura interactiva de un patrón rítmico tocado sobre los bajos.
///
/// Objeto de dominio puro (sin Flutter ni Riverpod): el controlador le pasa
/// el reloj virtual de la captura y los botones presionados. Esto mantiene
/// alta cohesión (sólo sabe de tiempos y golpes) y bajo acoplamiento.
///
/// # Triplas de Hoare
/// - `recordButton` {P}: la captura está activa y `buttonNumber` pertenece al
///   conjunto seleccionado. {Q}: o se añade un golpe nuevo (true) o el estado
///   no cambia (false).
/// - `buildPattern` {Q}: el patrón resultante tiene nombre no vacío, BPM > 0,
///   compás válido y golpes con `onset` creciente.
class BassRhythmRecorder {
  double _beatSeconds = 0.5;
  double _quarterNotesPerMinute = 120;
  int _beatsPerMeasure = 4;
  int _beatType = 4;
  Set<int> _selectedButtons = const {};
  bool _isRecording = false;

  double _lastRecordedQuarterBeat = -1;

  final List<BassRhythmHit> _hits = [];

  /// Nombre que tendrá el patrón al detener la captura.
  String name = '';

  bool get isRecording => _isRecording;

  /// Reloj virtual de la captura, inyectado por el controlador en cada tick.
  /// No se usa `DateTime.now()` para que las pruebas sean deterministas.
  Duration captureDuration = Duration.zero;

  Set<int> get selectedButtons => Set.unmodifiable(_selectedButtons);
  List<BassRhythmHit> get hits => List.unmodifiable(_hits);

  /// Inicia la captura.
  ///
  /// {P}: `quarterNotesPerMinute ∈ (0, 400]` y `beatSeconds > 0`.
  /// {Q}: `isRecording == true`, sin golpes previos ni selección alterada.
  void start({
    required String name,
    required double beatSeconds,
    required double quarterNotesPerMinute,
    required int beatsPerMeasure,
    required int beatType,
    required Set<int> selectedButtons,
  }) {
    if (beatSeconds <= 0 || quarterNotesPerMinute <= 0) {
      throw ArgumentError(
        'Precondición {P} de BassRhythmRecorder.start: '
        'beatSeconds y quarterNotesPerMinute deben ser > 0',
      );
    }
    this.name = name;
    _beatSeconds = beatSeconds;
    _quarterNotesPerMinute = quarterNotesPerMinute;
    _beatsPerMeasure = beatsPerMeasure <= 0 ? 4 : beatsPerMeasure;
    _beatType = beatType <= 0 ? 4 : beatType;
    _selectedButtons = Set.unmodifiable(selectedButtons);
    _hits.clear();
    captureDuration = Duration.zero;
    _lastRecordedQuarterBeat = -1;
    _isRecording = true;
  }

  /// Alterna la selección de un botón para esta captura.
  /// Acepta números de caja de la matriz (7, 8, 4, 5).
  void toggleSelection(int buttonNumber) {
    final next = Set<int>.from(_selectedButtons);
    if (!next.remove(buttonNumber)) next.add(buttonNumber);
    _selectedButtons = Set.unmodifiable(next);
  }

  /// Registra un golpe en el instante actual de la captura.
  ///
  /// Devuelve `true` si el golpe se añadió y `false` si la captura está
  /// detenida o el botón no fue presionado.
  bool recordButton(int buttonNumber) {
    if (!_isRecording) return false;
    if (!_selectedButtons.contains(buttonNumber)) return false;
    final onset = captureDuration.inMicroseconds / 1e6 / _beatSeconds;
    if ((onset - _lastRecordedQuarterBeat).abs() < 1e-6) return false;
    _lastRecordedQuarterBeat = onset;
    _hits.add(
      BassRhythmHit(
        onsetQuarterBeats: onset,
        // Duración provisional: se recalcula en buildPattern.
        durationQuarterBeats: 0,
        buttonIndex: buttonNumber,
        buttonType: BassRhythmButtonType.fundamental,
        fingerNumber: 2,
      ),
    );
    return true;
  }

  /// Construye el patrón definitivo cerrando duraciones pendientes.
  ///
  /// {Q}: cada golpe dura hasta el siguiente onset (o hasta el final de la
  /// captura), con un mínimo audible, y el patrón cubre el compás capturado.
  BassRhythmPattern buildPattern({required double totalSeconds}) {
    final double patternQuarters;
    if (_hits.isEmpty) {
      patternQuarters = _beatsPerMeasure * 4 / _beatType;
    } else {
      final measureQuarters = _beatsPerMeasure * 4 / _beatType;
      final lastBeat = totalSeconds > 0 ? totalSeconds / _beatSeconds : 0.0;
      final capturedLength = math.max(lastBeat, _hits.last.onsetQuarterBeats);
      patternQuarters =
          math.min(capturedLength, measureQuarters).clamp(0.25, measureQuarters);
    }

    final closed = <BassRhythmHit>[];
    for (var i = 0; i < _hits.length; i++) {
      final hit = _hits[i];
      final nextOnset = i + 1 < _hits.length
          ? _hits[i + 1].onsetQuarterBeats
          : math.max(patternQuarters, hit.onsetQuarterBeats + 0.125);
      final duration = (nextOnset - hit.onsetQuarterBeats)
          .clamp(0.125, patternQuarters)
          .toDouble();
      closed.add(
        BassRhythmHit(
          onsetQuarterBeats: hit.onsetQuarterBeats,
          durationQuarterBeats: duration,
          buttonIndex: hit.buttonIndex,
          buttonType: hit.buttonType,
          fingerNumber: hit.fingerNumber,
        ),
      );
    }

    final trimmed = name.trim();
    return BassRhythmPattern(
      id: 'capture:${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed.isEmpty ? 'Patrón sin nombre' : trimmed,
      partName: 'Captura en vivo',
      measureNumber: 1,
      beatsPerMeasure: _beatsPerMeasure,
      beatType: _beatType,
      durationQuarterBeats: patternQuarters <= 0
          ? (_beatsPerMeasure * 4 / _beatType)
          : patternQuarters,
      quarterNotesPerMinute: _quarterNotesPerMinute,
      hits: closed,
    );
  }

  /// Detiene la captura y libera el registro.
  void stop() => _isRecording = false;
}
