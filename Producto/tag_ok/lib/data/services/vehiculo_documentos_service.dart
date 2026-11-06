import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_vehiculo_model.dart';
import 'cache_offline.dart';

class VehiculoDocumentosService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Bucket privado donde se guardan las fotos y PDF de los documentos.
  static const bucket = 'vehiculo_docs';

  String get _userId => _client.auth.currentUser!.id;

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

  /// Borra el documento de ese tipo del vehículo, con su archivo si lo tenía. Si
  /// no existía, no hace nada.
  Future<void> eliminarDocumento(String vehiculoId, String tipo, {String? archivoPath}) async {
    await _client.from('vehiculo_documentos').delete().eq('vehiculo_id', vehiculoId).eq('tipo', tipo);
    if (archivoPath != null && archivoPath.isNotEmpty) await borrarArchivo(archivoPath);
  }

  /// Sube la foto o el PDF y devuelve su ruta en el bucket. Va en la carpeta del
  /// usuario (`<uid>/<vehiculo>/...`), que es lo que exigen las reglas de acceso.
  Future<String> subirArchivo({
    required String vehiculoId,
    required String tipo,
    required Uint8List bytes,
    required String nombre,
    String? mime,
  }) async {
    // Solo letras, números y algunos signos: el nombre original puede traer
    // espacios o caracteres que no son válidos en una ruta de Storage.
    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ruta = '$_userId/$vehiculoId/${tipo}_${DateTime.now().millisecondsSinceEpoch}_$limpio';
    await _client.storage.from(bucket).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );
    return ruta;
  }

  Future<Uint8List> descargarArchivo(String ruta) {
    return _client.storage.from(bucket).download(ruta);
  }

  /// Deja el documento sin archivo (los datos se conservan) y borra el archivo.
  Future<void> quitarArchivo(String vehiculoId, String tipo, String ruta) async {
    await _client
        .from('vehiculo_documentos')
        .update({'archivo_path': null, 'archivo_nombre': null})
        .eq('vehiculo_id', vehiculoId)
        .eq('tipo', tipo);
    await borrarArchivo(ruta);
  }

  Future<void> borrarArchivo(String ruta) async {
    try {
      await _client.storage.from(bucket).remove([ruta]);
    } catch (e) {
      // Un archivo huérfano no justifica fallar una operación que ya se hizo.
      debugPrint('TAG_OK_DOCUMENTOS: no se pudo borrar el archivo $ruta: $e');
    }
  }
}
