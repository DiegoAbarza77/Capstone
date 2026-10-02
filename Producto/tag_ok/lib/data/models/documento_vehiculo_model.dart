import 'package:intl/intl.dart';

const List<Map<String, String>> kTiposDocumentoVehiculo = [
  {'id': 'permiso_circulacion', 'label': 'Permiso de Circulación'},
  {'id': 'revision_tecnica', 'label': 'Revisión Técnica'},
  {'id': 'soap', 'label': 'SOAP'},
  {'id': 'seguro', 'label': 'Seguro Automotriz'},
];

enum EstadoVencimiento { alDia, atencion, vencido, sinDatos }

class DocumentoVehiculoModel {
  final String tipo;
  final String? numero;
  final DateTime? fechaEmision;
  final DateTime? fechaVencimiento;
  final String? compania;
  // Trazabilidad de "Registro Inteligente": de dónde salió el dato
  // (tipeo manual o extracción de IA), su fecha de captura y el nombre del
  // archivo que se analizó -- la regla es que la IA nunca guarda sola, así
  // que "origen: ia" siempre implica que un usuario confirmó estos datos.
  final String origen;
  final DateTime? aiCapturadoEn;
  final String? archivoNombre;

  DocumentoVehiculoModel({
    required this.tipo,
    this.numero,
    this.fechaEmision,
    this.fechaVencimiento,
    this.compania,
    this.origen = 'manual',
    this.aiCapturadoEn,
    this.archivoNombre,
  });

  String get label => kTiposDocumentoVehiculo.firstWhere(
        (t) => t['id'] == tipo,
        orElse: () => {'label': tipo},
      )['label']!;

  EstadoVencimiento get estado {
    if (fechaVencimiento == null) return EstadoVencimiento.sinDatos;
    final dias = fechaVencimiento!.difference(DateTime.now()).inDays;
    if (dias < 0) return EstadoVencimiento.vencido;
    if (dias <= 30) return EstadoVencimiento.atencion;
    return EstadoVencimiento.alDia;
  }

  /// Días que faltan para el vencimiento (negativo si ya venció), o null si no
  /// hay fecha. Misma cuenta que usa [estado].
  int? get diasParaVencer => fechaVencimiento?.difference(DateTime.now()).inDays;

  /// Texto corto para mostrar junto al documento: "Vence en 25 días" cuando
  /// está cerca, la fecha cuando está lejos, y "Vencido hace N días".
  String get textoVencimiento {
    final dias = diasParaVencer;
    if (dias == null) return 'Sin datos';
    if (dias < 0) {
      final atraso = -dias;
      return 'Vencido hace $atraso ${atraso == 1 ? 'día' : 'días'}';
    }
    if (dias == 0) return 'Vence hoy';
    if (dias <= 60) return 'Vence en $dias ${dias == 1 ? 'día' : 'días'}';
    return 'Vence ${DateFormat('dd/MM/yyyy').format(fechaVencimiento!)}';
  }

  factory DocumentoVehiculoModel.fromJson(
    String tipo,
    Map<String, dynamic>? row,
  ) {
    if (row == null) return DocumentoVehiculoModel(tipo: tipo);
    return DocumentoVehiculoModel(
      tipo: tipo,
      numero: row['numero'],
      fechaEmision: row['fecha_emision'] != null ? DateTime.parse(row['fecha_emision']) : null,
      fechaVencimiento: row['fecha_vencimiento'] != null ? DateTime.parse(row['fecha_vencimiento']) : null,
      compania: row['compania'],
      origen: row['origen'] ?? 'manual',
      aiCapturadoEn: row['ai_capturado_en'] != null ? DateTime.parse(row['ai_capturado_en']) : null,
      archivoNombre: row['archivo_nombre'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'fecha_emision': fechaEmision?.toIso8601String(),
      'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      'compania': compania,
      'origen': origen,
      'ai_capturado_en': aiCapturadoEn?.toIso8601String(),
      'archivo_nombre': archivoNombre,
    };
  }
}

/// Combina el estado de varios documentos en el peor caso (el más urgente).
EstadoVencimiento peorEstado(List<EstadoVencimiento> estados) {
  if (estados.contains(EstadoVencimiento.vencido)) return EstadoVencimiento.vencido;
  if (estados.contains(EstadoVencimiento.atencion)) return EstadoVencimiento.atencion;
  if (estados.contains(EstadoVencimiento.sinDatos)) return EstadoVencimiento.sinDatos;
  return EstadoVencimiento.alDia;
}

/// Etiqueta del estado *general* del vehículo (distinta de la etiqueta por
/// documento individual): los tres textos que pide el checklist maestro.
String labelEstadoGeneralVehiculo(EstadoVencimiento estado) {
  switch (estado) {
    case EstadoVencimiento.alDia:
      return 'Todo al día';
    case EstadoVencimiento.atencion:
      return 'Próximo vencimiento';
    case EstadoVencimiento.vencido:
      return 'Atención requerida';
    case EstadoVencimiento.sinDatos:
      return 'Sin datos';
  }
}
