import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/carga_combustible_model.dart';
import 'package:tag_ok/utils/combustible_metricas.dart';

CargaCombustibleModel carga({
  double? km,
  double cantidad = 0,
  double total = 0,
  String unidad = 'litros',
  bool lleno = false,
  DateTime? fecha,
}) {
  return CargaCombustibleModel(
    id: '',
    vehiculoId: 'v1',
    vehiculoPatente: 'ABCD12',
    fecha: fecha ?? DateTime(2026, 9, 15),
    kilometraje: km,
    litros: cantidad,
    total: total,
    unidad: unidad,
    tanqueLleno: lleno,
  );
}

void main() {
  group('calcularRendimiento', () {
    test('con un solo llenado no hay rendimiento', () {
      expect(calcularRendimiento([carga(km: 1000, cantidad: 40, lleno: true)], unidad: 'litros'), isNull);
    });

    test('dos llenados: kilómetros del tramo / litros del segundo llenado', () {
      final r = calcularRendimiento([
        carga(km: 1000, cantidad: 40, lleno: true),
        carga(km: 1400, cantidad: 32, lleno: true),
      ], unidad: 'litros');

      expect(r, isNotNull);
      expect(r!.kmPorUnidad, closeTo(12.5, 0.001)); // 400 km / 32 L
      expect(r.tramos, 1);
    });

    test('varios tramos se promedian ponderando por cantidad', () {
      final r = calcularRendimiento([
        carga(km: 1000, cantidad: 40, lleno: true),
        carga(km: 1400, cantidad: 32, lleno: true), // 400 km con 32 L
        carga(km: 1700, cantidad: 30, lleno: true), // 300 km con 30 L
      ], unidad: 'litros');

      expect(r!.kmPorUnidad, closeTo(700 / 62, 0.001));
      expect(r.tramos, 2);
    });

    test('ignora cargas parciales, sin odómetro o con cantidad 0', () {
      final r = calcularRendimiento([
        carga(km: 1000, cantidad: 40, lleno: true),
        carga(km: 1200, cantidad: 10, lleno: false), // parcial
        carga(cantidad: 20, lleno: true), // sin odómetro
        carga(km: 1300, cantidad: 0, lleno: true), // sin cantidad
        carga(km: 1400, cantidad: 32, lleno: true),
      ], unidad: 'litros');

      expect(r!.kmPorUnidad, closeTo(12.5, 0.001));
      expect(r.tramos, 1);
    });

    test('no mezcla litros con kWh', () {
      final cargas = [
        carga(km: 1000, cantidad: 40, lleno: true),
        carga(km: 1400, cantidad: 32, lleno: true),
        carga(km: 1500, cantidad: 15, unidad: 'kwh', lleno: true),
      ];
      expect(calcularRendimiento(cargas, unidad: 'kwh'), isNull);
      expect(calcularRendimiento(cargas, unidad: 'litros')!.tramos, 1);
    });

    test('kilometrajes iguales no cuentan como tramo', () {
      final r = calcularRendimiento([
        carga(km: 1000, cantidad: 40, lleno: true),
        carga(km: 1000, cantidad: 30, lleno: true),
      ], unidad: 'litros');
      expect(r, isNull);
    });

    test('no depende del orden en que vienen las cargas', () {
      final r = calcularRendimiento([
        carga(km: 1400, cantidad: 32, lleno: true),
        carga(km: 1000, cantidad: 40, lleno: true),
      ], unidad: 'litros');
      expect(r!.kmPorUnidad, closeTo(12.5, 0.001));
    });
  });

  group('métricas del mes', () {
    final cargas = [
      carga(cantidad: 30, total: 36000, fecha: DateTime(2026, 9, 3)),
      carga(cantidad: 25, total: 30000, fecha: DateTime(2026, 9, 20)),
      carga(cantidad: 10, total: 9000, unidad: 'kwh', fecha: DateTime(2026, 9, 25)),
      carga(cantidad: 40, total: 50000, fecha: DateTime(2026, 8, 30)),
    ];

    test('cargasDelMes filtra por año y mes', () {
      expect(cargasDelMes(cargas, DateTime(2026, 9, 1)).length, 3);
      expect(cargasDelMes(cargas, DateTime(2026, 8, 1)).length, 1);
      expect(cargasDelMes(cargas, DateTime(2025, 9, 1)), isEmpty);
    });

    test('gastoTotal suma los montos', () {
      expect(gastoTotal(cargasDelMes(cargas, DateTime(2026, 9, 1))), 75000);
    });

    test('cantidadTotal separa litros y kWh', () {
      final septiembre = cargasDelMes(cargas, DateTime(2026, 9, 1));
      expect(cantidadTotal(septiembre, 'litros'), 55);
      expect(cantidadTotal(septiembre, 'kwh'), 10);
    });
  });

  group('unidades', () {
    test('eléctrico se mide en kWh y el resto en litros', () {
      expect(unidadParaTipo('Eléctrico'), 'kwh');
      expect(unidadParaTipo('Bencina'), 'litros');
      expect(unidadParaTipo('Diésel'), 'litros');
      expect(unidadParaTipo(null), 'litros');
    });
  });
}
