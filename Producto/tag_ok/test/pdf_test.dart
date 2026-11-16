// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void testCostaneraOrVespucioSur(String filepath, String type) {
  final file = File(filepath);
  if (!file.existsSync()) {
    print('El archivo no existe: $filepath');
    return;
  }
  final fileBytes = file.readAsBytesSync();
  final PdfDocument document = PdfDocument(inputBytes: fileBytes);
  final PdfTextExtractor extractor = PdfTextExtractor(document);
  final String text = extractor.extractText();
  document.dispose();

  final lines = const LineSplitter().convert(text);
  print('\n=== PROBANDO PDF: $filepath ($type) ===');
  print('Total líneas extraídas: ${lines.length}');
  
  List<Map<String, dynamic>> extractedCrossings = [];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    // Buscar formato DD/MM/AAAA HH:MM
    if (RegExp(r'^\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}$').hasMatch(line)) {
      if (i + 5 < lines.length) {
        final String dateTimeStr = line;
        final String fPortico = lines[i + 2].trim();
        final String fCostRaw = lines[i + 4].trim(); // e.g. "$  889,00"
        final String fPatent = lines[i + 5].trim();  // e.g. "JHGK50"

        if (fCostRaw.contains('\$') && fPatent.length == 6) {
          final dateParts = dateTimeStr.split(' ')[0].split('/');
          final formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';
          final String fTime = '${dateTimeStr.split(' ')[1]}:00';
          
          final double cost = double.parse(
            fCostRaw.replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.').trim()
          );

          extractedCrossings.add({
            'date': formattedDate,
            'time': fTime,
            'portico': fPortico,
            'cost': cost,
            'patent': fPatent,
          });

          i += 5; // Saltar las siguientes 5 líneas procesadas
        }
      }
    }
  }

  print('Total transacciones extraídas con éxito: ${extractedCrossings.length}');
  if (extractedCrossings.isNotEmpty) {
    print('Muestra de las primeras 3 transacciones extraídas:');
    for (var i = 0; i < extractedCrossings.length.clamp(0, 3); i++) {
      print('  [$i]: ${extractedCrossings[i]}');
    }
  }
}

void testVespucioNorte(String filepath) {
  final file = File(filepath);
  if (!file.existsSync()) {
    print('El archivo no existe: $filepath');
    return;
  }
  final fileBytes = file.readAsBytesSync();
  final PdfDocument document = PdfDocument(inputBytes: fileBytes);
  final PdfTextExtractor extractor = PdfTextExtractor(document);
  final String text = extractor.extractText();
  document.dispose();

  print('\n=== PROBANDO PDF: $filepath (Vespucio Norte) ===');
  print('Longitud del texto extraído: ${text.length}');
  
  List<Map<String, dynamic>> extractedCrossings = [];

  // Expresión regular global sin espacios para el texto corrido de Syncfusion
  final regex = RegExp(
    r'([A-Z0-9]{6})(\d{2}-\d{2}-\d{4})(\d{2}:\d{2}:\d{2})(O-P|P-O)(\d+)(Laboral|Domingo|Sábado)(TBFP|TBP|TS)Normal\$\s*([\d\.,]+)'
  );

  for (final Match match in regex.allMatches(text)) {
    final String fPatent = match.group(1)!;
    final String fDate = match.group(2)!;
    final String fTime = match.group(3)!;
    final String fPortico = match.group(5)!;
    final String fCostRaw = match.group(8)!;

    final double cost = double.parse(
      fCostRaw.replaceAll('.', '').replaceAll(',', '.').trim()
    );

    final dateParts = fDate.split('-');
    final formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';

    extractedCrossings.add({
      'date': formattedDate,
      'time': fTime,
      'portico': fPortico,
      'cost': cost,
      'patent': fPatent,
    });
  }

  print('Total transacciones extraídas con éxito: ${extractedCrossings.length}');
  if (extractedCrossings.isNotEmpty) {
    print('Muestra de las primeras 3 transacciones extraídas:');
    for (var i = 0; i < extractedCrossings.length.clamp(0, 3); i++) {
      print('  [$i]: ${extractedCrossings[i]}');
    }
  }
}

void main() {
  // Las boletas reales no se versionan (ver .gitignore); este test solo corre
  // en máquinas que tengan la carpeta pdf_privados/ localmente.
  final basePath = 'pdf_privados';
  final hasPdfs = Directory(basePath).existsSync();

  test('Diagnóstico de PDF y Expresiones Regulares Mejoradas', () {
    testCostaneraOrVespucioSur('$basePath/COSTANERA_NORTE.pdf', 'Costanera Norte');
    testCostaneraOrVespucioSur('$basePath/VESPUCIO_SUR.pdf', 'Vespucio Sur');
    testVespucioNorte('$basePath/VESPUCIO_NORTE_1.pdf');
  }, skip: hasPdfs ? false : 'Falta la carpeta local pdf_privados/');
}
