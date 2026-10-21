import '../../core/constants/enums.dart';

/// Modelo de un botón físico del diapasón melódico.
class TrebleButtonModel {
  final String id;
  final String rowKey; // 'row1', 'row2', 'row3'
  final int btnIndex; // 1..10 o 1..11
  final int push; // Nota MIDI cerrando fuelle
  final int pull; // Nota MIDI abriendo fuelle

  const TrebleButtonModel({
    required this.id,
    required this.rowKey,
    required this.btnIndex,
    required this.push,
    required this.pull,
  });

  TrebleButtonModel transpose(int offset) {
    return TrebleButtonModel(
      id: id,
      rowKey: rowKey,
      btnIndex: btnIndex,
      push: push + offset,
      pull: pull + offset,
    );
  }
}

/// Modelo de un botón del panel de bajos (fundamental o acorde).
class BassButtonModel {
  final String id;
  final ButtonType type; // fundamental o chord
  final int btnIndex; // 1..6
  final String label;
  final List<int> pushNotes;
  final List<int> pullNotes;
  final String namePush;
  final String namePull;

  const BassButtonModel({
    required this.id,
    required this.type,
    required this.btnIndex,
    required this.label,
    required this.pushNotes,
    required this.pullNotes,
    required this.namePush,
    required this.namePull,
  });

  BassButtonModel transpose(int offset) {
    return BassButtonModel(
      id: id,
      type: type,
      btnIndex: btnIndex,
      label: label,
      pushNotes: pushNotes.map((n) => n + offset).toList(),
      pullNotes: pullNotes.map((n) => n + offset).toList(),
      namePush: namePush,
      namePull: namePull,
    );
  }
}

/// Base de datos física del acordeón vallenato en afinación Cinco Letras (Bb - Eb - Ab).
class AccordionData {
  static const Map<String, List<Map<String, int>>> baseCincoLetrasTreble = {
    'row1': [
      {'p': 64, 'pl': 66}, // B1: Mi4, Sol♭4
      {'p': 58, 'pl': 60}, // B2: Si♭3, Do4
      {'p': 62, 'pl': 63}, // B3: Re4, Mi♭4
      {'p': 65, 'pl': 67}, // B4: Fa4, Sol4
      {'p': 70, 'pl': 69}, // B5: Si♭4, La4
      {'p': 74, 'pl': 72}, // B6: Re5, Do5
      {'p': 77, 'pl': 75}, // B7: Fa5, Mi♭5
      {'p': 82, 'pl': 79}, // B8: Si♭5, Sol5
      {'p': 86, 'pl': 81}, // B9: Re6, La5
      {'p': 89, 'pl': 84}, // B10: Fa6, Do6
    ],
    'row2': [
      {'p': 57, 'pl': 59}, // B1: La3, Si3
      {'p': 58, 'pl': 62}, // B2: Si♭3, Re4
      {'p': 63, 'pl': 65}, // B3: Mi♭4, Fa4
      {'p': 67, 'pl': 68}, // B4: Sol4, La♭4
      {'p': 70, 'pl': 72}, // B5: Si♭4, Do5
      {'p': 75, 'pl': 74}, // B6: Mi♭5, Re5
      {'p': 79, 'pl': 77}, // B7: Sol5, Fa5
      {'p': 82, 'pl': 80}, // B8: Si♭5, La♭5
      {'p': 87, 'pl': 84}, // B9: Mi♭6, Do6
      {'p': 91, 'pl': 86}, // B10: Sol6, Re6
      {'p': 94, 'pl': 89}, // B11: Si♭6, Fa6
    ],
    'row3': [
      {'p': 66, 'pl': 64}, // B1: Sol♭4, Mi4
      {'p': 63, 'pl': 67}, // B2: Mi♭4, Sol4
      {'p': 68, 'pl': 70}, // B3: La♭4, Si♭4
      {'p': 72, 'pl': 73}, // B4: Do5, Re♭5
      {'p': 75, 'pl': 77}, // B5: Mi♭5, Fa5
      {'p': 80, 'pl': 79}, // B6: La♭5, Sol5
      {'p': 84, 'pl': 82}, // B7: Do6, Si♭5
      {'p': 87, 'pl': 85}, // B8: Mi♭6, Re♭6
      {'p': 92, 'pl': 89}, // B9: La♭6, Fa6
      {'p': 96, 'pl': 91}, // B10: Do7, Sol6
    ],
  };

  static const List<BassButtonModel> baseCincoLetrasBass = [
    BassButtonModel(
      id: 'bass_1',
      type: ButtonType.fundamental,
      btnIndex: 1,
      label: 'Bajo 1 (Bb/F)',
      pushNotes: [46],
      pullNotes: [41],
      namePush: 'Bb',
      namePull: 'F',
    ),
    BassButtonModel(
      id: 'chord_1',
      type: ButtonType.chord,
      btnIndex: 1,
      label: 'Acorde 1 (Bb/F)',
      pushNotes: [58, 62, 65],
      pullNotes: [53, 57, 60],
      namePush: 'Bb Maj',
      namePull: 'F Maj',
    ),
    BassButtonModel(
      id: 'bass_2',
      type: ButtonType.fundamental,
      btnIndex: 2,
      label: 'Bajo 2 (G/C)',
      pushNotes: [43],
      pullNotes: [48],
      namePush: 'G',
      namePull: 'C',
    ),
    BassButtonModel(
      id: 'chord_2',
      type: ButtonType.chord,
      btnIndex: 2,
      label: 'Acorde 2 (G/Cm)',
      pushNotes: [55, 59, 62],
      pullNotes: [60, 63, 67],
      namePush: 'G Maj',
      namePull: 'C min',
    ),
    BassButtonModel(
      id: 'bass_3',
      type: ButtonType.fundamental,
      btnIndex: 3,
      label: 'Bajo 3 (Eb/Bb)',
      pushNotes: [51],
      pullNotes: [46],
      namePush: 'Eb',
      namePull: 'Bb',
    ),
    BassButtonModel(
      id: 'chord_3',
      type: ButtonType.chord,
      btnIndex: 3,
      label: 'Acorde 3 (Eb/Bb)',
      pushNotes: [63, 67, 70],
      pullNotes: [58, 62, 65],
      namePush: 'Eb Maj',
      namePull: 'Bb Maj',
    ),
    BassButtonModel(
      id: 'bass_4',
      type: ButtonType.fundamental,
      btnIndex: 4,
      label: 'Bajo 4 (C/F)',
      pushNotes: [48],
      pullNotes: [41],
      namePush: 'C',
      namePull: 'F',
    ),
    BassButtonModel(
      id: 'chord_4',
      type: ButtonType.chord,
      btnIndex: 4,
      label: 'Acorde 4 (C/Fm)',
      pushNotes: [60, 64, 67],
      pullNotes: [53, 56, 60],
      namePush: 'C Maj',
      namePull: 'F min',
    ),
    BassButtonModel(
      id: 'bass_5',
      type: ButtonType.fundamental,
      btnIndex: 5,
      label: 'Bajo 5 (Ab/Eb)',
      pushNotes: [44],
      pullNotes: [51],
      namePush: 'Ab',
      namePull: 'Eb',
    ),
    BassButtonModel(
      id: 'chord_5',
      type: ButtonType.chord,
      btnIndex: 5,
      label: 'Acorde 5 (Ab/Eb)',
      pushNotes: [56, 60, 63],
      pullNotes: [63, 67, 70],
      namePush: 'Ab Maj',
      namePull: 'Eb Maj',
    ),
    BassButtonModel(
      id: 'bass_6',
      type: ButtonType.fundamental,
      btnIndex: 6,
      label: 'Bajo 6 (Db/Db)',
      pushNotes: [49],
      pullNotes: [49],
      namePush: 'Db',
      namePull: 'Db',
    ),
    BassButtonModel(
      id: 'chord_6',
      type: ButtonType.chord,
      btnIndex: 6,
      label: 'Acorde 6 (Db/Db)',
      pushNotes: [61, 65, 68],
      pullNotes: [61, 65, 68],
      namePush: 'Db Maj',
      namePull: 'Db Maj',
    ),
  ];

  static Map<String, List<TrebleButtonModel>> getTransposedTreble([int offset = 0]) {
    final Map<String, List<TrebleButtonModel>> result = {};
    for (final entry in baseCincoLetrasTreble.entries) {
      final rowKey = entry.key;
      result[rowKey] = entry.value.asMap().entries.map((item) {
        final index = item.key;
        final map = item.value;
        return TrebleButtonModel(
          id: '${rowKey}_$index',
          rowKey: rowKey,
          btnIndex: index + 1,
          push: map['p']! + offset,
          pull: map['pl']! + offset,
        );
      }).toList();
    }
    return result;
  }

  static List<BassButtonModel> getTransposedBasses([int offset = 0]) {
    return baseCincoLetrasBass.map((b) => b.transpose(offset)).toList();
  }
}
