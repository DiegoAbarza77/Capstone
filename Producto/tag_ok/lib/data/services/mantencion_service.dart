import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mantencion_model.dart';
import 'notificaciones_vencimiento_service.dart';
import 'vehiculo_service.dart';

/// Resultado de guardar una mantención.
class ResultadoGuardadoMantencion {
  final MantencionModel mantencion;

  /// true si el kilometraje del vehículo se actualizó porque el de la mantención
  /// era mayor.
  final bool odometroActualizado;

  /// true si la mantención se guardó pero el archivo adjunto no se pudo subir.
  final bool fallaAdjunto;

  const ResultadoGuardadoMantencion({
    required this.mantencion,
    this.odometroActualizado = false,
    this.fallaAdjunto = false,
  });
}

/// Mantenciones realizadas y mantenciones programadas de un vehículo.
class MantencionService {
  static const bucket = 'mantencion_docs';

  final SupabaseClient _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  // ── Historial ───────────────────────────────────────────────────────

  /// La línea de tiempo: de la más reciente a la más antigua.
  Stream<List<MantencionModel>> streamPorVehiculo(String vehiculoId) {
    return _client
        .from('mantenciones')
        .stream(primaryKey: ['id'])
        .eq('vehiculo_id', vehiculoId)
        .order('fecha', ascending: false)
        .map((rows) => rows.map(MantencionModel.fromJson).toList());
  }

  /// Guarda una mantención nueva (si [mantencion] no tiene id) o actualiza una
  /// existente. Si viene un archivo, lo sube y lo deja asociado. Si el
  /// kilometraje es mayor que el del vehículo, actualiza el odómetro.
  ///
  /// Si falla el guardado de la fila lanza la excepción (el usuario puede
  /// reintentar con los datos aún en pantalla). Si lo que falla es solo el
  /// archivo adjunto, la mantención queda guardada y se avisa en el resultado.
  Future<ResultadoGuardadoMantencion> guardar(
    MantencionModel mantencion, {
    Uint8List? archivoBytes,
    String? archivoNombre,
    String? archivoMime,
  }) async {
    final esNueva = mantencion.id.isEmpty;
    final datos = {...mantencion.toJson(), 'usuario_id': _userId};

    final Map<String, dynamic> fila;
    if (esNueva) {
      fila = await _client.from('mantenciones').insert(datos).select().single();
    } else {
      fila = await _client.from('mantenciones').update(datos).eq('id', mantencion.id).select().single();
    }
    var guardada = MantencionModel.fromJson(fila);

    var fallaAdjunto = false;
    if (archivoBytes != null && archivoNombre != null) {
      try {
        final anterior = guardada.documentoPath;
        final ruta = await _subirDocumento(
          mantencionId: guardada.id,
          bytes: archivoBytes,
          nombre: archivoNombre,
          mime: archivoMime,
        );
        await _client
            .from('mantenciones')
            .update({'documento_path': ruta, 'documento_nombre': archivoNombre}).eq('id', guardada.id);
        guardada = guardada.copyWith(documentoPath: ruta, documentoNombre: archivoNombre);
        if (anterior != null && anterior != ruta) await _borrarArchivo(anterior);
      } catch (e) {
        debugPrint('TAG_OK_MANTENCIONES: no se pudo subir el adjunto: $e');
        fallaAdjunto = true;
      }
    }

    var odometro = false;
    final km = guardada.kilometraje;
    if (km != null) {
      odometro = await VehiculoService().actualizarKilometrajeSiMayor(guardada.vehiculoId, km);
    }

    return ResultadoGuardadoMantencion(
      mantencion: guardada,
      odometroActualizado: odometro,
      fallaAdjunto: fallaAdjunto,
    );
  }

  Future<void> eliminar(MantencionModel mantencion) async {
    await _client.from('mantenciones').delete().eq('id', mantencion.id);
    final ruta = mantencion.documentoPath;
    if (ruta != null) await _borrarArchivo(ruta);
  }

  Future<Uint8List> descargarDocumento(String ruta) {
    return _client.storage.from(bucket).download(ruta);
  }

  Future<String> _subirDocumento({
    required String mantencionId,
    required Uint8List bytes,
    required String nombre,
    String? mime,
  }) async {
    // Solo letras, números y algunos signos: el nombre original puede traer
    // espacios o caracteres que no son válidos en una ruta de Storage.
    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ruta = '$_userId/$mantencionId/${DateTime.now().millisecondsSinceEpoch}_$limpio';
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
      debugPrint('TAG_OK_MANTENCIONES: no se pudo borrar el archivo $ruta: $e');
    }
  }

  // ── Próxima mantención programada ───────────────────────────────────

  Stream<List<MantencionProgramadaModel>> streamProgramadas(String vehiculoId) {
    return _client
        .from('mantenciones_programadas')
        .stream(primaryKey: ['id'])
        .eq('vehiculo_id', vehiculoId)
        .map((rows) => rows.map(MantencionProgramadaModel.fromJson).toList());
  }

  /// Guarda una programación nueva o actualiza una existente, y deja
  /// reprogramados los avisos de fecha en el dispositivo.
  Future<MantencionProgramadaModel> guardarProgramada(
    MantencionProgramadaModel programada, {
    required String patente,
  }) async {
    final datos = {...programada.toJson(), 'usuario_id': _userId};
    final Map<String, dynamic> fila;
    if (programada.id.isEmpty) {
      fila = await _client.from('mantenciones_programadas').insert(datos).select().single();
    } else {
      fila = await _client
          .from('mantenciones_programadas')
          .update(datos)
          .eq('id', programada.id)
          .select()
          .single();
    }
    final guardada = MantencionProgramadaModel.fromJson(fila);
    await _reprogramarAvisos(guardada, patente);
    return guardada;
  }

  Future<void> marcarProgramadaCompletada(MantencionProgramadaModel programada) async {
    await _client.from('mantenciones_programadas').update({'completada': true}).eq('id', programada.id);
    await _cancelarAvisos(programada.id);
  }

  Future<void> eliminarProgramada(String id) async {
    await _client.from('mantenciones_programadas').delete().eq('id', id);
    await _cancelarAvisos(id);
  }

  // Los avisos son locales: si no se pueden programar o cancelar (por ejemplo en
  // web, donde no existen) no debe fallar el guardado, que ya se hizo.
  Future<void> _reprogramarAvisos(MantencionProgramadaModel programada, String patente) async {
    try {
      await NotificacionesVencimientoService().programarParaMantencion(programada: programada, patente: patente);
    } catch (e) {
      debugPrint('TAG_OK_MANTENCIONES: no se pudieron programar los avisos: $e');
    }
  }

  Future<void> _cancelarAvisos(String programadaId) async {
    try {
      await NotificacionesVencimientoService().cancelarParaMantencion(programadaId);
    } catch (e) {
      debugPrint('TAG_OK_MANTENCIONES: no se pudieron cancelar los avisos: $e');
    }
  }
}
