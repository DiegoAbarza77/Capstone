import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/numero_chile.dart';

void main() {
  pruebasMiles();

  group('parseNumeroChile', () {
    test('números y textos simples', () {
      expect(parseNumeroChile(32.5), 32.5);
      expect(parseNumeroChile('40'), 40);
      expect(parseNumeroChile('32,5'), 32.5);
      expect(parseNumeroChile('32.5'), 32.5);
    });

    test('vacío, nulo o basura dan null', () {
      expect(parseNumeroChile(null), isNull);
      expect(parseNumeroChile(''), isNull);
      expect(parseNumeroChile('abc'), isNull);
    });

    test('con coma y punto, el último separador es el decimal', () {
      expect(parseNumeroChile('1.234,5'), 1234.5);
      expect(parseNumeroChile('1,234.5'), 1234.5);
    });

    test('un punto con tres dígitos es decimal salvo que se pida miles', () {
      expect(parseNumeroChile('32.500'), 32.5);
      expect(parseNumeroChile('45.000', puntoEsMiles: true), 45000);
      expect(parseNumeroChile(r'$ 1.234.567', puntoEsMiles: true), 1234567);
    });

    test('con puntoEsMiles, un decimal normal se respeta', () {
      expect(parseNumeroChile('32.5', puntoEsMiles: true), 32.5);
    });
  });

  group('formatos', () {
    test('formatoPesos agrupa los miles con punto', () {
      expect(formatoPesos(43875), r'$43.875');
      expect(formatoPesos(0), r'$0');
      expect(formatoPesos(1234567.4), r'$1.234.567');
    });

    test('formatoCantidad omite decimales innecesarios', () {
      expect(formatoCantidad(40), '40');
      expect(formatoCantidad(32.5), '32,5');
    });
  });
}

void pruebasMiles() {
  group('formatearMiles', () {
    test('agrupa de a tres con punto', () {
      expect(formatearMiles(129900), '129.900');
      expect(formatearMiles(78500), '78.500');
      expect(formatearMiles(1234567), '1.234.567');
      expect(formatearMiles(999), '999');
      expect(formatearMiles(0), '0');
    });

    test('ignora lo que no son dígitos y los ceros de más', () {
      expect(formatearMiles('1.234'), '1.234');
      expect(formatearMiles('007'), '7');
      expect(formatearMiles('abc'), '');
    });
  });

  group('MilesInputFormatter', () {
    TextEditingValue escribir(String texto) =>
        MilesInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: texto));

    test('da formato mientras se escribe y deja el cursor al final', () {
      final v = escribir('129900');
      expect(v.text, '129.900');
      expect(v.selection.baseOffset, 7);
    });

    test('rechaza letras y símbolos', () {
      expect(escribir('12a3b').text, '123');
      expect(escribir(r'$ 45.000').text, '45.000');
    });

    test('vacío queda vacío', () => expect(escribir('').text, ''));

    test('limita el largo', () => expect(escribir('1' * 20).text.replaceAll('.', '').length, 12));

    test('lo escrito se puede leer de vuelta como número', () {
      expect(parseNumeroChile(escribir('129900').text, puntoEsMiles: true), 129900);
      expect(parseNumeroChile(escribir('78500').text, puntoEsMiles: true), 78500);
      expect(parseNumeroChile(escribir('1234567').text, puntoEsMiles: true), 1234567);
    });
  });
}
