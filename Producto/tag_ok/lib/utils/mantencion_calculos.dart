import '../data/models/mantencion_model.dart';

enum EstadoProgramada { alDia, proxima, vencida }

/// Resultado de evaluar una mantención programada contra la fecha de hoy y el
/// kilometraje actual del vehículo.
class EvaluacionProgramada {
  final EstadoProgramada estado;

  /// Días que faltan para la fecha programada (negativo si ya pasó), o null si
  /// no se programó por fecha.
  final int? diasRestantes;

  /// Kilómetros que faltan para el kilometraje programado (negativo si ya se
  /// pasó), o null si no se programó por kilometraje o no se conoce el actual.
  final double? kmRestantes;

  const EvaluacionProgramada({required this.estado, this.diasRestantes, this.kmRestantes});
}

DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// Evalúa una mantención programada. Si tiene fecha y kilometraje, manda el
/// criterio más urgente de los dos.
EvaluacionProgramada evaluarProgramada(
  MantencionProgramadaModel p, {
  double? kmActual,
  DateTime? hoy,
}) {
  final ahora = _soloFecha(hoy ?? DateTime.now());
  var estado = EstadoProgramada.alDia;

  int? dias;
  if (p.fechaProgramada != null) {
    dias = _soloFecha(p.fechaProgramada!).difference(ahora).inDays;
    if (dias < 0) {
      estado = EstadoProgramada.vencida;
    } else if (dias <= p.avisoDiasAntes) {
      estado = EstadoProgramada.proxima;
    }
  }

  double? km;
  if (p.kmProgramado != null && kmActual != null) {
    km = p.kmProgramado! - kmActual;
    if (km <= 0) {
      estado = EstadoProgramada.vencida;
    } else if (km <= p.avisoKmAntes && estado == EstadoProgramada.alDia) {
      estado = EstadoProgramada.proxima;
    }
  }

  return EvaluacionProgramada(estado: estado, diasRestantes: dias, kmRestantes: km);
}

/// Devuelve la mantención anterior si el kilometraje [km] que se está
/// registrando es MENOR que el de ella (una incongruencia que conviene
/// verificar), o null si todo cuadra.
///
/// "Anterior" es la mantención más reciente con kilometraje cuya fecha sea igual
/// o previa a [fecha]. [excluirId] sirve al editar, para no compararse consigo
/// misma.
MantencionModel? incongruenciaKilometraje(
  List<MantencionModel> existentes, {
  required DateTime fecha,
  required double km,
  String? excluirId,
}) {
  final limite = _soloFecha(fecha);
  MantencionModel? anterior;

  for (final m in existentes) {
    if (m.id == excluirId || m.kilometraje == null) continue;
    if (_soloFecha(m.fecha).isAfter(limite)) continue;
    if (anterior == null) {
      anterior = m;
      continue;
    }
    final fm = _soloFecha(m.fecha);
    final fa = _soloFecha(anterior.fecha);
    if (fm.isAfter(fa) || (fm == fa && m.kilometraje! > anterior.kilometraje!)) anterior = m;
  }

  if (anterior != null && km < anterior.kilometraje!) return anterior;
  return null;
}

/// Suma [meses] a una fecha, dejando el día dentro del mes de destino
/// (31 de agosto + 6 meses = 28 de febrero, y no 3 de marzo).
DateTime sumarMeses(DateTime fecha, int meses) {
  final totalMeses = fecha.month - 1 + meses;
  final anio = fecha.year + totalMeses ~/ 12;
  final mes = totalMeses % 12 + 1;
  final ultimoDia = DateTime(anio, mes + 1, 0).day;
  return DateTime(anio, mes, fecha.day > ultimoDia ? ultimoDia : fecha.day);
}

/// Propuesta de cuándo hacer la siguiente mantención, según el tipo que se
/// acaba de hacer. Son valores habituales y el usuario siempre puede cambiarlos.
({DateTime fecha, double? km}) sugerirProximaMantencion(
  String tipo, {
  required DateTime fechaBase,
  double? kmBase,
}) {
  final (kmIntervalo, meses) = switch (tipo) {
    'frenos' => (20000.0, 12),
    'neumaticos' => (40000.0, 24),
    _ => (10000.0, 6), // aceite, preventiva y otras
  };
  return (
    fecha: sumarMeses(fechaBase, meses),
    km: kmBase != null ? kmBase + kmIntervalo : null,
  );
}

double costoTotalMantenciones(Iterable<MantencionModel> mantenciones) {
  return mantenciones.fold<double>(0, (suma, m) => suma + m.costo);
}
