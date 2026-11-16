// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tag_ok/data/mock/tolls_database.dart';
import 'package:tag_ok/data/services/simulated_toll_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() {
  // El token de Mapbox se lee del .env local (no versionado). Nunca incrustar
  // llaves en este archivo: queda en el historial de git.
  final envFile = File('.env');
  final envText = envFile.existsSync() ? envFile.readAsStringSync() : '';
  final hasMapboxToken = RegExp(r'^MAPBOX_ACCESS_TOKEN=.+', multiLine: true).hasMatch(envText);
  final mapboxSkip = hasMapboxToken ? false : 'Falta MAPBOX_ACCESS_TOKEN en tag_ok/.env';

  setUpAll(() {
    dotenv.testLoad(fileInput: envText);
  });

  test('Validar Base de Datos de Pórticos', () {
    final tolls = TollsDatabase.santiagoTolls;
    expect(tolls.length, 106);
    
    final p3 = tolls.firstWhere((t) => t.name == "P3 Puente Lo Saldes - Vivaceta" && t.direction == "O-P");
    expect(p3.cost, 719.04);
    expect(p3.costPunta, 1384.32);
    expect(p3.costSaturacion, 2096.64);
  });

  test('Simular Ruta y Detección de Peajes', () async {
    
    final service = SimulatedTollService();
    final origin = LatLng(-33.280, -70.690);      // Chicureo
    final destination = LatLng(-33.560, -70.680); // San Bernardo
    
    print("Iniciando cálculo de ruta de prueba...");
    final routeData = await service.calculateRouteAndTolls(
      origin: origin,
      destination: destination,
    );
    
    print("Distancia calculada: ${routeData.distanceKm} km");
    print("Costo total estimado: ${routeData.totalCost} CLP");
    print("Pórticos detectados: ${routeData.tolls.length}");
    for (var toll in routeData.tolls) {
      print("  - ${toll.name} (Costo: ${toll.cost} CLP)");
    }
    
    expect(routeData.tolls.length, greaterThan(0));
  }, skip: mapboxSkip);

  test('Simular Ruta y Detección de Peajes - Lampa a Maipú', () async {
    
    final service = SimulatedTollService();
    final origin = LatLng(-33.282, -70.879);      // Lampa
    final destination = LatLng(-33.517, -70.767); // Maipú
    
    print("Iniciando cálculo de ruta Lampa -> Maipú...");
    final routeData = await service.calculateRouteAndTolls(
      origin: origin,
      destination: destination,
    );
    
    print("Distancia calculada: ${routeData.distanceKm} km");
    print("Costo total estimado: ${routeData.totalCost} CLP");
    print("Pórticos detectados: ${routeData.tolls.length}");
    for (var toll in routeData.tolls) {
      print("  - ${toll.name} (Costo: ${toll.cost} CLP)");
    }
    
    expect(routeData.tolls.length, equals(4));
  }, skip: mapboxSkip);

  test('Simular Ruta Usuario - Maipu a Huechuraba', () async {
    
    final service = SimulatedTollService();
    final origin = LatLng(-33.5132, -70.7587); // Av. 5 de Abril 313, Maipú
    final destination = LatLng(-33.3852, -70.6225); // Palacio Riesco 4515, Huechuraba
    
    print("Iniciando cálculo de ruta Maipu -> Huechuraba...");
    final routeData = await service.calculateRouteAndTolls(
      origin: origin,
      destination: destination,
    );
    
    print("Distancia calculada: ${routeData.distanceKm} km");
    print("Costo total estimado: ${routeData.totalCost} CLP");
    print("Pórticos detectados: ${routeData.tolls.length}");
    for (var toll in routeData.tolls) {
      print("  - ${toll.name} (Costo: ${toll.cost} CLP)");
    }
  }, skip: mapboxSkip);
}
