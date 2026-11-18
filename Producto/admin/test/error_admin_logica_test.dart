import 'package:flutter_test/flutter_test.dart';
import 'package:intento2/error_admin_logica.dart';

void main() {
  group('mensajeErrorCrearAdmin', () {
    test('correo repetido', () {
      final m = mensajeErrorCrearAdmin(
          400, 'A user with this email address has already been registered');
      expect(m, contains('ya está registrado'));
      expect(m, isNot(contains('already')));
    });

    test('contraseña débil', () {
      final m = mensajeErrorCrearAdmin(
          400, 'Password should be at least 6 characters');
      expect(m, contains('contraseña es muy débil'));
    });

    test('correo inválido', () {
      final m = mensajeErrorCrearAdmin(
          400, 'Unable to validate email address: invalid format');
      expect(m, contains('no es válido'));
    });

    test('faltan datos', () {
      expect(mensajeErrorCrearAdmin(400, 'email y password son requeridos'),
          contains('Completa el correo'));
    });

    test('sin permisos (403)', () {
      expect(
          mensajeErrorCrearAdmin(403, 'Forbidden: requiere rol super_admin'),
          contains('super administrador'));
      expect(mensajeErrorCrearAdmin(403, ''), contains('super administrador'));
    });

    test('sesión vencida (401)', () {
      expect(mensajeErrorCrearAdmin(401, 'Unauthorized'),
          contains('sesión expiró'));
    });

    test('función no desplegada (404)', () {
      expect(mensajeErrorCrearAdmin(404, 'Requested function was not found'),
          contains('no está disponible'));
    });

    test('falla de red', () {
      expect(mensajeErrorCrearAdmin(null, 'ClientException: Failed to fetch'),
          contains('No se pudo conectar'));
    });

    test('error desconocido conserva el detalle', () {
      final m = mensajeErrorCrearAdmin(400, 'algo raro');
      expect(m, contains('No se pudo crear el administrador'));
      expect(m, contains('algo raro'));
    });

    test('error desconocido sin detalle', () {
      expect(mensajeErrorCrearAdmin(null, '   '), contains('Error desconocido'));
    });
  });

  group('mensajeErrorAdmin (otras acciones)', () {
    test('eliminar: sin permiso usa la acción en el mensaje', () {
      final m = mensajeErrorAdmin('eliminar el usuario', 403, 'Forbidden');
      expect(m, contains('eliminar el usuario'));
      expect(m, contains('super administrador'));
    });

    test('eliminar: no puedes borrarte a ti mismo', () {
      final m = mensajeErrorAdmin('eliminar el usuario', 400,
          'No puedes eliminar tu propia cuenta desde aquí');
      expect(m, contains('tu propia cuenta'));
    });

    test('eliminar: usuario inexistente', () {
      final m = mensajeErrorAdmin('eliminar el usuario', 400, 'User not found');
      expect(m, contains('ya haya sido eliminado'));
    });

    test('correo de restablecimiento: límite de envíos', () {
      final m = mensajeErrorAdmin('enviar el correo', 429,
          'email rate limit exceeded');
      expect(m, contains('demasiados envíos'));
    });

    test('cambiar rol: política de seguridad de la base de datos', () {
      final m = mensajeErrorAdmin('cambiar el rol', null,
          '42501 new row violates row-level security policy');
      expect(m, contains('No tienes permiso para cambiar el rol'));
    });

    test('datos relacionados', () {
      final m = mensajeErrorAdmin('eliminar el usuario', 400,
          'violates foreign key constraint');
      expect(m, contains('datos relacionados'));
    });

    test('servidor sin configurar', () {
      final m = mensajeErrorAdmin('eliminar el usuario', 500,
          'Faltan variables de entorno en el servidor');
      expect(m, contains('volver a desplegar'));
    });

    test('error desconocido nombra la acción', () {
      final m = mensajeErrorAdmin('cambiar el rol', null, 'algo raro');
      expect(m, startsWith('No se pudo cambiar el rol.'));
      expect(m, contains('algo raro'));
    });
  });
}
