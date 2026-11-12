// Lógica de la sección "Uso de IA" del panel: resume el registro que deja la
// función gemini-proxy (tabla uso_ia) en cifras y listas. No depende de la
// pantalla, para poder probarla con pruebas automáticas.
//
// Cada fila del registro es: {usuario_id, created_at, resultado, http_status,
// con_archivo, duracion_ms}. `resultado` es 'ok', 'error' o 'limitado' (chocó con
// el límite de 10 llamadas por minuto).

/// Llamadas de un día, para el gráfico de barras.
class UsoIaDia {
  final DateTime fecha;
  final int llamadas;
  final int fallidas;

  const UsoIaDia({required this.fecha, required this.llamadas, required this.fallidas});
}

/// Llamadas de un usuario dentro del período.
class UsoIaUsuario {
  final String usuarioId;
  final int llamadas;
  final int fallidas;

  const UsoIaUsuario({required this.usuarioId, required this.llamadas, required this.fallidas});
}

class UsoIaResumen {
  final int total;
  final int exitosas;
  final int conError;
  final int limitadas;

  /// Usuarios distintos que usaron la IA en el período.
  final int usuarios;
  final int conArchivo;

  /// Duración promedio de las llamadas que terminaron bien, en milisegundos.
  final double? duracionPromedioMs;

  final List<UsoIaDia> porDia;

  /// Causas de fallo, de la más frecuente a la menos: etiqueta -> cantidad.
  final Map<String, int> erroresPorTipo;

  /// Los usuarios con más llamadas (máximo 5).
  final List<UsoIaUsuario> topUsuarios;

  const UsoIaResumen({
    required this.total,
    required this.exitosas,
    required this.conError,
    required this.limitadas,
    required this.usuarios,
    required this.conArchivo,
    required this.duracionPromedioMs,
    required this.porDia,
    required this.erroresPorTipo,
    required this.topUsuarios,
  });

  /// Llamadas que no terminaron bien: errores y límite alcanzado.
  int get fallidas => conError + limitadas;

  /// Porcentaje de llamadas exitosas (0 a 100); 0 si no hubo llamadas.
  double get tasaExito => total == 0 ? 0 : exitosas * 100 / total;

  bool get estaVacio => total == 0;
}

/// Lo que muestra la pantalla: el resumen y los datos de quienes encabezan la lista.
class UsoIaDatos {
  final UsoIaResumen resumen;

  /// id de usuario -> {nombre_mostrar, email}, solo de los que aparecen en la lista.
  final Map<String, Map<String, dynamic>> usuarios;

  const UsoIaDatos({required this.resumen, required this.usuarios});
}

/// Texto de la causa de un fallo, para mostrar al administrador.
String etiquetaErrorIa(String resultado, int? httpStatus) {
  if (resultado == 'limitado') return 'Límite de 10 llamadas por minuto';
  switch (httpStatus) {
    case 503:
      return 'Google con alta demanda (503)';
    case 429:
      return 'Cuota de Google agotada (429)';
    case 502:
      return 'Respuesta vacía o bloqueada';
    case null:
      return 'Error sin detalle';
    default:
      return 'Error de Gemini ($httpStatus)';
  }
}

DateTime _soloDia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

/// Resume las filas del registro entre [desde] y [hasta] (ambos días incluidos).
/// Las filas fuera de ese rango se ignoran.
UsoIaResumen resumenUsoIa(
  List<Map<String, dynamic>> filas, {
  required DateTime desde,
  required DateTime hasta,
}) {
  final primerDia = _soloDia(desde);
  final ultimoDia = _soloDia(hasta);

  final dias = <DateTime, List<int>>{}; // día -> [llamadas, fallidas]
  for (var d = primerDia; !d.isAfter(ultimoDia); d = DateTime(d.year, d.month, d.day + 1)) {
    dias[d] = [0, 0];
  }

  var total = 0, exitosas = 0, conError = 0, limitadas = 0, conArchivo = 0;
  var sumaDuracion = 0, cuentaDuracion = 0;
  final usuarios = <String>{};
  final errores = <String, int>{};
  final porUsuario = <String, List<int>>{}; // id -> [llamadas, fallidas]

  for (final fila in filas) {
    final cuando = DateTime.tryParse(fila['created_at']?.toString() ?? '');
    if (cuando == null) continue;
    final dia = _soloDia(cuando.toLocal());
    final contadorDia = dias[dia];
    if (contadorDia == null) continue; // fuera del período

    final resultado = fila['resultado']?.toString() ?? 'error';
    final fallida = resultado != 'ok';
    final status = fila['http_status'] is num ? (fila['http_status'] as num).toInt() : null;

    total++;
    contadorDia[0]++;
    if (fallida) contadorDia[1]++;

    if (resultado == 'ok') {
      exitosas++;
      final ms = fila['duracion_ms'];
      if (ms is num) {
        sumaDuracion += ms.toInt();
        cuentaDuracion++;
      }
    } else if (resultado == 'limitado') {
      limitadas++;
    } else {
      conError++;
    }
    if (fallida) {
      final etiqueta = etiquetaErrorIa(resultado, status);
      errores[etiqueta] = (errores[etiqueta] ?? 0) + 1;
    }
    if (fila['con_archivo'] == true) conArchivo++;

    final usuarioId = fila['usuario_id']?.toString();
    if (usuarioId != null) {
      usuarios.add(usuarioId);
      final contador = porUsuario.putIfAbsent(usuarioId, () => [0, 0]);
      contador[0]++;
      if (fallida) contador[1]++;
    }
  }

  final erroresOrdenados = Map.fromEntries(
    errores.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key)),
  );

  final top = porUsuario.entries
      .map((e) => UsoIaUsuario(usuarioId: e.key, llamadas: e.value[0], fallidas: e.value[1]))
      .toList()
    ..sort((a, b) => b.llamadas != a.llamadas ? b.llamadas.compareTo(a.llamadas) : a.usuarioId.compareTo(b.usuarioId));

  return UsoIaResumen(
    total: total,
    exitosas: exitosas,
    conError: conError,
    limitadas: limitadas,
    usuarios: usuarios.length,
    conArchivo: conArchivo,
    duracionPromedioMs: cuentaDuracion == 0 ? null : sumaDuracion / cuentaDuracion,
    porDia: [
      for (final e in dias.entries) UsoIaDia(fecha: e.key, llamadas: e.value[0], fallidas: e.value[1]),
    ],
    erroresPorTipo: erroresOrdenados,
    topUsuarios: top.take(5).toList(),
  );
}

/// "2,3 s" o "850 ms"; "—" si no hay datos.
String formatoDuracionIa(double? milisegundos) {
  if (milisegundos == null) return '—';
  if (milisegundos < 1000) return '${milisegundos.round()} ms';
  final segundos = (milisegundos / 100).round() / 10;
  return '${segundos.toString().replaceAll('.', ',')} s';
}
