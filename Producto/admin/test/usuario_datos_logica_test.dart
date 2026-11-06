import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/usuario_datos_logica.dart';

void main() {
  final ahora = DateTime(2026, 11, 10);

  group('estadoDocumento', () {
    test('sin fecha es "sin datos"', () {
      expect(estadoDocumento(null, ahora: ahora), EstadoDocumento.sinDatos);
    });

    test('una fecha pasada es vencido', () {
      expect(estadoDocumento(DateTime(2026, 11, 9), ahora: ahora), EstadoDocumento.vencido);
    });

    test('faltando 30 días o menos es por vencer', () {
      expect(estadoDocumento(DateTime(2026, 12, 10), ahora: ahora), EstadoDocumento.porVencer);
      expect(estadoDocumento(DateTime(2026, 11, 11), ahora: ahora), EstadoDocumento.porVencer);
    });

    test('faltando más de 30 días está al día', () {
      expect(estadoDocumento(DateTime(2026, 12, 11), ahora: ahora), EstadoDocumento.alDia);
    });
  });

  group('formatos', () {
    test('formatoPesos usa punto de miles', () {
      expect(formatoPesos(0), '\$0');
      expect(formatoPesos(950), '\$950');
      expect(formatoPesos(39000), '\$39.000');
      expect(formatoPesos(1234567), '\$1.234.567');
      expect(formatoPesos(-5000), '-\$5.000');
    });

    test('formatoFecha entrega dd/MM/yyyy y raya si no hay fecha', () {
      expect(formatoFecha('2026-10-25T12:00:00'), '25/10/2026');
      expect(formatoFecha(null), '—');
      // Una fecha guardada como medianoche UTC no debe retroceder un día.
      expect(formatoFecha('2027-07-31T00:00:00+00:00'), '31/07/2027');
      expect(formatoFecha('no es fecha'), '—');
    });

    test('formatoDuracion', () {
      expect(formatoDuracion(0), '0 min');
      expect(formatoDuracion(45), '45 min');
      expect(formatoDuracion(60), '1 h');
      expect(formatoDuracion(90), '1 h 30 min');
      expect(formatoDuracion(null), '—');
    });

    test('formatoCantidad usa coma decimal', () {
      expect(formatoCantidad(30), '30');
      expect(formatoCantidad(42.5), '42,5');
      expect(formatoCantidad('12.25'), '12,3');
      expect(formatoCantidad(null), '—');
    });
  });

  group('DatosUsuario', () {
    final datos = DatosUsuario(
      vehiculos: [
        {'id': 'v1', 'patente': 'ABCD77'},
      ],
      documentos: [
        {'vehiculo_id': 'v1', 'tipo': 'soap', 'fecha_vencimiento': '2026-11-20T00:00:00'},
        {'vehiculo_id': 'v1', 'tipo': 'seguro', 'fecha_vencimiento': '2026-11-01T00:00:00'},
        {'vehiculo_id': 'v1', 'tipo': 'permiso_circulacion', 'fecha_vencimiento': '2027-10-19T00:00:00'},
      ],
      mantenciones: [
        {'costo': 129007},
        {'costo': '103000.50'},
      ],
      cargas: [
        {'total': 39000},
        {'total': 45000},
      ],
      estacionamientos: [
        {'costo': 5000},
        {'costo': null},
      ],
    );

    test('suma el gasto de cada módulo y el total', () {
      expect(datos.gastoMantenciones, 232007.5);
      expect(datos.gastoCombustible, 84000);
      expect(datos.gastoEstacionamientos, 5000);
      expect(datos.gastoTotal, 321007.5);
    });

    test('documentosDe devuelve siempre los 4 en orden, con huecos vacíos', () {
      final docs = datos.documentosDe('v1');
      expect(docs.map((d) => d['tipo']), kTiposDocumento);
      expect(docs[0]['fecha_vencimiento'], '2027-10-19T00:00:00');
      expect(docs[1]['fecha_vencimiento'], isNull); // revisión técnica sin cargar
    });

    test('cuenta los documentos vencidos o por vencer', () {
      // soap vence en 10 días (por vencer), seguro ya venció, permiso está al día.
      expect(datos.documentosConAlerta(ahora: ahora), 2);
    });

    test('un usuario sin registros se detecta como vacío', () {
      expect(const DatosUsuario().estaVacio, isTrue);
      expect(datos.estaVacio, isFalse);
    });

    test('avisa cuando hay más registros que el máximo mostrado', () {
      final muchas = DatosUsuario(
        cargas: List.generate(DatosUsuario.limiteFilas, (_) => {'total': 1}),
      );
      expect(muchas.hayRegistrosOcultos, isTrue);
      expect(datos.hayRegistrosOcultos, isFalse);
    });
  });
}
