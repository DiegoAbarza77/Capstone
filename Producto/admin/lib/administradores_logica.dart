// Separa a los administradores de los conductores.
//
// En la base de datos, un disparador crea una fila en `usuarios` por cada
// cuenta nueva, incluidas las de los administradores. Para que la lista de
// Usuarios y las cifras del panel cuenten solo conductores, hay que excluir a
// las cuentas que figuran en `administradores`.
//
// Es lógica pura (sin Flutter ni Supabase) para poder probarla con tests.

/// Identificadores de las cuentas de administrador, a partir de las filas de
/// la tabla `administradores`. Ignora filas sin identificador.
Set<String> idsDeAdministradores(List<Map<String, dynamic>> filas) {
  final ids = <String>{};
  for (final fila in filas) {
    final id = fila['id']?.toString();
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  return ids;
}

/// Filas de `usuarios` sin las que pertenecen a un administrador.
List<Map<String, dynamic>> sinAdministradores(
  List<Map<String, dynamic>> filas,
  Set<String> idsAdmin,
) {
  if (idsAdmin.isEmpty) return filas;
  return filas.where((f) => !idsAdmin.contains(f['id']?.toString())).toList();
}

/// Total de conductores: el total de la tabla `usuarios` menos los
/// administradores que tienen fila ahí. Nunca devuelve un número negativo.
int conductoresTotales(int totalUsuarios, int administradoresEnUsuarios) {
  final resta = totalUsuarios - administradoresEnUsuarios;
  return resta < 0 ? 0 : resta;
}
