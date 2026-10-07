/// Filas crudas que el panel trae de la base de datos para calcular las
/// métricas. Solo contienen identificadores y números: no hay correos, nombres ni
/// ningún dato personal.
///
/// Todo se mide por la fecha en que se REGISTRÓ en la plataforma (created_at), y
/// no por la fecha del hecho (una boleta antigua subida hoy cuenta como hoy),
/// porque son métricas de uso de la aplicación.
class FilasMetricas {
  /// Totales de toda la historia, sin filtro de fechas.
  final int usuariosTotales;
  final int vehiculosTotales;

  /// Usuarios creados dentro del período: {fecha_creacion}.
  final List<Map<String, dynamic>> usuarios;

  /// TODOS los vehículos (sirven para saber de quién es cada documento):
  /// {id, usuario_id, created_at}.
  final List<Map<String, dynamic>> vehiculos;

  /// Registros hechos dentro del período.
  final List<Map<String, dynamic>> viajes; // {usuario_id, created_at, total_cost}
  final List<Map<String, dynamic>> cargas; // {usuario_id, created_at, total, origen}
  final List<Map<String, dynamic>> mantenciones; // {usuario_id, created_at, costo, origen}
  final List<Map<String, dynamic>> estacionamientos; // {usuario_id, created_at, costo, origen}
  final List<Map<String, dynamic>> documentos; // {vehiculo_id, fecha_actualizacion, origen}
  final List<Map<String, dynamic>> boletas; // {usuario_id, created_at, ai_report}

  const FilasMetricas({
    required this.usuariosTotales,
    required this.vehiculosTotales,
    this.usuarios = const [],
    this.vehiculos = const [],
    this.viajes = const [],
    this.cargas = const [],
    this.mantenciones = const [],
    this.estacionamientos = const [],
    this.documentos = const [],
    this.boletas = const [],
  });
}

class FilaCrecimiento {
  /// Primer día del mes.
  final DateTime mes;
  final int usuariosNuevos;
  final int vehiculosNuevos;
  final int registros;
  final int documentosIa;

  const FilaCrecimiento({
    required this.mes,
    required this.usuariosNuevos,
    required this.vehiculosNuevos,
    required this.registros,
    required this.documentosIa,
  });
}

class MetricasUso {
  final DateTime desde;
  final DateTime hasta;

  final int usuariosTotales;
  final int usuariosNuevos;

  /// Usuarios que registraron algo en el período.
  final int usuariosActivos;
  final int vehiculosTotales;
  final int vehiculosNuevos;

  /// Documentos procesados por IA en el período, por módulo.
  final Map<String, int> iaPorModulo;

  /// Registros creados en el período, por módulo.
  final Map<String, int> registrosPorModulo;

  /// Gasto registrado en el período, por categoría (pesos).
  final Map<String, double> gastoPorCategoria;
  final List<FilaCrecimiento> crecimiento;

  const MetricasUso({
    required this.desde,
    required this.hasta,
    required this.usuariosTotales,
    required this.usuariosNuevos,
    required this.usuariosActivos,
    required this.vehiculosTotales,
    required this.vehiculosNuevos,
    required this.iaPorModulo,
    required this.registrosPorModulo,
    required this.gastoPorCategoria,
    required this.crecimiento,
  });

  int get iaTotal => iaPorModulo.values.fold(0, (a, b) => a + b);
  int get registrosTotal => registrosPorModulo.values.fold(0, (a, b) => a + b);
  double get gastoTotal => gastoPorCategoria.values.fold(0.0, (a, b) => a + b);
}

DateTime? _fecha(Map<String, dynamic> fila, String clave) {
  final v = fila[clave];
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

double _numero(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

bool _esIa(Map<String, dynamic> fila) => fila['origen'] == 'ia';

/// Primer instante y último instante del período, contando los días completos.
({DateTime inicio, DateTime fin}) limitesDelPeriodo(DateTime desde, DateTime hasta) => (
      inicio: DateTime(desde.year, desde.month, desde.day),
      fin: DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999),
    );

/// Máximo de meses que muestra la tabla de crecimiento.
const int kMaximoMesesCrecimiento = 24;

/// Calcula todas las métricas del período [desde]–[hasta] (ambos días incluidos)
/// a partir de las filas crudas. Solo cuenta lo que cae dentro del período.
MetricasUso calcularMetricas(FilasMetricas f, {required DateTime desde, required DateTime hasta}) {
  final (inicio: inicio, fin: fin) = limitesDelPeriodo(desde, hasta);

  bool dentro(DateTime? d) => d != null && !d.isBefore(inicio) && !d.isAfter(fin);
  List<Map<String, dynamic>> delPeriodo(List<Map<String, dynamic>> filas, String clave) =>
      filas.where((r) => dentro(_fecha(r, clave))).toList();

  final usuarios = delPeriodo(f.usuarios, 'fecha_creacion');
  final vehiculosNuevos = delPeriodo(f.vehiculos, 'created_at');
  final viajes = delPeriodo(f.viajes, 'created_at');
  final cargas = delPeriodo(f.cargas, 'created_at');
  final mantenciones = delPeriodo(f.mantenciones, 'created_at');
  final estacionamientos = delPeriodo(f.estacionamientos, 'created_at');
  final documentos = delPeriodo(f.documentos, 'fecha_actualizacion');
  final boletas = delPeriodo(f.boletas, 'created_at');

  // Un documento no guarda el usuario, solo su vehículo: se busca el dueño.
  final duenoDeVehiculo = {
    for (final v in f.vehiculos)
      if (v['id'] != null && v['usuario_id'] != null) v['id'].toString(): v['usuario_id'].toString(),
  };

  final activos = <String>{
    for (final r in [...viajes, ...cargas, ...mantenciones, ...estacionamientos, ...boletas])
      if (r['usuario_id'] != null) r['usuario_id'].toString(),
    for (final d in documentos)
      if (duenoDeVehiculo[d['vehiculo_id']?.toString()] != null) duenoDeVehiculo[d['vehiculo_id'].toString()]!,
  };

  bool boletaConIa(Map<String, dynamic> b) => (b['ai_report']?.toString().trim().isNotEmpty ?? false);

  final iaPorModulo = <String, int>{
    'Documentos del vehículo': documentos.where(_esIa).length,
    'Mantenciones': mantenciones.where(_esIa).length,
    'Estacionamientos': estacionamientos.where(_esIa).length,
    'Combustible': cargas.where(_esIa).length,
    'Boletas de peaje': boletas.where(boletaConIa).length,
  };

  final registrosPorModulo = <String, int>{
    'Viajes': viajes.length,
    'Combustible': cargas.length,
    'Mantenciones': mantenciones.length,
    'Estacionamientos': estacionamientos.length,
  };

  double suma(List<Map<String, dynamic>> filas, String clave) => filas.fold(0.0, (a, r) => a + _numero(r[clave]));

  final gastoPorCategoria = <String, double>{
    'Peajes': suma(viajes, 'total_cost'),
    'Combustible': suma(cargas, 'total'),
    'Mantenciones': suma(mantenciones, 'costo'),
    'Estacionamientos': suma(estacionamientos, 'costo'),
  };

  // ── Crecimiento mensual ───────────────────────────────────────────
  var mes = DateTime(inicio.year, inicio.month);
  final ultimoMes = DateTime(fin.year, fin.month);
  final meses = <DateTime>[];
  while (!mes.isAfter(ultimoMes)) {
    meses.add(mes);
    mes = DateTime(mes.year, mes.month + 1);
  }
  final mesesMostrados = meses.length > kMaximoMesesCrecimiento
      ? meses.sublist(meses.length - kMaximoMesesCrecimiento)
      : meses;

  int enMes(List<Map<String, dynamic>> filas, String clave, DateTime m) => filas.where((r) {
        final d = _fecha(r, clave);
        return d != null && d.year == m.year && d.month == m.month;
      }).length;

  final crecimiento = [
    for (final m in mesesMostrados)
      FilaCrecimiento(
        mes: m,
        usuariosNuevos: enMes(usuarios, 'fecha_creacion', m),
        vehiculosNuevos: enMes(vehiculosNuevos, 'created_at', m),
        registros: enMes(viajes, 'created_at', m) +
            enMes(cargas, 'created_at', m) +
            enMes(mantenciones, 'created_at', m) +
            enMes(estacionamientos, 'created_at', m),
        documentosIa: enMes(documentos.where(_esIa).toList(), 'fecha_actualizacion', m) +
            enMes(mantenciones.where(_esIa).toList(), 'created_at', m) +
            enMes(estacionamientos.where(_esIa).toList(), 'created_at', m) +
            enMes(cargas.where(_esIa).toList(), 'created_at', m) +
            enMes(boletas.where(boletaConIa).toList(), 'created_at', m),
      ),
  ];

  return MetricasUso(
    desde: inicio,
    hasta: DateTime(fin.year, fin.month, fin.day),
    usuariosTotales: f.usuariosTotales,
    usuariosNuevos: usuarios.length,
    usuariosActivos: activos.length,
    vehiculosTotales: f.vehiculosTotales,
    vehiculosNuevos: vehiculosNuevos.length,
    iaPorModulo: iaPorModulo,
    registrosPorModulo: registrosPorModulo,
    gastoPorCategoria: gastoPorCategoria,
    crecimiento: crecimiento,
  );
}

/// 1234567 -> "1.234.567"
String formatoMilesEs(num valor) {
  final redondeado = valor.round();
  final texto = redondeado.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return '${redondeado < 0 ? '-' : ''}$buffer';
}

/// 129900 -> "\$129.900"
String formatoPesosEs(num monto) => '\$${formatoMilesEs(monto)}';

const _nombresMeses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// DateTime(2026, 9) -> "septiembre 2026"
String etiquetaMes(DateTime mes) => '${_nombresMeses[mes.month - 1]} ${mes.year}';
