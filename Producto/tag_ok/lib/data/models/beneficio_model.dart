/// Categorías de beneficios, con el identificador que usa la base de datos. Son
/// las mismas que el administrador asigna desde el panel.
const Map<String, String> kCategoriasBeneficio = {
  'combustible': 'Combustible',
  'talleres': 'Talleres',
  'mantenciones': 'Mantenciones',
  'estacionamiento': 'Estacionamientos',
  'lavado': 'Lavado',
  'neumaticos': 'Neumáticos',
  'seguros': 'Seguros',
  'accesorios': 'Accesorios',
  'otros': 'Otros',
};

String etiquetaCategoriaBeneficio(String? categoria) => kCategoriasBeneficio[categoria] ?? 'Otros';

/// Un beneficio, convenio o descuento de un comercio aliado.
class BeneficioModel {
  final String id;

  /// El título del beneficio (columna "nombre").
  final String titulo;
  final String comercio;
  final String? categoria;
  final String? descripcion;

  /// Dónde aplica ("Santiago", "Región Metropolitana"). Vacío significa que
  /// aplica en todas partes.
  final String? ubicacion;
  final String? condiciones;

  /// Código o instrucción para canjearlo ("TAGOK10", "Muestra la app en caja").
  final String? codigoCanje;
  final String? imagenUrl;

  /// Primer y último día en que se puede usar, sin hora.
  final DateTime? vigenciaDesde;
  final DateTime? vigenciaHasta;
  final bool destacado;
  final bool activo;

  const BeneficioModel({
    this.id = '',
    required this.titulo,
    required this.comercio,
    this.categoria,
    this.descripcion,
    this.ubicacion,
    this.condiciones,
    this.codigoCanje,
    this.imagenUrl,
    this.vigenciaDesde,
    this.vigenciaHasta,
    this.destacado = false,
    this.activo = true,
  });

  factory BeneficioModel.fromJson(Map<String, dynamic> row) {
    DateTime? dia(dynamic v) {
      if (v == null) return null;
      final f = DateTime.parse(v.toString()).toLocal();
      return DateTime(f.year, f.month, f.day);
    }

    String? texto(dynamic v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    return BeneficioModel(
      id: row['id'] ?? '',
      titulo: row['nombre'] ?? '',
      comercio: row['comercio'] ?? '',
      categoria: row['categoria'],
      descripcion: texto(row['descripcion']),
      ubicacion: texto(row['ubicacion']),
      condiciones: texto(row['condiciones']),
      codigoCanje: texto(row['codigo_canje']),
      imagenUrl: texto(row['imagen']),
      vigenciaDesde: dia(row['vigencia_desde']),
      vigenciaHasta: dia(row['vigencia_hasta']),
      destacado: row['destacado'] ?? false,
      activo: row['activo'] ?? true,
    );
  }
}
