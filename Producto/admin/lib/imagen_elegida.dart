import 'dart:typed_data';

/// Imagen que el administrador eligió desde su equipo.
class ImagenElegida {
  final Uint8List bytes;
  final String nombre;

  const ImagenElegida({required this.bytes, required this.nombre});
}
