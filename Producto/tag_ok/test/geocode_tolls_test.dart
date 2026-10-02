import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;

// ATENCIÓN: este archivo no es una prueba, es un GENERADOR que reescribe
// lib/data/mock/tolls_database.dart a partir de los PDF de "pdf porticos/".
// Si corre dentro de `flutter test` sin querer, pisa la base de 106 pórticos
// con una versión casi vacía. Por eso solo se ejecuta si se pide a propósito:
//   REGENERAR_PORTICOS=1 flutter test test/geocode_tolls_test.dart
final _regenerar = Platform.environment['REGENERAR_PORTICOS'] == '1';

void main() {
  test('Geocode PDF Tolls', () async {
    // 1. Read Mapbox Token from .env
    final envContent = File('.env').readAsStringSync();
    String mapboxToken = '';
    for (var line in envContent.split('\n')) {
      if (line.startsWith('MAPBOX_ACCESS_TOKEN=')) {
        mapboxToken = line.split('=')[1].trim();
        break;
      }
    }

    if (mapboxToken.isEmpty) {
      print('Mapbox token not found');
      return;
    }

    final pdfDir = Directory('pdf porticos');
    final files = pdfDir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList();

    List<String> outputLines = [
      "import 'package:latlong2/latlong.dart';",
      "import '../models/route_model.dart';",
      "",
      "class TollsDatabase {",
      "  static final List<TollData> santiagoTolls = [",
    ];

    int tollCount = 0;

    for (var file in files) {
      final highwayName = file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
      print('\n=== $highwayName ===\n');
      
      outputLines.add("    // --- $highwayName ---");

      final document = PdfDocument(inputBytes: file.readAsBytesSync());
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      // Extract lines that look like "Name A - Name B"
      // They usually don't have numbers in them, except maybe a highway number
      final lines = text.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.contains('-') && !line.contains('\$') && line.length > 5 && line.length < 50) {
          // It looks like a segment name
          final parts = line.split('-');
          if (parts.length >= 2 && !RegExp(r'\d{2}:\d{2}').hasMatch(line)) {
            // It's not a time like 12:00-13:00
            
            final query = Uri.encodeComponent('${line.replaceAll("-", " ")}, $highwayName, Santiago, Chile');
            final url = Uri.parse('https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$mapboxToken&limit=1');
            
            try {
              final response = await http.get(url);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['features'] != null && data['features'].isNotEmpty) {
                  final center = data['features'][0]['center']; // [lng, lat]
                  final lng = center[0];
                  final lat = center[1];
                  
                  // Estimate cost (we just use a flat cost of 600 for simulation since parsing the matrix is impossible without complex OCR)
                  outputLines.add('    TollData(');
                  outputLines.add('      name: "$highwayName: $line",');
                  outputLines.add('      location: const LatLng($lat, $lng),');
                  outputLines.add('      cost: 600.0,');
                  outputLines.add('    ),');
                  
                  tollCount++;
                  print('Geocoded: $line -> $lat, $lng');
                  
                  // Mapbox rate limit protection
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            } catch (e) {
              print('Error geocoding $line: $e');
            }
          }
        }
      }
    }

    outputLines.add("  ];");
    outputLines.add("}");

    File('lib/data/mock/tolls_database.dart').writeAsStringSync(outputLines.join('\n'));
    print('Total tolls geocoded: $tollCount');
  }, skip: _regenerar ? false : 'Generador: solo corre con REGENERAR_PORTICOS=1');
}
