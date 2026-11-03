import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/presentation/controllers/subcontrollers/accordion_transport_controller.dart';

void main() {
  group('AccordionTransportController Tests (SPEC-001)', () {
    late AccordionTransportController controller;

    setUp(() {
      controller = AccordionTransportController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Inicia en estado detenido (isPlaying == false)', () {
      expect(controller.isPlaying, isFalse);
    });

    test('startLoop activa isPlaying y stopLoop lo desactiva', () {
      var stateChangedCount = 0;
      controller.attach(onStateChanged: () {
        stateChangedCount++;
      });

      controller.startLoop(
        bpm: 120,
        totalBeats: 4,
        onTick: (nextIndex) {},
      );

      expect(controller.isPlaying, isTrue);

      controller.stopLoop();
      expect(controller.isPlaying, isFalse);
      expect(stateChangedCount, greaterThan(0));
    });

    test('createClock produce instancia con invariantes correctos', () {
      final clock = controller.createClock(bpm: 120.0, durationQuarterBeats: 4.0);
      expect(clock.bpm, equals(120.0));
      expect(clock.durationQuarterBeats, equals(4.0));
      expect(clock.positionAtMicroseconds(500000), equals(1.0)); // 0.5s a 120 BPM = 1 negra
    });
  });
}
