import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/metricas_logica.dart';

String d(int a, int m, int dia) => DateTime(a, m, dia, 12).toIso8601String();

void main() {
  pruebasFormato();

  final desde = DateTime(2026, 9, 1);
  final hasta = DateTime(2026, 10, 31);

  group('calcularMetricas', () {
    test('sin datos todo es cero y no falla', () {
      final m = calcularMetricas(const FilasMetricas(usuariosTotales: 0, vehiculosTotales: 0), desde: desde, hasta: hasta);
      expect(m.usuariosActivos, 0);
      expect(m.iaTotal, 0);
      expect(m.registrosTotal, 0);
      expect(m.gastoTotal, 0);
      expect(m.crecimiento.length, 2); // septiembre y octubre
    });

    test('usuarios y vehículos: totales y nuevos del período', () {
      final f = FilasMetricas(
        usuariosTotales: 50,
        vehiculosTotales: 30,
        usuarios: [
          {'fecha_creacion': d(2026, 9, 3)},
          {'fecha_creacion': d(2026, 10, 10)},
          {'fecha_creacion': d(2026, 8, 31)}, // antes del período
        ],
        vehiculos: [
          {'id': 'v1', 'usuario_id': 'u1', 'created_at': d(2026, 9, 5)},
          {'id': 'v2', 'usuario_id': 'u2', 'created_at': d(2026, 1, 5)}, // antiguo
        ],
      );
      final m = calcularMetricas(f, desde: desde, hasta: hasta);
      expect(m.usuariosTotales, 50);
      expect(m.usuariosNuevos, 2);
      expect(m.vehiculosTotales, 30);
      expect(m.vehiculosNuevos, 1);
    });

    test('usuarios activos: cuenta cada usuario una vez, aunque haga muchas cosas', () {
      final f = FilasMetricas(
        usuariosTotales: 10,
        vehiculosTotales: 3,
        vehiculos: [
          {'id': 'v1', 'usuario_id': 'u3', 'created_at': d(2025, 1, 1)},
        ],
        viajes: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 2), 'total_cost': 1000},
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 3), 'total_cost': 1000},
        ],
        cargas: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 4), 'total': 30000, 'origen': 'manual'},
          {'usuario_id': 'u2', 'created_at': d(2026, 9, 4), 'total': 20000, 'origen': 'manual'},
        ],
        // Un documento solo trae el vehículo: su dueño u3 también está activo.
        documentos: [
          {'vehiculo_id': 'v1', 'fecha_actualizacion': d(2026, 9, 6), 'origen': 'manual'},
        ],
      );
      expect(calcularMetricas(f, desde: desde, hasta: hasta).usuariosActivos, 3);
    });

    test('la actividad fuera del período no cuenta', () {
      final f = FilasMetricas(
        usuariosTotales: 1,
        vehiculosTotales: 0,
        viajes: [
          {'usuario_id': 'u1', 'created_at': d(2026, 8, 31), 'total_cost': 500},
          {'usuario_id': 'u2', 'created_at': d(2026, 11, 1), 'total_cost': 500},
        ],
      );
      final m = calcularMetricas(f, desde: desde, hasta: hasta);
      expect(m.usuariosActivos, 0);
      expect(m.registrosTotal, 0);
      expect(m.gastoTotal, 0);
    });

    test('los días de inicio y término del período se incluyen completos', () {
      final f = FilasMetricas(
        usuariosTotales: 2,
        vehiculosTotales: 0,
        viajes: [
          {'usuario_id': 'u1', 'created_at': DateTime(2026, 9, 1, 0, 0, 1).toIso8601String(), 'total_cost': 1},
          {'usuario_id': 'u2', 'created_at': DateTime(2026, 10, 31, 23, 59, 30).toIso8601String(), 'total_cost': 1},
        ],
      );
      expect(calcularMetricas(f, desde: desde, hasta: hasta).usuariosActivos, 2);
    });

    test('documentos procesados por IA, separados por módulo', () {
      final f = FilasMetricas(
        usuariosTotales: 1,
        vehiculosTotales: 1,
        documentos: [
          {'vehiculo_id': 'v1', 'fecha_actualizacion': d(2026, 9, 6), 'origen': 'ia'},
          {'vehiculo_id': 'v1', 'fecha_actualizacion': d(2026, 9, 7), 'origen': 'manual'},
        ],
        mantenciones: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 8), 'costo': 100000, 'origen': 'ia'},
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 9), 'costo': 50000, 'origen': 'ia'},
        ],
        estacionamientos: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 10), 'costo': 2000, 'origen': 'ia'},
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 11), 'costo': 1500, 'origen': 'manual'},
        ],
        boletas: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 12), 'ai_report': 'Informe...'},
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 13), 'ai_report': null},
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 14), 'ai_report': '   '},
        ],
      );
      final m = calcularMetricas(f, desde: desde, hasta: hasta);
      expect(m.iaPorModulo['Documentos del vehículo'], 1);
      expect(m.iaPorModulo['Mantenciones'], 2);
      expect(m.iaPorModulo['Estacionamientos'], 1);
      expect(m.iaPorModulo['Combustible'], 0);
      expect(m.iaPorModulo['Boletas de peaje'], 1);
      expect(m.iaTotal, 5);
    });

    test('gasto por categoría suma cada módulo por separado', () {
      final f = FilasMetricas(
        usuariosTotales: 1,
        vehiculosTotales: 1,
        viajes: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 2), 'total_cost': 2500},
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 3), 'total_cost': 1500},
        ],
        cargas: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 4), 'total': 40000, 'origen': 'manual'},
        ],
        mantenciones: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 5), 'costo': 129900, 'origen': 'manual'},
        ],
        estacionamientos: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 6), 'costo': 3750, 'origen': 'manual'},
        ],
      );
      final m = calcularMetricas(f, desde: desde, hasta: hasta);
      expect(m.gastoPorCategoria['Peajes'], 4000);
      expect(m.gastoPorCategoria['Combustible'], 40000);
      expect(m.gastoPorCategoria['Mantenciones'], 129900);
      expect(m.gastoPorCategoria['Estacionamientos'], 3750);
      expect(m.gastoTotal, 177650);
      expect(m.registrosTotal, 5);
    });

    test('valores nulos o ausentes cuentan como cero y no rompen', () {
      final f = FilasMetricas(
        usuariosTotales: 1,
        vehiculosTotales: 0,
        mantenciones: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 2), 'costo': null, 'origen': null},
          {'usuario_id': null, 'created_at': d(2026, 9, 3)},
        ],
      );
      final m = calcularMetricas(f, desde: desde, hasta: hasta);
      expect(m.gastoPorCategoria['Mantenciones'], 0);
      expect(m.registrosPorModulo['Mantenciones'], 2);
      expect(m.usuariosActivos, 1);
    });

    test('una fecha ilegible se ignora en vez de romper el cálculo', () {
      final f = FilasMetricas(
        usuariosTotales: 1,
        vehiculosTotales: 0,
        viajes: [
          {'usuario_id': 'u1', 'created_at': 'no es una fecha', 'total_cost': 100},
        ],
      );
      expect(calcularMetricas(f, desde: desde, hasta: hasta).registrosTotal, 0);
    });
  });

  group('crecimiento mensual', () {
    test('una fila por mes del período, en orden', () {
      final m = calcularMetricas(
        const FilasMetricas(usuariosTotales: 0, vehiculosTotales: 0),
        desde: DateTime(2026, 7, 15),
        hasta: DateTime(2026, 10, 2),
      );
      expect(m.crecimiento.map((c) => c.mes.month).toList(), [7, 8, 9, 10]);
    });

    test('cada fila cuenta lo suyo', () {
      final f = FilasMetricas(
        usuariosTotales: 5,
        vehiculosTotales: 3,
        usuarios: [
          {'fecha_creacion': d(2026, 9, 3)},
          {'fecha_creacion': d(2026, 9, 20)},
          {'fecha_creacion': d(2026, 10, 1)},
        ],
        vehiculos: [
          {'id': 'v1', 'usuario_id': 'u1', 'created_at': d(2026, 10, 2)},
        ],
        mantenciones: [
          {'usuario_id': 'u1', 'created_at': d(2026, 9, 5), 'costo': 1, 'origen': 'ia'},
          {'usuario_id': 'u1', 'created_at': d(2026, 10, 5), 'costo': 1, 'origen': 'manual'},
        ],
      );
      final m = calcularMetricas(f, desde: desde, hasta: hasta);
      final sept = m.crecimiento[0];
      final oct = m.crecimiento[1];
      expect(sept.usuariosNuevos, 2);
      expect(oct.usuariosNuevos, 1);
      expect(sept.vehiculosNuevos, 0);
      expect(oct.vehiculosNuevos, 1);
      expect(sept.registros, 1);
      expect(sept.documentosIa, 1);
      expect(oct.registros, 1);
      expect(oct.documentosIa, 0);
    });

    test('un período largo se limita a los últimos 24 meses', () {
      final m = calcularMetricas(
        const FilasMetricas(usuariosTotales: 0, vehiculosTotales: 0),
        desde: DateTime(2020, 1, 1),
        hasta: DateTime(2026, 10, 31),
      );
      expect(m.crecimiento.length, kMaximoMesesCrecimiento);
      expect(m.crecimiento.last.mes, DateTime(2026, 10));
      expect(m.crecimiento.first.mes, DateTime(2024, 11));
    });

    test('cruza el cambio de año', () {
      final m = calcularMetricas(
        const FilasMetricas(usuariosTotales: 0, vehiculosTotales: 0),
        desde: DateTime(2025, 11, 10),
        hasta: DateTime(2026, 2, 5),
      );
      expect(m.crecimiento.map((c) => '${c.mes.year}-${c.mes.month}').toList(), ['2025-11', '2025-12', '2026-1', '2026-2']);
    });
  });
}

void pruebasFormato() {
  group('formatos', () {
    test('formatoMilesEs agrupa de a tres con punto', () {
      expect(formatoMilesEs(0), '0');
      expect(formatoMilesEs(999), '999');
      expect(formatoMilesEs(1000), '1.000');
      expect(formatoMilesEs(1234567), '1.234.567');
      expect(formatoMilesEs(1234.6), '1.235');
      expect(formatoMilesEs(-1500), '-1.500');
    });

    test('formatoPesosEs', () => expect(formatoPesosEs(129900), r'$129.900'));

    test('etiquetaMes', () {
      expect(etiquetaMes(DateTime(2026, 9)), 'septiembre 2026');
      expect(etiquetaMes(DateTime(2026, 1)), 'enero 2026');
    });
  });
}
