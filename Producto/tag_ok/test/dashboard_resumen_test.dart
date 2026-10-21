import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/carga_combustible_model.dart';
import 'package:tag_ok/data/models/documento_vehiculo_model.dart';
import 'package:tag_ok/data/models/estacionamiento_model.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/data/models/trip_history.dart';
import 'package:tag_ok/utils/dashboard_resumen.dart';
import 'package:tag_ok/utils/mantencion_calculos.dart';

TripHistory _viaje(DateTime fecha, double costo, String vehiculo) => TripHistory(
      id: 'x',
      date: fecha,
      totalCost: costo,
      tolls: const [],
      distanceKm: 10,
      duration: '',
      vehicleName: vehiculo,
    );

void main() {
  final septiembre = DateTime(2026, 9, 15);

  group('calcularGastosMes', () {
    test('sin registros todo queda en cero', () {
      final g = calcularGastosMes(mes: septiembre, patente: 'ABCD12');
      expect(g.total, 0);
      expect(g.fraccion(0), 0);
    });

    test('suma cada categoría solo del mes y del vehículo', () {
      final g = calcularGastosMes(
        mes: septiembre,
        patente: 'ABCD12',
        viajes: [
          _viaje(DateTime(2026, 9, 3), 1000, 'Hyundai (ABCD12)'),
          _viaje(DateTime(2026, 9, 4), 500, 'Otro auto (ZZZZ99)'),
          _viaje(DateTime(2026, 8, 30), 700, 'Hyundai (ABCD12)'),
        ],
        cargas: [
          CargaCombustibleModel(id: '', vehiculoId: 'v', vehiculoPatente: 'ABCD12', fecha: DateTime(2026, 9, 1), total: 45000),
          CargaCombustibleModel(id: '', vehiculoId: 'v', vehiculoPatente: 'ABCD12', fecha: DateTime(2026, 8, 1), total: 99999),
        ],
        estacionamientos: [
          EstacionamientoModel(vehiculoId: 'v', fecha: DateTime(2026, 9, 10), costo: 3000),
          EstacionamientoModel(vehiculoId: 'v', fecha: DateTime(2026, 9, 11), costo: 9999, enCurso: true),
        ],
        mantenciones: [
          MantencionModel(vehiculoId: 'v', fecha: DateTime(2026, 9, 20), costo: 50000),
          MantencionModel(vehiculoId: 'v', fecha: DateTime(2026, 7, 20), costo: 80000),
        ],
      );
      expect(g.tag, 1000);
      expect(g.combustible, 45000);
      expect(g.estacionamientos, 3000);
      expect(g.mantenciones, 50000);
      expect(g.total, 99000);
      expect(g.fraccion(g.combustible), closeTo(45000 / 99000, 1e-9));
    });
  });

  group('diasProximoVencimiento', () {
    test('sin documentos o sin fechas es null', () {
      expect(diasProximoVencimiento([]), isNull);
      expect(diasProximoVencimiento([DocumentoVehiculoModel(tipo: 'soap')]), isNull);
    });

    test('toma el que vence primero, incluso uno ya vencido', () {
      final ahora = DateTime.now();
      final dias = diasProximoVencimiento([
        DocumentoVehiculoModel(tipo: 'soap', fechaVencimiento: ahora.add(const Duration(days: 40))),
        DocumentoVehiculoModel(tipo: 'seguro', fechaVencimiento: ahora.add(const Duration(days: 10))),
      ]);
      expect(dias, inInclusiveRange(9, 10));
      final vencido = diasProximoVencimiento([
        DocumentoVehiculoModel(tipo: 'soap', fechaVencimiento: ahora.subtract(const Duration(days: 5))),
      ]);
      expect(vencido, lessThan(0));
    });
  });

  group('resumenProximaMantencion', () {
    test('sin programadas dice Sin programar', () {
      final r = resumenProximaMantencion([]);
      expect(r.texto, 'Sin programar');
      expect(r.urgente, isFalse);
    });

    test('prioriza los km que faltan', () {
      final r = resumenProximaMantencion([
        const EvaluacionProgramada(estado: EstadoProgramada.alDia, kmRestantes: 1200, diasRestantes: 20),
        const EvaluacionProgramada(estado: EstadoProgramada.alDia, kmRestantes: 5000),
      ]);
      expect(r.texto, '1.200 km');
      expect(r.urgente, isFalse);
    });

    test('usa días si no hay kilómetros', () {
      final r = resumenProximaMantencion([const EvaluacionProgramada(estado: EstadoProgramada.proxima, diasRestantes: 1)]);
      expect(r.texto, '1 día');
    });

    test('una vencida es urgente', () {
      final r = resumenProximaMantencion([const EvaluacionProgramada(estado: EstadoProgramada.vencida, kmRestantes: -50)]);
      expect(r.texto, 'Vencida');
      expect(r.urgente, isTrue);
    });
  });
}
