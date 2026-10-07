import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/utils/combustible_calculos.dart';

Map<String, String> validar({
  String cantidad = '',
  String precio = '',
  String total = '',
  String km = '',
  DateTime? fecha,
}) {
  return validarCarga(
    cantidad: cantidad,
    precio: precio,
    total: total,
    kilometraje: km,
    fecha: fecha ?? DateTime(2026, 10, 1),
    hoy: DateTime(2026, 10, 5),
  );
}

void main() {
  group('tipoEnergiaPorDefecto', () {
    test('eléctrico, diésel y bencina', () {
      expect(tipoEnergiaPorDefecto('Eléctrico'), 'Eléctrico');
      expect(tipoEnergiaPorDefecto('Diésel'), 'Diésel');
      expect(tipoEnergiaPorDefecto('Bencina'), 'Bencina');
    });

    test('un híbrido o un vehículo sin dato arranca en bencina', () {
      expect(tipoEnergiaPorDefecto('Híbrido'), 'Bencina');
      expect(tipoEnergiaPorDefecto(null), 'Bencina');
    });
  });

  group('completarMontos', () {
    test('con cantidad y precio calcula el total', () {
      final m = completarMontos(cantidad: 32.5, precio: 1350);
      expect(m.total, 43875);
      expect(m.cantidad, 32.5);
      expect(m.precio, 1350);
    });

    test('el total se redondea a pesos enteros', () {
      expect(completarMontos(cantidad: 10.3, precio: 1349).total, 13895);
    });

    test('con cantidad y total calcula el precio por unidad', () {
      final m = completarMontos(cantidad: 40, total: 54000);
      expect(m.precio, 1350);
    });

    test('con precio y total calcula la cantidad', () {
      final m = completarMontos(precio: 1350, total: 54000);
      expect(m.cantidad, 40);
    });

    test('un registro parcial con solo el total deja el resto en cero', () {
      final m = completarMontos(total: 20000);
      expect(m.total, 20000);
      expect(m.cantidad, 0);
      expect(m.precio, 0);
    });

    test('solo la cantidad: no puede deducir montos', () {
      final m = completarMontos(cantidad: 30);
      expect(m.cantidad, 30);
      expect(m.total, 0);
      expect(m.precio, 0);
    });

    test('no pisa un total que el usuario ya escribió', () {
      final m = completarMontos(cantidad: 40, precio: 1350, total: 50000);
      expect(m.total, 50000);
    });

    test('valores negativos o nulos cuentan como ausentes', () {
      final m = completarMontos(cantidad: -5, precio: null, total: 1000);
      expect(m.cantidad, 0);
      expect(m.total, 1000);
    });

    test('kWh con precio decimal', () {
      final m = completarMontos(cantidad: 18, precio: 245.5);
      expect(m.total, 4419);
    });
  });

  group('validarCarga', () {
    test('con la cantidad basta', () => expect(validar(cantidad: '32,5'), isEmpty));
    test('con el total basta', () => expect(validar(total: '43.875'), isEmpty));
    test('todo completo', () {
      expect(validar(cantidad: '32,5', precio: '1.350', total: '43.875', km: '78.500'), isEmpty);
    });

    test('datos mínimos: sin cantidad ni total no se puede guardar', () {
      expect(validar().containsKey('minimo'), isTrue);
      expect(validar(km: '1000').containsKey('minimo'), isTrue);
      expect(validar(precio: '1350').containsKey('minimo'), isTrue);
    });

    test('cantidad o total en cero cuentan como vacíos', () {
      expect(validar(cantidad: '0').containsKey('minimo'), isTrue);
      expect(validar(total: '0').containsKey('minimo'), isTrue);
    });

    test('E3: un campo no numérico marca ese campo', () {
      expect(validar(cantidad: 'abc').containsKey('cantidad'), isTrue);
      expect(validar(total: '12x').containsKey('total'), isTrue);
      expect(validar(cantidad: '30', precio: 'caro').containsKey('precio'), isTrue);
      expect(validar(cantidad: '30', km: 'mucho').containsKey('kilometraje'), isTrue);
    });

    test('E3: los negativos tampoco valen', () {
      expect(validar(cantidad: '-3').containsKey('cantidad'), isTrue);
      expect(validar(total: '-100').containsKey('total'), isTrue);
    });

    test('con un error numérico no se suma el aviso de datos mínimos', () {
      final e = validar(cantidad: 'abc');
      expect(e.containsKey('cantidad'), isTrue);
      expect(e.containsKey('minimo'), isFalse);
    });

    test('la fecha no puede ser futura', () {
      expect(validar(cantidad: '30', fecha: DateTime(2026, 10, 6)).containsKey('fecha'), isTrue);
      expect(validar(cantidad: '30', fecha: DateTime(2026, 10, 5)), isEmpty);
    });

    test('acepta coma o punto como decimal en la cantidad', () {
      expect(validar(cantidad: '32,5'), isEmpty);
      expect(validar(cantidad: '32.5'), isEmpty);
    });
  });
}
