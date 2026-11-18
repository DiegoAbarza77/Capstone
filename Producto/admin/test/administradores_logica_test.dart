import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/administradores_logica.dart';

void main() {
  group('idsDeAdministradores', () {
    test('toma el id de cada fila', () {
      final ids = idsDeAdministradores([
        {'id': 'a', 'email': 'a@x.cl', 'rol': 'super_admin'},
        {'id': 'b', 'email': 'b@x.cl', 'rol': 'operador'},
      ]);
      expect(ids, {'a', 'b'});
    });

    test('ignora filas sin id o con id vacío', () {
      final ids = idsDeAdministradores([
        {'email': 'a@x.cl'},
        {'id': null},
        {'id': ''},
        {'id': 'c'},
      ]);
      expect(ids, {'c'});
    });

    test('lista vacía da conjunto vacío', () {
      expect(idsDeAdministradores([]), isEmpty);
    });
  });

  group('sinAdministradores', () {
    final usuarios = [
      {'id': '1', 'nombre_mostrar': 'Ana'},
      {'id': '2', 'nombre_mostrar': 'Sin nombre'},
      {'id': '3', 'nombre_mostrar': 'Luis'},
    ];

    test('quita a los administradores', () {
      final r = sinAdministradores(usuarios, {'2'});
      expect(r.map((f) => f['id']), ['1', '3']);
    });

    test('sin administradores devuelve todo igual', () {
      expect(sinAdministradores(usuarios, {}), usuarios);
    });

    test('un administrador que no está en la lista no cambia nada', () {
      expect(sinAdministradores(usuarios, {'99'}).length, 3);
    });

    test('si todos son administradores queda vacío', () {
      expect(sinAdministradores(usuarios, {'1', '2', '3'}), isEmpty);
    });

    test('compara ids aunque vengan como número', () {
      final r = sinAdministradores([
        {'id': 7},
        {'id': 8},
      ], {'7'});
      expect(r.map((f) => f['id']), [8]);
    });
  });

  group('conductoresTotales', () {
    test('resta los administradores', () {
      expect(conductoresTotales(6, 1), 5);
    });

    test('sin administradores no cambia', () {
      expect(conductoresTotales(6, 0), 6);
    });

    test('nunca es negativo', () {
      expect(conductoresTotales(1, 3), 0);
    });
  });
}
