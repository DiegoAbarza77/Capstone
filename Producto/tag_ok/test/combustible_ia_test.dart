import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/combustible_ia_service.dart';
import 'package:tag_ok/data/services/gemini_proxy_service.dart';

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

Future<CargaExtraidaIa> _leer(String? respuesta, {bool falla = false}) {
  return CombustibleIaService(proxy: _ProxyFalso(respuesta: respuesta, falla: falla))
      .extraerBoleta(fileBytes: Uint8List(0), mimeType: 'image/jpeg');
}

void main() {
  group('CargaExtraidaIa.fromJson', () {
    test('lee una boleta completa', () {
      final c = CargaExtraidaIa.fromJson({
        'fecha': '2026-09-15',
        'estacion': 'Copec',
        'tipo_combustible': 'Bencina',
        'cantidad': 32.5,
        'unidad': 'litros',
        'precio_unidad': 1350,
        'total': 43875,
        'kilometraje': 48200,
      });
      expect(c.fecha, DateTime(2026, 9, 15));
      expect(c.estacion, 'Copec');
      expect(c.tipoCombustible, 'Bencina');
      expect(c.cantidad, 32.5);
      expect(c.unidad, 'litros');
      expect(c.precioUnidad, 1350);
      expect(c.total, 43875);
      expect(c.kilometraje, 48200);
      expect(c.vacia, isFalse);
    });

    test('los campos que no se leyeron quedan en null', () {
      final c = CargaExtraidaIa.fromJson({'estacion': 'Shell', 'total': 20000});
      expect(c.estacion, 'Shell');
      expect(c.total, 20000);
      expect(c.cantidad, isNull);
      expect(c.fecha, isNull);
      expect(c.kilometraje, isNull);
    });

    test('un texto "null" o vacío no cuenta como dato', () {
      final c = CargaExtraidaIa.fromJson({'estacion': 'null', 'tipo_combustible': ''});
      expect(c.estacion, isNull);
      expect(c.vacia, isTrue);
    });

    test('interpreta números escritos como texto', () {
      final c = CargaExtraidaIa.fromJson({'total': r'$ 45.000', 'cantidad': '32,5', 'precio_unidad': '1.350,5'});
      expect(c.total, 45000);
      expect(c.cantidad, 32.5);
      expect(c.precioUnidad, 1350.5);
    });

    test('una carga eléctrica queda en kWh', () {
      final c = CargaExtraidaIa.fromJson({'tipo_combustible': 'Carga eléctrica', 'cantidad': 18});
      expect(c.tipoCombustible, 'Eléctrico');
      expect(c.unidad, 'kwh');
    });

    test('descarta fechas imposibles', () {
      expect(CargaExtraidaIa.fromJson({'fecha': '1990-01-01', 'total': 1}).fecha, isNull);
      expect(CargaExtraidaIa.fromJson({'fecha': '2999-01-01', 'total': 1}).fecha, isNull);
      expect(CargaExtraidaIa.fromJson({'fecha': 'ayer', 'total': 1}).fecha, isNull);
    });
  });

  group('normalizarTipoEnergia', () {
    test('reconoce los nombres habituales', () {
      expect(CargaExtraidaIa.normalizarTipoEnergia('Gasolina 95'), 'Bencina');
      expect(CargaExtraidaIa.normalizarTipoEnergia('BENCINA 93'), 'Bencina');
      expect(CargaExtraidaIa.normalizarTipoEnergia('Diesel'), 'Diésel');
      expect(CargaExtraidaIa.normalizarTipoEnergia('Petróleo'), 'Diésel');
      expect(CargaExtraidaIa.normalizarTipoEnergia('kWh'), 'Eléctrico');
      expect(CargaExtraidaIa.normalizarTipoEnergia('GLP'), isNull);
      expect(CargaExtraidaIa.normalizarTipoEnergia(null), isNull);
    });
  });

  group('CombustibleIaService.extraerBoleta', () {
    test('devuelve los datos cuando la IA responde bien', () async {
      final c = await _leer('{"estacion":"Copec","total":43875,"cantidad":32.5,"tipo_combustible":"Bencina"}');
      expect(c.estacion, 'Copec');
    });

    test('E1: comprobante ilegible (todo null) avisa y no inventa datos', () async {
      expect(
        () => _leer('{"fecha":null,"estacion":null,"total":null}'),
        throwsA(isA<LecturaBoletaException>()),
      );
    });

    test('E1: respuesta que no es JSON avisa con un mensaje amable', () async {
      expect(() => _leer('no pude leerlo'), throwsA(isA<LecturaBoletaException>()));
    });

    test('falla de conexión con la IA avisa con un mensaje amable', () async {
      expect(() => _leer(null, falla: true), throwsA(isA<LecturaBoletaException>()));
    });
  });
}
