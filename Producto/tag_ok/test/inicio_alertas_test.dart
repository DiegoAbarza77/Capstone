import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehiculo_model.dart';
import 'package:tag_ok/data/models/carga_combustible_model.dart';
import 'package:tag_ok/utils/dashboard_resumen.dart';
import 'package:tag_ok/utils/inicio_alertas.dart';

DocumentoVehiculoModel doc(String tipo, int? dias) => DocumentoVehiculoModel(
      tipo: tipo,
      fechaVencimiento: dias == null ? null : DateTime.now().add(Duration(days: dias, hours: 1)),
    );

void main() {
  test('solo avisa los vencidos y por vencer, el más urgente primero', () {
    final a = alertasDocumentos([
      doc('soap', 200),
      doc('seguro', 10),
      doc('revision_tecnica', -5),
      doc('permiso_circulacion', null),
    ]);
    expect(a.length, 2);
    expect(a.first.texto, startsWith('Revisión Técnica: Vencido'));
    expect(a.first.urgente, isTrue);
    expect(a.last.urgente, isFalse);
  });

  test('sin documentos por atender no hay avisos', () {
    expect(alertasDocumentos([doc('soap', 300)]), isEmpty);
  });

  test('gastos con mes null suman todo el historial', () {
    final cargas = <CargaCombustibleModel>[
      CargaCombustibleModel(
        id: '1', vehiculoId: 'v', vehiculoPatente: 'X', fecha: DateTime(2026, 1, 5), litros: 10, precioLitro: 1000, total: 10000,
      ),
      CargaCombustibleModel(
        id: '2', vehiculoId: 'v', vehiculoPatente: 'X', fecha: DateTime(2026, 3, 5), litros: 10, precioLitro: 1000, total: 20000,
      ),
    ];
    expect(calcularGastosMes(mes: null, patente: 'X', cargas: cargas).combustible, 30000);
    expect(calcularGastosMes(mes: DateTime(2026, 3), patente: 'X', cargas: cargas).combustible, 20000);
  });
}
