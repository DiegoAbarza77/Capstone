import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_history.dart';
import 'cache_offline.dart';

class HistoryService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<void> saveTrip(TripHistory trip) async {
    try {
      await _client.from('trips').insert({
        ...trip.toMap(),
        'usuario_id': _userId,
      });
    } catch (e) {
      print('Error saving trip: $e');
      rethrow;
    }
  }

  Future<void> updateMonthlyLimit(double limit) async {
    await _client.from('usuarios').update({
      'limite_presupuesto_mensual': limit,
    }).eq('id', _userId);
  }

  Stream<double> getMonthlyLimit() {
    return _client
        .from('usuarios')
        .stream(primaryKey: ['id'])
        .eq('id', _userId)
        .map((rows) {
      if (rows.isEmpty) return 50000.0; // Valor por defecto
      final val = rows.first['limite_presupuesto_mensual'];
      if (val is num) return val.toDouble();
      return 50000.0;
    });
  }

  Stream<List<TripHistory>> getTripHistory() {
    return CacheOffline.filas(
      'trips',
      _client.from('trips').stream(primaryKey: ['id']).eq('usuario_id', _userId).order('date', ascending: false),
    ).map((rows) => rows.map((row) => TripHistory.fromJson(row)).toList());
  }

  Future<Map<String, dynamic>?> getPrincipalVehicleInfo() async {
    final userRow = await _client
        .from('usuarios')
        .select('vehiculo_principal_patente')
        .eq('id', _userId)
        .maybeSingle();
    final patente = userRow?['vehiculo_principal_patente'];
    if (patente == null) return null;

    final rows = await _client
        .from('vehiculos')
        .select()
        .eq('usuario_id', _userId)
        .eq('patente', patente)
        .limit(1);

    if (rows.isNotEmpty) {
      return rows.first;
    }
    return {'patente': patente, 'marca': 'Vehículo Principal'};
  }

  Future<List<Map<String, dynamic>>> getUserVehicles() async {
    return await _client.from('vehiculos').select().eq('usuario_id', _userId);
  }

  // --- GESTIÓN DE ALERTAS (Para evitar spam) ---

  Future<bool> hasAlertBeenNotified(int threshold) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month}_$threshold";

    final row = await _client
        .from('usuarios')
        .select('alertas_vistas')
        .eq('id', _userId)
        .maybeSingle();
    if (row == null) return false;

    final alertas = Map<String, dynamic>.from(row['alertas_vistas'] ?? {});
    return alertas.containsKey(monthKey);
  }

  Future<void> markAlertAsNotified(int threshold) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month}_$threshold";

    final row = await _client
        .from('usuarios')
        .select('alertas_vistas')
        .eq('id', _userId)
        .maybeSingle();
    final alertas = Map<String, dynamic>.from(row?['alertas_vistas'] ?? {});
    alertas[monthKey] = true;

    await _client.from('usuarios').update({'alertas_vistas': alertas}).eq('id', _userId);
  }
}
