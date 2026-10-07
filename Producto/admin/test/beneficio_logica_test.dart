import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/beneficio_logica.dart';

Beneficio ben({
  String titulo = '10% de descuento',
  String comercio = 'Copec',
  String? categoria = 'combustible',
  DateTime? desde,
  DateTime? hasta,
  bool activo = true,
  bool destacado = false,
}) {
  return Beneficio(
    id: 'x',
    titulo: titulo,
    comercio: comercio,
    categoria: categoria,
    vigenciaDesde: desde,
    vigenciaHasta: hasta,
    activo: activo,
    destacado: destacado,
  );
}

void main() {
  final hoy = DateTime(2026, 10, 5, 15, 30);

  group('validarBeneficio', () {
    test('un beneficio completo no tiene errores', () {
      expect(
        validarBeneficio(titulo: 'Lavado gratis', comercio: 'AutoSpa', categoria: 'lavado'),
        isEmpty,
      );
    });

    test('E2: sin título, comercio ni categoría marca los tres campos', () {
      final e = validarBeneficio(titulo: '  ', comercio: '', categoria: null);
      expect(e.keys, containsAll(['titulo', 'comercio', 'categoria']));
      expect(e.containsKey('vigencia'), isFalse);
    });

    test('E2: una categoría inventada no vale', () {
      expect(validarBeneficio(titulo: 'a', comercio: 'b', categoria: 'xyz').containsKey('categoria'), isTrue);
    });

    test('E1: término anterior al inicio bloquea el guardado', () {
      final e = validarBeneficio(
        titulo: 'a',
        comercio: 'b',
        categoria: 'otros',
        vigenciaDesde: DateTime(2026, 10, 10),
        vigenciaHasta: DateTime(2026, 10, 1),
      );
      expect(e.containsKey('vigencia'), isTrue);
    });

    test('inicio y término el mismo día es válido', () {
      final e = validarBeneficio(
        titulo: 'a',
        comercio: 'b',
        categoria: 'otros',
        vigenciaDesde: DateTime(2026, 10, 10),
        vigenciaHasta: DateTime(2026, 10, 10),
      );
      expect(e, isEmpty);
    });

    test('la vigencia es opcional, completa o a medias', () {
      expect(validarBeneficio(titulo: 'a', comercio: 'b', categoria: 'otros', vigenciaDesde: DateTime(2026, 1, 1)), isEmpty);
      expect(validarBeneficio(titulo: 'a', comercio: 'b', categoria: 'otros', vigenciaHasta: DateTime(2026, 1, 1)), isEmpty);
    });
  });

  group('validarImagenBeneficio (E3)', () {
    test('formatos válidos', () {
      for (final n in ['a.jpg', 'a.JPEG', 'a.png', 'a.webp']) {
        expect(validarImagenBeneficio(nombre: n, bytes: 1000), isNull, reason: n);
      }
    });

    test('formato no válido', () {
      expect(validarImagenBeneficio(nombre: 'a.gif', bytes: 1000), contains('Formato'));
      expect(validarImagenBeneficio(nombre: 'a.pdf', bytes: 1000), contains('Formato'));
      expect(validarImagenBeneficio(nombre: 'sin_extension', bytes: 1000), contains('Formato'));
    });

    test('demasiado pesada', () {
      final msg = validarImagenBeneficio(nombre: 'a.png', bytes: 3 * 1024 * 1024);
      expect(msg, contains('2 MB'));
      expect(msg, contains('3.0'));
    });

    test('justo en el límite sirve', () {
      expect(validarImagenBeneficio(nombre: 'a.png', bytes: kPesoMaximoImagenBytes), isNull);
      expect(validarImagenBeneficio(nombre: 'a.png', bytes: kPesoMaximoImagenBytes + 1), isNotNull);
    });

    test('archivo vacío', () => expect(validarImagenBeneficio(nombre: 'a.png', bytes: 0), isNotNull));
  });

  group('estadoBeneficio', () {
    test('activo y sin vigencia definida', () => expect(estadoBeneficio(ben(), hoy: hoy), EstadoBeneficio.activo));

    test('desactivado manda sobre todo lo demás', () {
      expect(estadoBeneficio(ben(activo: false), hoy: hoy), EstadoBeneficio.inactivo);
      expect(estadoBeneficio(ben(activo: false, hasta: DateTime(2020, 1, 1)), hoy: hoy), EstadoBeneficio.inactivo);
    });

    test('vigencia futura: programado', () {
      expect(estadoBeneficio(ben(desde: DateTime(2026, 10, 6)), hoy: hoy), EstadoBeneficio.programado);
    });

    test('vigencia terminada: vencido', () {
      expect(estadoBeneficio(ben(hasta: DateTime(2026, 10, 4)), hoy: hoy), EstadoBeneficio.vencido);
    });

    test('el último día de vigencia todavía está activo', () {
      expect(estadoBeneficio(ben(hasta: DateTime(2026, 10, 5)), hoy: hoy), EstadoBeneficio.activo);
    });

    test('el primer día de vigencia ya está activo', () {
      expect(estadoBeneficio(ben(desde: DateTime(2026, 10, 5)), hoy: hoy), EstadoBeneficio.activo);
    });
  });

  group('filtrarBeneficios', () {
    final lista = [
      ben(titulo: 'Cambio de aceite', comercio: 'Midas', categoria: 'talleres'),
      ben(titulo: '10% bencina', comercio: 'Copec', categoria: 'combustible', destacado: true),
      ben(titulo: 'Lavado express', comercio: 'AutoSpa', categoria: 'lavado', activo: false),
      ben(titulo: 'Estacionamiento gratis', comercio: 'Mall', categoria: 'estacionamiento', hasta: DateTime(2026, 1, 1)),
    ];

    test('sin filtros devuelve todo, con los destacados primero', () {
      final r = filtrarBeneficios(lista, hoy: hoy);
      expect(r.length, 4);
      expect(r.first.titulo, '10% bencina');
    });

    test('busca por título o por comercio, sin importar mayúsculas', () {
      expect(filtrarBeneficios(lista, texto: 'MIDAS', hoy: hoy).single.comercio, 'Midas');
      expect(filtrarBeneficios(lista, texto: 'lavado', hoy: hoy).single.comercio, 'AutoSpa');
    });

    test('por categoría', () {
      expect(filtrarBeneficios(lista, categoria: 'combustible', hoy: hoy).single.comercio, 'Copec');
    });

    test('por estado', () {
      expect(filtrarBeneficios(lista, estado: EstadoBeneficio.inactivo, hoy: hoy).single.comercio, 'AutoSpa');
      expect(filtrarBeneficios(lista, estado: EstadoBeneficio.vencido, hoy: hoy).single.comercio, 'Mall');
      expect(filtrarBeneficios(lista, estado: EstadoBeneficio.activo, hoy: hoy).length, 2);
    });

    test('sin coincidencias devuelve una lista vacía', () {
      expect(filtrarBeneficios(lista, texto: 'zzz', hoy: hoy), isEmpty);
    });
  });

  group('Beneficio json', () {
    test('las fechas de vigencia no cambian de día al guardar y volver a leer', () {
      final original = ben(desde: DateTime(2026, 11, 1), hasta: DateTime(2026, 11, 30));
      final leido = Beneficio.fromJson({...original.toJson(), 'id': 'z'});
      expect(leido.vigenciaDesde, DateTime(2026, 11, 1));
      expect(leido.vigenciaHasta, DateTime(2026, 11, 30));
    });

    test('el título se guarda en la columna nombre y los textos vacíos como null', () {
      final json = const Beneficio(titulo: ' Lavado ', comercio: ' AutoSpa ', descripcion: '  ', ubicacion: '').toJson();
      expect(json['nombre'], 'Lavado');
      expect(json['comercio'], 'AutoSpa');
      expect(json['descripcion'], isNull);
      expect(json['ubicacion'], isNull);
    });

    test('mimeDeImagen', () {
      expect(mimeDeImagen('a.PNG'), 'image/png');
      expect(mimeDeImagen('a.webp'), 'image/webp');
      expect(mimeDeImagen('a.jpg'), 'image/jpeg');
    });

    test('el código de canje se guarda y se lee', () {
      final json = const Beneficio(titulo: 'a', comercio: 'b', codigoCanje: ' TAGOK10 ').toJson();
      expect(json['codigo_canje'], 'TAGOK10');
      expect(Beneficio.fromJson({...json, 'id': 'z', 'nombre': 'a', 'comercio': 'b'}).codigoCanje, 'TAGOK10');
      expect(const Beneficio(titulo: 'a', comercio: 'b', codigoCanje: '  ').toJson()['codigo_canje'], isNull);
    });

    test('están las 8 categorías del catálogo de la app', () {
      expect(
        kCategoriasBeneficio.keys,
        containsAll(['combustible', 'talleres', 'mantenciones', 'estacionamiento', 'lavado', 'neumaticos', 'seguros', 'accesorios']),
      );
    });

    test('etiquetaCategoria', () {
      expect(etiquetaCategoria('talleres'), 'Talleres');
      expect(etiquetaCategoria(null), 'Sin categoría');
    });
  });
}
