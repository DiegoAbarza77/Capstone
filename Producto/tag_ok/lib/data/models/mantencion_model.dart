/// Tipos de mantención, con el mismo identificador que acepta la base de datos.
const Map<String, String> kTiposMantencion = {
  'preventiva': 'Preventiva',
  'aceite': 'Cambio de aceite',
  'frenos': 'Frenos',
  'neumaticos': 'Neumáticos',
  'otra': 'Otra',
};

String etiquetaTipoMantencion(String? tipo) => kTiposMantencion[tipo] ?? 'Otra';

/// Una mantención, servicio o reparación realizada al vehículo.
class MantencionModel {
  final String id;
  final String vehiculoId;
  final DateTime fecha;
  final double? kilometraje;
  final String tipo;
  final String? taller;
  final double costo;
  final String? descripcion;
  final String? observaciones;

  /// Servicios realizados, tal como aparecen en la boleta ("Cambio de aceite").
  final List<String> servicios;
  final List<String> repuestos;

  /// Boleta o factura adjunta, guardada en el bucket privado mantencion_docs.
  final String? documentoPath;
  final String? documentoNombre;

  /// 'manual' o 'ia'.
  final String origen;
  final DateTime? aiCapturadoEn;

  const MantencionModel({
    this.id = '',
    required this.vehiculoId,
    required this.fecha,
    this.kilometraje,
    this.tipo = 'preventiva',
    this.taller,
    this.costo = 0,
    this.descripcion,
    this.observaciones,
    this.servicios = const [],
    this.repuestos = const [],
    this.documentoPath,
    this.documentoNombre,
    this.origen = 'manual',
    this.aiCapturadoEn,
  });

  bool get tieneDocumento => documentoPath != null && documentoPath!.isNotEmpty;

  /// Título corto para la línea de tiempo: el primer servicio si hay, y si no el tipo.
  String get titulo => servicios.isNotEmpty ? servicios.first : etiquetaTipoMantencion(tipo);

  factory MantencionModel.fromJson(Map<String, dynamic> row) {
    List<String> lista(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

    return MantencionModel(
      id: row['id'] ?? '',
      vehiculoId: row['vehiculo_id'] ?? '',
      // Se guarda al mediodía UTC para que la fecha no cambie de día al
      // convertirla a la hora de Chile (ver toJson).
      fecha: DateTime.parse(row['fecha']).toLocal(),
      kilometraje: (row['kilometraje'] as num?)?.toDouble(),
      tipo: row['tipo'] ?? 'otra',
      taller: row['taller'],
      costo: (row['costo'] as num?)?.toDouble() ?? 0,
      descripcion: row['descripcion'],
      observaciones: row['observaciones'],
      servicios: lista(row['servicios']),
      repuestos: lista(row['repuestos']),
      documentoPath: row['documento_path'],
      documentoNombre: row['documento_nombre'],
      origen: row['origen'] ?? 'manual',
      aiCapturadoEn: row['ai_capturado_en'] != null ? DateTime.parse(row['ai_capturado_en']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    String? textoONulo(String? t) => t == null || t.trim().isEmpty ? null : t.trim();

    return {
      'vehiculo_id': vehiculoId,
      // Mediodía UTC: en Chile (UTC-3 / UTC-4) sigue siendo el mismo día.
      'fecha': DateTime.utc(fecha.year, fecha.month, fecha.day, 12).toIso8601String(),
      'kilometraje': kilometraje,
      'tipo': tipo,
      'taller': textoONulo(taller),
      'costo': costo,
      'descripcion': textoONulo(descripcion),
      'observaciones': textoONulo(observaciones),
      'servicios': servicios,
      'repuestos': repuestos,
      'documento_path': documentoPath,
      'documento_nombre': documentoNombre,
      'origen': origen,
      'ai_capturado_en': aiCapturadoEn?.toIso8601String(),
    };
  }

  MantencionModel copyWith({
    String? id,
    String? documentoPath,
    String? documentoNombre,
  }) {
    return MantencionModel(
      id: id ?? this.id,
      vehiculoId: vehiculoId,
      fecha: fecha,
      kilometraje: kilometraje,
      tipo: tipo,
      taller: taller,
      costo: costo,
      descripcion: descripcion,
      observaciones: observaciones,
      servicios: servicios,
      repuestos: repuestos,
      documentoPath: documentoPath ?? this.documentoPath,
      documentoNombre: documentoNombre ?? this.documentoNombre,
      origen: origen,
      aiCapturadoEn: aiCapturadoEn,
    );
  }
}

/// Próxima mantención que el usuario programó por fecha, kilometraje o ambos.
class MantencionProgramadaModel {
  final String id;
  final String vehiculoId;
  final String tipo;
  final String? descripcion;
  final DateTime? fechaProgramada;
  final double? kmProgramado;

  /// Días de anticipación con que se avisa antes de la fecha.
  final int avisoDiasAntes;

  /// Kilómetros de anticipación con que se avisa antes del kilometraje.
  final double avisoKmAntes;
  final bool completada;

  const MantencionProgramadaModel({
    this.id = '',
    required this.vehiculoId,
    this.tipo = 'preventiva',
    this.descripcion,
    this.fechaProgramada,
    this.kmProgramado,
    this.avisoDiasAntes = 7,
    this.avisoKmAntes = 500,
    this.completada = false,
  });

  String get titulo {
    final d = descripcion?.trim();
    return d != null && d.isNotEmpty ? d : etiquetaTipoMantencion(tipo);
  }

  factory MantencionProgramadaModel.fromJson(Map<String, dynamic> row) {
    DateTime? soloFecha(dynamic v) {
      if (v == null) return null;
      final f = DateTime.parse(v.toString());
      return DateTime(f.year, f.month, f.day);
    }

    return MantencionProgramadaModel(
      id: row['id'] ?? '',
      vehiculoId: row['vehiculo_id'] ?? '',
      tipo: row['tipo'] ?? 'preventiva',
      descripcion: row['descripcion'],
      fechaProgramada: soloFecha(row['fecha_programada']),
      kmProgramado: (row['km_programado'] as num?)?.toDouble(),
      avisoDiasAntes: (row['aviso_dias_antes'] as num?)?.toInt() ?? 7,
      avisoKmAntes: (row['aviso_km_antes'] as num?)?.toDouble() ?? 500,
      completada: row['completada'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    String? fecha;
    final f = fechaProgramada;
    if (f != null) {
      fecha = '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
    }
    final d = descripcion?.trim();
    return {
      'vehiculo_id': vehiculoId,
      'tipo': tipo,
      'descripcion': d == null || d.isEmpty ? null : d,
      'fecha_programada': fecha,
      'km_programado': kmProgramado,
      'aviso_dias_antes': avisoDiasAntes,
      'aviso_km_antes': avisoKmAntes,
      'completada': completada,
    };
  }
}
