import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estacionamiento_model.dart';
import 'cache_offline.dart';

/// Ya hay un estacionamiento con el cronómetro corriendo para ese vehículo.
class EstacionamientoEnCursoException implements Exception {
  const EstacionamientoEnCursoException();

  @override
  String toString() => 'Ya tienes un estacionamiento en curso. Finalízalo antes de iniciar otro.';
}

/// Resultado de guardar un estacionamiento.
class ResultadoGuardadoEstacionamiento {
  final EstacionamientoModel estacionamiento;

  /// true si el estacionamiento se guardó pero el archivo adjunto no se pudo subir.
  final bool fallaAdjunto;

  const ResultadoGuardadoEstacionamiento({required this.estacionamiento, this.fallaAdjunto = false});
}

/// Estacionamientos de un vehículo: registro manual o con IA, y el cronómetro.
class EstacionamientoService {
  static const bucket = 'estacionamiento_docs';

  final SupabaseClient _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  /// Todos los estacionamientos del vehículo, incluido el que está en curso.
  /// Quien lo use ordena y filtra (ver utils/estacionamiento_calculos.dart).
  Stream<List<EstacionamientoModel>> streamPorVehiculo(String vehiculoId) {
    return CacheOffline.filas(
      'estacionamientos:$vehiculoId',
      _client.from('estacionamientos').stream(primaryKey: ['id']).eq('vehiculo_id', vehiculoId),
    ).map((rows) => rows.map(EstacionamientoModel.fromJson).toList());
  }

  // ── Cronómetro ──────────────────────────────────────────────────────

  /// Inicia el cronómetro. La hora de inicio queda guardada en la base de datos,
  /// no solo en la app, para recuperar la duración aunque la app se cierre.
  ///
  /// Lanza [EstacionamientoEnCursoException] si ya hay uno corriendo.
  Future<EstacionamientoModel> iniciar({
    required String vehiculoId,
    double? lat,
    double? lng,
  }) async {
    final ahora = DateTime.now();
    final nuevo = EstacionamientoModel(
      vehiculoId: vehiculoId,
      fecha: DateTime(ahora.year, ahora.month, ahora.day),
      horaEntrada: ahora,
      lat: lat,
      lng: lng,
      enCurso: true,
    );

    try {
      // La base de datos impide dos sesiones en curso (índice único): así el
      // chequeo vale aunque la app se abra desde dos dispositivos a la vez.
      final fila = await _client
          .from('estacionamientos')
          .insert({...nuevo.toJson(), 'usuario_id': _userId})
          .select()
          .single();
      return EstacionamientoModel.fromJson(fila);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const EstacionamientoEnCursoException();
      rethrow;
    }
  }

  /// Detiene el cronómetro y guarda la hora de salida, el costo y los datos que
  /// el usuario quiera completar. [horaSalida] es el momento en que el usuario
  /// pulsó "Finalizar" (no cuando termina de llenar el formulario).
  Future<EstacionamientoModel> finalizar(
    EstacionamientoModel enCurso, {
    required DateTime horaSalida,
    required double costo,
    String? lugar,
    String? direccion,
    String? observaciones,
  }) async {
    final cierre = EstacionamientoModel(
      id: enCurso.id,
      vehiculoId: enCurso.vehiculoId,
      fecha: enCurso.fecha,
      lugar: lugar,
      direccion: direccion,
      lat: enCurso.lat,
      lng: enCurso.lng,
      horaEntrada: enCurso.horaEntrada,
      horaSalida: horaSalida,
      costo: costo,
      observaciones: observaciones,
      enCurso: false,
      origen: enCurso.origen,
    );
    final fila = await _client
        .from('estacionamientos')
        .update(cierre.toJson())
        .eq('id', enCurso.id)
        .select()
        .single();
    return EstacionamientoModel.fromJson(fila);
  }

  /// Descarta una sesión en curso sin guardarla (por ejemplo, se inició por error).
  Future<void> cancelarEnCurso(String id) async {
    await _client.from('estacionamientos').delete().eq('id', id).eq('en_curso', true);
  }

  // ── Registro manual o con IA ────────────────────────────────────────

  /// Guarda un estacionamiento nuevo (si no tiene id) o actualiza uno existente.
  /// Si viene un archivo, lo sube y lo deja asociado.
  ///
  /// Si falla el guardado de la fila lanza la excepción (el usuario puede
  /// reintentar con los datos aún en pantalla). Si lo que falla es solo el
  /// archivo adjunto, el estacionamiento queda guardado y se avisa en el resultado.
  Future<ResultadoGuardadoEstacionamiento> guardar(
    EstacionamientoModel estacionamiento, {
    Uint8List? archivoBytes,
    String? archivoNombre,
    String? archivoMime,
  }) async {
    final esNuevo = estacionamiento.id.isEmpty;
    final datos = {...estacionamiento.toJson(), 'usuario_id': _userId};

    final Map<String, dynamic> fila;
    if (esNuevo) {
      fila = await _client.from('estacionamientos').insert(datos).select().single();
    } else {
      fila = await _client.from('estacionamientos').update(datos).eq('id', estacionamiento.id).select().single();
    }
    var guardado = EstacionamientoModel.fromJson(fila);

    var fallaAdjunto = false;
    if (archivoBytes != null && archivoNombre != null) {
      try {
        final anterior = guardado.documentoPath;
        final ruta = await _subirDocumento(
          estacionamientoId: guardado.id,
          bytes: archivoBytes,
          nombre: archivoNombre,
          mime: archivoMime,
        );
        await _client
            .from('estacionamientos')
            .update({'documento_path': ruta, 'documento_nombre': archivoNombre}).eq('id', guardado.id);
        guardado = guardado.copyWith(documentoPath: ruta, documentoNombre: archivoNombre);
        if (anterior != null && anterior != ruta) await _borrarArchivo(anterior);
      } catch (e) {
        debugPrint('TAG_OK_ESTACIONAMIENTOS: no se pudo subir el adjunto: $e');
        fallaAdjunto = true;
      }
    }

    return ResultadoGuardadoEstacionamiento(estacionamiento: guardado, fallaAdjunto: fallaAdjunto);
  }

  Future<void> eliminar(EstacionamientoModel estacionamiento) async {
    await _client.from('estacionamientos').delete().eq('id', estacionamiento.id);
    final ruta = estacionamiento.documentoPath;
    if (ruta != null) await _borrarArchivo(ruta);
  }

  Future<Uint8List> descargarDocumento(String ruta) {
    return _client.storage.from(bucket).download(ruta);
  }

  Future<String> _subirDocumento({
    required String estacionamientoId,
    required Uint8List bytes,
    required String nombre,
    String? mime,
  }) async {
    // Solo letras, números y algunos signos: el nombre original puede traer
    // espacios o caracteres que no son válidos en una ruta de Storage.
    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ruta = '$_userId/$estacionamientoId/${DateTime.now().millisecondsSinceEpoch}_$limpio';
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
      debugPrint('TAG_OK_ESTACIONAMIENTOS: no se pudo borrar el archivo $ruta: $e');
    }
  }
}
