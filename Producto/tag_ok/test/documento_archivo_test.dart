import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/documento_vehiculo_model.dart';

void main() {
  group('Archivo del documento', () {
    test('un documento sin archivo no lo declara y no envía la ruta', () {
      final doc = DocumentoVehiculoModel(tipo: 'soap', numero: 'S-1');
      expect(doc.tieneArchivo, isFalse);
      // Sin la ruta en el envío, guardar sigue funcionando aunque la
      // migración 0018 (que agrega la columna) no esté aplicada.
      expect(doc.toJson().containsKey('archivo_path'), isFalse);
    });

    test('un documento con archivo envía su ruta y su nombre', () {
      final doc = DocumentoVehiculoModel(
        tipo: 'soap',
        archivoNombre: 'soap.pdf',
        archivoPath: 'u1/v1/soap_1_soap.pdf',
      );
      expect(doc.tieneArchivo, isTrue);
      expect(doc.toJson()['archivo_path'], 'u1/v1/soap_1_soap.pdf');
      expect(doc.toJson()['archivo_nombre'], 'soap.pdf');
    });

    test('una ruta vacía no cuenta como archivo', () {
      expect(DocumentoVehiculoModel(tipo: 'soap', archivoPath: '').tieneArchivo, isFalse);
    });

    test('conArchivo cambia solo el archivo y conserva todos los datos', () {
      final original = DocumentoVehiculoModel(
        tipo: 'seguro',
        numero: 'POL-1',
        compania: 'Andes Seguros',
        fechaEmision: DateTime(2026, 5, 20),
        fechaVencimiento: DateTime(2027, 5, 19),
        origen: 'ia',
        aiCapturadoEn: DateTime(2026, 5, 20, 10),
        archivoNombre: 'viejo.png',
        archivoPath: 'u1/v1/viejo.png',
      );

      final nuevo = original.conArchivo(path: 'u1/v1/nuevo.pdf', nombre: 'nuevo.pdf');

      expect(nuevo.archivoPath, 'u1/v1/nuevo.pdf');
      expect(nuevo.archivoNombre, 'nuevo.pdf');
      expect(nuevo.tipo, original.tipo);
      expect(nuevo.numero, original.numero);
      expect(nuevo.compania, original.compania);
      expect(nuevo.fechaEmision, original.fechaEmision);
      expect(nuevo.fechaVencimiento, original.fechaVencimiento);
      expect(nuevo.origen, 'ia');
      expect(nuevo.aiCapturadoEn, original.aiCapturadoEn);
    });

    test('se lee la ruta guardada en la base de datos', () {
      final doc = DocumentoVehiculoModel.fromJson('soap', {
        'numero': 'S-1',
        'archivo_nombre': 'soap.pdf',
        'archivo_path': 'u1/v1/soap.pdf',
      });
      expect(doc.archivoPath, 'u1/v1/soap.pdf');
      expect(doc.tieneArchivo, isTrue);
    });

    test('una fila antigua sin la columna se lee sin archivo', () {
      final doc = DocumentoVehiculoModel.fromJson('soap', {'numero': 'S-1', 'archivo_nombre': 'soap.pdf'});
      expect(doc.archivoPath, isNull);
      expect(doc.tieneArchivo, isFalse);
    });
  });
}
