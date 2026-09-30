import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importa dotenv
import 'screens/login_screen.dart'; // Importa tu nueva pantalla
import 'screens/home_screen.dart'; // Importa la pantalla principal
import 'data/services/notificaciones_vencimiento_service.dart';

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

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TagOk',
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
            return const HomeScreen();
          }
          // Si no hay sesión, muestra el Login
          return const LoginScreen();
        },
      ),
    );
  }
}
