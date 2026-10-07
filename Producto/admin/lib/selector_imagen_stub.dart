import 'imagen_elegida.dart';

/// En plataformas que no son web no hay selector disponible.
Future<ImagenElegida?> elegirImagen() async {
  throw UnsupportedError('Elegir imágenes solo está disponible en el panel web.');
}
