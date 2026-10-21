import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/consulta_periodica.dart';

void main() {
  group('consultaPeriodica', () {
    test('consulta al abrir y entrega el resultado', () async {
      final flujo = consultaPeriodica<int>(() async => 1, cada: const Duration(hours: 1));
      expect(await flujo.first, 1);
    });

    test('vuelve a consultar de inmediato cuando se avisa de un cambio', () async {
      var valor = 1;
      final aviso = AvisoDeCambios();
      final flujo = consultaPeriodica<int>(() async => valor, cada: const Duration(hours: 1), alCambiar: aviso);
      final recibidos = <int>[];
      final sub = flujo.listen(recibidos.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      valor = 2;
      aviso.avisar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(recibidos, [1, 2]);
    });

    test('un cambio que llega mientras se consulta provoca otra consulta', () async {
      var valor = 1;
      final aviso = AvisoDeCambios();
      final flujo = consultaPeriodica<int>(() async {
        final leido = valor;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return leido;
      }, cada: const Duration(hours: 1), alCambiar: aviso);
      final recibidos = <int>[];
      final sub = flujo.listen(recibidos.add);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      valor = 2;
      aviso.avisar();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await sub.cancel();

      expect(recibidos.last, 2);
    });

    test('refresca solo cada cierto tiempo', () async {
      var cuenta = 0;
      final flujo = consultaPeriodica<int>(() async => ++cuenta, cada: const Duration(milliseconds: 30));
      final recibidos = <int>[];
      final sub = flujo.listen(recibidos.add);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await sub.cancel();

      expect(recibidos.length, greaterThanOrEqualTo(3));
    });

    test('si falla antes de recibir datos, el error llega al flujo', () async {
      final flujo = consultaPeriodica<int>(() async => throw Exception('sin red'), cada: const Duration(hours: 1));
      expect(flujo, emitsError(isA<Exception>()));
    });

    test('si falla después de recibir datos, conserva lo último y no emite error', () async {
      var falla = false;
      final aviso = AvisoDeCambios();
      final flujo = consultaPeriodica<int>(() async {
        if (falla) throw Exception('sin red');
        return 7;
      }, cada: const Duration(hours: 1), alCambiar: aviso);
      final recibidos = <int>[];
      final errores = <Object>[];
      final sub = flujo.listen(recibidos.add, onError: errores.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      falla = true;
      aviso.avisar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(recibidos, [7]);
      expect(errores, isEmpty);
    });
  });
}
