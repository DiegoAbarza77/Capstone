import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/uso_ia_logica.dart';

/// Fila del registro: la hora va al mediodía UTC, que cae el mismo día en Chile.
Map<String, dynamic> _fila(
  String dia, {
  String resultado = 'ok',
  int? status,
  String usuario = 'u1',
  bool archivo = true,
  int? ms,
}) =>
    {
      'usuario_id': usuario,
      'created_at': '${dia}T15:00:00Z',
      'resultado': resultado,
      'http_status': status,
      'con_archivo': archivo,
      'duracion_ms': ms,
    };

void main() {
  final desde = DateTime(2026, 11, 1);
  final hasta = DateTime(2026, 11, 5);

  test('un registro vacío da un resumen en cero, con todos los días del período', () {
    final r = resumenUsoIa([], desde: desde, hasta: hasta);
    expect(r.estaVacio, isTrue);
    expect(r.total, 0);
    expect(r.tasaExito, 0);
    expect(r.duracionPromedioMs, isNull);
    expect(r.porDia.length, 5);
    expect(r.porDia.every((d) => d.llamadas == 0), isTrue);
    expect(r.topUsuarios, isEmpty);
  });

  group('con llamadas', () {
    final filas = [
      _fila('2026-11-01', ms: 2000),
      _fila('2026-11-01', ms: 3000, usuario: 'u2'),
      _fila('2026-11-02', resultado: 'error', status: 503),
      _fila('2026-11-02', resultado: 'error', status: 503, usuario: 'u2'),
      _fila('2026-11-03', resultado: 'limitado', status: 429, archivo: false),
      _fila('2026-11-05', ms: 1000),
    ];
    final r = resumenUsoIa(filas, desde: desde, hasta: hasta);

    test('cuenta total, exitosas, errores y límite alcanzado', () {
      expect(r.total, 6);
      expect(r.exitosas, 3);
      expect(r.conError, 2);
      expect(r.limitadas, 1);
      expect(r.fallidas, 3);
    });

    test('calcula la tasa de éxito', () {
      expect(r.tasaExito, 50);
    });

    test('cuenta usuarios distintos y llamadas con archivo', () {
      expect(r.usuarios, 2);
      expect(r.conArchivo, 5);
    });

    test('promedia la duración solo de las llamadas exitosas', () {
      expect(r.duracionPromedioMs, 2000); // (2000 + 3000 + 1000) / 3
    });

    test('reparte las llamadas por día, con los días sin uso en cero', () {
      expect(r.porDia.map((d) => d.llamadas), [2, 2, 1, 0, 1]);
      expect(r.porDia.map((d) => d.fallidas), [0, 2, 1, 0, 0]);
    });

    test('agrupa los errores por causa, de más a menos frecuente', () {
      expect(r.erroresPorTipo.keys.toList(), [
        'Proveedor de IA con alta demanda (503)',
        'Límite de 10 llamadas por minuto',
      ]);
      expect(r.erroresPorTipo['Proveedor de IA con alta demanda (503)'], 2);
    });

    test('ordena los usuarios por llamadas', () {
      expect(r.topUsuarios.first.usuarioId, 'u1');
      expect(r.topUsuarios.first.llamadas, 4);
      expect(r.topUsuarios.first.fallidas, 2);
      expect(r.topUsuarios.last.usuarioId, 'u2');
    });
  });

  test('ignora las llamadas fuera del período', () {
    final r = resumenUsoIa(
      [_fila('2026-10-31'), _fila('2026-11-03'), _fila('2026-11-06')],
      desde: desde,
      hasta: hasta,
    );
    expect(r.total, 1);
  });

  test('una fila sin fecha válida se ignora y sin usuario no rompe el conteo', () {
    final r = resumenUsoIa(
      [
        {'created_at': 'no es fecha', 'resultado': 'ok'},
        {'created_at': '2026-11-02T15:00:00Z', 'resultado': 'ok'},
      ],
      desde: desde,
      hasta: hasta,
    );
    expect(r.total, 1);
    expect(r.usuarios, 0);
    expect(r.topUsuarios, isEmpty);
  });

  test('el top se limita a 5 usuarios', () {
    final filas = [for (var i = 0; i < 8; i++) _fila('2026-11-02', usuario: 'u$i')];
    expect(resumenUsoIa(filas, desde: desde, hasta: hasta).topUsuarios.length, 5);
  });

  group('etiquetas', () {
    test('causas de fallo', () {
      expect(etiquetaErrorIa('limitado', 429), 'Límite de 10 llamadas por minuto');
      expect(etiquetaErrorIa('error', 503), 'Proveedor de IA con alta demanda (503)');
      expect(etiquetaErrorIa('error', 429), 'Límite o saldo del proveedor de IA (429)');
      expect(etiquetaErrorIa('error', 502), 'Respuesta vacía o bloqueada');
      expect(etiquetaErrorIa('error', null), 'Error sin detalle');
      expect(etiquetaErrorIa('error', 500), 'Error del proveedor de IA (500)');
    });

    test('formatoDuracionIa', () {
      expect(formatoDuracionIa(null), '—');
      expect(formatoDuracionIa(850), '850 ms');
      expect(formatoDuracionIa(2300), '2,3 s');
    });
  });
}
