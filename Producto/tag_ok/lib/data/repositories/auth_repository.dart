import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_offline.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Stream para escuchar cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  // Iniciar Sesión
  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    final AuthResponse respuesta;
    try {
      respuesta = await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw _handleAuthException(e);
    }
    // Una cuenta suspendida por un administrador no puede entrar (CU18).
    if (await cuentaSuspendida()) {
      await _client.auth.signOut();
      throw mensajeCuentaSuspendida;
    }
    return respuesta;
  }

  static const String mensajeCuentaSuspendida =
      'Tu cuenta está suspendida. Contacta al administrador para reactivarla.';

  /// true si el administrador suspendió la cuenta de la sesión actual. Si no se
  /// puede consultar (sin red, o la columna aún no existe) se deja pasar: no se
  /// bloquea a nadie por un fallo de conexión.
  Future<bool> cuentaSuspendida() async {
    final id = currentUser?.id;
    if (id == null) return false;
    try {
      final fila = await _client.from('usuarios').select('estado').eq('id', id).maybeSingle();
      return fila?['estado'] == 'suspendido';
    } catch (_) {
      return false;
    }
  }

  // Registrarse. La fila en la tabla "usuarios" la crea automáticamente el
  // trigger on_auth_user_created (ver supabase/migrations/0002_profile_trigger.sql)
  // a partir de los metadatos que se pasan aquí.
  Future<AuthResponse> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? nombre,
    String? telefono,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (nombre != null) 'nombre_mostrar': nombre,
          if (telefono != null) 'telefono': telefono,
        },
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Cerrar Sesión
  Future<void> signOut() async {
    await _client.auth.signOut();
    await CacheOffline.limpiar();
  }

  // Enviar correo de recuperación de contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Reautentica con la contraseña actual antes de cambiarla. Supabase no
  // exige esto para updateUser (la sesión ya está autenticada), pero evita
  // que alguien con el celular desbloqueado cambie la contraseña sin saberla.
  Future<void> reauthenticate(String email, String currentPassword) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: currentPassword);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Cambiar la contraseña de la sesión actual
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Manejador de errores amigable
  String _handleAuthException(dynamic e) {
    if (e is AuthException) {
      switch (e.code) {
        case 'invalid_credentials':
          return 'Credenciales incorrectas.';
        case 'user_already_exists':
        case 'email_exists':
          return 'El correo ya está registrado.';
        case 'weak_password':
          return 'La contraseña es muy débil (mínimo 6 caracteres).';
        case 'email_address_invalid':
          return 'El formato del correo es inválido.';
        default:
          return 'Ocurrió un error de autenticación: ${e.message}';
      }
    }
    return 'Ocurrió un error inesperado.';
  }
}
