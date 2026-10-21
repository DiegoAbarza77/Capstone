import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehiculo_model.dart';

void main() {
  group('validarFechasDocumento', () {
    test('sin alguna de las fechas no hay error', () {
      expect(validarFechasDocumento(null, null), isNull);
      expect(validarFechasDocumento(DateTime(2026, 1, 1), null), isNull);
      expect(validarFechasDocumento(null, DateTime(2026, 1, 1)), isNull);
    });

    test('emisión anterior al vencimiento es válida', () {
      expect(validarFechasDocumento(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), isNull);
    });

    test('el mismo día es válido', () {
      expect(validarFechasDocumento(DateTime(2026, 5, 5, 23), DateTime(2026, 5, 5, 1)), isNull);
    });

    test('emisión posterior al vencimiento es un error', () {
      expect(validarFechasDocumento(DateTime(2027, 1, 2), DateTime(2027, 1, 1)), isNotNull);
    });
  });
}
