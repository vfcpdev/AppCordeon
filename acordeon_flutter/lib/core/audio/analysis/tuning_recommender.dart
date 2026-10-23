/// Recomendador de afinación vallenata para acordeón diatónico según la tónica detectada.
class TuningRecommender {
  static const List<int> rowBaseTonics = [3, 8, 1]; // Eb, Ab, Db en Cinco Letras

  const TuningRecommender();

  (String name, int offset, String row) recommend(int rootMod) {
    const tunings = [
      ('Cinco Letras (Bb-Eb-Ab)', 10),
      ('Rey Vallenato (Bb-Eb-Ab)', 7),
      ('ADG (La-Re-Sol)', 9),
      ('Do-Fa-Si♭ (C-F-Bb)', 0),
    ];

    for (final t in tunings) {
      final r1 = (rowBaseTonics[0] + t.$2) % 12;
      final r2 = (rowBaseTonics[1] + t.$2) % 12;
      final r3 = (rowBaseTonics[2] + t.$2) % 12;

      if (rootMod == r2) return (t.$1, t.$2, 'row2');
      if (rootMod == r1) return (t.$1, t.$2, 'row1');
      if (rootMod == r3) return (t.$1, t.$2, 'row3');
    }

    return ('Cinco Letras (Bb-Eb-Ab)', 10, 'row2');
  }
}
