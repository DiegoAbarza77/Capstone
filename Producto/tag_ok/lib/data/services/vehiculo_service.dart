import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_vehiculo_model.dart';
import 'notificaciones_vencimiento_service.dart';

class VehiculoService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Sube el kilometraje del vehículo si [km] es mayor que el actual (o si aún
  /// no tenía uno). Devuelve true si lo actualizó. Nunca lo baja: un registro
  /// con un kilometraje menor (por ejemplo una boleta antigua) no debe retroceder
  /// el odómetro.
  Future<bool> actualizarKilometrajeSiMayor(String vehiculoId, double km) async {
    if (km <= 0) return false;
    try {
      final fila = await _client.from('vehiculos').select('kilometraje').eq('id', vehiculoId).maybeSingle();
      final actual = (fila?['kilometraje'] as num?)?.toDouble();
      if (actual != null && km <= actual) return false;
      await _client.from('vehiculos').update({'kilometraje': km}).eq('id', vehiculoId);
      return true;
    } catch (e) {
      // El registro que originó esto ya se guardó; no debe fallar por el odómetro.
      debugPrint('TAG_OK_VEHICULOS: no se pudo actualizar el kilometraje: $e');
      return false;
    }
  }

  /// Elimina un vehículo y todo lo que depende de él:
  ///  - sus cargas de combustible (la clave foránea las dejaría huérfanas, sin
  ///    vehículo, e invisibles en la app),
  ///  - el vehículo en sí, que borra en cascada sus documentos, mantenciones,
  ///    mantenciones programadas y estacionamientos,
  ///  - los archivos adjuntos de sus mantenciones, estacionamientos y cargas de
  ///    combustible (el borrado en cascada solo elimina las filas, no los archivos
  ///    de Storage),
  ///  - la marca de "vehículo principal" si era este,
  ///  - los avisos de vencimiento y de mantención programados en el dispositivo.
  Future<void> eliminar({required String vehiculoId, required String patente}) async {
    final userId = _client.auth.currentUser!.id;

    // Antes de borrar el vehículo hay que anotar qué archivos y avisos dependen
    // de él: después de borrarlo ya no hay cómo encontrarlos.
    final mantenciones = await _client
        .from('mantenciones')
        .select('documento_path')
        .eq('vehiculo_id', vehiculoId);
    final programadas = await _client
        .from('mantenciones_programadas')
        .select('id')
        .eq('vehiculo_id', vehiculoId);
    final estacionamientos = await _client
        .from('estacionamientos')
        .select('documento_path')
        .eq('vehiculo_id', vehiculoId);
    final cargas = await _client
        .from('combustible_cargas')
        .select('documento_path')
        .eq('vehiculo_id', vehiculoId);

    await _client.from('combustible_cargas').delete().eq('vehiculo_id', vehiculoId);
    await _client.from('vehiculos').delete().eq('id', vehiculoId);

    await _client
        .from('usuarios')
        .update({'vehiculo_principal_patente': null})
        .eq('id', userId)
        .eq('vehiculo_principal_patente', patente);

    // Lo que sigue es limpieza: si falla algo no debe hacer fallar la eliminación,
    // que ya se hizo.
    final rutas = [
      for (final m in mantenciones)
        if (m['documento_path'] != null) m['documento_path'] as String,
    ];
    if (rutas.isNotEmpty) {
      try {
        await _client.storage.from('mantencion_docs').remove(rutas);
      } catch (e) {
        debugPrint('TAG_OK_VEHICULOS: no se pudieron borrar los adjuntos de mantenciones: $e');
      }
    }

    final rutasEstacionamientos = [
      for (final e in estacionamientos)
        if (e['documento_path'] != null) e['documento_path'] as String,
    ];
    if (rutasEstacionamientos.isNotEmpty) {
      try {
        await _client.storage.from('estacionamiento_docs').remove(rutasEstacionamientos);
      } catch (e) {
        debugPrint('TAG_OK_VEHICULOS: no se pudieron borrar los comprobantes de estacionamientos: $e');
      }
    }

    final rutasCombustible = [
      for (final c in cargas)
        if (c['documento_path'] != null) c['documento_path'] as String,
    ];
    if (rutasCombustible.isNotEmpty) {
      try {
        await _client.storage.from('combustible_docs').remove(rutasCombustible);
      } catch (e) {
        debugPrint('TAG_OK_VEHICULOS: no se pudieron borrar los comprobantes de combustible: $e');
      }
    }

    for (final tipo in kTiposDocumentoVehiculo) {
      try {
        await NotificacionesVencimientoService().cancelarParaDocumento(vehiculoId, tipo['id']!);
      } catch (e) {
        debugPrint('TAG_OK_VEHICULOS: no se pudo cancelar el aviso de ${tipo['id']}: $e');
      }
    }
    for (final p in programadas) {
      try {
        await NotificacionesVencimientoService().cancelarParaMantencion(p['id'] as String);
      } catch (e) {
        debugPrint('TAG_OK_VEHICULOS: no se pudo cancelar el aviso de mantención: $e');
      }
    }
  }
}
