// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'imagen_elegida.dart';

/// Abre el selector de archivos del navegador y devuelve la imagen elegida, o
/// null si el administrador lo cierra sin elegir nada.
Future<ImagenElegida?> elegirImagen() {
  final completer = Completer<ImagenElegida?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp'
    ..style.display = 'none';
  html.document.body!.append(input);

  void terminar(ImagenElegida? resultado) {
    if (!completer.isCompleted) completer.complete(resultado);
    input.remove();
  }

  input.onChange.listen((_) {
    final archivos = input.files;
    if (archivos == null || archivos.isEmpty) {
      terminar(null);
      return;
    }
    final archivo = archivos.first;
    final lector = html.FileReader();
    lector.onLoadEnd.listen((_) {
      final resultado = lector.result;
      Uint8List? bytes;
      if (resultado is ByteBuffer) {
        bytes = resultado.asUint8List();
      } else if (resultado is Uint8List) {
        bytes = resultado;
      }
      terminar(bytes == null ? null : ImagenElegida(bytes: bytes, nombre: archivo.name));
    });
    lector.onError.listen((_) => terminar(null));
    lector.readAsArrayBuffer(archivo);
  });

  // Si se cierra el selector sin elegir, el navegador no avisa: se detecta
  // cuando la ventana recupera el foco y sigue sin haber ningún archivo.
  html.window.onFocus.first.then((_) {
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (input.files == null || input.files!.isEmpty) terminar(null);
    });
  });

  input.click();
  return completer.future;
}
