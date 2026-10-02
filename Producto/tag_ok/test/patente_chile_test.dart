import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/patente_chile.dart';

void main() {
  group('formatos válidos', () {
    for (final entrada in {
      'ABCD12': 'auto actual',
      'AB1234': 'auto antiguo',
      'ABC12': 'moto actual',
      'AB123': 'moto antigua',
    }.entries) {
      test('${entrada.key} (${entrada.value})', () {
        expect(esPatenteValida(normalizarPatente(entrada.key)), isTrue);
      });
    }
  });

  group('formatos inválidos', () {
    for (final patente in ['', 'A1', 'ABCDE1', 'ABCDEF', '123456', 'ABCD1', 'AB12345', 'A1234', 'ABC123', 'AB-12', 'ÑÑÑÑ12']) {
      test('"$patente"', () {
        expect(esPatenteValida(normalizarPatente(patente)), isFalse);
      });
    }
  });

  group('normalizarPatente', () {
    test('pasa a mayúsculas', () => expect(normalizarPatente('abcd12'), 'ABCD12'));
    test('quita guiones y espacios', () {
      expect(normalizarPatente('abcd-12'), 'ABCD12');
      expect(normalizarPatente(' AB 1234 '), 'AB1234');
    });
  });
}
