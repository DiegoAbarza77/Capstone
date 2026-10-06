import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/gemini_proxy_service.dart';
import 'package:tag_ok/data/services/lectura_boleta_exception.dart';
import 'package:tag_ok/data/services/mantencion_ia_service.dart';

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

Future<MantencionExtraidaIa> _leer(String? respuesta, {bool falla = false}) {
  return MantencionIaService(proxy: _ProxyFalso(respuesta: respuesta, falla: falla))
      .extraerBoleta(fileBytes: Uint8List(0), mimeType: 'image/jpeg');
}

void main() {
  pruebasLimpiezaServicios();

  group('MantencionExtraidaIa.fromJson', () {
    test('el ejemplo de la presentación: aceite, filtros, \$129.900 y 78.500 km', () {
      final m = MantencionExtraidaIa.fromJson({
        'taller': 'Taller Los Aromos',
        'fecha': '2026-09-15',
        'servicios': ['Cambio de aceite'],
        'repuestos': ['Filtro de aceite', 'Filtro de aire'],
        'kilometraje': 78500,
        'total': 129900,
        'tipo': 'aceite',
      });

      expect(m.taller, 'Taller Los Aromos');
      expect(m.fecha, DateTime(2026, 9, 15));
      expect(m.servicios, ['Cambio de aceite']);
      expect(m.repuestos, ['Filtro de aceite', 'Filtro de aire']);
      expect(m.kilometraje, 78500);
      expect(m.total, 129900);
      expect(m.tipo, 'aceite');
      expect(m.vacia, isFalse);
    });

    test('lee montos y kilómetros escritos con puntos de miles', () {
      final m = MantencionExtraidaIa.fromJson({'total': r'$ 129.900', 'kilometraje': '78.500 km'});
      expect(m.total, 129900);
      expect(m.kilometraje, 78500);
    });

    test('lo que no se leyó queda vacío', () {
      final m = MantencionExtraidaIa.fromJson({'taller': 'Midas', 'total': 50000});
      expect(m.servicios, isEmpty);
      expect(m.repuestos, isEmpty);
      expect(m.fecha, isNull);
      expect(m.kilometraje, isNull);
    });

    test('acepta servicios como texto separado por comas o saltos de línea', () {
      final m = MantencionExtraidaIa.fromJson({
        'servicios': 'Cambio de aceite, Alineación\nBalanceo',
        'total': 1,
      });
      expect(m.servicios, ['Cambio de aceite', 'Alineación', 'Balanceo']);
    });

    test('quita servicios repetidos y vacíos', () {
      final m = MantencionExtraidaIa.fromJson({
        'servicios': ['Cambio de aceite', 'cambio de aceite', '', null, 'null'],
        'total': 1,
      });
      expect(m.servicios, ['Cambio de aceite']);
    });

    test('descarta fechas imposibles o futuras', () {
      expect(MantencionExtraidaIa.fromJson({'fecha': '1950-01-01', 'total': 1}).fecha, isNull);
      expect(MantencionExtraidaIa.fromJson({'fecha': '2999-01-01', 'total': 1}).fecha, isNull);
      expect(MantencionExtraidaIa.fromJson({'fecha': 'ayer', 'total': 1}).fecha, isNull);
    });

    test('todo en null es una lectura vacía', () {
      expect(MantencionExtraidaIa.fromJson({'taller': null, 'servicios': []}).vacia, isTrue);
    });
  });

  group('clasificarTipoMantencion', () {
    test('respeta una categoría válida de la IA', () {
      expect(clasificarTipoMantencion('frenos', ['Cambio de aceite']), 'frenos');
    });

    test('si la IA no clasificó, lo deduce de los servicios', () {
      expect(clasificarTipoMantencion(null, ['Cambio de aceite y filtro']), 'aceite');
      expect(clasificarTipoMantencion(null, ['Cambio de pastillas de freno']), 'frenos');
      expect(clasificarTipoMantencion(null, ['Alineación y balanceo']), 'neumaticos');
      expect(clasificarTipoMantencion(null, ['Mantención preventiva 40.000 km']), 'preventiva');
    });

    test('una categoría inventada por la IA se corrige con los servicios', () {
      expect(clasificarTipoMantencion('lubricacion', ['Cambio de aceite']), 'aceite');
    });

    test('sin pistas queda como otra', () {
      expect(clasificarTipoMantencion(null, ['Pulido de focos']), 'otra');
      expect(clasificarTipoMantencion(null, []), 'otra');
    });
  });

  group('MantencionIaService.extraerBoleta', () {
    test('devuelve los datos cuando la IA responde bien', () async {
      final m = await _leer('{"taller":"Midas","servicios":["Cambio de aceite"],"total":129900,"tipo":"aceite"}');
      expect(m.taller, 'Midas');
      expect(m.tipo, 'aceite');
    });

    test('E2: comprobante ilegible (todo vacío) avisa y no inventa datos', () async {
      expect(() => _leer('{"taller":null,"servicios":[],"total":null}'), throwsA(isA<LecturaBoletaException>()));
    });

    test('E2: respuesta que no es JSON avisa con un mensaje amable', () async {
      expect(() => _leer('no pude leerlo'), throwsA(isA<LecturaBoletaException>()));
    });

    test('falla de conexión con la IA avisa con un mensaje amable', () async {
      expect(() => _leer(null, falla: true), throwsA(isA<LecturaBoletaException>()));
    });
  });
}

void pruebasLimpiezaServicios() {
  group('limpiarNombreServicio', () {
    test('quita "Mano de obra" y pone mayúscula inicial', () {
      expect(limpiarNombreServicio('Mano de obra cambio de aceite'), 'Cambio de aceite');
      expect(limpiarNombreServicio('MANO DE OBRA alineación'), 'Alineación');
      expect(limpiarNombreServicio('mano de obra: balanceo'), 'Balanceo');
      expect(limpiarNombreServicio('Mano de obra de frenos'), 'Frenos');
      expect(limpiarNombreServicio('Mano de obra - cambio de pastillas'), 'Cambio de pastillas');
    });

    test('entiende las abreviaturas M.O. y M/O', () {
      expect(limpiarNombreServicio('M.O. alineación'), 'Alineación');
      expect(limpiarNombreServicio('M/O cambio de filtro'), 'Cambio de filtro');
    });

    test('un servicio normal queda igual', () {
      expect(limpiarNombreServicio('Cambio de aceite'), 'Cambio de aceite');
      expect(limpiarNombreServicio('Alineación y balanceo'), 'Alineación y balanceo');
    });

    test('no confunde palabras que solo empiezan parecido', () {
      expect(limpiarNombreServicio('Montaje de neumáticos'), 'Montaje de neumáticos');
      expect(limpiarNombreServicio('Motor: revisión'), 'Motor: revisión');
    });

    test('si solo dice "Mano de obra", se deja tal cual', () {
      expect(limpiarNombreServicio('Mano de obra'), 'Mano de obra');
    });

    test('se aplica al leer la boleta con IA', () {
      final m = MantencionExtraidaIa.fromJson({
        'servicios': ['Mano de obra cambio de aceite', 'M.O. alineación'],
        'total': 1,
      });
      expect(m.servicios, ['Cambio de aceite', 'Alineación']);
    });
  });
}
