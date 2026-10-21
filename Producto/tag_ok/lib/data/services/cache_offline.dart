import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Copia local de los últimos datos recibidos, para seguir viendo historiales y
/// el tablero cuando se cae la conexión (RNF-12, y los casos de uso de
/// historial y dashboard). Solo lectura: no se puede registrar nada sin red.
class CacheOffline {
  CacheOffline._();

  static const String _prefijo = 'cache_offline|';

  /// Fecha de la copia que se está mostrando en lugar de datos en vivo, o null
  /// si lo que se ve está actualizado. Con varias pantallas abiertas a la vez
  /// refleja el último cambio.
  static final ValueNotifier<DateTime?> datosGuardadosDesde = ValueNotifier<DateTime?>(null);

  /// Envuelve un flujo de filas de Supabase: cada vez que llegan datos los guarda,
  /// y si el flujo falla o no responde a tiempo entrega la última copia guardada.
  /// Sin copia, el error llega igual que antes.
  ///
  /// [clave] identifica los datos (por ejemplo "combustible:ID_DEL_VEHICULO"); la
  /// copia queda separada por usuario.
  static Stream<List<Map<String, dynamic>>> filas(
    String clave,
    Stream<List<Map<String, dynamic>>> origen, {
    Duration espera = const Duration(seconds: 6),
    String? usuarioId,
  }) {
    late final StreamController<List<Map<String, dynamic>>> salida;
    StreamSubscription<List<Map<String, dynamic>>>? suscripcion;
    Timer? temporizador;
    var recibioEnVivo = false;
    final claveCompleta = _claveCompleta(clave, usuarioId);

    Future<void> servirCopia({required bool esError, Object? error, StackTrace? pila}) async {
      final copia = await _leer(claveCompleta);
      if (salida.isClosed) return;
      if (copia != null) {
        salida.add(copia.filas);
        datosGuardadosDesde.value = copia.fecha;
      } else if (esError) {
        salida.addError(error!, pila);
      }
    }

    salida = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        // Sin respuesta en un rato (sin red, el flujo queda esperando) se muestra la copia.
        temporizador = Timer(espera, () {
          if (!recibioEnVivo) servirCopia(esError: false);
        });
        suscripcion = origen.listen(
          (filas) {
            recibioEnVivo = true;
            temporizador?.cancel();
            datosGuardadosDesde.value = null;
            if (!salida.isClosed) salida.add(filas);
            _guardar(claveCompleta, filas);
          },
          onError: (Object error, StackTrace pila) {
            temporizador?.cancel();
            servirCopia(esError: true, error: error, pila: pila);
          },
          onDone: () {
            temporizador?.cancel();
            if (!salida.isClosed) salida.close();
          },
        );
      },
      onCancel: () {
        temporizador?.cancel();
        return suscripcion?.cancel();
      },
    );
    return salida.stream;
  }

  /// Borra todas las copias (al cerrar sesión, para que no queden datos de la
  /// persona en el dispositivo).
  static Future<void> limpiar() async {
    datosGuardadosDesde.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_prefijo)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  static String _claveCompleta(String clave, String? usuarioId) {
    final uid = usuarioId ?? _usuarioActual();
    return '$_prefijo$uid|$clave';
  }

  static String _usuarioActual() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'anonimo';
    } catch (_) {
      return 'anonimo';
    }
  }

  static Future<void> _guardar(String clave, List<Map<String, dynamic>> filas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clave, jsonEncode({'t': DateTime.now().toIso8601String(), 'filas': filas}));
    } catch (_) {
      // La copia es un respaldo: si no se puede guardar, no pasa nada.
    }
  }

  static Future<({DateTime fecha, List<Map<String, dynamic>> filas})?> _leer(String clave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(clave);
      if (texto == null) return null;
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      return (
        fecha: DateTime.parse(mapa['t'] as String),
        filas: [for (final f in mapa['filas'] as List) Map<String, dynamic>.from(f as Map)],
      );
    } catch (_) {
      return null;
    }
  }
}
