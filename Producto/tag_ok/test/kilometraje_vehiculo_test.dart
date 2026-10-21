import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/screens/vehiculo_edicion.dart';

void main() {
  group('kilometrajeMenorAlPrevio', () {
    test('menor al previo avisa', () => expect(kilometrajeMenorAlPrevio(50000, 49000), isTrue));
    test('igual o mayor no avisa', () {
      expect(kilometrajeMenorAlPrevio(50000, 50000), isFalse);
      expect(kilometrajeMenorAlPrevio(50000, 51000), isFalse);
    });
    test('sin dato previo o sin dato nuevo no avisa', () {
      expect(kilometrajeMenorAlPrevio(null, 100), isFalse);
      expect(kilometrajeMenorAlPrevio(100, null), isFalse);
    });
  });
}
