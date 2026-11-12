import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/admin_supabase_service.dart';
import 'package:intento2/uso_ia_logica.dart';
import 'package:intento2/uso_ia_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio con datos de muestra: no se conecta a ninguna base de datos.
class _ServicioDeMuestra extends AdminSupabaseService {
  _ServicioDeMuestra({this.datos, this.error})
      : super(
          client: SupabaseClient(
            'http://localhost:54321',
            'clave-de-prueba',
            // Sin renovación automática de sesión: dejaría un temporizador pendiente.
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final UsoIaDatos? datos;
  final Object? error;

  @override
  Future<UsoIaDatos> fetchUsoIa({required DateTime desde, required DateTime hasta}) async {
    if (error != null) throw error!;
    return datos!;
  }
}

Future<void> _mostrar(WidgetTester tester, AdminSupabaseService servicio) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: UsoIaPage(service: servicio))));
  await tester.pumpAndSettle();
}

void main() {
  final hoy = DateTime.now();
  String dia(int atras) {
    final d = DateTime(hoy.year, hoy.month, hoy.day, 12).subtract(Duration(days: atras));
    return d.toUtc().toIso8601String();
  }

  Map<String, dynamic> fila(int atras, {String resultado = 'ok', int? status, String usuario = 'u1', int? ms}) => {
        'usuario_id': usuario,
        'created_at': dia(atras),
        'resultado': resultado,
        'http_status': status,
        'con_archivo': true,
        'duracion_ms': ms,
      };

  testWidgets('con llamadas muestra las cifras, los errores y quién la usa más', (tester) async {
    final desde = DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 29));
    final resumen = resumenUsoIa(
      [
        fila(0, ms: 2000),
        fila(0, ms: 3000, usuario: 'u2'),
        fila(1, resultado: 'error', status: 503),
        fila(2, resultado: 'limitado', status: 429),
      ],
      desde: desde,
      hasta: DateTime(hoy.year, hoy.month, hoy.day),
    );
    final datos = UsoIaDatos(
      resumen: resumen,
      usuarios: {
        'u1': {'nombre_mostrar': 'Ana Pérez', 'email': 'ana@example.com'},
        'u2': {'nombre_mostrar': 'Luis Soto', 'email': 'luis@example.com'},
      },
    );

    await _mostrar(tester, _ServicioDeMuestra(datos: datos));

    expect(tester.takeException(), isNull); // sin desbordes ni errores al dibujar
    expect(find.text('Uso de IA'), findsOneWidget);
    expect(find.text('Llamadas a la IA'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Google con alta demanda (503)'), findsOneWidget);
    expect(find.text('Límite de 10 llamadas por minuto'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('luis@example.com'), findsOneWidget);
  });

  testWidgets('sin llamadas explica cuándo empieza a llenarse el registro', (tester) async {
    final hasta = DateTime(hoy.year, hoy.month, hoy.day);
    final vacio = UsoIaDatos(
      resumen: resumenUsoIa([], desde: hasta.subtract(const Duration(days: 29)), hasta: hasta),
      usuarios: const {},
    );

    await _mostrar(tester, _ServicioDeMuestra(datos: vacio));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Todavía no hay llamadas registradas'), findsOneWidget);
  });

  testWidgets('si falta la tabla indica aplicar la migración 0019', (tester) async {
    await _mostrar(
      tester,
      _ServicioDeMuestra(error: const PostgrestException(message: 'relation "public.uso_ia" does not exist')),
    );

    expect(find.textContaining('0019_uso_ia.sql'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('otro error muestra un aviso genérico con reintentar', (tester) async {
    await _mostrar(tester, _ServicioDeMuestra(error: Exception('sin conexión')));

    expect(find.textContaining('Error al cargar el uso de la IA'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
