import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/carga_combustible_model.dart';
import 'vehiculo_service.dart';
import 'cache_offline.dart';

/// Resultado de guardar una carga.
class ResultadoGuardadoCarga {
  final CargaCombustibleModel carga;

  /// true si el kilometraje del vehículo se actualizó porque el de la carga era mayor.
  final bool odometroActualizado;

  /// true si la carga se guardó pero el comprobante no se pudo subir.
  final bool fallaAdjunto;

  const ResultadoGuardadoCarga({required this.carga, this.odometroActualizado = false, this.fallaAdjunto = false});
}

/// Cargas de combustible o de energía de un vehículo.
class CombustibleService {
  static const bucket = 'combustible_docs';

  final SupabaseClient _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  /// Todas las cargas del vehículo, de la más reciente a la más antigua. Las
  /// políticas de la base de datos ya limitan las filas al dueño.
  Stream<List<CargaCombustibleModel>> streamPorVehiculo(String vehiculoId) {
    return CacheOffline.filas(
      'combustible:$vehiculoId',
      _client
          .from('combustible_cargas')
          .stream(primaryKey: ['id'])
          .eq('vehiculo_id', vehiculoId)
          .order('fecha', ascending: false),
    ).map((rows) => rows.map(CargaCombustibleModel.fromJson).toList());
  }

  /// Guarda una carga nueva (si no tiene id) o actualiza una existente. Si viene un
  /// archivo, lo sube y lo deja asociado. Si el kilometraje es mayor que el del
  /// vehículo, actualiza el odómetro.
  ///
  /// Si falla el guardado de la fila lanza la excepción (el usuario puede reintentar
  /// con los datos aún en pantalla). Si lo que falla es solo el comprobante, la
  /// carga queda guardada y se avisa en el resultado.
  Future<ResultadoGuardadoCarga> guardar(
    CargaCombustibleModel carga, {
    Uint8List? archivoBytes,
    String? archivoNombre,
    String? archivoMime,
  }) async {
    final esNueva = carga.id.isEmpty;
    // Los datos del comprobante los maneja este servicio, no el formulario.
    final datos = {...carga.toJson(), 'usuario_id': _userId}
      ..remove('documento_path')
      ..remove('documento_nombre');

    final Map<String, dynamic> fila;
    if (esNueva) {
      fila = await _client.from('combustible_cargas').insert(datos).select().single();
    } else {
      fila = await _client.from('combustible_cargas').update(datos).eq('id', carga.id).select().single();
    }
    var guardada = CargaCombustibleModel.fromJson(fila);

    var fallaAdjunto = false;
    if (archivoBytes != null && archivoNombre != null) {
      try {
        final anterior = guardada.documentoPath;
        final ruta = await _subirDocumento(
          cargaId: guardada.id,
          bytes: archivoBytes,
          nombre: archivoNombre,
          mime: archivoMime,
        );
        await _client
            .from('combustible_cargas')
            .update({'documento_path': ruta, 'documento_nombre': archivoNombre}).eq('id', guardada.id);
        guardada = guardada.copyWith(documentoPath: ruta, documentoNombre: archivoNombre);
        if (anterior != null && anterior != ruta) await _borrarArchivo(anterior);
      } catch (e) {
        debugPrint('TAG_OK_COMBUSTIBLE: no se pudo subir el comprobante: $e');
        fallaAdjunto = true;
      }
    }

    var odometro = false;
    final km = guardada.kilometraje;
    if (km != null) {
      odometro = await VehiculoService().actualizarKilometrajeSiMayor(guardada.vehiculoId, km);
    }

    return ResultadoGuardadoCarga(carga: guardada, odometroActualizado: odometro, fallaAdjunto: fallaAdjunto);
  }

  Future<void> eliminar(CargaCombustibleModel carga) async {
    await _client.from('combustible_cargas').delete().eq('id', carga.id);
    final ruta = carga.documentoPath;
    if (ruta != null) await _borrarArchivo(ruta);
  }

  Future<Uint8List> descargarDocumento(String ruta) {
    return _client.storage.from(bucket).download(ruta);
  }

  Future<String> _subirDocumento({
    required String cargaId,
    required Uint8List bytes,
    required String nombre,
    String? mime,
  }) async {
    // Solo letras, números y algunos signos: el nombre original puede traer
    // espacios o caracteres que no son válidos en una ruta de Storage.
    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ruta = '$_userId/$cargaId/${DateTime.now().millisecondsSinceEpoch}_$limpio';
    await _client.storage.from(bucket).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );
    return ruta;
  }

  Future<void> _borrarArchivo(String ruta) async {
    try {
      await _client.storage.from(bucket).remove([ruta]);
    } catch (e) {
      // Un archivo huérfano no justifica fallar una operación que ya se hizo.
      debugPrint('TAG_OK_COMBUSTIBLE: no se pudo borrar el archivo $ruta: $e');
    }
  }
}
