const List<String> kTiposCombustible = [
  'Bencina',
  'Diésel',
  'Híbrido',
  'Eléctrico',
];

class VehiculoModel {
  final String id;
  final String usuarioId;
  final String patente;
  final String categoria; // AUTO, CAMIONETA, MOTO
  final String marca;
  final String? modelo;
  final int? anio;
  final String? tipoCombustible;
  final double? kilometraje;
  final String? alias;
  final DateTime? fechaIngreso;
  final String? fotoUrl;

  VehiculoModel({
    required this.id,
    required this.usuarioId,
    required this.patente,
    required this.categoria,
    required this.marca,
    this.modelo,
    this.anio,
    this.tipoCombustible,
    this.kilometraje,
    this.alias,
    this.fechaIngreso,
    this.fotoUrl,
  });

  factory VehiculoModel.fromJson(Map<String, dynamic> row) {
    return VehiculoModel(
      id: row['id'] ?? '',
      usuarioId: row['usuario_id'] ?? '',
      patente: row['patente'] ?? '',
      categoria: row['categoria'] ?? 'AUTO',
      marca: row['marca'] ?? 'No especificada',
      modelo: row['modelo'],
      anio: row['anio'] is int
          ? row['anio']
          : int.tryParse(row['anio']?.toString() ?? ''),
      tipoCombustible: row['tipo_combustible'],
      kilometraje: (row['kilometraje'] as num?)?.toDouble(),
      alias: row['alias'],
      fechaIngreso: row['fecha_ingreso'] != null ? DateTime.parse(row['fecha_ingreso']) : null,
      fotoUrl: row['foto_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario_id': usuarioId,
      'patente': patente,
      'categoria': categoria,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'tipo_combustible': tipoCombustible,
      'kilometraje': kilometraje,
      'alias': alias,
      'foto_url': fotoUrl,
    };
  }
}
