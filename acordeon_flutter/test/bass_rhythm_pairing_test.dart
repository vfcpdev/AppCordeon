import 'package:acordeon_flutter/domain/services/bass_rhythm_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parejas de bajos del catálogo', () {
    test('cada golpe toca bajo y acorde con índice y dedo medio', () {
      for (final pattern in BassRhythmCatalog.patterns) {
        for (final hit in pattern.hits) {
          expect(hit.pairedButtonIndex, isNotNull);
          expect(hit.pairedButtonIndex, isNot(hit.buttonIndex));
          expect(
            (hit.buttonIndex - hit.pairedButtonIndex!).abs(),
            1,
            reason:
                '${pattern.id} debe emparejar bajo y acorde de la misma nota',
          );
          expect(hit.fingerNumber, 2);
          expect(hit.pairedFingerNumber, 3);
          expect(hit.buttonIndexes, hasLength(2));
          expect(hit.fingerNumberFor(hit.buttonIndex), 2);
          expect(hit.fingerNumberFor(hit.pairedButtonIndex!), 3);
        }
      }
    });

    test(
      'las parejas alternan exterior 1-2, interior 1-2, exterior 3-4...',
      () {
        final hits = BassRhythmCatalog.patterns
            .firstWhere((pattern) => pattern.id == 'builtin:paseo')
            .hits;

        expect(hits.map((hit) => hit.buttonIndex), [1, 7, 3, 9, 5]);
        expect(hits.map((hit) => hit.pairedButtonIndex), [0, 6, 2, 8, 4]);
      },
    );
  });
}
