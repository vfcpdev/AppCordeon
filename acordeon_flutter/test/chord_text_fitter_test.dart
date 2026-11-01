import 'package:flutter_test/flutter_test.dart';
import 'package:acordeon_flutter/core/text/chord_text_fitter.dart';

void main() {
  group('ChordTextFitter - Triplas de Hoare {P} C {Q} para el ajuste del acorde', () {
    const base = 10.0;
    const min = 6.0;

    test('{Q}: el tamaño resultante nunca excede baseFontSize y es positivo', () {
      final result = ChordTextFitter.fitFontSize(
        text: 'Do',
        availableWidth: 200,
        baseFontSize: base,
        minFontSize: min,
        horizontalPadding: 8,
      );
      expect(result, greaterThan(0));
      expect(result, lessThanOrEqualTo(base));
      // Texto corto en celda amplia: se usa el tamaño base
      expect(result, base);
    });

    test('{Q}: el texto estimado cabe en el ancho disponible', () {
      const text = 'Dom7b5';
      const available = 60.0;
      const padding = 8.0;
      final result = ChordTextFitter.fitFontSize(
        text: text,
        availableWidth: available,
        baseFontSize: base,
        minFontSize: min,
        horizontalPadding: padding,
      );
      final estimated = text.trim().length *
          ChordTextFitter.defaultCharWidthFactor *
          result +
          padding;
      // {Q}: si result > min, cabe; en el peor caso se usa la cota mínima
      expect(result <= available / (1 * 0.62) + 1.0, isTrue);
      expect(estimated <= available || result == min, isTrue);
    });

    test('Monotonía: textos más largos no obtienen tamaños mayores', () {
      final short = ChordTextFitter.fitFontSize(
        text: 'Do',
        availableWidth: 40,
        baseFontSize: base,
        minFontSize: min,
        horizontalPadding: 8,
      );
      final medium = ChordTextFitter.fitFontSize(
        text: 'Dom7',
        availableWidth: 40,
        baseFontSize: base,
        minFontSize: min,
        horizontalPadding: 8,
      );
      final long = ChordTextFitter.fitFontSize(
        text: 'Dom7b5/Sol',
        availableWidth: 40,
        baseFontSize: base,
        minFontSize: min,
        horizontalPadding: 8,
      );
      expect(short >= medium, isTrue);
      expect(medium >= long, isTrue);
    });

    test('{Q}: textos que no caben de ninguna forma usan la cota mínima', () {
      final result = ChordTextFitter.fitFontSize(
        text: 'Dom7b5/Sol',
        availableWidth: 30,
        baseFontSize: base,
        minFontSize: min,
        horizontalPadding: 8,
      );
      expect(result, min);
    });

    test('{P}: violada con ancho no positivo', () {
      expect(
        () => ChordTextFitter.fitFontSize(
          text: 'Do',
          availableWidth: 0,
          baseFontSize: base,
          minFontSize: min,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('{P}: violada con minFontSize fuera de rango', () {
      expect(
        () => ChordTextFitter.fitFontSize(
          text: 'Do',
          availableWidth: 100,
          baseFontSize: base,
          minFontSize: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
