import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/usuarios_filtros_logica.dart';

void main() {
  final activa = {'id': 'a', 'estado': 'activo'};
  final suspendida = {'id': 'b', 'estado': 'suspendido'};
  final antigua = {'id': 'c'}; // cuenta sin el campo estado

  group('coincideEstado', () {
    test('"todos" deja pasar todas las cuentas', () {
      for (final u in [activa, suspendida, antigua]) {
        expect(coincideEstado(u, FiltroEstado.todos), isTrue);
      }
    });

    test('"activas" excluye solo a las suspendidas', () {
      expect(coincideEstado(activa, FiltroEstado.activas), isTrue);
      expect(coincideEstado(antigua, FiltroEstado.activas), isTrue);
      expect(coincideEstado(suspendida, FiltroEstado.activas), isFalse);
    });

    test('"suspendidas" deja pasar solo a las suspendidas', () {
      expect(coincideEstado(suspendida, FiltroEstado.suspendidas), isTrue);
      expect(coincideEstado(activa, FiltroEstado.suspendidas), isFalse);
      expect(coincideEstado(antigua, FiltroEstado.suspendidas), isFalse);
    });

    test('cada cuenta está en exactamente una de las dos listas', () {
      final cuentas = [activa, suspendida, antigua];
      final activas = cuentas.where((u) => coincideEstado(u, FiltroEstado.activas)).length;
      final suspendidas = cuentas.where((u) => coincideEstado(u, FiltroEstado.suspendidas)).length;
      expect(activas + suspendidas, cuentas.length);
    });
  });

  test('las etiquetas están en español', () {
    expect(etiquetaFiltroEstado(FiltroEstado.todos), 'Todos los estados');
    expect(etiquetaFiltroEstado(FiltroEstado.activas), 'Activas');
    expect(etiquetaFiltroEstado(FiltroEstado.suspendidas), 'Suspendidas');
  });
}
