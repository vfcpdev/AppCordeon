import 'dart:convert';
import 'measure_models.dart';

/// Servicio para exportar e importar compases con sus 4 secciones/tiempos en formato JSON.
class MeasureJsonSerializer {
  /// Exporta una lista de [MeasureRow] a un string JSON formateado.
  static String exportToJson(
    List<MeasureRow> measures, {
    int? bpm,
    String? name,
  }) {
    final data = <String, dynamic>{
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (name != null) data['name'] = name;
    if (bpm != null) data['bpm'] = bpm;
    data['measures'] = measures.map((m) {
      return {
        'barNumber': m.barNumber,
        'beats': m.beats.map((b) {
          return {
            'beatIndex': b.beatIndex,
            'chord': b.chord,
            'timeText': b.timeText,
            'isContinue': b.isContinue,
          };
        }).toList(),
      };
    }).toList();

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Importa compases desde un string JSON.
  /// Retorna una lista de [MeasureRow] restaurada con sus 4 tiempos cada una.
  static List<MeasureRow> importFromJson(String jsonString) {
    final decoded = json.decode(jsonString);
    final List<dynamic> measuresList;

    if (decoded is Map<String, dynamic> && decoded.containsKey('measures')) {
      measuresList = decoded['measures'] as List<dynamic>;
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

        beats.add(MeasureBeat(
          barIndex: bIdx,
          beatIndex: beatIdx,
          chord: chord,
          timeText: timeText,
          isContinue: isContinue,
        ));
      }

      result.add(MeasureRow(barNumber: barNum, beats: beats));
    }

    return result;
  }

  static String _defaultTimeText(int bIdx, int beatIdx) {
    final timeSec = (bIdx * 4 + beatIdx) * 0.5;
    final mins = (timeSec ~/ 60).toString().padLeft(2, '0');
    final secs = ((timeSec % 60).toInt()).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
