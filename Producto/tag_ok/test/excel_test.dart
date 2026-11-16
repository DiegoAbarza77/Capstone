// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  test('Test FilePicker saveFile compilation', () async {
    // Just verifying compilation and method signatures
    try {
      final bytes = Uint8List(10);
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Archivo',
        fileName: 'test.xlsx',
        bytes: bytes,
      );
      print('saveFile compiló correctamente.');
    } catch (e) {
      // It's fine if it throws a platform exception during headless tests, we just want to verify compilation.
      print('Llamada a saveFile arrojó: $e');
    }
  });
}
