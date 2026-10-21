import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_vehiculo_model.dart';
import 'cache_offline.dart';

class VehiculoDocumentosService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Emite siempre los 4 tipos de documento definidos, con datos vacíos
  /// para los que el usuario aún no ha registrado.
  Stream<List<DocumentoVehiculoModel>> streamDocumentos(String vehiculoId) {
    return CacheOffline.filas(
      'documentos:$vehiculoId',
      _client.from('vehiculo_documentos').stream(primaryKey: ['id']).eq('vehiculo_id', vehiculoId),
    ).map((rows) {
      final Map<String, Map<String, dynamic>> porTipo = {
        for (final row in rows) row['tipo'] as String: row,
      };
      return kTiposDocumentoVehiculo
          .map((t) => DocumentoVehiculoModel.fromJson(t['id']!, porTipo[t['id']]))
          .toList();
    });
  }

  Future<void> guardarDocumento(String vehiculoId, DocumentoVehiculoModel doc) async {
    await _client.from('vehiculo_documentos').upsert(
      {
        ...doc.toJson(),
        'vehiculo_id': vehiculoId,
        'tipo': doc.tipo,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      onConflict: 'vehiculo_id,tipo',
    );
  }

  /// Borra el documento de ese tipo del vehículo. Si no existía, no hace nada.
  Future<void> eliminarDocumento(String vehiculoId, String tipo) async {
    await _client.from('vehiculo_documentos').delete().eq('vehiculo_id', vehiculoId).eq('tipo', tipo);
  }
}
