import '../data/models/carga_combustible_model.dart';

/// Rendimiento estimado de un vehículo: kilómetros recorridos por cada litro
/// (o kWh) cargado.
class RendimientoCombustible {
  final double kmPorUnidad;
  final String unidad;

  /// Cantidad de tramos (pares de llenados sucesivos) usados en el promedio.
  final int tramos;

  const RendimientoCombustible({
    required this.kmPorUnidad,
    required this.unidad,
    required this.tramos,
  });

  /// Para mostrarlo como "12,5 km/L" o "6,1 km/kWh".
  String get etiqueta => 'km/${etiquetaUnidad(unidad)}';
}

/// Estima el rendimiento a partir de cargas con estanque lleno y odómetro.
///
/// Entre dos llenados sucesivos, lo que se carga en el segundo repone lo que se
/// consumió desde el primero. Por eso, para cada par se toma la distancia entre
/// ambos kilometrajes y la cantidad del segundo llenado; el resultado es el
/// promedio ponderado (kilómetros totales / cantidad total).
///
/// Devuelve null si no hay al menos dos llenados comparables en [unidad].
RendimientoCombustible? calcularRendimiento(
  List<CargaCombustibleModel> cargas, {
  required String unidad,
}) {
  final llenados = cargas
      .where((c) => c.tanqueLleno && c.unidad == unidad && c.kilometraje != null && c.cantidad > 0)
      .toList()
    ..sort((a, b) => a.kilometraje!.compareTo(b.kilometraje!));

  double kmTotales = 0;
  double cantidadTotal = 0;
  int tramos = 0;

  for (var i = 1; i < llenados.length; i++) {
    final distancia = llenados[i].kilometraje! - llenados[i - 1].kilometraje!;
    if (distancia <= 0) continue; // mismo kilometraje: no hay tramo que medir
    kmTotales += distancia;
    cantidadTotal += llenados[i].cantidad;
    tramos++;
  }

  if (tramos == 0 || cantidadTotal <= 0) return null;
  return RendimientoCombustible(kmPorUnidad: kmTotales / cantidadTotal, unidad: unidad, tramos: tramos);
}

/// Cargas cuya fecha cae dentro del mes de [mes].
List<CargaCombustibleModel> cargasDelMes(List<CargaCombustibleModel> cargas, DateTime mes) {
  return cargas.where((c) => c.fecha.year == mes.year && c.fecha.month == mes.month).toList();
}

double gastoTotal(Iterable<CargaCombustibleModel> cargas) {
  return cargas.fold<double>(0, (suma, c) => suma + c.total);
}

/// Cantidad cargada en [unidad] (litros o kWh), sin mezclar unidades.
double cantidadTotal(Iterable<CargaCombustibleModel> cargas, String unidad) {
  return cargas.where((c) => c.unidad == unidad).fold<double>(0, (suma, c) => suma + c.cantidad);
}
