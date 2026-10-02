import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_ok/data/services/conexion_servidor_service.dart';
import 'package:tag_ok/presentation/widgets/banner_sin_conexion.dart';

void main() {
  const mensaje = 'Sin conexión con el servidor, reintentando…';

  Widget app() => const MaterialApp(
        home: BannerSinConexion(child: Scaffold(body: Text('contenido'))),
      );

  tearDown(() => ConexionServidorService.instance.conectado.value = true);

  testWidgets('no muestra el aviso cuando hay conexión', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text(mensaje), findsNothing);
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('muestra el aviso sin perder el contenido cuando se cae la conexión', (tester) async {
    await tester.pumpWidget(app());

    ConexionServidorService.instance.conectado.value = false;
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(mensaje), findsOneWidget);
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('quita el aviso cuando vuelve la conexión', (tester) async {
    await tester.pumpWidget(app());

    ConexionServidorService.instance.conectado.value = false;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(mensaje), findsOneWidget);

    ConexionServidorService.instance.conectado.value = true;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(mensaje), findsNothing);
  });
}
