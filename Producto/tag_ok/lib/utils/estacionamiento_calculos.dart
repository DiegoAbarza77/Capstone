import '../data/models/estacionamiento_model.dart';

/// "2 h 15 min", "45 min", "3 h". Para duraciones de un estacionamiento ya
/// terminado.
String formatoDuracion(Duration d) {
  final totalMin = d.inMinutes;
  final horas = totalMin ~/ 60;
  final min = totalMin % 60;
  if (horas == 0) return '$min min';
  if (min == 0) return '$horas h';
  return '$horas h $min min';
}

/// "01:23:45", para el cronómetro que corre.
String formatoCronometro(Duration d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final horas = d.inHours;
  return '${dos(horas)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}';
}

/// "14:05"
String formatoHora(DateTime h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

/// Une un día con una hora y minutos.
DateTime combinarFechaHora(DateTime fecha, int hora, int minuto) =>
    DateTime(fecha.year, fecha.month, fecha.day, hora, minuto);

/// Calcula la hora de salida a partir del día de entrada y las horas escritas por
/// el usuario. Si la hora de salida es igual o anterior a la de entrada, se
/// entiende que el auto pasó la medianoche y salió al día siguiente.
({DateTime entrada, DateTime salida, bool diaSiguiente}) resolverEntradaSalida(
  DateTime fecha, {
  required int horaEntrada,
  required int minutoEntrada,
  required int horaSalida,
  required int minutoSalida,
}) {
  final entrada = combinarFechaHora(fecha, horaEntrada, minutoEntrada);
  var salida = combinarFechaHora(fecha, horaSalida, minutoSalida);
  final diaSiguiente = !salida.isAfter(entrada);
  if (diaSiguiente) salida = salida.add(const Duration(days: 1));
  return (entrada: entrada, salida: salida, diaSiguiente: diaSiguiente);
}

/// Estacionamientos cuyo día cae dentro del mes de [mes] (sin contar el que está
/// en curso, que todavía no tiene un costo).
List<EstacionamientoModel> estacionamientosDelMes(List<EstacionamientoModel> todos, DateTime mes) {
  return todos
      .where((e) => !e.enCurso && e.fecha.year == mes.year && e.fecha.month == mes.month)
      .toList();
}

double gastoEstacionamientos(Iterable<EstacionamientoModel> lista) {
  return lista.fold<double>(0, (suma, e) => suma + e.costo);
}

/// Tiempo total estacionado; ignora los registros sin duración conocida.
Duration tiempoTotalEstacionado(Iterable<EstacionamientoModel> lista) {
  return lista.fold<Duration>(Duration.zero, (suma, e) => suma + (e.duracion() ?? Duration.zero));
}

/// El estacionamiento con el cronómetro corriendo, si hay uno.
EstacionamientoModel? estacionamientoEnCurso(Iterable<EstacionamientoModel> lista) {
  for (final e in lista) {
    if (e.enCurso) return e;
  }
  return null;
}
