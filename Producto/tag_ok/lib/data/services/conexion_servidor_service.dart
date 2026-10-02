import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Comprueba cada cierto tiempo si el servidor (Supabase) es alcanzable, para
/// poder avisarle al usuario en vez de dejarlo frente a una pantalla sin datos
/// cuando falla su internet o el DNS. Solo consulta el endpoint de salud de
/// Auth: no envía ni lee datos del usuario.
class ConexionServidorService {
  ConexionServidorService._();
  static final ConexionServidorService instance = ConexionServidorService._();

  /// true mientras el servidor responde; false cuando no se puede alcanzar.
  final ValueNotifier<bool> conectado = ValueNotifier<bool>(true);

  static const _intervaloConectado = Duration(seconds: 30);
  // Con el servidor caído se reintenta más seguido para quitar el aviso rápido.
  static const _intervaloDesconectado = Duration(seconds: 5);
  static const _tiempoMaximo = Duration(seconds: 8);

  Timer? _timer;
  bool _iniciado = false;

  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    _verificarYProgramar();
  }

  void detener() {
    _iniciado = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _verificarYProgramar() async {
    await _verificar();
    if (!_iniciado) return;
    _timer = Timer(
      conectado.value ? _intervaloConectado : _intervaloDesconectado,
      _verificarYProgramar,
    );
  }

  Future<void> _verificar() async {
    final url = dotenv.env['SUPABASE_URL'];
    final apiKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (url == null || url.isEmpty || apiKey == null || apiKey.isEmpty) return;

    try {
      final respuesta = await http
          .get(Uri.parse('$url/auth/v1/health'), headers: {'apikey': apiKey})
          .timeout(_tiempoMaximo);
      // Cualquier respuesta por debajo de 500 significa que el servidor llegó a
      // contestar, así que la conexión está bien.
      conectado.value = respuesta.statusCode < 500;
    } catch (e) {
      debugPrint('TAG_OK_CONEXION: servidor no alcanzable ($e)');
      conectado.value = false;
    }
  }
}
