// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tag_ok/utils/selector_archivo.dart';

/// Cámara y galería simuladas: anotan de dónde se pidió la foto y con qué opciones.
class _FotosFalsas extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  XFile? foto;
  Object? error;
  final List<ImageSource> fuentes = [];
  ImagePickerOptions? ultimasOpciones;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    fuentes.add(source);
    ultimasOpciones = options;
    if (error != null) throw error!;
    return foto;
  }
}

void main() {
  late _FotosFalsas fotos;
  XFile? resultado;
  var terminado = false;

  setUp(() {
    fotos = _FotosFalsas();
    ImagePickerPlatform.instance = fotos;
    resultado = null;
    terminado = false;
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await elegirFotoConCamara(context, maxWidth: 640, maxHeight: 640);
                terminado = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('ofrece tomar una foto o elegirla de la galería', (tester) async {
    await abrir(tester);

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
  });

  testWidgets('"Tomar foto" abre la cámara con el tamaño pedido', (tester) async {
    fotos.foto = XFile.fromData(Uint8List.fromList([1, 2, 3]), path: '/cache/yo.jpg');
    await abrir(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(fotos.fuentes, [ImageSource.camera]);
    expect(fotos.ultimasOpciones?.maxWidth, 640);
    expect(fotos.ultimasOpciones?.maxHeight, 640);
    expect(resultado, isNotNull);
  });

  testWidgets('"Elegir de la galería" abre la galería', (tester) async {
    fotos.foto = XFile.fromData(Uint8List.fromList([9]), path: '/cache/galeria.png');
    await abrir(tester);

    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();

    expect(fotos.fuentes, [ImageSource.gallery]);
    expect(resultado, isNotNull);
  });

  testWidgets('cerrar el menú sin elegir no abre nada', (tester) async {
    await abrir(tester);

    await tester.tapAt(const Offset(10, 10)); // fuera del menú
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(resultado, isNull);
    expect(fotos.fuentes, isEmpty);
  });

  testWidgets('si la cámara falla avisa y no devuelve foto', (tester) async {
    fotos.error = Exception('permiso denegado');
    await abrir(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(resultado, isNull);
    expect(find.textContaining('No se pudo abrir la cámara'), findsOneWidget);
  });

  testWidgets('cancelar la cámara sin sacar foto no devuelve nada', (tester) async {
    fotos.foto = null;
    await abrir(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(resultado, isNull);
  });
}
