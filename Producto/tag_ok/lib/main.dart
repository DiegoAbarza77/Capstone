import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importa dotenv
import 'screens/login_screen.dart'; // Importa tu nueva pantalla
import 'screens/home_screen.dart'; // Importa la pantalla principal
import 'data/repositories/auth_repository.dart';
import 'data/services/notificaciones_vencimiento_service.dart';
import 'data/services/conexion_servidor_service.dart';
import 'presentation/widgets/banner_sin_conexion.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importa Riverpod


void main() async {
  // 1. Asegura que los widgets estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargar las variables de entorno (Supabase, Mapbox y Gemini)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error al cargar .env: $e");
  }

  // 3. Inicializa Supabase con las credenciales del proyecto
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 4. Inicializa el plugin de notificaciones locales (vencimientos de
  // documentos del vehículo). No pide permiso todavía -- eso ocurre recién
  // cuando el usuario entra al módulo de Documentos, para no interrumpir el
  // primer arranque de la app con un diálogo de permisos.
  await NotificacionesVencimientoService().init();

  // 5. Empieza a vigilar la conexión con el servidor para mostrar el aviso
  // "Sin conexión" cuando falle internet o el DNS.
  ConexionServidorService.instance.iniciar();

  runApp(const ProviderScope(child: MyApp()));
}

final GlobalKey<ScaffoldMessengerState> _mensajesKey = GlobalKey<ScaffoldMessengerState>();

/// Si el administrador suspende la cuenta mientras la persona ya tenía la sesión
/// abierta, al abrir la app se cierra la sesión y se avisa (CU18).
class _GuardiaCuenta extends StatefulWidget {
  final Widget child;
  const _GuardiaCuenta({required this.child});

  @override
  State<_GuardiaCuenta> createState() => _GuardiaCuentaState();
}

class _GuardiaCuentaState extends State<_GuardiaCuenta> {
  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final repo = AuthRepository();
    if (await repo.cuentaSuspendida()) {
      await repo.signOut();
      _mensajesKey.currentState?.showSnackBar(
        const SnackBar(content: Text(AuthRepository.mensajeCuentaSuspendida), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _mensajesKey,
      title: 'TagOk',
      builder: (context, child) => BannerSinConexion(child: child ?? const SizedBox.shrink()),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Si todavía está revisando si hay sesión guardada
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Si encontró una sesión activa, manda directo al Home
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const _GuardiaCuenta(child: HomeScreen());
          }
          // Si no hay sesión, muestra el Login
          return const LoginScreen();
        },
      ),
    );
  }
}
