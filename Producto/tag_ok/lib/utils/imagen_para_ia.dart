import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lado más largo (en píxeles) al que se reducen las fotos antes de mandarlas a
/// la IA: de sobra para leer una boleta y mucho más liviano que una foto de cámara.
const int kLadoMaximoIa = 1600;

/// Bajo este peso y dentro del lado máximo, la imagen se manda tal cual.
const int _pesoSinComprimir = 300 * 1024;

const int _calidadJpg = 80;

class ArchivoParaIa {
  final Uint8List bytes;
  final String mimeType;
  const ArchivoParaIa(this.bytes, this.mimeType);
}

/// Reduce y comprime una foto antes de enviarla a la IA (RNF-06), para gastar
/// menos datos móviles y acelerar el envío. Los PDF y todo lo que no sea imagen
/// pasan sin cambios; si la imagen no se puede leer, o comprimida pesara más,
/// se devuelve la original: la compresión nunca debe impedir leer una boleta.
Future<ArchivoParaIa> comprimirParaIa(Uint8List bytes, String mimeType) async {
  final original = ArchivoParaIa(bytes, mimeType);
  if (!mimeType.startsWith('image/')) return original;
  try {
    final resultado = await compute(_comprimir, bytes);
    if (resultado == null || resultado.bytes.length >= bytes.length) return original;
    return ArchivoParaIa(resultado.bytes, resultado.mimeType);
  } catch (_) {
    return original;
  }
}

/// Corre en un hilo aparte para no congelar la pantalla con fotos grandes.
ArchivoParaIa? _comprimir(Uint8List bytes) {
  final imagen = img.decodeImage(bytes);
  if (imagen == null) return null;

  final ladoLargo = imagen.width > imagen.height ? imagen.width : imagen.height;
  if (ladoLargo <= kLadoMaximoIa && bytes.length <= _pesoSinComprimir) return null;

  var trabajo = img.bakeOrientation(imagen);
  if (ladoLargo > kLadoMaximoIa) {
    trabajo = trabajo.width >= trabajo.height
        ? img.copyResize(trabajo, width: kLadoMaximoIa, interpolation: img.Interpolation.average)
        : img.copyResize(trabajo, height: kLadoMaximoIa, interpolation: img.Interpolation.average);
  }

  // Con transparencia, JPG la dejaría en negro: se conserva como PNG.
  if (trabajo.hasAlpha) {
    return ArchivoParaIa(Uint8List.fromList(img.encodePng(trabajo)), 'image/png');
  }
  return ArchivoParaIa(Uint8List.fromList(img.encodeJpg(trabajo, quality: _calidadJpg)), 'image/jpeg');
}
