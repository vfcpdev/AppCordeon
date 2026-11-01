import 'dart:math' as math;

import 'package:xml/xml.dart';
import '../models/bass_rhythm_pattern.dart';

/// Importa patrones MusicXML a golpes secuenciales del panel de bajos.
///
/// {P}: el documento es MusicXML partwise válido, salvo por el evento de
/// pausa defectuoso que se reconoce explícitamente.
/// {Q}: cada nota no-pausa produce un golpe con índice 0..11 y tiempo en
/// negras; las pausas avanzan el reloj sin resaltar botones.
class MusicXmlRhythmImporter {
  static final RegExp _recoverableRest = RegExp(
    r'<note>\s*<pitch>\s*<step>[A-G]</node>\s*<rest>\s*(<duration>\d+</duration>\s*<voice>[^<]+</voice>\s*<type>[^<]+</type>\s*)</rest>',
  );

  BassRhythmImportSummary importPatterns(String content) {
    final recoveredMatches = _recoverableRest.allMatches(content).length;
    final normalizedContent = content.replaceAllMapped(
      _recoverableRest,
      (match) => '<note><rest/>${match[1]}</note>',
    );

    final XmlDocument document;
    try {
      document = XmlDocument.parse(normalizedContent);
    } on XmlParserException catch (error) {
      throw FormatException('El archivo no es un MusicXML válido: $error');
    }

    final root = document.rootElement;
    if (root.name.local != 'score-partwise') {
      throw const FormatException(
        'El archivo debe ser un MusicXML de tipo score-partwise.',
      );
    }

    final partNames = <String, String>{};
    final partList = _child(root, 'part-list');
    if (partList != null) {
      for (final scorePart in _children(partList, 'score-part')) {
        final id = scorePart.getAttribute('id');
        final name = _child(scorePart, 'part-name')?.innerText.trim();
        if (id != null && name != null && name.isNotEmpty) {
          partNames[id] = name;
        }
      }
    }

    final patterns = <BassRhythmPattern>[];
    for (final part in _children(root, 'part')) {
      final partId = part.getAttribute('id');
      if (partId == null || partId.isEmpty) continue;

      final partName = partNames[partId] ?? partId;
      var divisions = 1;
      var beatsPerMeasure = 4;
      var beatType = 4;
      double? quarterNotesPerMinute;

      for (final measure in _children(part, 'measure')) {
        final attributes = _child(measure, 'attributes');
        if (attributes != null) {
          final parsedDivisions = _integerChild(attributes, 'divisions');
          if (parsedDivisions != null && parsedDivisions > 0) {
            divisions = parsedDivisions;
          }
          final time = _child(attributes, 'time');
          final parsedBeats = time == null ? null : _integerChild(time, 'beats');
          final parsedBeatType =
              time == null ? null : _integerChild(time, 'beat-type');
          if (parsedBeats != null &&
              parsedBeatType != null &&
              parsedBeats > 0 &&
              parsedBeatType > 0) {
            beatsPerMeasure = parsedBeats;
            beatType = parsedBeatType;
          }
        }

        final measureWords = <String>[];
        for (final direction in _children(measure, 'direction')) {
          final sound = _child(direction, 'sound');
          final soundTempo = double.tryParse(
            sound?.getAttribute('tempo') ?? '',
          );
          if (soundTempo != null && soundTempo > 0) {
            quarterNotesPerMinute = soundTempo;
          } else {
            final metronome = _descendant(direction, 'metronome');
            final parsedTempo = _quarterNoteTempo(metronome);
            if (parsedTempo != null) {
              quarterNotesPerMinute = parsedTempo;
            }
          }
          for (final words in _descendants(direction, 'words')) {
            final value = words.innerText.trim();
            if (value.isNotEmpty) measureWords.add(value);
          }
        }

        var cursor = 0.0;
        var previousOnset = 0.0;
        var sourceOrder = 0;
        final pendingHits = <({double onset, double duration, int order})>[];
        for (final child in measure.children.whereType<XmlElement>()) {
          if (child.name.local == 'backup' ||
              child.name.local == 'forward') {
            final duration = _integerChild(child, 'duration');
            if (duration == null || duration < 0) {
              throw FormatException(
                'Duración inválida en ${partName}, compás ${measure.getAttribute('number') ?? '?'}.',
              );
            }
            final shift = duration / divisions;
            cursor += child.name.local == 'backup' ? -shift : shift;
            if (cursor < 0) cursor = 0;
            continue;
          }
          if (child.name.local != 'note') continue;

          final duration = _integerChild(child, 'duration');
          if (duration == null || duration <= 0) {
            throw FormatException(
              'Nota sin duración válida en ${partName}, compás ${measure.getAttribute('number') ?? '?'}.',
            );
          }

          final noteDuration = duration / divisions;
          final isChordTone = _child(child, 'chord') != null;
          final onset = isChordTone ? previousOnset : cursor;
          final isRest = _child(child, 'rest') != null;
          if (!isRest) {
            pendingHits.add((
              onset: onset,
              duration: noteDuration,
              order: sourceOrder++,
            ));
          }
          if (!isChordTone) {
            previousOnset = onset;
            cursor += noteDuration;
          }
        }

        pendingHits.sort((a, b) {
          final onsetOrder = a.onset.compareTo(b.onset);
          return onsetOrder == 0 ? a.order.compareTo(b.order) : onsetOrder;
        });
        final hits = <BassRhythmHit>[
          for (var index = 0; index < pendingHits.length; index++)
            BassRhythmHit(
              onsetQuarterBeats: pendingHits[index].onset,
              durationQuarterBeats: pendingHits[index].duration,
              buttonIndex: index % 12,
            ),
        ];
        if (hits.isEmpty) continue;

        final measureNumber =
            int.tryParse(measure.getAttribute('number') ?? '') ??
            patterns.length + 1;
        final measureDuration = math
            .max(cursor, beatsPerMeasure * 4 / beatType)
            .toDouble();
        patterns.add(
          BassRhythmPattern(
            id: '$partId:$measureNumber',
            name: measureWords.isEmpty
                ? '$partName · Compás $measureNumber'
                : measureWords.join(' · '),
            partName: partName,
            measureNumber: measureNumber,
            beatsPerMeasure: beatsPerMeasure,
            beatType: beatType,
            durationQuarterBeats: measureDuration,
            quarterNotesPerMinute: quarterNotesPerMinute,
            hits: hits,
          ),
        );
      }
    }

    if (patterns.isEmpty) {
      throw const FormatException(
        'No se encontraron notas rítmicas en las pistas del MusicXML.',
      );
    }
    return BassRhythmImportSummary(
      patterns: patterns,
      recoveredMalformedEvents: recoveredMatches,
    );
  }

  static double? _quarterNoteTempo(XmlElement? metronome) {
    if (metronome == null) return null;
    final perMinute = double.tryParse(
      _child(metronome, 'per-minute')?.innerText.trim() ?? '',
    );
    final beatUnit = _child(metronome, 'beat-unit')?.innerText.trim();
    if (perMinute == null || perMinute <= 0 || beatUnit == null) return null;

    const beatUnitLengths = <String, double>{
      'maxima': 32,
      'long': 16,
      'breve': 8,
      'whole': 4,
      'half': 2,
      'quarter': 1,
      'eighth': 0.5,
      '16th': 0.25,
      '32nd': 0.125,
      '64th': 0.0625,
      '128th': 0.03125,
    };
    var quarterNotesPerBeat = beatUnitLengths[beatUnit];
    if (quarterNotesPerBeat == null) return null;
    var dotValue = 0.5;
    for (final _ in _children(metronome, 'beat-unit-dot')) {
      quarterNotesPerBeat += quarterNotesPerBeat * dotValue;
      dotValue /= 2;
    }
    return perMinute * quarterNotesPerBeat;
  }

  static int? _integerChild(XmlElement element, String name) =>
      int.tryParse(_child(element, name)?.innerText.trim() ?? '');

  static XmlElement? _child(XmlElement element, String name) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local == name) return child;
    }
    return null;
  }

  static Iterable<XmlElement> _children(XmlElement element, String name) =>
      element.children
          .whereType<XmlElement>()
          .where((child) => child.name.local == name);

  static Iterable<XmlElement> _descendants(XmlElement element, String name) =>
      element.descendants
          .whereType<XmlElement>()
          .where((child) => child.name.local == name);

  static XmlElement? _descendant(XmlElement element, String name) {
    for (final descendant in _descendants(element, name)) {
      return descendant;
    }
    return null;
  }
}
