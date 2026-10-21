import '../data/models/carga_combustible_model.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/models/estacionamiento_model.dart';
import '../data/models/mantencion_model.dart';
import '../data/models/trip_history.dart';
import 'combustible_metricas.dart';
import 'estacionamiento_calculos.dart';
import 'mantencion_calculos.dart';
import 'numero_chile.dart';

/// Gasto del mes de un vehículo, separado por categoría (CU16).
class GastosMes {
  final double tag;
  final double combustible;
  final double estacionamientos;
  final double mantenciones;

  const GastosMes({
    this.tag = 0,
    this.combustible = 0,
    this.estacionamientos = 0,
    this.mantenciones = 0,
  });

  double get total => tag + combustible + estacionamientos + mantenciones;

  /// Parte del total que representa [monto], entre 0 y 1 (0 si no hay gastos).
  double fraccion(double monto) => total <= 0 ? 0 : monto / total;
}

bool _mismoMes(DateTime f, DateTime mes) => f.year == mes.year && f.month == mes.month;

/// Peajes del mes de la patente indicada. Los viajes guardan el vehículo como
/// "Marca (PATENTE)", así que se busca la patente dentro de ese nombre.
double gastoTagDelMes(Iterable<TripHistory> viajes, String patente, DateTime mes) {
  final p = patente.trim().toUpperCase();
  if (p.isEmpty) return 0;
  return viajes
      .where((v) => _mismoMes(v.date, mes) && v.vehicleName.toUpperCase().contains(p))
      .fold<double>(0, (suma, v) => suma + v.totalCost);
}

GastosMes calcularGastosMes({
  required DateTime mes,
  required String patente,
  Iterable<TripHistory> viajes = const [],
  List<CargaCombustibleModel> cargas = const [],
  List<EstacionamientoModel> estacionamientos = const [],
  List<MantencionModel> mantenciones = const [],
}) {
  return GastosMes(
    tag: gastoTagDelMes(viajes, patente, mes),
    combustible: gastoTotal(cargasDelMes(cargas, mes)),
    estacionamientos: gastoEstacionamientos(estacionamientosDelMes(estacionamientos, mes)),
    mantenciones: costoTotalMantenciones(mantenciones.where((m) => _mismoMes(m.fecha, mes))),
  );
}

/// Días hasta el documento que vence primero (negativo si ya hay uno vencido),
/// o null si ningún documento tiene fecha de vencimiento.
int? diasProximoVencimiento(Iterable<DocumentoVehiculoModel> documentos) {
  int? menor;
  for (final d in documentos) {
    final dias = d.diasParaVencer;
    if (dias != null && (menor == null || dias < menor)) menor = dias;
  }
  return menor;
}

/// Texto y estado de la tarjeta "Próxima mantención": prioriza los kilómetros
/// que faltan; si solo hay fecha, usa los días.
({String texto, bool urgente}) resumenProximaMantencion(Iterable<EvaluacionProgramada> evaluaciones) {
  double? km;
  int? dias;
  var urgente = false;
  for (final e in evaluaciones) {
    if (e.estado == EstadoProgramada.vencida) urgente = true;
    final k = e.kmRestantes;
    if (k != null && (km == null || k < km)) km = k;
    final d = e.diasRestantes;
    if (d != null && (dias == null || d < dias)) dias = d;
  }
  if (km != null) {
    return km <= 0
        ? (texto: 'Vencida', urgente: true)
        : (texto: '${formatearMiles(km.round())} km', urgente: urgente);
  }
  if (dias != null) {
    return dias < 0
        ? (texto: 'Vencida', urgente: true)
        : (texto: '$dias ${dias == 1 ? 'día' : 'días'}', urgente: urgente);
  }
  return (texto: 'Sin programar', urgente: false);
}
