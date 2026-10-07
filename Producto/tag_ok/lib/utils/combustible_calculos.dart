import 'numero_chile.dart';

/// Tipo de energía con que arranca el formulario según el combustible del
/// vehículo. Un híbrido arranca en bencina (si va a cargar electricidad lo cambia).
String tipoEnergiaPorDefecto(String? combustibleDelVehiculo) {
  switch (combustibleDelVehiculo) {
    case 'Eléctrico':
      return 'Eléctrico';
    case 'Diésel':
      return 'Diésel';
    default:
      return 'Bencina';
  }
}

/// Cantidad, precio por unidad y total ya completos.
typedef MontosCarga = ({double cantidad, double precio, double total});

/// Completa el dato que falte a partir de los otros dos: cantidad × precio = total.
/// Un registro parcial puede traer solo algunos (por ejemplo el total y nada más);
/// lo que no se puede deducir queda en cero.
///
///  - Con cantidad y precio, y sin total: total = cantidad × precio.
///  - Con cantidad y total, y sin precio: precio = total ÷ cantidad.
///  - Con precio y total, y sin cantidad: cantidad = total ÷ precio.
MontosCarga completarMontos({double? cantidad, double? precio, double? total}) {
  double redondear(double v, int decimales) {
    final f = _potencia10(decimales);
    return (v * f).round() / f;
  }

  var c = cantidad != null && cantidad > 0 ? cantidad : 0.0;
  var p = precio != null && precio > 0 ? precio : 0.0;
  var t = total != null && total > 0 ? total : 0.0;

  if (t == 0 && c > 0 && p > 0) t = (c * p).roundToDouble();
  if (p == 0 && c > 0 && t > 0) p = redondear(t / c, 2);
  if (c == 0 && p > 0 && t > 0) c = redondear(t / p, 2);

  return (cantidad: c, precio: p, total: t);
}

double _potencia10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Errores del formulario de una carga, por campo. Vacío si todo está bien.
///
///  - E3: un monto, volumen o kilometraje con formato no numérico o negativo.
///  - Datos mínimos: debe haber al menos la cantidad o el total (mayor que 0).
Map<String, String> validarCarga({
  required String cantidad,
  required String precio,
  required String total,
  required String kilometraje,
  required DateTime fecha,
  DateTime? hoy,
}) {
  final errores = <String, String>{};
  final ahora = hoy ?? DateTime.now();
  final soloHoy = DateTime(ahora.year, ahora.month, ahora.day);

  // Devuelve el número si el texto está vacío (null) o es válido; marca el error si no.
  double? leer(String campo, String texto, String mensajeInvalido, {bool puntoEsMiles = false}) {
    final t = texto.trim();
    if (t.isEmpty) return null;
    // parseNumeroChile ignora las letras ("12x" daría 12), así que antes se exige
    // que el texto sea realmente un número: dígitos, puntos, comas y a lo más un
    // signo "$" o "-" al comienzo.
    final pareceNumero = RegExp(r'^[\s$]*-?[0-9][0-9.,\s]*$').hasMatch(t);
    final n = pareceNumero ? parseNumeroChile(t, puntoEsMiles: puntoEsMiles) : null;
    if (n == null || n < 0) {
      errores[campo] = mensajeInvalido;
      return null;
    }
    return n;
  }

  final c = leer('cantidad', cantidad, 'La cantidad no es un número válido.');
  leer('precio', precio, 'El precio no es un número válido.', puntoEsMiles: true);
  final t = leer('total', total, 'El monto no es un número válido.', puntoEsMiles: true);
  leer('kilometraje', kilometraje, 'El kilometraje no es válido.', puntoEsMiles: true);

  if (DateTime(fecha.year, fecha.month, fecha.day).isAfter(soloHoy)) {
    errores['fecha'] = 'La fecha no puede ser futura.';
  }

  // Solo se pide "datos mínimos" si lo escrito es válido: si un campo está mal, el
  // mensaje útil es el de ese campo.
  final hayErrorNumerico = errores.keys.any((k) => k != 'fecha');
  if (!hayErrorNumerico && (c ?? 0) <= 0 && (t ?? 0) <= 0) {
    errores['minimo'] = 'Ingresa al menos la cantidad cargada o el monto total.';
  }
  return errores;
}
