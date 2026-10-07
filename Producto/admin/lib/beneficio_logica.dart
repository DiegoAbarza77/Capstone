/// Categorías sugeridas para un beneficio (CU19). El identificador es el que
/// acepta la base de datos.
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

String etiquetaCategoria(String? categoria) => kCategoriasBeneficio[categoria] ?? 'Sin categoría';

/// Peso máximo de la imagen promocional (el bucket de Storage también lo exige).
const int kPesoMaximoImagenBytes = 2 * 1024 * 1024;

/// Un beneficio o alianza comercial que se muestra a los conductores.
class Beneficio {
  final String id;

  /// El título del beneficio (columna "nombre").
  final String titulo;
  final String comercio;
  final String? categoria;
  final String? descripcion;
  final String? ubicacion;
  final String? condiciones;

  /// Código o instrucción para canjear el beneficio ("TAGOK10", "Muestra la app en caja").
  final String? codigoCanje;
  final String? imagenUrl;

  /// Primer día en que se puede usar, sin hora.
  final DateTime? vigenciaDesde;

  /// Último día en que se puede usar, sin hora.
  final DateTime? vigenciaHasta;
  final bool destacado;
  final bool activo;

  const Beneficio({
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

  factory Beneficio.fromJson(Map<String, dynamic> row) {
    DateTime? dia(dynamic v) {
      if (v == null) return null;
      final f = DateTime.parse(v.toString()).toLocal();
      return DateTime(f.year, f.month, f.day);
    }

    return Beneficio(
      id: row['id'] ?? '',
      titulo: row['nombre'] ?? '',
      comercio: row['comercio'] ?? '',
      categoria: row['categoria'],
      descripcion: row['descripcion'],
      ubicacion: row['ubicacion'],
      condiciones: row['condiciones'],
      codigoCanje: row['codigo_canje'],
      imagenUrl: row['imagen'],
      vigenciaDesde: dia(row['vigencia_desde']),
      vigenciaHasta: dia(row['vigencia_hasta']),
      destacado: row['destacado'] ?? false,
      activo: row['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    String? textoONulo(String? t) => t == null || t.trim().isEmpty ? null : t.trim();

    return {
      'nombre': titulo.trim(),
      'comercio': comercio.trim(),
      'categoria': categoria,
      'descripcion': textoONulo(descripcion),
      'ubicacion': textoONulo(ubicacion),
      'condiciones': textoONulo(condiciones),
      'codigo_canje': textoONulo(codigoCanje),
      'imagen': imagenUrl,
      // La vigencia es por días: empieza a las 00:00 del primer día y termina a
      // las 23:59:59 del último, en la hora local del administrador.
      'vigencia_desde': vigenciaDesde == null
          ? null
          : DateTime(vigenciaDesde!.year, vigenciaDesde!.month, vigenciaDesde!.day).toUtc().toIso8601String(),
      'vigencia_hasta': vigenciaHasta == null
          ? null
          : DateTime(vigenciaHasta!.year, vigenciaHasta!.month, vigenciaHasta!.day, 23, 59, 59).toUtc().toIso8601String(),
      'destacado': destacado,
      'activo': activo,
      'fecha_actualizacion': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Beneficio copyWith({String? imagenUrl, bool quitarImagen = false}) {
    return Beneficio(
      id: id,
      titulo: titulo,
      comercio: comercio,
      categoria: categoria,
      descripcion: descripcion,
      ubicacion: ubicacion,
      condiciones: condiciones,
      codigoCanje: codigoCanje,
      imagenUrl: quitarImagen ? null : (imagenUrl ?? this.imagenUrl),
      vigenciaDesde: vigenciaDesde,
      vigenciaHasta: vigenciaHasta,
      destacado: destacado,
      activo: activo,
    );
  }
}

/// Errores de validación del formulario, por campo. Vacío si todo está bien.
///
///  - E2: faltan el título, el comercio o la categoría.
///  - E1: la fecha de término es anterior a la de inicio.
Map<String, String> validarBeneficio({
  required String titulo,
  required String comercio,
  required String? categoria,
  DateTime? vigenciaDesde,
  DateTime? vigenciaHasta,
}) {
  final errores = <String, String>{};
  if (titulo.trim().isEmpty) errores['titulo'] = 'Ingresa el título del beneficio.';
  if (comercio.trim().isEmpty) errores['comercio'] = 'Ingresa el comercio.';
  if (categoria == null || !kCategoriasBeneficio.containsKey(categoria)) {
    errores['categoria'] = 'Elige una categoría.';
  }
  if (vigenciaDesde != null && vigenciaHasta != null && vigenciaHasta.isBefore(vigenciaDesde)) {
    errores['vigencia'] = 'La fecha de término no puede ser anterior a la de inicio.';
  }
  return errores;
}

/// E3: devuelve el motivo por el que la imagen no sirve, o null si es válida.
String? validarImagenBeneficio({required String nombre, required int bytes}) {
  final n = nombre.toLowerCase();
  final formatoValido = n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.webp');
  if (!formatoValido) return 'Formato no válido. Usa una imagen JPG, PNG o WebP.';
  if (bytes <= 0) return 'El archivo está vacío.';
  if (bytes > kPesoMaximoImagenBytes) {
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return 'La imagen pesa $mb MB y el máximo es 2 MB. Elige una más liviana.';
  }
  return null;
}

/// Tipo MIME según la extensión de la imagen.
String mimeDeImagen(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

enum EstadoBeneficio { activo, programado, vencido, inactivo }

String etiquetaEstadoBeneficio(EstadoBeneficio e) {
  switch (e) {
    case EstadoBeneficio.activo:
      return 'Activo';
    case EstadoBeneficio.programado:
      return 'Programado';
    case EstadoBeneficio.vencido:
      return 'Vencido';
    case EstadoBeneficio.inactivo:
      return 'Inactivo';
  }
}

/// Estado real de un beneficio hoy. Un beneficio desactivado es "inactivo" aunque
/// su vigencia no haya terminado; uno activo puede estar "programado" (empieza
/// más adelante) o "vencido" (su vigencia ya terminó).
EstadoBeneficio estadoBeneficio(Beneficio b, {DateTime? hoy}) {
  if (!b.activo) return EstadoBeneficio.inactivo;
  final ahora = hoy ?? DateTime.now();
  final dia = DateTime(ahora.year, ahora.month, ahora.day);
  if (b.vigenciaHasta != null && b.vigenciaHasta!.isBefore(dia)) return EstadoBeneficio.vencido;
  if (b.vigenciaDesde != null && b.vigenciaDesde!.isAfter(dia)) return EstadoBeneficio.programado;
  return EstadoBeneficio.activo;
}

/// Filtra la lista por texto (título o comercio), categoría y estado. Los
/// destacados van primero y luego se ordena por título.
List<Beneficio> filtrarBeneficios(
  List<Beneficio> lista, {
  String texto = '',
  String? categoria,
  EstadoBeneficio? estado,
  DateTime? hoy,
}) {
  final q = texto.trim().toLowerCase();
  final filtrados = lista.where((b) {
    if (q.isNotEmpty && !b.titulo.toLowerCase().contains(q) && !b.comercio.toLowerCase().contains(q)) return false;
    if (categoria != null && b.categoria != categoria) return false;
    if (estado != null && estadoBeneficio(b, hoy: hoy) != estado) return false;
    return true;
  }).toList();

  filtrados.sort((a, b) {
    if (a.destacado != b.destacado) return a.destacado ? -1 : 1;
    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  });
  return filtrados;
}
