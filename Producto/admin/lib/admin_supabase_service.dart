import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'beneficio_logica.dart';
import 'metricas_logica.dart';

class AdminOverview {
  const AdminOverview({
    required this.users,
    required this.vehicles,
    required this.porticos,
    required this.tariffs,
  });

  final int users;
  final int vehicles;
  final int porticos;
  final int tariffs;
}

class ReportMetrics {
  const ReportMetrics({
    required this.totalUsers,
    required this.totalVehicles,
    required this.totalTrips,
    required this.totalTollCost,
    required this.averageCostPerTrip,
    required this.costByHighway,
  });

  final int totalUsers;
  final int totalVehicles;
  final int totalTrips;
  final double totalTollCost;
  final double averageCostPerTrip;
  final Map<String, double> costByHighway;
}

class AdminSupabaseService {
  AdminSupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String _classifyHighway(String tollName) {
    final name = tollName.toLowerCase();
    if (name.contains('autopista de conexión') || name.contains('conexión')) {
      return 'Conexión / Otras';
    }
    if (name.startsWith('pa') ||
        name.contains('autopista central') ||
        name.contains('ruta 5')) {
      return 'Autopista Central';
    }
    if (name.contains('costanera') ||
        name.contains('vivaceta') ||
        name.contains('lo saldes') ||
        name.contains('la dehesa') ||
        name.contains('estoril') ||
        name.contains('padre arteaga') ||
        name.contains('tranqueras') ||
        name.contains('carrascal') ||
        name.contains('padre hurtado') ||
        name.startsWith('ev ') ||
        name.startsWith('sv ')) {
      return 'Costanera Norte';
    }
    if (name.contains('avo') ||
        name.contains('kennedy') ||
        name.contains('p101') ||
        name.contains('p102') ||
        name.contains('vespucio oriente')) {
      return 'Vespucio Oriente (AVO)';
    }
    if (name.contains('vespucio norte') ||
        name.contains('guanaco') ||
        name.contains('el salto') ||
        name.contains('lo boza') ||
        name.contains('recabal') ||
        name.contains('enea') ||
        name.contains('p14') ||
        name.contains('p13') ||
        name.contains('p12') ||
        name.contains('p15')) {
      return 'Vespucio Norte';
    }
    if (name.contains('vespucio sur') ||
        name.contains('pvs') ||
        name.contains('velásquez') ||
        name.contains('velasquez') ||
        name.contains('gran avenida') ||
        name.contains('santa rosa') ||
        name.contains('vicuña mackenna') ||
        name.contains('alderete') ||
        name.contains('2a transversal') ||
        name.contains('los mares') ||
        name.contains('coronel') ||
        name.contains('camino a melipilla')) {
      return 'Vespucio Sur';
    }
    if (name.contains('ruta 68')) {
      return 'Conexión / Otras';
    }
    if (name.contains('ruta 78') || name.contains('autopista del sol')) {
      return 'Conexión / Otras';
    }
    return 'Conexión / Otras';
  }

  Future<ReportMetrics> fetchReportMetrics() async {
    final users = await _client.from('usuarios').select('id').count(CountOption.exact);
    final vehicles = await _client.from('vehiculos').select('id').count(CountOption.exact);
    // RLS (is_admin() OR usuario_id = auth.uid()) le da al admin visibilidad
    // de los viajes de todos los usuarios; reemplaza al collectionGroup('trips') de Firestore.
    final tripsRows = await _client.from('trips').select('total_cost, tolls');

    final int totalUsers = users.count;
    final int totalVehicles = vehicles.count;
    final int totalTrips = tripsRows.length;

    double totalTollCost = 0.0;
    final Map<String, double> costByHighway = {
      'Autopista Central': 0.0,
      'Costanera Norte': 0.0,
      'Vespucio Norte': 0.0,
      'Vespucio Sur': 0.0,
      'Vespucio Oriente (AVO)': 0.0,
      'Conexión / Otras': 0.0,
    };

    for (var row in tripsRows) {
      final double tripCost = (row['total_cost'] as num?)?.toDouble() ?? 0.0;
      totalTollCost += tripCost;

      final List<dynamic> tollsList = row['tolls'] as List<dynamic>? ?? [];
      for (var tollRaw in tollsList) {
        if (tollRaw is Map) {
          final String tollName = (tollRaw['name'] ?? '').toString();
          final double tollCost =
              double.tryParse(tollRaw['cost']?.toString() ?? '0') ?? 0.0;
          final String highway = _classifyHighway(tollName);

          if (costByHighway.containsKey(highway)) {
            costByHighway[highway] = costByHighway[highway]! + tollCost;
          } else {
            costByHighway['Conexión / Otras'] =
                costByHighway['Conexión / Otras']! + tollCost;
          }
        }
      }
    }

    final double averageCostPerTrip = totalTrips > 0
        ? (totalTollCost / totalTrips)
        : 0.0;

    return ReportMetrics(
      totalUsers: totalUsers,
      totalVehicles: totalVehicles,
      totalTrips: totalTrips,
      totalTollCost: totalTollCost,
      averageCostPerTrip: averageCostPerTrip,
      costByHighway: costByHighway,
    );
  }

  Future<AdminOverview> fetchOverview() async {
    final results = await Future.wait([
      _count('usuarios'),
      _count('vehiculos'),
      _count('porticos'),
      _count('tarifas'),
    ]);

    return AdminOverview(
      users: results[0],
      vehicles: results[1],
      porticos: results[2],
      tariffs: results[3],
    );
  }

  Stream<List<Map<String, dynamic>>> streamUsers() {
    return _client.from('usuarios').stream(primaryKey: ['id']);
  }

  Stream<List<Map<String, dynamic>>> streamPorticos() {
    return _client.from('porticos').stream(primaryKey: ['id']);
  }

  Stream<List<Map<String, dynamic>>> streamTariffs() {
    return _client
        .from('tarifas')
        .stream(primaryKey: ['id'])
        .order('fecha_actualizacion', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamUserTrips() {
    return _client.from('trips').stream(primaryKey: ['id']).order('date', ascending: false);
  }

  Future<void> logAction({
    required String action,
    required String target,
    required String details,
  }) async {
    final String adminEmail = _client.auth.currentUser?.email ?? 'admin_desconocido';
    await _client.from('auditoria').insert({
      'admin_email': adminEmail,
      'action': action,
      'target': target,
      'details': details,
    });
  }

  Stream<List<Map<String, dynamic>>> streamAuditLogs() {
    return _client
        .from('auditoria')
        .stream(primaryKey: ['id'])
        .order('fecha', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamAdministradores() {
    return _client.from('administradores').stream(primaryKey: ['id']);
  }

  Future<void> updateAdminRole(String docId, String role) async {
    await _client.from('administradores').update({'rol': role}).eq('id', docId);
  }

  /// Borra al administrador y su cuenta de Auth completa a través de la
  /// Edge Function "delete-user" (requiere la service-role key en el
  /// servidor, no disponible en el cliente Flutter). Evita dejar cuentas de
  /// Auth huérfanas, a diferencia del borrado directo de Firestore de antes.
  Future<void> deleteAdmin(String docId) async {
    final response = await _client.functions.invoke(
      'delete-user',
      body: {'userId': docId},
    );
    if (response.status != 200) {
      throw Exception('No se pudo eliminar el administrador: ${response.data}');
    }
  }

  // ── Beneficios (CU19) ──────────────────────────────────────────────

  /// Todos los beneficios, activos o no: las políticas de la base de datos le
  /// dan al administrador visibilidad completa.
  Stream<List<Beneficio>> streamBeneficios() {
    return _client
        .from('beneficios')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(Beneficio.fromJson).toList());
  }

  static const _bucketImagenes = 'beneficios_imagenes';

  /// Sube la imagen promocional y devuelve su dirección pública. Lanza una
  /// excepción si Storage la rechaza (formato o peso no permitidos).
  Future<String> subirImagenBeneficio({required Uint8List bytes, required String nombre}) async {
    // Solo letras, números y algunos signos: el nombre original puede traer
    // espacios o caracteres que no son válidos en una ruta de Storage.
    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ruta = '${DateTime.now().millisecondsSinceEpoch}_$limpio';
    await _client.storage.from(_bucketImagenes).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: mimeDeImagen(nombre)),
        );
    return _client.storage.from(_bucketImagenes).getPublicUrl(ruta);
  }

  /// Crea un beneficio (si no tiene id) o actualiza uno existente, y deja el
  /// movimiento en la bitácora de auditoría.
  Future<void> guardarBeneficio(Beneficio beneficio) async {
    final esNuevo = beneficio.id.isEmpty;
    if (esNuevo) {
      await _client.from('beneficios').insert(beneficio.toJson());
    } else {
      await _client.from('beneficios').update(beneficio.toJson()).eq('id', beneficio.id);
    }
    await _registrarSinFallar(
      action: esNuevo ? 'Crear beneficio' : 'Editar beneficio',
      target: beneficio.titulo,
      details: '${beneficio.comercio} · ${etiquetaCategoria(beneficio.categoria)}'
          ' · ${beneficio.activo ? 'activo' : 'desactivado'}',
    );
  }

  /// Activa o desactiva un beneficio, o lo marca o desmarca como destacado.
  Future<void> cambiarEstadoBeneficio(Beneficio beneficio, {bool? activo, bool? destacado}) async {
    final cambios = <String, dynamic>{
      'activo': ?activo,
      'destacado': ?destacado,
      'fecha_actualizacion': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('beneficios').update(cambios).eq('id', beneficio.id);

    final detalle = [
      if (activo != null) activo ? 'activado' : 'desactivado',
      if (destacado != null) destacado ? 'marcado como destacado' : 'quitado de destacados',
    ].join(', ');
    await _registrarSinFallar(action: 'Cambiar beneficio', target: beneficio.titulo, details: detalle);
  }

  /// La bitácora es un registro auxiliar: si falla, la acción que ya se hizo no
  /// debe darse por fallida.
  Future<void> _registrarSinFallar({required String action, required String target, required String details}) async {
    try {
      await logAction(action: action, target: target, details: details);
    } catch (e) {
      debugPrint('TAG_OK_ADMIN: no se pudo registrar en la auditoría: $e');
    }
  }

  // ── Métricas de uso (CU20) ─────────────────────────────────────────

  /// Trae TODAS las filas, de a páginas: Supabase devuelve como máximo 1.000 por
  /// consulta y, sin esto, las métricas quedarían cortadas en silencio.
  Future<List<Map<String, dynamic>>> _traerTodo(
    String tabla,
    String columnas, {
    String? columnaFecha,
    DateTime? inicio,
    DateTime? fin,
  }) async {
    const tamanoPagina = 1000;
    final filas = <Map<String, dynamic>>[];
    var desdeFila = 0;

    while (true) {
      var consulta = _client.from(tabla).select(columnas);
      if (columnaFecha != null && inicio != null) {
        consulta = consulta.gte(columnaFecha, inicio.toUtc().toIso8601String());
      }
      if (columnaFecha != null && fin != null) {
        consulta = consulta.lte(columnaFecha, fin.toUtc().toIso8601String());
      }
      final lote = await consulta.order('id').range(desdeFila, desdeFila + tamanoPagina - 1);
      filas.addAll(lote);
      if (lote.length < tamanoPagina) break;
      desdeFila += tamanoPagina;
    }
    return filas;
  }

  /// Reúne las filas necesarias para las métricas de [desde] a [hasta]. Solo
  /// pide identificadores, fechas y montos: nunca correos, nombres ni datos
  /// personales.
  Future<FilasMetricas> fetchFilasMetricas({required DateTime desde, required DateTime hasta}) async {
    final limites = limitesDelPeriodo(desde, hasta);
    final inicio = limites.inicio;
    final fin = limites.fin;

    final resultados = await Future.wait([
      _count('usuarios'),
      _count('vehiculos'),
      _traerTodo('usuarios', 'id, fecha_creacion', columnaFecha: 'fecha_creacion', inicio: inicio, fin: fin),
      _traerTodo('vehiculos', 'id, usuario_id, created_at'),
      _traerTodo('trips', 'id, usuario_id, created_at, total_cost', columnaFecha: 'created_at', inicio: inicio, fin: fin),
      _traerTodo('combustible_cargas', 'id, usuario_id, created_at, total, origen',
          columnaFecha: 'created_at', inicio: inicio, fin: fin),
      _traerTodo('mantenciones', 'id, usuario_id, created_at, costo, origen',
          columnaFecha: 'created_at', inicio: inicio, fin: fin),
      _traerTodo('estacionamientos', 'id, usuario_id, created_at, costo, origen',
          columnaFecha: 'created_at', inicio: inicio, fin: fin),
      _traerTodo('vehiculo_documentos', 'id, vehiculo_id, fecha_actualizacion, origen',
          columnaFecha: 'fecha_actualizacion', inicio: inicio, fin: fin),
      _traerTodo('audited_invoices', 'id, usuario_id, created_at, ai_report',
          columnaFecha: 'created_at', inicio: inicio, fin: fin),
    ]);

    return FilasMetricas(
      usuariosTotales: resultados[0] as int,
      vehiculosTotales: resultados[1] as int,
      usuarios: resultados[2] as List<Map<String, dynamic>>,
      vehiculos: resultados[3] as List<Map<String, dynamic>>,
      viajes: resultados[4] as List<Map<String, dynamic>>,
      cargas: resultados[5] as List<Map<String, dynamic>>,
      mantenciones: resultados[6] as List<Map<String, dynamic>>,
      estacionamientos: resultados[7] as List<Map<String, dynamic>>,
      documentos: resultados[8] as List<Map<String, dynamic>>,
      boletas: resultados[9] as List<Map<String, dynamic>>,
    );
  }

  Future<MetricasUso> fetchMetricasUso({required DateTime desde, required DateTime hasta}) async {
    final filas = await fetchFilasMetricas(desde: desde, hasta: hasta);
    return calcularMetricas(filas, desde: desde, hasta: hasta);
  }

  Future<int> _count(String table) async {
    final response = await _client.from(table).select('id').count(CountOption.exact);
    return response.count;
  }
}
