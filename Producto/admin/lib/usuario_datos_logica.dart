// Lógica de la vista "Datos del usuario" del panel: lo que un conductor ha
// registrado en la app (vehículos, documentos, mantenciones, combustible y
// estacionamientos). Es solo de lectura y no depende de la pantalla, para poder
// probarla con pruebas automáticas.

enum EstadoDocumento { alDia, porVencer, vencido, sinDatos }

/// Los 4 documentos de cada vehículo, en el orden en que se muestran.
const List<String> kTiposDocumento = ['permiso_circulacion', 'revision_tecnica', 'soap', 'seguro'];

const Map<String, String> kEtiquetaDocumento = {
  'permiso_circulacion': 'Permiso de Circulación',
  'revision_tecnica': 'Revisión Técnica',
  'soap': 'SOAP',
  'seguro': 'Seguro Automotriz',
};

/// Mismo criterio que la app del conductor: vencido si ya pasó la fecha, por
/// vencer si faltan 30 días o menos, al día si faltan más, y sin datos si no hay
/// fecha.
EstadoDocumento estadoDocumento(DateTime? vencimiento, {DateTime? ahora}) {
  if (vencimiento == null) return EstadoDocumento.sinDatos;
  final dias = vencimiento.difference(ahora ?? DateTime.now()).inDays;
  if (dias < 0) return EstadoDocumento.vencido;
  if (dias <= 30) return EstadoDocumento.porVencer;
  return EstadoDocumento.alDia;
}

String etiquetaEstadoDocumento(EstadoDocumento estado) {
  switch (estado) {
    case EstadoDocumento.alDia:
      return 'Al día';
    case EstadoDocumento.porVencer:
      return 'Por vencer';
    case EstadoDocumento.vencido:
      return 'Vencido';
    case EstadoDocumento.sinDatos:
      return 'Sin datos';
  }
}

/// "dd/MM/yyyy" a partir de un texto ISO de la base de datos; "—" si no hay fecha.
String formatoFecha(dynamic valor) {
  final fecha = valor == null ? null : DateTime.tryParse(valor.toString());
  if (fecha == null) return '—';
  // Sin convertir a la hora local: la app guarda "31/07/2027" como medianoche y
  // la muestra tal cual; convertirla aquí la mostraría un día antes.
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// "\$12.345", con punto como separador de miles (formato chileno).
String formatoPesos(num valor) {
  final entero = valor.round();
  final texto = entero.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return '${entero < 0 ? '-' : ''}\$${buffer.toString()}';
}

/// "1 h 30 min", "45 min" o "—" si no se conoce la duración.
String formatoDuracion(dynamic minutos) {
  final total = minutos is num ? minutos.toInt() : int.tryParse(minutos?.toString() ?? '');
  if (total == null || total < 0) return '—';
  final horas = total ~/ 60;
  final resto = total % 60;
  if (horas == 0) return '$resto min';
  if (resto == 0) return '$horas h';
  return '$horas h $resto min';
}

/// Cantidad con hasta un decimal y coma decimal: 30 -> "30", 42.5 -> "42,5".
String formatoCantidad(dynamic valor) {
  final numero = valor is num ? valor.toDouble() : double.tryParse(valor?.toString() ?? '');
  if (numero == null) return '—';
  final redondeado = (numero * 10).round() / 10;
  return redondeado == redondeado.roundToDouble()
      ? redondeado.toInt().toString()
      : redondeado.toString().replaceAll('.', ',');
}

double sumarCampo(List<Map<String, dynamic>> filas, String campo) {
  var total = 0.0;
  for (final fila in filas) {
    final valor = fila[campo];
    if (valor is num) {
      total += valor.toDouble();
    } else if (valor != null) {
      total += double.tryParse(valor.toString()) ?? 0;
    }
  }
  return total;
}

/// Todo lo que el panel trae de un conductor. Cada lista llega ordenada de la
/// más reciente a la más antigua y con un máximo de [limiteFilas] registros.
class DatosUsuario {
  /// Máximo de registros que se traen por módulo.
  static const int limiteFilas = 500;

  final List<Map<String, dynamic>> vehiculos;
  final List<Map<String, dynamic>> documentos;
  final List<Map<String, dynamic>> mantenciones;
  final List<Map<String, dynamic>> cargas;
  final List<Map<String, dynamic>> estacionamientos;

  const DatosUsuario({
    this.vehiculos = const [],
    this.documentos = const [],
    this.mantenciones = const [],
    this.cargas = const [],
    this.estacionamientos = const [],
  });

  double get gastoMantenciones => sumarCampo(mantenciones, 'costo');
  double get gastoCombustible => sumarCampo(cargas, 'total');
  double get gastoEstacionamientos => sumarCampo(estacionamientos, 'costo');
  double get gastoTotal => gastoMantenciones + gastoCombustible + gastoEstacionamientos;

  /// True si algún módulo llegó al máximo de registros: hay más que no se ven.
  bool get hayRegistrosOcultos =>
      mantenciones.length >= limiteFilas || cargas.length >= limiteFilas || estacionamientos.length >= limiteFilas;

  bool get estaVacio =>
      vehiculos.isEmpty && documentos.isEmpty && mantenciones.isEmpty && cargas.isEmpty && estacionamientos.isEmpty;

  /// Los 4 documentos de un vehículo, siempre en el mismo orden; los que el
  /// conductor no ha cargado salen como filas vacías con su tipo.
  List<Map<String, dynamic>> documentosDe(String vehiculoId) {
    return [
      for (final tipo in kTiposDocumento)
        documentos.firstWhere(
          (d) => d['vehiculo_id'] == vehiculoId && d['tipo'] == tipo,
          orElse: () => {'vehiculo_id': vehiculoId, 'tipo': tipo},
        ),
    ];
  }

  /// Documentos vencidos o por vencer, de todos sus vehículos.
  int documentosConAlerta({DateTime? ahora}) {
    var cuenta = 0;
    for (final doc in documentos) {
      final vence = DateTime.tryParse(doc['fecha_vencimiento']?.toString() ?? '');
      final estado = estadoDocumento(vence, ahora: ahora);
      if (estado == EstadoDocumento.vencido || estado == EstadoDocumento.porVencer) cuenta++;
    }
    return cuenta;
  }
}
