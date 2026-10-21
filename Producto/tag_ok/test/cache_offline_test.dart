import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_ok/data/services/cache_offline.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CacheOffline.datosGuardadosDesde.value = null;
  });

  const filasEjemplo = [
    {'id': '1', 'total': 45000, 'servicios': ['a', 'b']},
  ];

  test('los datos en vivo pasan y quedan guardados', () async {
    final origen = StreamController<List<Map<String, dynamic>>>();
    final recibidos = <List<Map<String, dynamic>>>[];
    final sub = CacheOffline.filas('prueba', origen.stream, usuarioId: 'u1').listen(recibidos.add);

    origen.add([...filasEjemplo]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recibidos.single.single['total'], 45000);
    expect(CacheOffline.datosGuardadosDesde.value, isNull);

    await sub.cancel();
    await origen.close();
  });

  test('si el flujo falla, entrega la última copia guardada y marca su fecha', () async {
    final primero = StreamController<List<Map<String, dynamic>>>();
    final s1 = CacheOffline.filas('prueba', primero.stream, usuarioId: 'u1').listen((_) {});
    primero.add([...filasEjemplo]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s1.cancel();

    // Se abre de nuevo sin conexión: el flujo falla.
    final caido = StreamController<List<Map<String, dynamic>>>();
    final recibidos = <List<Map<String, dynamic>>>[];
    final s2 = CacheOffline.filas('prueba', caido.stream, usuarioId: 'u1').listen(recibidos.add);
    caido.addError(Exception('sin red'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(recibidos.single.single['id'], '1');
    expect(recibidos.single.single['servicios'], ['a', 'b']);
    expect(CacheOffline.datosGuardadosDesde.value, isNotNull);

    // Al volver la conexión llegan datos nuevos y se quita el aviso.
    caido.add([
      {'id': '2'},
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recibidos.last.single['id'], '2');
    expect(CacheOffline.datosGuardadosDesde.value, isNull);

    await s2.cancel();
    await caido.close();
  });

  test('si el flujo no responde a tiempo, muestra la copia', () async {
    final primero = StreamController<List<Map<String, dynamic>>>();
    final s1 = CacheOffline.filas('prueba', primero.stream, usuarioId: 'u1').listen((_) {});
    primero.add([...filasEjemplo]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s1.cancel();

    final mudo = StreamController<List<Map<String, dynamic>>>();
    final recibidos = <List<Map<String, dynamic>>>[];
    final s2 = CacheOffline.filas('prueba', mudo.stream, usuarioId: 'u1', espera: const Duration(milliseconds: 50))
        .listen(recibidos.add);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(recibidos, hasLength(1));
    expect(CacheOffline.datosGuardadosDesde.value, isNotNull);

    await s2.cancel();
    await mudo.close();
  });

  test('sin copia, el error llega igual que antes', () async {
    final caido = StreamController<List<Map<String, dynamic>>>();
    final errores = <Object>[];
    final s = CacheOffline.filas('otra', caido.stream, usuarioId: 'u1').listen((_) {}, onError: errores.add);
    caido.addError(Exception('sin red'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(errores, hasLength(1));
    await s.cancel();
    await caido.close();
  });

  test('la copia de un usuario no se ve en otro', () async {
    final origen = StreamController<List<Map<String, dynamic>>>();
    final s1 = CacheOffline.filas('prueba', origen.stream, usuarioId: 'u1').listen((_) {});
    origen.add([...filasEjemplo]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s1.cancel();

    final caido = StreamController<List<Map<String, dynamic>>>();
    final errores = <Object>[];
    final s2 = CacheOffline.filas('prueba', caido.stream, usuarioId: 'u2').listen((_) {}, onError: errores.add);
    caido.addError(Exception('sin red'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(errores, hasLength(1));
    await s2.cancel();
  });

  test('limpiar borra todas las copias', () async {
    final origen = StreamController<List<Map<String, dynamic>>>();
    final s1 = CacheOffline.filas('prueba', origen.stream, usuarioId: 'u1').listen((_) {});
    origen.add([...filasEjemplo]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await s1.cancel();

    await CacheOffline.limpiar();

    final caido = StreamController<List<Map<String, dynamic>>>();
    final errores = <Object>[];
    final s2 = CacheOffline.filas('prueba', caido.stream, usuarioId: 'u1').listen((_) {}, onError: errores.add);
    caido.addError(Exception('sin red'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(errores, hasLength(1));
    await s2.cancel();
  });
}
