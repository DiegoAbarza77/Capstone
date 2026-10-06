import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/estacionamiento_model.dart';
import 'package:tag_ok/utils/estacionamiento_calculos.dart';

EstacionamientoModel est({
  DateTime? fecha,
  DateTime? entrada,
  DateTime? salida,
  int? minutos,
  double costo = 0,
  bool enCurso = false,
}) {
  return EstacionamientoModel(
    id: 'x',
    vehiculoId: 'v1',
    fecha: fecha ?? DateTime(2026, 9, 15),
    horaEntrada: entrada,
    horaSalida: salida,
    duracionMinutos: minutos,
    costo: costo,
    enCurso: enCurso,
  );
}

void main() {
  group('formatoDuracion', () {
    test('minutos solos', () => expect(formatoDuracion(const Duration(minutes: 45)), '45 min'));
    test('horas exactas', () => expect(formatoDuracion(const Duration(hours: 3)), '3 h'));
    test('horas y minutos', () => expect(formatoDuracion(const Duration(hours: 2, minutes: 15)), '2 h 15 min'));
    test('cero', () => expect(formatoDuracion(Duration.zero), '0 min'));
    test('más de un día', () => expect(formatoDuracion(const Duration(hours: 26, minutes: 5)), '26 h 5 min'));
  });

  group('formatoCronometro', () {
    test('rellena con ceros', () => expect(formatoCronometro(const Duration(hours: 1, minutes: 5, seconds: 9)), '01:05:09'));
    test('arranca en cero', () => expect(formatoCronometro(Duration.zero), '00:00:00'));
    test('pasa de las 24 horas sin reiniciarse', () {
      expect(formatoCronometro(const Duration(hours: 25, minutes: 1, seconds: 2)), '25:01:02');
    });
  });

  group('resolverEntradaSalida', () {
    final dia = DateTime(2026, 9, 15);

    test('mismo día', () {
      final r = resolverEntradaSalida(dia, horaEntrada: 14, minutoEntrada: 0, horaSalida: 16, minutoSalida: 30);
      expect(r.salida, DateTime(2026, 9, 15, 16, 30));
      expect(r.diaSiguiente, isFalse);
      expect(r.salida.difference(r.entrada), const Duration(hours: 2, minutes: 30));
    });

    test('salida anterior a la entrada: pasó la medianoche', () {
      final r = resolverEntradaSalida(dia, horaEntrada: 22, minutoEntrada: 0, horaSalida: 6, minutoSalida: 0);
      expect(r.salida, DateTime(2026, 9, 16, 6, 0));
      expect(r.diaSiguiente, isTrue);
      expect(r.salida.difference(r.entrada), const Duration(hours: 8));
    });

    test('misma hora de entrada y salida cuenta como 24 horas, no como cero', () {
      final r = resolverEntradaSalida(dia, horaEntrada: 10, minutoEntrada: 0, horaSalida: 10, minutoSalida: 0);
      expect(r.salida.difference(r.entrada), const Duration(hours: 24));
    });

    test('cruza el fin de mes', () {
      final r = resolverEntradaSalida(DateTime(2026, 9, 30), horaEntrada: 23, minutoEntrada: 0, horaSalida: 1, minutoSalida: 0);
      expect(r.salida, DateTime(2026, 10, 1, 1, 0));
    });
  });

  group('EstacionamientoModel.duracion', () {
    test('con las dos horas es la diferencia', () {
      final e = est(entrada: DateTime(2026, 9, 15, 14), salida: DateTime(2026, 9, 15, 15, 30));
      expect(e.duracion(), const Duration(hours: 1, minutes: 30));
    });

    test('sin horas usa la duración leída del ticket', () {
      expect(est(minutos: 90).duracion(), const Duration(minutes: 90));
    });

    test('las horas mandan sobre la duración leída', () {
      final e = est(entrada: DateTime(2026, 9, 15, 14), salida: DateTime(2026, 9, 15, 15), minutos: 999);
      expect(e.duracion(), const Duration(hours: 1));
    });

    test('sin ningún dato no hay duración', () => expect(est().duracion(), isNull));

    test('en curso: ahora menos la hora de inicio, aunque la app se haya cerrado', () {
      final inicio = DateTime(2026, 9, 15, 14, 0);
      final e = est(entrada: inicio, enCurso: true);
      expect(e.duracion(ahora: DateTime(2026, 9, 15, 16, 30, 15)), const Duration(hours: 2, minutes: 30, seconds: 15));
      // Recuperada "al reabrir la app" mucho después:
      expect(e.duracion(ahora: DateTime(2026, 9, 16, 14, 0)), const Duration(hours: 24));
    });

    test('un reloj atrasado nunca da duración negativa', () {
      final e = est(entrada: DateTime(2026, 9, 15, 14), enCurso: true);
      expect(e.duracion(ahora: DateTime(2026, 9, 15, 13)), Duration.zero);
    });
  });

  group('métricas del mes', () {
    final lista = [
      est(fecha: DateTime(2026, 9, 3), minutos: 60, costo: 1500),
      est(fecha: DateTime(2026, 9, 20), entrada: DateTime(2026, 9, 20, 10), salida: DateTime(2026, 9, 20, 12), costo: 3000),
      est(fecha: DateTime(2026, 8, 30), minutos: 30, costo: 800),
      est(fecha: DateTime(2026, 9, 25), entrada: DateTime(2026, 9, 25, 9), enCurso: true),
    ];

    test('el del mes excluye otros meses y el que está en curso', () {
      expect(estacionamientosDelMes(lista, DateTime(2026, 9, 1)).length, 2);
      expect(estacionamientosDelMes(lista, DateTime(2026, 8, 1)).length, 1);
    });

    test('gasto y tiempo total', () {
      final septiembre = estacionamientosDelMes(lista, DateTime(2026, 9, 1));
      expect(gastoEstacionamientos(septiembre), 4500);
      expect(tiempoTotalEstacionado(septiembre), const Duration(hours: 3));
    });

    test('encuentra el que está en curso', () {
      expect(estacionamientoEnCurso(lista)?.fecha, DateTime(2026, 9, 25));
      expect(estacionamientoEnCurso([]), isNull);
    });
  });

  group('EstacionamientoModel json', () {
    test('la fecha no cambia de día al guardar y volver a leer', () {
      final original = est(fecha: DateTime(2026, 3, 15), costo: 2500);
      final leido = EstacionamientoModel.fromJson({...original.toJson(), 'id': 'z'});
      expect(leido.fecha, DateTime(2026, 3, 15));
      expect(leido.costo, 2500);
    });

    test('las horas hacen el viaje de ida y vuelta', () {
      final entrada = DateTime(2026, 9, 15, 14, 5);
      final salida = DateTime(2026, 9, 15, 16, 20);
      final leido = EstacionamientoModel.fromJson({...est(entrada: entrada, salida: salida).toJson(), 'id': 'z'});
      expect(leido.horaEntrada, entrada);
      expect(leido.horaSalida, salida);
    });

    test('coordenadas y textos vacíos', () {
      final json = EstacionamientoModel(
        vehiculoId: 'v1',
        fecha: DateTime(2026, 1, 1),
        lugar: '  ',
        lat: -33.45,
        lng: -70.66,
      ).toJson();
      expect(json['lugar'], isNull);
      expect(json['lat'], -33.45);
      expect(EstacionamientoModel.fromJson({...json, 'id': 'a'}).tieneUbicacion, isTrue);
    });

    test('título por defecto', () {
      expect(est().titulo, 'Estacionamiento');
      expect(EstacionamientoModel(vehiculoId: 'v', fecha: DateTime(2026, 1, 1), lugar: 'Mall Plaza').titulo, 'Mall Plaza');
    });
  });
}
