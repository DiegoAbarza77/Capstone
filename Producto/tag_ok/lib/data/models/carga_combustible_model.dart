/// Tipos de energía que se pueden cargar. "Híbrido" no es una opción acá: un
/// híbrido carga bencina o electricidad en momentos distintos.
const List<String> kTiposEnergiaCarga = ['Bencina', 'Diésel', 'Eléctrico'];

/// Unidad en la que se mide la carga según el tipo de energía.
String unidadParaTipo(String? tipoEnergia) => tipoEnergia == 'Eléctrico' ? 'kwh' : 'litros';

String etiquetaUnidad(String unidad) => unidad == 'kwh' ? 'kWh' : 'L';

class CargaCombustibleModel {
  final String id;
  final String vehiculoId;
  final String vehiculoPatente;
  final DateTime fecha;
  final double? kilometraje;
  final String estacion;
  final String? tipoCombustible;

  /// Cantidad cargada, en [unidad] (litros o kWh). Es 0 si no se registró.
  final double litros;

  /// Precio por unidad. Es 0 si no se registró.
  final double precioLitro;
  final double total;

  /// 'litros' o 'kwh'.
  final String unidad;

  /// 'manual' o 'ia'.
  final String origen;
  final DateTime? aiCapturadoEn;
  final String? archivoNombre;

  /// Si se llenó el estanque (o la batería): habilita calcular el rendimiento.
  final bool tanqueLleno;

  CargaCombustibleModel({
    required this.id,
    required this.vehiculoId,
    required this.vehiculoPatente,
    required this.fecha,
    this.kilometraje,
    this.estacion = '',
    this.tipoCombustible,
    this.litros = 0,
    this.precioLitro = 0,
    this.total = 0,
    this.unidad = 'litros',
    this.origen = 'manual',
    this.aiCapturadoEn,
    this.archivoNombre,
    this.tanqueLleno = false,
  });

  /// Alias más claro para el código nuevo: la columna se llama "litros" por
  /// historia, pero guarda litros o kWh.
  double get cantidad => litros;

  String get etiquetaCantidad => etiquetaUnidad(unidad);

  factory CargaCombustibleModel.fromJson(Map<String, dynamic> row) {
    return CargaCombustibleModel(
      id: row['id'] ?? '',
      vehiculoId: row['vehiculo_id'] ?? '',
      vehiculoPatente: row['vehiculo_patente'] ?? '',
      fecha: DateTime.parse(row['fecha']),
      kilometraje: (row['kilometraje'] as num?)?.toDouble(),
      estacion: row['estacion'] ?? '',
      tipoCombustible: row['tipo_combustible'],
      litros: (row['litros'] as num?)?.toDouble() ?? 0.0,
      precioLitro: (row['precio_litro'] as num?)?.toDouble() ?? 0.0,
      total: (row['total'] as num?)?.toDouble() ?? 0.0,
      unidad: row['unidad'] ?? 'litros',
      origen: row['origen'] ?? 'manual',
      aiCapturadoEn: row['ai_capturado_en'] != null ? DateTime.parse(row['ai_capturado_en']) : null,
      archivoNombre: row['archivo_nombre'],
      tanqueLleno: row['tanque_lleno'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehiculo_id': vehiculoId,
      'vehiculo_patente': vehiculoPatente,
      'fecha': fecha.toIso8601String(),
      'kilometraje': kilometraje,
      'estacion': estacion.isEmpty ? null : estacion,
      'tipo_combustible': tipoCombustible,
      'litros': litros,
      'precio_litro': precioLitro,
      'total': total,
      'unidad': unidad,
      'origen': origen,
      'ai_capturado_en': aiCapturadoEn?.toIso8601String(),
      'archivo_nombre': archivoNombre,
      'tanque_lleno': tanqueLleno,
    };
  }
}
