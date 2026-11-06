// Filtro por estado de la cuenta en la lista de Usuarios del panel.
//
// Una cuenta está suspendida cuando su campo `estado` vale 'suspendido'; todo lo
// demás (incluidas las cuentas antiguas sin ese campo) cuenta como activa, igual
// que en la tabla.

enum FiltroEstado { todos, activas, suspendidas }

String etiquetaFiltroEstado(FiltroEstado filtro) {
  switch (filtro) {
    case FiltroEstado.todos:
      return 'Todos los estados';
    case FiltroEstado.activas:
      return 'Activas';
    case FiltroEstado.suspendidas:
      return 'Suspendidas';
  }
}

bool cuentaSuspendida(Map<String, dynamic> usuario) => usuario['estado'] == 'suspendido';

bool coincideEstado(Map<String, dynamic> usuario, FiltroEstado filtro) {
  switch (filtro) {
    case FiltroEstado.todos:
      return true;
    case FiltroEstado.activas:
      return !cuentaSuspendida(usuario);
    case FiltroEstado.suspendidas:
      return cuentaSuspendida(usuario);
  }
}
