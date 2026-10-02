import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehiculo_model.dart';

DocumentoVehiculoModel _docConVencimiento(Duration desdeAhora) => DocumentoVehiculoModel(
      tipo: 'soap',
      fechaVencimiento: DateTime.now().add(desdeAhora),
    );

void main() {
  group('textoVencimiento', () {
    test('sin fecha dice "Sin datos"', () {
      expect(DocumentoVehiculoModel(tipo: 'soap').textoVencimiento, 'Sin datos');
    });

    test('cerca de vencer usa días restantes', () {
      // +12 horas para que inDays no cuente un día de menos por los milisegundos.
      final doc = _docConVencimiento(const Duration(days: 25, hours: 12));
      expect(doc.textoVencimiento, 'Vence en 25 días');
    });

    test('un solo día usa singular', () {
      final doc = _docConVencimiento(const Duration(days: 1, hours: 12));
      expect(doc.textoVencimiento, 'Vence en 1 día');
    });

    test('lejos de vencer muestra la fecha', () {
      final doc = DocumentoVehiculoModel(tipo: 'soap', fechaVencimiento: DateTime(2099, 3, 15));
      expect(doc.textoVencimiento, 'Vence 15/03/2099');
    });

    test('ya vencido indica hace cuántos días', () {
      final doc = _docConVencimiento(const Duration(days: -3, hours: -12));
      expect(doc.textoVencimiento, 'Vencido hace 3 días');
    });
  });

  group('estado general', () {
    test('un documento vencido marca "Atención requerida"', () {
      final estado = peorEstado([EstadoVencimiento.alDia, EstadoVencimiento.vencido]);
      expect(labelEstadoGeneralVehiculo(estado), 'Atención requerida');
    });

    test('uno por vencer marca "Próximo vencimiento"', () {
      final estado = peorEstado([EstadoVencimiento.alDia, EstadoVencimiento.atencion]);
      expect(labelEstadoGeneralVehiculo(estado), 'Próximo vencimiento');
    });

    test('todo vigente marca "Todo al día"', () {
      final estado = peorEstado([EstadoVencimiento.alDia, EstadoVencimiento.alDia]);
      expect(labelEstadoGeneralVehiculo(estado), 'Todo al día');
    });
  });
}
