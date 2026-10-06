/// Un estacionamiento: una sesión del cronómetro o un registro manual / leído de
/// un ticket.
class EstacionamientoModel {
  final String id;
  final String vehiculoId;

  /// Día del estacionamiento (sin hora).
  final DateTime fecha;
  final String? lugar;
  final String? direccion;

  /// Ubicación GPS de dónde quedó el auto; ambas son null o ninguna.
  final double? lat;
  final double? lng;
  final DateTime? horaEntrada;
  final DateTime? horaSalida;

  /// Duración leída de un ticket que no trae las dos horas.
  final int? duracionMinutos;
  final double costo;
  final String? observaciones;

  /// true mientras el cronómetro corre.
  final bool enCurso;
  final String? documentoPath;
  final String? documentoNombre;

  /// 'manual' o 'ia'.
  final String origen;
  final DateTime? aiCapturadoEn;

  const EstacionamientoModel({
    this.id = '',
    required this.vehiculoId,
    required this.fecha,
    this.lugar,
    this.direccion,
    this.lat,
    this.lng,
    this.horaEntrada,
    this.horaSalida,
    this.duracionMinutos,
    this.costo = 0,
    this.observaciones,
    this.enCurso = false,
    this.documentoPath,
    this.documentoNombre,
    this.origen = 'manual',
    this.aiCapturadoEn,
  });

  bool get tieneUbicacion => lat != null && lng != null;
  bool get tieneDocumento => documentoPath != null && documentoPath!.isNotEmpty;

  /// Nombre para mostrar en listas.
  String get titulo {
    final l = lugar?.trim();
    return l != null && l.isNotEmpty ? l : 'Estacionamiento';
  }

  /// Cuánto duró (o lleva durando, si el cronómetro corre). Se calcula siempre
  /// contra la hora de inicio guardada, así sigue correcto aunque la app se haya
  /// cerrado. Si no hay las dos horas, usa la duración leída del ticket.
  Duration? duracion({DateTime? ahora}) {
    final entrada = horaEntrada;
    if (enCurso && entrada != null) {
      final d = (ahora ?? DateTime.now()).difference(entrada);
      return d.isNegative ? Duration.zero : d;
    }
    final salida = horaSalida;
    if (entrada != null && salida != null) return salida.difference(entrada);
    if (duracionMinutos != null) return Duration(minutes: duracionMinutos!);
    return null;
  }

  /// Momento para ordenar la lista: la hora de entrada si la hay, y si no el día.
  DateTime get momento => horaEntrada ?? fecha;

  factory EstacionamientoModel.fromJson(Map<String, dynamic> row) {
    DateTime? instante(dynamic v) => v == null ? null : DateTime.parse(v.toString()).toLocal();

    // La fecha se guarda al mediodía UTC para que no cambie de día al pasarla a
    // la hora de Chile (ver toJson).
    final fecha = DateTime.parse(row['fecha']).toLocal();

    return EstacionamientoModel(
      id: row['id'] ?? '',
      vehiculoId: row['vehiculo_id'] ?? '',
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      lugar: row['lugar'],
      direccion: row['direccion'],
      lat: (row['lat'] as num?)?.toDouble(),
      lng: (row['lng'] as num?)?.toDouble(),
      horaEntrada: instante(row['hora_entrada']),
      horaSalida: instante(row['hora_salida']),
      duracionMinutos: (row['duracion_minutos'] as num?)?.toInt(),
      costo: (row['costo'] as num?)?.toDouble() ?? 0,
      observaciones: row['observaciones'],
      enCurso: row['en_curso'] ?? false,
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
      'lugar': textoONulo(lugar),
      'direccion': textoONulo(direccion),
      'lat': lat,
      'lng': lng,
      'hora_entrada': horaEntrada?.toUtc().toIso8601String(),
      'hora_salida': horaSalida?.toUtc().toIso8601String(),
      'duracion_minutos': duracionMinutos,
      'costo': costo,
      'observaciones': textoONulo(observaciones),
      'en_curso': enCurso,
      'documento_path': documentoPath,
      'documento_nombre': documentoNombre,
      'origen': origen,
      'ai_capturado_en': aiCapturadoEn?.toUtc().toIso8601String(),
    };
  }

  EstacionamientoModel copyWith({
    String? id,
    String? documentoPath,
    String? documentoNombre,
  }) {
    return EstacionamientoModel(
      id: id ?? this.id,
      vehiculoId: vehiculoId,
      fecha: fecha,
      lugar: lugar,
      direccion: direccion,
      lat: lat,
      lng: lng,
      horaEntrada: horaEntrada,
      horaSalida: horaSalida,
      duracionMinutos: duracionMinutos,
      costo: costo,
      observaciones: observaciones,
      enCurso: enCurso,
      documentoPath: documentoPath ?? this.documentoPath,
      documentoNombre: documentoNombre ?? this.documentoNombre,
      origen: origen,
      aiCapturadoEn: aiCapturadoEn,
    );
  }
}
