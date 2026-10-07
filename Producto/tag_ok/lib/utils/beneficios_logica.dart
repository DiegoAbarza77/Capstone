import '../data/models/beneficio_model.dart';

/// Filtro de vigencia temporal del catálogo.
enum FiltroVigencia {
  /// Cualquiera de los vigentes.
  cualquiera,

  /// Los que vencen en los próximos 7 días.
  venceEn7Dias,

  /// Los que vencen en los próximos 30 días.
  venceEn30Dias,
}

String etiquetaFiltroVigencia(FiltroVigencia f) {
  switch (f) {
    case FiltroVigencia.cualquiera:
      return 'Cualquier vigencia';
    case FiltroVigencia.venceEn7Dias:
      return 'Vencen esta semana';
    case FiltroVigencia.venceEn30Dias:
      return 'Vencen este mes';
  }
}

/// Criterios que el conductor puede combinar en el catálogo.
class FiltrosBeneficios {
  /// Categorías elegidas (puede ser más de una). Vacío significa todas.
  final Set<String> categorias;

  /// Ubicación elegida, o null para todas.
  final String? ubicacion;
  final FiltroVigencia vigencia;

  const FiltrosBeneficios({
    this.categorias = const {},
    this.ubicacion,
    this.vigencia = FiltroVigencia.cualquiera,
  });

  /// Cuántos criterios están aplicados (para mostrarlo en el botón de filtros).
  int get cantidadActivos =>
      (categorias.isNotEmpty ? 1 : 0) + (ubicacion != null ? 1 : 0) + (vigencia != FiltroVigencia.cualquiera ? 1 : 0);

  bool get hayFiltros => cantidadActivos > 0;

  FiltrosBeneficios copyWith({
    Set<String>? categorias,
    String? ubicacion,
    bool quitarUbicacion = false,
    FiltroVigencia? vigencia,
  }) {
    return FiltrosBeneficios(
      categorias: categorias ?? this.categorias,
      ubicacion: quitarUbicacion ? null : (ubicacion ?? this.ubicacion),
      vigencia: vigencia ?? this.vigencia,
    );
  }
}

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

/// true si hoy está dentro de la vigencia y el beneficio está activo. La base de
/// datos ya entrega solo estos, pero se revisa de nuevo por si el celular
/// guardó la lista un par de días y alguno venció mientras tanto.
bool estaVigente(BeneficioModel b, {DateTime? hoy}) {
  if (!b.activo) return false;
  final dia = _dia(hoy ?? DateTime.now());
  if (b.vigenciaDesde != null && b.vigenciaDesde!.isAfter(dia)) return false;
  if (b.vigenciaHasta != null && b.vigenciaHasta!.isBefore(dia)) return false;
  return true;
}

/// Días que faltan para que venza (0 si vence hoy), o null si no tiene fecha límite.
int? diasParaVencer(BeneficioModel b, {DateTime? hoy}) {
  final hasta = b.vigenciaHasta;
  if (hasta == null) return null;
  return _dia(hasta).difference(_dia(hoy ?? DateTime.now())).inDays;
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String _fechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "Vence hoy", "Vence mañana", "Vence en 5 días", "Hasta el 30 sep 2026" o
/// "Sin fecha límite".
String textoVigencia(BeneficioModel b, {DateTime? hoy}) {
  final dias = diasParaVencer(b, hoy: hoy);
  if (dias == null) return 'Sin fecha límite';
  if (dias == 0) return 'Vence hoy';
  if (dias == 1) return 'Vence mañana';
  if (dias <= 7) return 'Vence en $dias días';
  return 'Hasta el ${_fechaCorta(b.vigenciaHasta!)}';
}

/// El beneficio aplica en [ubicacion]: coincide con la suya, o no tiene ubicación
/// (aplica en todas partes).
bool _aplicaEn(BeneficioModel b, String ubicacion) {
  final u = b.ubicacion;
  if (u == null) return true;
  return u.trim().toLowerCase() == ubicacion.trim().toLowerCase();
}

/// Aplica los filtros y ordena: destacados primero y, dentro de cada grupo, los
/// que vencen antes (los que no vencen, al final) y luego por título.
List<BeneficioModel> aplicarFiltros(
  List<BeneficioModel> lista,
  FiltrosBeneficios filtros, {
  DateTime? hoy,
}) {
  bool cumple(BeneficioModel b) {
    if (!estaVigente(b, hoy: hoy)) return false;
    if (filtros.categorias.isNotEmpty && !filtros.categorias.contains(b.categoria ?? 'otros')) return false;
    if (filtros.ubicacion != null && !_aplicaEn(b, filtros.ubicacion!)) return false;

    final dias = diasParaVencer(b, hoy: hoy);
    switch (filtros.vigencia) {
      case FiltroVigencia.cualquiera:
        return true;
      case FiltroVigencia.venceEn7Dias:
        return dias != null && dias <= 7;
      case FiltroVigencia.venceEn30Dias:
        return dias != null && dias <= 30;
    }
  }

  final resultado = lista.where(cumple).toList();
  resultado.sort((a, b) {
    if (a.destacado != b.destacado) return a.destacado ? -1 : 1;
    final da = diasParaVencer(a, hoy: hoy);
    final db = diasParaVencer(b, hoy: hoy);
    if (da != db) {
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }
    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  });
  return resultado;
}

/// Ubicaciones que aparecen en el catálogo, sin repetir y ordenadas, para
/// ofrecerlas como opciones del filtro.
List<String> ubicacionesDisponibles(List<BeneficioModel> lista) {
  final vistas = <String, String>{};
  for (final b in lista) {
    final u = b.ubicacion?.trim();
    if (u != null && u.isNotEmpty) vistas.putIfAbsent(u.toLowerCase(), () => u);
  }
  final resultado = vistas.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return resultado;
}

/// Categorías que realmente tienen beneficios, en el orden en que se definen,
/// para no ofrecer filtros que dejarían la lista vacía.
List<String> categoriasConBeneficios(List<BeneficioModel> lista) {
  final presentes = {for (final b in lista) b.categoria ?? 'otros'};
  return kCategoriasBeneficio.keys.where(presentes.contains).toList();
}
