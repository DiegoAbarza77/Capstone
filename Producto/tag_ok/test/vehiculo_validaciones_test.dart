import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tag_ok/screens/vehiculo_edicion.dart';

void main() {
  group('validarAnioVehiculo', () {
    test('vacío es válido (el año es opcional)', () => expect(validarAnioVehiculo(''), isNull));
    test('un año razonable es válido', () => expect(validarAnioVehiculo('2019'), isNull));
    test('el año que viene es válido', () {
      expect(validarAnioVehiculo('${DateTime.now().year + 1}'), isNull);
    });
    test('muy antiguo es inválido', () => expect(validarAnioVehiculo('1800'), isNotNull));
    test('en el futuro lejano es inválido', () => expect(validarAnioVehiculo('2999'), isNotNull));
    test('cero es inválido', () => expect(validarAnioVehiculo('0'), isNotNull));
  });

  group('mensajeErrorVehiculo', () {
    test('patente repetida', () {
      final e = PostgrestException(message: 'duplicate key value', code: '23505');
      expect(mensajeErrorVehiculo(e), 'Ya tienes un vehículo con esa patente.');
    });

    test('sin permiso', () {
      final e = PostgrestException(message: 'rls', code: '42501');
      expect(mensajeErrorVehiculo(e), 'No tienes permiso para hacer esto.');
    });

    test('sin conexión', () {
      expect(
        mensajeErrorVehiculo(Exception('ClientException: Failed to fetch')),
        contains('Revisa tu conexión'),
      );
    });

    test('error desconocido no expone la excepción técnica', () {
      final mensaje = mensajeErrorVehiculo(Exception('algo muy técnico xyz'));
      expect(mensaje, isNot(contains('xyz')));
    });
  });
}
