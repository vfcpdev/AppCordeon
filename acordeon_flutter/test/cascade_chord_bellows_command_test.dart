import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/constants/enums.dart';
import 'package:acordeon_flutter/domain/commands/accordion_commands.dart';
import 'package:acordeon_flutter/domain/models/measure_models.dart';

void main() {
  group('CascadeChordBellowsCommand Tests (SPEC-002)', () {
    late List<MeasureRow> testMeasures;

    setUp(() {
      testMeasures = [
        MeasureRow(
          barNumber: 1,
          beats: [
            const MeasureBeat(barIndex: 0, beatIndex: 0, chord: 'Do Mayor', bellows: BellowsMode.both),
            const MeasureBeat(barIndex: 0, beatIndex: 1, chord: 'Sol7', bellows: BellowsMode.both),
            const MeasureBeat(barIndex: 0, beatIndex: 2, chord: 'Do Mayor', bellows: BellowsMode.both),
            const MeasureBeat(barIndex: 0, beatIndex: 3, chord: '', bellows: BellowsMode.both),
          ],
        ),
        MeasureRow(
          barNumber: 2,
          beats: [
            const MeasureBeat(barIndex: 1, beatIndex: 0, chord: 'Do Mayor', bellows: BellowsMode.both),
            const MeasureBeat(barIndex: 1, beatIndex: 1, chord: 'Fa Mayor', bellows: BellowsMode.both),
            const MeasureBeat(barIndex: 1, beatIndex: 2, chord: 'Sol7', bellows: BellowsMode.both),
            const MeasureBeat(barIndex: 1, beatIndex: 3, chord: 'Do Mayor', bellows: BellowsMode.both),
          ],
        ),
      ];
    });

    test('Asignación individual (cascade: false) solo afecta la celda seleccionada', () {
      final command = CascadeChordBellowsCommand(
        measures: testMeasures,
        targetBarIndex: 0,
        targetBeatIndex: 0,
        newBellows: BellowsMode.pull,
        cascade: false,
      );

      final result = command.execute();

      // C1.1 cambió a pull
      expect(result[0].beats[0].bellows, equals(BellowsMode.pull));
      // C1.3 (también Do Mayor) debe seguir en both
      expect(result[0].beats[2].bellows, equals(BellowsMode.both));
      // C2.1 debe seguir en both
      expect(result[1].beats[0].bellows, equals(BellowsMode.both));
    });

    test('Asignación en cascada (cascade: true) actualiza todas las apariciones de ese acorde', () {
      final command = CascadeChordBellowsCommand(
        measures: testMeasures,
        targetBarIndex: 0,
        targetBeatIndex: 0,
        newBellows: BellowsMode.push,
        cascade: true,
      );

      final result = command.execute();

      // Todas las celdas con 'Do Mayor' deben ser push
      expect(result[0].beats[0].bellows, equals(BellowsMode.push)); // C1.1
      expect(result[0].beats[2].bellows, equals(BellowsMode.push)); // C1.3
      expect(result[1].beats[0].bellows, equals(BellowsMode.push)); // C2.1
      expect(result[1].beats[3].bellows, equals(BellowsMode.push)); // C2.4

      // Celdas con otros acordes permanecen invariantes
      expect(result[0].beats[1].bellows, equals(BellowsMode.both)); // Sol7
      expect(result[1].beats[1].bellows, equals(BellowsMode.both)); // Fa Mayor
      expect(result[1].beats[2].bellows, equals(BellowsMode.both)); // Sol7
      expect(result[0].beats[3].bellows, equals(BellowsMode.both)); // Vacía
    });

    test('Lanza PreconditionViolationException si la celda no tiene acorde', () {
      final command = CascadeChordBellowsCommand(
        measures: testMeasures,
        targetBarIndex: 0,
        targetBeatIndex: 3, // Celda vacía
        newBellows: BellowsMode.push,
        cascade: true,
      );

      expect(() => command.execute(), throwsA(isA<PreconditionViolationException>()));
    });
  });
}
