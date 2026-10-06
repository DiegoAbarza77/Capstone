import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Interpreta un número escrito a la chilena: la coma es decimal ("32,5") y el
/// punto suele separar miles ("45.000"). Devuelve null si no se puede leer.
///
/// En una cantidad de litros el punto puede ser decimal ("32.500 L" son 32,5
/// litros), por eso [puntoEsMiles] es opcional: con él, un punto seguido de
/// exactamente tres dígitos se lee como separador de miles (montos, precios y
/// kilómetros, que van sin decimales).
double? parseNumeroChile(dynamic valor, {bool puntoEsMiles = false}) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  var t = valor.toString().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',') && t.contains('.')) {
    // "1.234,5": el último separador es el decimal.
    t = t.lastIndexOf(',') > t.lastIndexOf('.') ? t.replaceAll('.', '').replaceAll(',', '.') : t.replaceAll(',', '');
  } else if (t.contains(',')) {
    t = t.replaceAll(',', '.');
  } else if (puntoEsMiles && RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

/// "$43.875"
String formatoPesos(num monto) => '\$${NumberFormat.decimalPattern('es').format(monto.round())}';

/// "32,5" o "40" (sin ceros de más).
String formatoCantidad(num cantidad) {
  final entero = cantidad == cantidad.roundToDouble();
  return NumberFormat(entero ? '#,##0' : '#,##0.0#', 'es').format(cantidad);
}

/// "1234567" -> "1.234.567". Acepta un entero o un texto de dígitos.
String formatearMiles(Object valor) {
  final digitos = valor.toString().replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return '';
  final sinCeros = digitos.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < sinCeros.length; i++) {
    if (i > 0 && (sinCeros.length - i) % 3 == 0) buffer.write('.');
    buffer.write(sinCeros[i]);
  }
  return buffer.toString();
}

/// Da formato de miles a un campo numérico mientras el usuario escribe: tipea
/// 129900 y ve 129.900. Solo admite dígitos (pensado para pesos y kilómetros,
/// que van sin decimales). Leer el valor con
/// `parseNumeroChile(texto, puntoEsMiles: true)`.
class MilesInputFormatter extends TextInputFormatter {
  static const _maximoDigitos = 12;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    var digitos = nuevo.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return const TextEditingValue();
    if (digitos.length > _maximoDigitos) digitos = digitos.substring(0, _maximoDigitos);
    final texto = formatearMiles(digitos);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
