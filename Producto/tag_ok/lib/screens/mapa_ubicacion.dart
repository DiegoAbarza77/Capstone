import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'mantencion_ui.dart';

/// Mapa pequeño con un marcador en [lat], [lng]: sirve para recordar dónde quedó
/// el auto. Usa los mismos mapas de Mapbox que la pantalla principal; si no hay
/// token configurado muestra solo las coordenadas.
class MapaUbicacion extends StatelessWidget {
  final double lat;
  final double lng;
  final double altura;

  const MapaUbicacion({super.key, required this.lat, required this.lng, this.altura = 180});

  @override
  Widget build(BuildContext context) {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final punto = LatLng(lat, lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: altura,
        child: token.isEmpty
            ? Container(
                color: kMantTarjeta,
                alignment: Alignment.center,
                child: Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(color: kMantTextoSuave),
                ),
              )
            : FlutterMap(
                options: MapOptions(
                  initialCenter: punto,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$token',
                    tileSize: 512,
                    zoomOffset: -1,
                    userAgentPackageName: 'com.tagok.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: punto,
                        width: 44,
                        height: 44,
                        // La punta del pin queda sobre el punto exacto.
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on, color: kMantError, size: 44),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
