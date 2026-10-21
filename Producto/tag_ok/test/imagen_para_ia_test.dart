import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tag_ok/utils/imagen_para_ia.dart';

/// Foto con ruido, como una de cámara: no se comprime tan fácil como un color liso.
Uint8List _foto(int ancho, int alto) {
  final azar = Random(1);
  final imagen = img.Image(width: ancho, height: alto);
  for (final p in imagen) {
    p.r = azar.nextInt(256);
    p.g = azar.nextInt(256);
    p.b = azar.nextInt(256);
  }
  return Uint8List.fromList(img.encodeJpg(imagen, quality: 95));
}

void main() {
  test('un PDF pasa sin cambios', () async {
    final pdf = Uint8List.fromList([37, 80, 68, 70, 1, 2, 3]);
    final r = await comprimirParaIa(pdf, 'application/pdf');
    expect(r.bytes, same(pdf));
    expect(r.mimeType, 'application/pdf');
  });

  test('bytes que no son una imagen se devuelven igual', () async {
    final raro = Uint8List.fromList([1, 2, 3, 4]);
    final r = await comprimirParaIa(raro, 'image/jpeg');
    expect(r.bytes, same(raro));
  });

  test('una foto grande se reduce de tamaño y de píxeles', () async {
    final grande = _foto(3000, 2000);
    final r = await comprimirParaIa(grande, 'image/jpeg');
    expect(r.bytes.length, lessThan(grande.length));
    expect(r.mimeType, 'image/jpeg');
    final salida = img.decodeJpg(r.bytes)!;
    expect(salida.width, kLadoMaximoIa);
    expect(salida.height, lessThanOrEqualTo(kLadoMaximoIa));
    expect(salida.width / salida.height, closeTo(3000 / 2000, 0.01));
  });

  test('una foto vertical se limita por el alto', () async {
    final r = await comprimirParaIa(_foto(1800, 2400), 'image/jpeg');
    final salida = img.decodeJpg(r.bytes)!;
    expect(salida.height, kLadoMaximoIa);
    expect(salida.width, lessThan(salida.height));
  });

  test('una imagen chica y liviana no se toca', () async {
    final chica = Uint8List.fromList(img.encodeJpg(img.Image(width: 200, height: 200), quality: 80));
    final r = await comprimirParaIa(chica, 'image/jpeg');
    expect(r.bytes, same(chica));
  });
}
