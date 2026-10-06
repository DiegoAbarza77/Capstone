import 'package:flutter/material.dart';
import '../data/models/mantencion_model.dart';
import '../utils/mantencion_calculos.dart';
import '../utils/numero_chile.dart';

const Color kMantFondo = Color(0xFF0F172A);
const Color kMantPrimario = Color(0xFF4F46E5);
const Color kMantTarjeta = Color(0xFF1E293B);
const Color kMantTextoSuave = Color(0xFF94A3B8);
const Color kMantTexto = Color(0xFFF8FAFC);
const Color kMantIA = Color(0xFF8B5CF6);
const Color kMantAdvertencia = Color(0xFFF59E0B);
const Color kMantError = Color(0xFFEF4444);
const Color kMantOk = Color(0xFF10B981);

IconData iconoTipoMantencion(String? tipo) {
  switch (tipo) {
    case 'aceite':
      return Icons.oil_barrel_outlined;
    case 'frenos':
      return Icons.album_outlined;
    case 'neumaticos':
      return Icons.tire_repair_outlined;
    case 'preventiva':
      return Icons.build_circle_outlined;
    default:
      return Icons.build_outlined;
  }
}

Color colorTipoMantencion(String? tipo) {
  switch (tipo) {
    case 'aceite':
      return const Color(0xFFF59E0B);
    case 'frenos':
      return const Color(0xFFEF4444);
    case 'neumaticos':
      return const Color(0xFF38BDF8);
    case 'preventiva':
      return const Color(0xFF10B981);
    default:
      return const Color(0xFF94A3B8);
  }
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "15 sep 2026"
String formatoFechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "78.500 km"
String formatoKm(num km) => '${formatoCantidad(km.round())} km';

Color colorEstadoProgramada(EstadoProgramada estado) {
  switch (estado) {
    case EstadoProgramada.alDia:
      return kMantOk;
    case EstadoProgramada.proxima:
      return kMantAdvertencia;
    case EstadoProgramada.vencida:
      return kMantError;
  }
}

String etiquetaEstadoProgramada(EstadoProgramada estado) {
  switch (estado) {
    case EstadoProgramada.alDia:
      return 'Al día';
    case EstadoProgramada.proxima:
      return 'Próxima';
    case EstadoProgramada.vencida:
      return 'Vencida';
  }
}

/// Describe cuándo toca la mantención: "12 oct 2026 · en 11 días" y/o
/// "a los 88.500 km · faltan 1.200 km".
List<String> descripcionCriterios(MantencionProgramadaModel p, EvaluacionProgramada e) {
  final lineas = <String>[];

  final fecha = p.fechaProgramada;
  final dias = e.diasRestantes;
  if (fecha != null && dias != null) {
    final cuando = dias < 0
        ? 'venció hace ${-dias} ${-dias == 1 ? 'día' : 'días'}'
        : dias == 0
            ? 'es hoy'
            : 'en $dias ${dias == 1 ? 'día' : 'días'}';
    lineas.add('${formatoFechaCorta(fecha)} · $cuando');
  }

  final km = p.kmProgramado;
  if (km != null) {
    final restantes = e.kmRestantes;
    final detalle = restantes == null
        ? ''
        : restantes <= 0
            ? ' · ya se alcanzó'
            : ' · faltan ${formatoKm(restantes)}';
    lineas.add('a los ${formatoKm(km)}$detalle');
  }
  return lineas;
}

InputDecoration decoracionMantencion(String etiqueta, {String? ayuda, String? error, bool resaltar = false, IconData? icono}) {
  final borde = resaltar ? kMantAdvertencia : kMantTextoSuave.withValues(alpha: 0.5);
  return InputDecoration(
    labelText: etiqueta,
    helperText: ayuda,
    errorText: error,
    labelStyle: const TextStyle(color: kMantTextoSuave),
    helperStyle: TextStyle(color: resaltar ? kMantAdvertencia : kMantTextoSuave),
    prefixIcon: icono != null ? Icon(icono, color: kMantTextoSuave, size: 20) : null,
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borde)),
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kMantPrimario)),
  );
}
