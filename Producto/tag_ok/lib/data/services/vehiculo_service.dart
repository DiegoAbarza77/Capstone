import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_vehiculo_model.dart';
import 'notificaciones_vencimiento_service.dart';

class VehiculoService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Elimina un vehículo y todo lo que depende de él:
  ///  - sus cargas de combustible (la clave foránea las dejaría huérfanas, sin
  ///    vehículo, e invisibles en la app),
  ///  - el vehículo en sí, que borra en cascada sus documentos, mantenciones
  ///    y estacionamientos,
  ///  - la marca de "vehículo principal" si era este,
  ///  - los avisos de vencimiento programados en el dispositivo.
  Future<void> eliminar({required String vehiculoId, required String patente}) async {
    final userId = _client.auth.currentUser!.id;

    await _client.from('combustible_cargas').delete().eq('vehiculo_id', vehiculoId);
    await _client.from('vehiculos').delete().eq('id', vehiculoId);

    await _client
        .from('usuarios')
        .update({'vehiculo_principal_patente': null})
        .eq('id', userId)
        .eq('vehiculo_principal_patente', patente);

    // Los avisos son locales: si no se pueden cancelar (por ejemplo en web,
    // donde no existen) no debe fallar la eliminación, que ya se hizo.
    for (final tipo in kTiposDocumentoVehiculo) {
      try {
        await NotificacionesVencimientoService().cancelarParaDocumento(vehiculoId, tipo['id']!);
      } catch (e) {
        debugPrint('TAG_OK_VEHICULOS: no se pudo cancelar el aviso de ${tipo['id']}: $e');
      }
    }
  }
}
