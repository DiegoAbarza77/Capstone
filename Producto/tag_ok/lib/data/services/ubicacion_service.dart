import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum EstadoUbicacion {
  /// Se obtuvo la ubicación.
  ok,

  /// El GPS del dispositivo está apagado.
  servicioApagado,

  /// El usuario no dio permiso de ubicación.
  sinPermiso,

  /// El usuario negó el permiso de forma permanente (hay que activarlo en Ajustes).
  sinPermisoPermanente,

  /// No se pudo leer la posición (sin señal, tiempo agotado...).
  error,
}

class ResultadoUbicacion {
  final EstadoUbicacion estado;
  final double? lat;
  final double? lng;

  const ResultadoUbicacion(this.estado, {this.lat, this.lng});

  bool get obtenida => estado == EstadoUbicacion.ok && lat != null && lng != null;

  /// Por qué no hay ubicación, para decírselo al usuario.
  String? get motivo {
    switch (estado) {
      case EstadoUbicacion.ok:
        return null;
      case EstadoUbicacion.servicioApagado:
        return 'El GPS está desactivado.';
      case EstadoUbicacion.sinPermiso:
        return 'No diste permiso de ubicación.';
      case EstadoUbicacion.sinPermisoPermanente:
        return 'El permiso de ubicación está bloqueado. Puedes activarlo en los ajustes del teléfono.';
      case EstadoUbicacion.error:
        return 'No se pudo obtener tu ubicación.';
    }
  }
}

/// Pide permiso y lee la ubicación actual del dispositivo, sin lanzar errores: si
/// no se puede, devuelve el motivo para que la app siga funcionando sin
/// coordenadas (por ejemplo, el cronómetro corre igual).
class UbicacionService {
  Future<ResultadoUbicacion> obtenerActual({Duration limite = const Duration(seconds: 10)}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoUbicacion(EstadoUbicacion.servicioApagado);
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion(EstadoUbicacion.sinPermisoPermanente);
      }
      if (permiso == LocationPermission.denied) {
        return const ResultadoUbicacion(EstadoUbicacion.sinPermiso);
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: limite),
      );
      return ResultadoUbicacion(EstadoUbicacion.ok, lat: posicion.latitude, lng: posicion.longitude);
    } catch (e) {
      debugPrint('TAG_OK_UBICACION: no se pudo obtener la ubicación: $e');
      return const ResultadoUbicacion(EstadoUbicacion.error);
    }
  }
}
