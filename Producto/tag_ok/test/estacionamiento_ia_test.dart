import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/estacionamiento_ia_service.dart';
import 'package:tag_ok/data/services/gemini_proxy_service.dart';
import 'package:tag_ok/data/services/lectura_boleta_exception.dart';

class _ProxyFalso extends GeminiProxyService {
  final String? respuesta;
  final bool falla;
  _ProxyFalso({this.respuesta, this.falla = false});

  @override
  Future<String> pedirTexto(String prompt, {required Uint8List fileBytes, required String mimeType}) async {
    if (falla) throw Exception('sin red');
    return respuesta!;
  }
}

Future<EstacionamientoExtraidoIa> _leer(String? respuesta, {bool falla = false}) {
  return EstacionamientoIaService(proxy: _ProxyFalso(respuesta: respuesta, falla: falla))
      .extraerTicket(fileBytes: Uint8List(0), mimeType: 'image/jpeg');
}

void main() {
  group('parseHoraDelDia', () {
    test('formatos habituales', () {
      expect(parseHoraDelDia('14:30'), (hora: 14, minuto: 30));
      expect(parseHoraDelDia('9:05'), (hora: 9, minuto: 5));
      expect(parseHoraDelDia('14.30'), (hora: 14, minuto: 30));
      expect(parseHoraDelDia('14h30'), (hora: 14, minuto: 30));
      expect(parseHoraDelDia('14:30:45'), (hora: 14, minuto: 30));
    });

    test('formato de 12 horas', () {
      expect(parseHoraDelDia('2:30 PM'), (hora: 14, minuto: 30));
      expect(parseHoraDelDia('9:05 am'), (hora: 9, minuto: 5));
      expect(parseHoraDelDia('12:00 AM'), (hora: 0, minuto: 0));
      expect(parseHoraDelDia('12:15 PM'), (hora: 12, minuto: 15));
      expect(parseHoraDelDia('3:00 p.m.'), (hora: 15, minuto: 0));
    });

    test('lo que no es una hora válida da null', () {
      expect(parseHoraDelDia('25:00'), isNull);
      expect(parseHoraDelDia('14:75'), isNull);
      expect(parseHoraDelDia('13:00 PM'), isNull);
      expect(parseHoraDelDia('mediodía'), isNull);
      expect(parseHoraDelDia(''), isNull);
      expect(parseHoraDelDia(null), isNull);
      expect(parseHoraDelDia('null'), isNull);
    });
  });

  group('parseDuracionMinutos', () {
    test('números y textos', () {
      expect(parseDuracionMinutos(90), 90);
      expect(parseDuracionMinutos('90'), 90);
      expect(parseDuracionMinutos('2 h 30 min'), 150);
      expect(parseDuracionMinutos('2h 30m'), 150);
      expect(parseDuracionMinutos('1 hora'), 60);
      expect(parseDuracionMinutos('45 minutos'), 45);
      expect(parseDuracionMinutos('02:30'), 150);
      expect(parseDuracionMinutos('00:45:10'), 45);
    });

    test('lo que no se entiende da null', () {
      expect(parseDuracionMinutos('mucho rato'), isNull);
      expect(parseDuracionMinutos(''), isNull);
      expect(parseDuracionMinutos(null), isNull);
      expect(parseDuracionMinutos(-5), isNull);
      expect(parseDuracionMinutos('00:99'), isNull);
    });
  });

  group('EstacionamientoExtraidoIa.fromJson', () {
    test('un ticket completo', () {
      final e = EstacionamientoExtraidoIa.fromJson({
        'estacionamiento': 'Estacionamientos Mall Plaza',
        'ubicacion': 'Av. Ejemplo 1234, Santiago',
        'fecha': '2026-09-15',
        'hora_entrada': '14:05',
        'hora_salida': '16:35',
        'duracion': '2 h 30 min',
        'monto': 3750,
      });
      expect(e.lugar, 'Estacionamientos Mall Plaza');
      expect(e.direccion, 'Av. Ejemplo 1234, Santiago');
      expect(e.fecha, DateTime(2026, 9, 15));
      expect(e.horaEntrada, (hora: 14, minuto: 5));
      expect(e.horaSalida, (hora: 16, minuto: 35));
      expect(e.duracionMinutos, 150);
      expect(e.monto, 3750);
      expect(e.vacia, isFalse);
    });

    test('lee el monto con puntos de miles', () {
      expect(EstacionamientoExtraidoIa.fromJson({'monto': r'$ 3.750'}).monto, 3750);
    });

    test('con entrada y duración deduce la salida', () {
      final e = EstacionamientoExtraidoIa.fromJson({'hora_entrada': '14:00', 'duracion': '1 h 30 min'});
      expect(e.horaSalida, (hora: 15, minuto: 30));
    });

    test('con salida y duración deduce la entrada, aunque cruce la medianoche', () {
      final e = EstacionamientoExtraidoIa.fromJson({'hora_salida': '00:30', 'duracion': '1 h'});
      expect(e.horaEntrada, (hora: 23, minuto: 30));
    });

    test('no pisa una hora que sí se leyó', () {
      final e = EstacionamientoExtraidoIa.fromJson({'hora_entrada': '14:00', 'hora_salida': '16:00', 'duracion': '30 min'});
      expect(e.horaSalida, (hora: 16, minuto: 0));
    });

    test('sin horas, la duración queda sola', () {
      final e = EstacionamientoExtraidoIa.fromJson({'duracion': '2 h', 'monto': 2000});
      expect(e.horaEntrada, isNull);
      expect(e.horaSalida, isNull);
      expect(e.duracionMinutos, 120);
    });

    test('descarta fechas imposibles o futuras', () {
      expect(EstacionamientoExtraidoIa.fromJson({'fecha': '1990-01-01', 'monto': 1}).fecha, isNull);
      expect(EstacionamientoExtraidoIa.fromJson({'fecha': '2999-01-01', 'monto': 1}).fecha, isNull);
    });

    test('todo en null es una lectura vacía', () {
      expect(EstacionamientoExtraidoIa.fromJson({'estacionamiento': null, 'monto': 'null'}).vacia, isTrue);
    });
  });

  group('EstacionamientoIaService.extraerTicket', () {
    test('devuelve los datos cuando la IA responde bien', () async {
      final e = await _leer('{"estacionamiento":"Playa Centro","hora_entrada":"10:00","monto":2500}');
      expect(e.lugar, 'Playa Centro');
      expect(e.monto, 2500);
    });

    test('ticket ilegible (todo null) avisa y no inventa datos', () async {
      expect(() => _leer('{"estacionamiento":null,"monto":null}'), throwsA(isA<LecturaBoletaException>()));
    });

    test('respuesta que no es JSON avisa con un mensaje amable', () async {
      expect(() => _leer('no pude leerlo'), throwsA(isA<LecturaBoletaException>()));
    });

    test('falla de conexión con la IA avisa con un mensaje amable', () async {
      expect(() => _leer(null, falla: true), throwsA(isA<LecturaBoletaException>()));
    });
  });
}
