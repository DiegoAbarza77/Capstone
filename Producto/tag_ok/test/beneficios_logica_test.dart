import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/models/beneficio_model.dart';
import 'package:tag_ok/utils/beneficios_logica.dart';

BeneficioModel ben({
  String titulo = 'Descuento',
  String comercio = 'Copec',
  String? categoria = 'combustible',
  String? ubicacion,
  DateTime? desde,
  DateTime? hasta,
  bool destacado = false,
  bool activo = true,
}) {
  return BeneficioModel(
    id: titulo,
    titulo: titulo,
    comercio: comercio,
    categoria: categoria,
    ubicacion: ubicacion,
    vigenciaDesde: desde,
    vigenciaHasta: hasta,
    destacado: destacado,
    activo: activo,
  );
}

void main() {
  final hoy = DateTime(2026, 10, 5, 15, 0);

  group('estaVigente', () {
    test('sin fechas y activo', () => expect(estaVigente(ben(), hoy: hoy), isTrue));
    test('desactivado no', () => expect(estaVigente(ben(activo: false), hoy: hoy), isFalse));
    test('el último día todavía sirve', () => expect(estaVigente(ben(hasta: DateTime(2026, 10, 5)), hoy: hoy), isTrue));
    test('al día siguiente de terminar ya no', () => expect(estaVigente(ben(hasta: DateTime(2026, 10, 4)), hoy: hoy), isFalse));
    test('el primer día ya sirve', () => expect(estaVigente(ben(desde: DateTime(2026, 10, 5)), hoy: hoy), isTrue));
    test('uno que aún no empieza no', () => expect(estaVigente(ben(desde: DateTime(2026, 10, 6)), hoy: hoy), isFalse));
  });

  group('textoVigencia', () {
    test('sin fecha límite', () => expect(textoVigencia(ben(), hoy: hoy), 'Sin fecha límite'));
    test('hoy', () => expect(textoVigencia(ben(hasta: DateTime(2026, 10, 5)), hoy: hoy), 'Vence hoy'));
    test('mañana', () => expect(textoVigencia(ben(hasta: DateTime(2026, 10, 6)), hoy: hoy), 'Vence mañana'));
    test('esta semana', () => expect(textoVigencia(ben(hasta: DateTime(2026, 10, 9)), hoy: hoy), 'Vence en 4 días'));
    test('más lejos muestra la fecha', () {
      expect(textoVigencia(ben(hasta: DateTime(2026, 11, 30)), hoy: hoy), 'Hasta el 30 nov 2026');
    });
  });

  group('aplicarFiltros', () {
    final lista = [
      ben(titulo: 'A bencina', categoria: 'combustible', ubicacion: 'Santiago', hasta: DateTime(2026, 12, 31)),
      ben(titulo: 'B aceite', categoria: 'talleres', ubicacion: 'Valparaíso', hasta: DateTime(2026, 10, 8)),
      ben(titulo: 'C lavado', categoria: 'lavado', hasta: DateTime(2026, 10, 25)),
      ben(titulo: 'D seguro', categoria: 'seguros', ubicacion: 'Santiago', destacado: true),
      ben(titulo: 'E viejo', categoria: 'combustible', hasta: DateTime(2026, 9, 1)),
      ben(titulo: 'F apagado', categoria: 'combustible', activo: false),
    ];

    List<String> titulos(FiltrosBeneficios f) => aplicarFiltros(lista, f, hoy: hoy).map((b) => b.titulo).toList();

    test('sin filtros: solo los vigentes, destacados primero', () {
      final r = titulos(const FiltrosBeneficios());
      expect(r.first, 'D seguro');
      expect(r, isNot(contains('E viejo')));
      expect(r, isNot(contains('F apagado')));
      expect(r.length, 4);
    });

    test('dentro del grupo, los que vencen antes van primero y los sin fecha al final', () {
      final r = titulos(const FiltrosBeneficios());
      expect(r, ['D seguro', 'B aceite', 'C lavado', 'A bencina']);
    });

    test('por una categoría', () {
      expect(titulos(const FiltrosBeneficios(categorias: {'talleres'})), ['B aceite']);
    });

    test('por varias categorías a la vez', () {
      expect(titulos(const FiltrosBeneficios(categorias: {'talleres', 'lavado'})), ['B aceite', 'C lavado']);
    });

    test('por ubicación incluye los que aplican en todas partes', () {
      final r = titulos(const FiltrosBeneficios(ubicacion: 'Santiago'));
      expect(r, containsAll(['A bencina', 'D seguro', 'C lavado']));
      expect(r, isNot(contains('B aceite')));
    });

    test('la ubicación no distingue mayúsculas', () {
      expect(titulos(const FiltrosBeneficios(ubicacion: 'VALPARAÍSO')), contains('B aceite'));
    });

    test('vencen esta semana', () {
      expect(titulos(const FiltrosBeneficios(vigencia: FiltroVigencia.venceEn7Dias)), ['B aceite']);
    });

    test('vencen este mes no incluye los que no tienen fecha límite', () {
      final r = titulos(const FiltrosBeneficios(vigencia: FiltroVigencia.venceEn30Dias));
      expect(r, ['B aceite', 'C lavado']);
    });

    test('los filtros se combinan', () {
      final f = const FiltrosBeneficios(categorias: {'combustible'}, ubicacion: 'Santiago');
      expect(titulos(f), ['A bencina']);
    });

    test('E1: criterios sin resultados dan una lista vacía', () {
      expect(titulos(const FiltrosBeneficios(categorias: {'neumaticos'})), isEmpty);
    });

    test('un beneficio sin categoría cuenta como Otros', () {
      final r = aplicarFiltros([ben(titulo: 'X', categoria: null)], const FiltrosBeneficios(categorias: {'otros'}), hoy: hoy);
      expect(r.length, 1);
    });
  });

  group('FiltrosBeneficios', () {
    test('cuenta los criterios activos', () {
      expect(const FiltrosBeneficios().cantidadActivos, 0);
      expect(const FiltrosBeneficios().hayFiltros, isFalse);
      expect(const FiltrosBeneficios(categorias: {'a', 'b'}).cantidadActivos, 1);
      expect(
        const FiltrosBeneficios(categorias: {'a'}, ubicacion: 'x', vigencia: FiltroVigencia.venceEn7Dias).cantidadActivos,
        3,
      );
    });

    test('copyWith puede quitar la ubicación', () {
      final f = const FiltrosBeneficios(ubicacion: 'Santiago').copyWith(quitarUbicacion: true);
      expect(f.ubicacion, isNull);
    });
  });

  group('opciones de filtro', () {
    final lista = [
      ben(categoria: 'talleres', ubicacion: 'Santiago'),
      ben(categoria: 'combustible', ubicacion: 'santiago '),
      ben(categoria: 'combustible', ubicacion: 'Valparaíso'),
      ben(categoria: null),
    ];

    test('las ubicaciones no se repiten ni distinguen mayúsculas, y salen ordenadas', () {
      expect(ubicacionesDisponibles(lista), ['Santiago', 'Valparaíso']);
    });

    test('solo se ofrecen categorías que tienen beneficios, en el orden definido', () {
      expect(categoriasConBeneficios(lista), ['combustible', 'talleres', 'otros']);
    });

    test('lista vacía no ofrece nada', () {
      expect(ubicacionesDisponibles([]), isEmpty);
      expect(categoriasConBeneficios([]), isEmpty);
    });
  });

  group('BeneficioModel.fromJson', () {
    test('lee el título desde la columna nombre y los textos vacíos como null', () {
      final b = BeneficioModel.fromJson({
        'id': '1',
        'nombre': '10% de descuento',
        'comercio': 'Copec',
        'categoria': 'combustible',
        'descripcion': '  ',
        'codigo_canje': 'TAGOK10',
        'vigencia_hasta': '2026-11-30T23:59:59Z',
      });
      expect(b.titulo, '10% de descuento');
      expect(b.descripcion, isNull);
      expect(b.codigoCanje, 'TAGOK10');
      expect(b.vigenciaHasta, isNotNull);
    });

    test('etiquetas de categoría', () {
      expect(etiquetaCategoriaBeneficio('neumaticos'), 'Neumáticos');
      expect(etiquetaCategoriaBeneficio(null), 'Otros');
      expect(etiquetaCategoriaBeneficio('xyz'), 'Otros');
    });
  });
}
