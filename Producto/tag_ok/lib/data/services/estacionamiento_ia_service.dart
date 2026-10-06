import 'dart:convert';
import 'dart:typed_data';
import '../../utils/numero_chile.dart';
import 'gemini_proxy_service.dart';
import 'lectura_boleta_exception.dart';

/// Una hora del día, sin fecha.
typedef HoraDelDia = ({int hora, int minuto});

/// Datos que la IA pudo leer de un ticket o boleta de estacionamiento. Todos son
/// opcionales: lo que no se pudo leer queda vacío y el usuario lo completa en la
/// pantalla de revisión (nada se guarda sin que él confirme).
class EstacionamientoExtraidoIa {
  final String? lugar;
  final String? direccion;
  final DateTime? fecha;
  final HoraDelDia? horaEntrada;
  final HoraDelDia? horaSalida;
  final int? duracionMinutos;
  final double? monto;

  const EstacionamientoExtraidoIa({
    this.lugar,
    this.direccion,
    this.fecha,
    this.horaEntrada,
    this.horaSalida,
    this.duracionMinutos,
    this.monto,
  });

  /// true si la IA no logró leer ningún dato útil (ticket borroso o que no es de
  /// un estacionamiento).
  bool get vacia =>
      (lugar == null || lugar!.isEmpty) &&
      (direccion == null || direccion!.isEmpty) &&
      fecha == null &&
      horaEntrada == null &&
      horaSalida == null &&
      duracionMinutos == null &&
      monto == null;

  factory EstacionamientoExtraidoIa.fromJson(Map<String, dynamic> json) {
    var entrada = parseHoraDelDia(json['hora_entrada']);
    var salida = parseHoraDelDia(json['hora_salida']);
    final duracion = parseDuracionMinutos(json['duracion']);

    // Con dos de los tres datos (entrada, salida, duración) se deduce el tercero
    // que falte. El usuario lo revisa igual antes de guardar.
    if (duracion != null) {
      if (entrada != null && salida == null) {
        salida = _sumarMinutos(entrada, duracion);
      } else if (salida != null && entrada == null) {
        entrada = _sumarMinutos(salida, -duracion);
      }
    }

    return EstacionamientoExtraidoIa(
      lugar: _textoONulo(json['estacionamiento']),
      direccion: _textoONulo(json['ubicacion']),
      fecha: _parseFecha(json['fecha']),
      horaEntrada: entrada,
      horaSalida: salida,
      duracionMinutos: duracion,
      monto: parseNumeroChile(json['monto'], puntoEsMiles: true),
    );
  }

  static HoraDelDia _sumarMinutos(HoraDelDia h, int minutos) {
    final total = ((h.hora * 60 + h.minuto + minutos) % 1440 + 1440) % 1440;
    return (hora: total ~/ 60, minuto: total % 60);
  }

  static String? _textoONulo(dynamic valor) {
    final t = valor?.toString().trim();
    return t == null || t.isEmpty || t.toLowerCase() == 'null' ? null : t;
  }

  static DateTime? _parseFecha(dynamic valor) {
    final t = _textoONulo(valor);
    if (t == null) return null;
    try {
      final f = DateTime.parse(t);
      // Descarta fechas imposibles (la IA a veces inventa) o del futuro.
      if (f.year < 2000 || f.isAfter(DateTime.now().add(const Duration(days: 1)))) return null;
      return DateTime(f.year, f.month, f.day);
    } catch (_) {
      return null;
    }
  }
}

/// Interpreta una hora escrita de varias formas: "14:30", "14.30", "14h30",
/// "2:30 PM", "9:05 am". Devuelve null si no es una hora válida.
HoraDelDia? parseHoraDelDia(dynamic valor) {
  if (valor == null) return null;
  final t = valor.toString().trim().toLowerCase();
  if (t.isEmpty || t == 'null') return null;

  final m = RegExp(r'^(\d{1,2})\s*[:.hH]\s*(\d{2})(?:\s*(?::\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?$').firstMatch(t);
  if (m == null) return null;

  var hora = int.parse(m.group(1)!);
  final minuto = int.parse(m.group(2)!);
  final sufijo = m.group(3);
  if (sufijo != null) {
    if (hora < 1 || hora > 12) return null;
    final esPm = sufijo.startsWith('p');
    if (esPm && hora != 12) hora += 12;
    if (!esPm && hora == 12) hora = 0;
  }
  if (hora > 23 || minuto > 59) return null;
  return (hora: hora, minuto: minuto);
}

/// Interpreta una duración en minutos: acepta un número ("90"), "2 h 30 min",
/// "1h", "45 min" o "02:30" (horas:minutos). Devuelve null si no se entiende.
int? parseDuracionMinutos(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor < 0 ? null : valor.round();

  final t = valor.toString().trim().toLowerCase();
  if (t.isEmpty || t == 'null') return null;

  final reloj = RegExp(r'^(\d{1,3}):(\d{2})(?::\d{2})?$').firstMatch(t);
  if (reloj != null) {
    final minutos = int.parse(reloj.group(2)!);
    if (minutos > 59) return null;
    return int.parse(reloj.group(1)!) * 60 + minutos;
  }

  final horas = RegExp(r'(\d+)\s*(?:h|hr|hrs|hora|horas)\b').firstMatch(t);
  final minutos = RegExp(r'(\d+)\s*(?:m|min|mins|minuto|minutos)\b').firstMatch(t);
  if (horas != null || minutos != null) {
    return (horas != null ? int.parse(horas.group(1)!) * 60 : 0) + (minutos != null ? int.parse(minutos.group(1)!) : 0);
  }

  return int.tryParse(t);
}

/// Lee tickets y boletas de estacionamiento (foto o PDF) con Gemini.
class EstacionamientoIaService {
  final GeminiProxyService _proxy;

  EstacionamientoIaService({GeminiProxyService? proxy}) : _proxy = proxy ?? GeminiProxyService();

  static const _prompt = '''
Eres un asistente experto en tickets y boletas de estacionamientos y
playas de estacionamiento en Chile. Se te entrega la foto o el PDF de un
comprobante. Extrae:

1. "estacionamiento": nombre del estacionamiento o del recinto (por ejemplo
   "Estacionamientos Mall Plaza" o "Playa Centro").
2. "ubicacion": la dirección o el lugar, si aparece.
3. "fecha": fecha del estacionamiento, formato "YYYY-MM-DD".
4. "hora_entrada": hora de ingreso, formato 24 horas "HH:MM".
5. "hora_salida": hora de salida, formato 24 horas "HH:MM".
6. "duracion": el tiempo estacionado, tal como aparece (por ejemplo "2 h 30 min").
7. "monto": monto total pagado en pesos chilenos, solo el número, sin puntos de
   miles.

Usa null para cualquier dato que no puedas determinar con confianza: es
preferible dejarlo en blanco a inventarlo.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con esta estructura exacta:
{
  "estacionamiento": "Estacionamientos Mall Plaza",
  "ubicacion": "Av. Ejemplo 1234, Santiago",
  "fecha": "2026-09-15",
  "hora_entrada": "14:05",
  "hora_salida": "16:35",
  "duracion": "2 h 30 min",
  "monto": 3750
}
''';

  /// Lanza una [LecturaBoletaException] con un mensaje amable si la IA no
  /// responde o no puede interpretar el archivo, para que la pantalla ofrezca el
  /// registro manual.
  Future<EstacionamientoExtraidoIa> extraerTicket({
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final String respuesta;
    try {
      respuesta = await _proxy.pedirTexto(_prompt, fileBytes: fileBytes, mimeType: mimeType);
    } catch (_) {
      throw const LecturaBoletaException('No se pudo contactar al servicio de IA. Revisa tu conexión.');
    }

    try {
      final parsed = jsonDecode(respuesta);
      if (parsed is! Map) throw const FormatException('No es un objeto JSON.');
      final ticket = EstacionamientoExtraidoIa.fromJson(Map<String, dynamic>.from(parsed));
      if (ticket.vacia) {
        throw const LecturaBoletaException('No pude leer datos en el comprobante.');
      }
      return ticket;
    } on LecturaBoletaException {
      rethrow;
    } catch (_) {
      throw const LecturaBoletaException('No pude interpretar el comprobante.');
    }
  }
}
