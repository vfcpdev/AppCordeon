import 'dart:convert';
import '../../core/constants/enums.dart';
import 'measure_models.dart';

/// Datos completos recuperados de un archivo JSON de compases.
class MeasureJsonData {
  final List<MeasureRow> measures;
  final int? bpm;
  final String? name;
  final String? tuning;
  final Set<int> markedBeats;
  final String timeSignature;
  final int version;
  final String? createdAt;

  const MeasureJsonData({
    required this.measures,
    this.bpm,
    this.name,
    this.tuning,
    this.markedBeats = const {},
    this.timeSignature = '4/4',
    this.version = 1,
    this.createdAt,
  });
}

/// Servicio para exportar e importar compases con sus 4 secciones/tiempos en formato JSON.
class MeasureJsonSerializer {
  /// Exporta una lista de [MeasureRow] a un string JSON formateado.
  static String exportToJson(
    List<MeasureRow> measures, {
    int? bpm,
    String? name,
    String? tuning,
    Set<int>? markedBeats,
  }) {
    final data = <String, dynamic>{
      'version': 1,
      'app': 'AppCordeon',
      'createdAt': DateTime.now().toIso8601String(),
      'timeSignature': '4/4',
      'totalMeasures': measures.length,
    };
    if (name != null && name.isNotEmpty) data['name'] = name;
    if (bpm != null) data['bpm'] = bpm;
    if (tuning != null && tuning.isNotEmpty) data['tuning'] = tuning;
    if (markedBeats != null && markedBeats.isNotEmpty) {
      data['markedBeats'] = markedBeats.toList()..sort();
    }
    data['measures'] = measures.map((m) {
      return {
        'barNumber': m.barNumber,
        'beats': m.beats.map((b) {
          return {
            'beatIndex': b.beatIndex,
            'chord': b.chord,
            'timeText': b.timeText,
            'isContinue': b.isContinue,
            'bellows': b.bellows.name,
          };
        }).toList(),
      };
    }).toList();

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Parsea la estructura completa de metadatos y compases desde una cadena JSON.
  static MeasureJsonData parseJsonData(String jsonString) {
    final decoded = json.decode(jsonString);
    final List<dynamic> measuresList;
    int? bpm;
    String? name;
    String? tuning;
    String? createdAt;
    int version = 1;
    String timeSignature = '4/4';
    Set<int> markedBeats = const {};

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('measures')) {
        measuresList = decoded['measures'] as List<dynamic>;
      } else {
        measuresList = const [];
      }
      if (decoded['bpm'] is num) bpm = (decoded['bpm'] as num).toInt();
      if (decoded['name'] is String) name = decoded['name'] as String;
      if (decoded['tuning'] is String) tuning = decoded['tuning'] as String;
      if (decoded['createdAt'] is String) createdAt = decoded['createdAt'] as String;
      if (decoded['version'] is num) version = (decoded['version'] as num).toInt();
      if (decoded['timeSignature'] is String) timeSignature = decoded['timeSignature'] as String;
      if (decoded['markedBeats'] is List) {
        markedBeats = (decoded['markedBeats'] as List)
            .map((e) {
              if (e is num) return e.toInt();
              return int.tryParse(e.toString());
            })
            .whereType<int>()
            .toSet();
      }
    } else if (decoded is List) {
      measuresList = decoded;
    } else {
      throw const FormatException('Formato JSON no válido para compases');
    }

    final result = <MeasureRow>[];

    for (var bIdx = 0; bIdx < measuresList.length; bIdx++) {
      final m = measuresList[bIdx];
      final barNum =
          (m is Map && m.containsKey('barNumber'))
              ? (m['barNumber'] as num).toInt()
              : (bIdx + 1);

      final beatsList =
          (m is Map && m.containsKey('beats'))
              ? (m['beats'] as List<dynamic>)
              : <dynamic>[];

      final beats = <MeasureBeat>[];
      for (var beatIdx = 0; beatIdx < 4; beatIdx++) {
        Map<String, dynamic>? beatMap;
        if (beatIdx < beatsList.length && beatsList[beatIdx] is Map) {
          beatMap = Map<String, dynamic>.from(beatsList[beatIdx] as Map);
        }

        final chord = beatMap?['chord']?.toString() ?? '';
        final isContinue = beatMap?['isContinue'] == true;
        final timeText =
            beatMap?['timeText']?.toString() ?? _defaultTimeText(bIdx, beatIdx);
        final bellowsStr = beatMap?['bellows']?.toString();
        final bellows = BellowsMode.values.firstWhere(
          (v) => v.name == bellowsStr,
          orElse: () => BellowsMode.both,
        );

        beats.add(MeasureBeat(
          barIndex: bIdx,
          beatIndex: beatIdx,
          chord: chord,
          timeText: timeText,
          isContinue: isContinue,
          bellows: bellows,
        ));
      }

      result.add(MeasureRow(barNumber: barNum, beats: beats));
    }

    return MeasureJsonData(
      measures: result,
      bpm: bpm,
      name: name,
      tuning: tuning,
      markedBeats: markedBeats,
      timeSignature: timeSignature,
      version: version,
      createdAt: createdAt,
    );
  }

  /// Importa compases desde un string JSON (mantiene compatibilidad directa con [MeasureRow]).
  static List<MeasureRow> importFromJson(String jsonString) {
    return parseJsonData(jsonString).measures;
  }

  static String _defaultTimeText(int bIdx, int beatIdx) {
    final timeSec = (bIdx * 4 + beatIdx) * 0.5;
    final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
    final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
