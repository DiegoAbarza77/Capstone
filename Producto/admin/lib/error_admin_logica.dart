// Traduce los errores de las acciones del panel (crear o eliminar usuarios y
// administradores, cambiar roles, enviar correos de restablecimiento, etc.) a
// mensajes claros en español, en vez de mostrar el texto técnico.
//
// Es lógica pura (sin Flutter ni Supabase) para poder probarla con tests.

/// Devuelve un mensaje en español para un error del panel.
///
/// [accion] describe lo que se intentaba hacer, en infinitivo y sin punto:
/// "crear el administrador", "eliminar el usuario", etc.
/// [status] es el código HTTP si el error vino de una función del servidor
/// (null si no se conoce, por ejemplo una falla de red).
/// [detalle] es el texto original del error.
String mensajeErrorAdmin(String accion, int? status, String detalle) {
  final texto = detalle.trim();
  final t = texto.toLowerCase();

  if (t.contains('already been registered') ||
      t.contains('already registered') ||
      t.contains('already exists') ||
      t.contains('duplicate key')) {
    return 'Ese correo ya está registrado en el sistema (puede ser un conductor '
        'o un administrador anterior). Usa otro correo.';
  }
  if (t.contains('password') &&
      (t.contains('at least') || t.contains('weak') || t.contains('short'))) {
    return 'La contraseña es muy débil: usa al menos 6 caracteres '
        '(se recomiendan 8 o más).';
  }
  if (t.contains('unable to validate email') ||
      (t.contains('email') && t.contains('invalid'))) {
    return 'El correo no es válido. Revisa que esté bien escrito.';
  }
  if (t.contains('rate limit') ||
      t.contains('too many requests') ||
      status == 429) {
    return 'Se hicieron demasiados envíos de correo seguidos. '
        'Espera unos minutos e inténtalo de nuevo.';
  }
  if (t.contains('email y password son requeridos')) {
    return 'Completa el correo y la contraseña.';
  }
  if (t.contains('no puedes eliminar tu propia cuenta')) {
    return 'No puedes eliminar tu propia cuenta desde el panel.';
  }
  if (t.contains('user not found') || t.contains('user_not_found')) {
    return 'No se encontró el usuario. Puede que ya haya sido eliminado: '
        'actualiza la lista.';
  }
  if (t.contains('foreign key')) {
    return 'No se puede completar porque el registro tiene datos relacionados.';
  }
  if (status == 403 ||
      t.contains('forbidden') ||
      t.contains('row-level security') ||
      t.contains('permission denied') ||
      t.contains('42501')) {
    return 'No tienes permiso para $accion. '
        'Solo un super administrador puede hacerlo.';
  }
  if (status == 401 || t.contains('unauthorized') || t.contains('jwt expired')) {
    return 'Tu sesión expiró. Cierra sesión, vuelve a entrar y repite.';
  }
  if (status == 404 || t.contains('function not found')) {
    return 'La función del servidor no está disponible. '
        'Hay que desplegarla en Supabase.';
  }
  if (t.contains('faltan variables de entorno')) {
    return 'El servidor no está configurado correctamente. '
        'Hay que volver a desplegar la función.';
  }
  if (t.contains('failed to fetch') ||
      t.contains('socketexception') ||
      t.contains('clientexception')) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión e '
        'inténtalo de nuevo.';
  }
  return 'No se pudo $accion. '
      '${texto.isEmpty ? 'Error desconocido.' : 'Detalle: $texto'}';
}

/// Atajo para el caso de crear un administrador.
String mensajeErrorCrearAdmin(int? status, String detalle) =>
    mensajeErrorAdmin('crear el administrador', status, detalle);
