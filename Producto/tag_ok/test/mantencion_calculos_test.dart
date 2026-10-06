import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/mantencion_model.dart';
import 'package:tag_ok/utils/mantencion_calculos.dart';

MantencionModel mant({String id = 'x', required DateTime fecha, double? km, double costo = 0, String tipo = 'aceite'}) {
  return MantencionModel(id: id, vehiculoId: 'v1', fecha: fecha, kilometraje: km, costo: costo, tipo: tipo);
}

MantencionProgramadaModel prog({DateTime? fecha, double? km, int dias = 7, double kmAviso = 500}) {
  return MantencionProgramadaModel(
    vehiculoId: 'v1',
    fechaProgramada: fecha,
    kmProgramado: km,
    avisoDiasAntes: dias,
    avisoKmAntes: kmAviso,
  );
}

void main() {
  final hoy = DateTime(2026, 10, 1);

  group('evaluarProgramada por fecha', () {
    test('lejos: al día', () {
      final e = evaluarProgramada(prog(fecha: DateTime(2026, 12, 1)), hoy: hoy);
      expect(e.estado, EstadoProgramada.alDia);
      expect(e.diasRestantes, 61);
    });

    test('dentro del aviso: próxima', () {
      expect(evaluarProgramada(prog(fecha: DateTime(2026, 10, 6)), hoy: hoy).estado, EstadoProgramada.proxima);
    });

    test('justo el día del aviso: próxima', () {
      expect(evaluarProgramada(prog(fecha: DateTime(2026, 10, 8)), hoy: hoy).estado, EstadoProgramada.proxima);
    });

    test('el mismo día: próxima, no vencida', () {
      expect(evaluarProgramada(prog(fecha: hoy), hoy: hoy).estado, EstadoProgramada.proxima);
    });

    test('ya pasó: vencida', () {
      final e = evaluarProgramada(prog(fecha: DateTime(2026, 9, 30)), hoy: hoy);
      expect(e.estado, EstadoProgramada.vencida);
      expect(e.diasRestantes, -1);
    });
  });

  group('evaluarProgramada por kilometraje', () {
    test('lejos: al día', () {
      final e = evaluarProgramada(prog(km: 90000), kmActual: 80000, hoy: hoy);
      expect(e.estado, EstadoProgramada.alDia);
      expect(e.kmRestantes, 10000);
    });

    test('dentro del aviso: próxima', () {
      expect(evaluarProgramada(prog(km: 80400), kmActual: 80000, hoy: hoy).estado, EstadoProgramada.proxima);
    });

    test('ya se pasó el kilometraje: vencida', () {
      expect(evaluarProgramada(prog(km: 80000), kmActual: 80000, hoy: hoy).estado, EstadoProgramada.vencida);
      expect(evaluarProgramada(prog(km: 79000), kmActual: 80000, hoy: hoy).estado, EstadoProgramada.vencida);
    });

    test('sin kilometraje actual no se puede evaluar por km', () {
      final e = evaluarProgramada(prog(km: 90000), hoy: hoy);
      expect(e.estado, EstadoProgramada.alDia);
      expect(e.kmRestantes, isNull);
    });
  });

  group('evaluarProgramada con ambos criterios', () {
    test('manda el más urgente: la fecha está lejos pero el km ya se pasó', () {
      final e = evaluarProgramada(prog(fecha: DateTime(2027, 6, 1), km: 80000), kmActual: 81000, hoy: hoy);
      expect(e.estado, EstadoProgramada.vencida);
    });

    test('la fecha vencida no se corrige porque el km esté lejos', () {
      final e = evaluarProgramada(prog(fecha: DateTime(2026, 9, 1), km: 99999), kmActual: 80000, hoy: hoy);
      expect(e.estado, EstadoProgramada.vencida);
    });

    test('próxima por km con fecha lejana sigue siendo próxima', () {
      final e = evaluarProgramada(prog(fecha: DateTime(2027, 6, 1), km: 80300), kmActual: 80000, hoy: hoy);
      expect(e.estado, EstadoProgramada.proxima);
    });
  });

  group('incongruenciaKilometraje (CU9 E1)', () {
    final historial = [
      mant(id: 'a', fecha: DateTime(2026, 1, 10), km: 60000),
      mant(id: 'b', fecha: DateTime(2026, 6, 10), km: 72000),
    ];

    test('km menor al de la mantención anterior: devuelve esa mantención', () {
      final anterior = incongruenciaKilometraje(historial, fecha: DateTime(2026, 9, 1), km: 70000);
      expect(anterior?.id, 'b');
    });

    test('km mayor o igual: sin incongruencia', () {
      expect(incongruenciaKilometraje(historial, fecha: DateTime(2026, 9, 1), km: 75000), isNull);
      expect(incongruenciaKilometraje(historial, fecha: DateTime(2026, 9, 1), km: 72000), isNull);
    });

    test('solo compara con mantenciones de fecha anterior o igual', () {
      // En marzo la anterior es la de enero (60.000), así que 65.000 cuadra
      // aunque sea menor que la de junio (72.000), que es posterior.
      expect(incongruenciaKilometraje(historial, fecha: DateTime(2026, 3, 1), km: 65000), isNull);
      expect(incongruenciaKilometraje(historial, fecha: DateTime(2026, 3, 1), km: 55000)?.id, 'a');
    });

    test('sin mantenciones previas con km no hay nada que comparar', () {
      expect(incongruenciaKilometraje([], fecha: DateTime(2026, 9, 1), km: 10), isNull);
      expect(
        incongruenciaKilometraje([mant(fecha: DateTime(2026, 1, 1))], fecha: DateTime(2026, 9, 1), km: 10),
        isNull,
      );
    });

    test('al editar no se compara con la propia mantención', () {
      expect(
        incongruenciaKilometraje(historial, fecha: DateTime(2026, 6, 10), km: 70000, excluirId: 'b'),
        isNull,
      );
    });
  });

  group('sumarMeses', () {
    test('suma meses normales', () => expect(sumarMeses(DateTime(2026, 10, 15), 6), DateTime(2027, 4, 15)));
    test('el día se ajusta al último del mes', () {
      expect(sumarMeses(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(sumarMeses(DateTime(2023, 8, 31), 6), DateTime(2024, 2, 29));
    });
    test('cruza el cambio de año', () => expect(sumarMeses(DateTime(2026, 11, 5), 14), DateTime(2028, 1, 5)));
  });

  group('sugerirProximaMantencion', () {
    test('aceite: +10.000 km y +6 meses', () {
      final s = sugerirProximaMantencion('aceite', fechaBase: DateTime(2026, 10, 1), kmBase: 78500);
      expect(s.km, 88500);
      expect(s.fecha, DateTime(2027, 4, 1));
    });

    test('frenos y neumáticos tienen intervalos más largos', () {
      expect(sugerirProximaMantencion('frenos', fechaBase: DateTime(2026, 1, 1), kmBase: 1000).km, 21000);
      expect(sugerirProximaMantencion('neumaticos', fechaBase: DateTime(2026, 1, 1), kmBase: 1000).km, 41000);
    });

    test('sin kilometraje base, solo sugiere fecha', () {
      expect(sugerirProximaMantencion('aceite', fechaBase: DateTime(2026, 1, 1)).km, isNull);
    });
  });

  group('MantencionModel', () {
    test('la fecha no cambia de día al guardar y volver a leer', () {
      final original = mant(fecha: DateTime(2026, 3, 15), km: 1000, costo: 129900);
      final leida = MantencionModel.fromJson({...original.toJson(), 'id': 'z'});
      expect(leida.fecha.year, 2026);
      expect(leida.fecha.month, 3);
      expect(leida.fecha.day, 15);
    });

    test('lee servicios y repuestos como listas', () {
      final m = MantencionModel.fromJson({
        'id': '1',
        'vehiculo_id': 'v1',
        'fecha': '2026-03-15T12:00:00Z',
        'servicios': ['Cambio de aceite', 'Filtro de aire'],
        'repuestos': ['Filtro de aceite'],
        'costo': 129900,
      });
      expect(m.servicios, ['Cambio de aceite', 'Filtro de aire']);
      expect(m.titulo, 'Cambio de aceite');
      expect(m.costo, 129900);
    });

    test('un tipo desconocido se muestra como Otra', () {
      expect(etiquetaTipoMantencion('xyz'), 'Otra');
      expect(etiquetaTipoMantencion('aceite'), 'Cambio de aceite');
    });

    test('textos vacíos se guardan como null', () {
      final json = MantencionModel(vehiculoId: 'v1', fecha: DateTime(2026, 1, 1), taller: '  ', descripcion: '').toJson();
      expect(json['taller'], isNull);
      expect(json['descripcion'], isNull);
    });
  });

  group('costoTotalMantenciones', () {
    test('suma los costos', () {
      expect(costoTotalMantenciones([mant(fecha: DateTime(2026, 1, 1), costo: 100), mant(fecha: DateTime(2026, 2, 1), costo: 250)]), 350);
      expect(costoTotalMantenciones([]), 0);
    });
  });

  group('MantencionProgramadaModel', () {
    test('la fecha se guarda como yyyy-MM-dd y se lee igual', () {
      final p = prog(fecha: DateTime(2027, 4, 1), km: 88500);
      final json = p.toJson();
      expect(json['fecha_programada'], '2027-04-01');
      final leida = MantencionProgramadaModel.fromJson({...json, 'id': 'p1'});
      expect(leida.fechaProgramada, DateTime(2027, 4, 1));
      expect(leida.kmProgramado, 88500);
    });

    test('título usa la descripción y si no el tipo', () {
      expect(const MantencionProgramadaModel(vehiculoId: 'v', tipo: 'frenos').titulo, 'Frenos');
      expect(const MantencionProgramadaModel(vehiculoId: 'v', descripcion: 'Correa de distribución').titulo, 'Correa de distribución');
    });
  });
}
