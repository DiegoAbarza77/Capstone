// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tag_ok/utils/selector_archivo.dart';

/// Cámara simulada: devuelve la foto que se le indique, o falla.
class _CamaraFalsa extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  XFile? foto;
  Object? error;
  int llamadas = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    llamadas++;
    if (error != null) throw error!;
    return foto;
  }
}

void main() {
  late _CamaraFalsa camara;
  ArchivoElegido? resultado;
  var terminado = false;

  setUp(() {
    camara = _CamaraFalsa();
    ImagePickerPlatform.instance = camara;
    resultado = null;
    terminado = false;
  });

  Future<void> abrirSelector(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await elegirArchivoConCamara(context, extensiones: const ['pdf', 'jpg']);
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

  testWidgets('en el celular ofrece tomar una foto o elegir un archivo', (tester) async {
    await abrirSelector(tester);

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir archivo'), findsOneWidget);
  });

  testWidgets('tomar una foto devuelve sus bytes y un nombre .jpg', (tester) async {
    camara.foto = XFile.fromData(Uint8List.fromList([1, 2, 3, 4]), path: '/cache/image_picker_8841');
    await abrirSelector(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(resultado, isNotNull);
    expect(resultado!.bytes, Uint8List.fromList([1, 2, 3, 4]));
    expect(resultado!.name, 'image_picker_8841.jpg');
    expect(camara.llamadas, 1);
  });

  testWidgets('una foto que ya trae extensión conserva su nombre', (tester) async {
    camara.foto = XFile.fromData(Uint8List.fromList([9]), path: '/cache/boleta.png');
    await abrirSelector(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(resultado!.name, 'boleta.png');
  });

  testWidgets('una foto sin nombre recibe uno por defecto', (tester) async {
    camara.foto = XFile.fromData(Uint8List.fromList([7]));
    await abrirSelector(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(resultado!.name, 'foto.jpg');
  });

  testWidgets('si se cierra la cámara sin sacar foto no devuelve nada', (tester) async {
    camara.foto = null;
    await abrirSelector(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(resultado, isNull);
  });

  testWidgets('si la cámara falla avisa al usuario y no devuelve nada', (tester) async {
    camara.error = Exception('permiso denegado');
    await abrirSelector(tester);

    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(resultado, isNull);
    expect(find.textContaining('No se pudo abrir la cámara'), findsOneWidget);
  });

  testWidgets('cerrar el menú sin elegir no abre la cámara', (tester) async {
    await abrirSelector(tester);

    await tester.tapAt(const Offset(10, 10)); // fuera del menú
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(resultado, isNull);
    expect(camara.llamadas, 0);
  });
}
