import 'dart:convert';
import 'dart:typed_data';
import '../../utils/numero_chile.dart';
import '../models/mantencion_model.dart';
import 'gemini_proxy_service.dart';
import 'lectura_boleta_exception.dart';

/// Datos que la IA pudo leer de una boleta o factura de taller. Todos son
/// opcionales: lo que no se pudo leer queda vacío y el usuario lo completa en la
/// pantalla de revisión (nada se guarda sin que él confirme).
class MantencionExtraidaIa {
  final DateTime? fecha;
  final String? taller;
  final List<String> servicios;
  final List<String> repuestos;
  final double? kilometraje;
  final double? total;

  /// Siempre uno de los identificadores de [kTiposMantencion].
  final String tipo;

  const MantencionExtraidaIa({
    this.fecha,
    this.taller,
    this.servicios = const [],
    this.repuestos = const [],
    this.kilometraje,
    this.total,
    this.tipo = 'otra',
  });

  /// true si la IA no logró leer ningún dato útil (boleta borrosa o que no es de
  /// un taller).
  bool get vacia =>
      fecha == null &&
      (taller == null || taller!.isEmpty) &&
      servicios.isEmpty &&
      repuestos.isEmpty &&
      kilometraje == null &&
      total == null;

  factory MantencionExtraidaIa.fromJson(Map<String, dynamic> json) {
    final servicios = _lista(json['servicios']).map(limpiarNombreServicio).toList();
    return MantencionExtraidaIa(
      fecha: _parseFecha(json['fecha']),
      taller: _textoONulo(json['taller']),
      servicios: servicios,
      repuestos: _lista(json['repuestos']),
      kilometraje: parseNumeroChile(json['kilometraje'], puntoEsMiles: true),
      total: parseNumeroChile(json['total'], puntoEsMiles: true),
      tipo: clasificarTipoMantencion(json['tipo']?.toString(), servicios),
    );
  }

  static String? _textoONulo(dynamic valor) {
    final t = valor?.toString().trim();
    return t == null || t.isEmpty || t.toLowerCase() == 'null' ? null : t;
  }

  /// Acepta una lista, o un texto separado por comas, punto y coma o saltos de
  /// línea, y devuelve los elementos sin repetir ni vacíos.
  static List<String> _lista(dynamic valor) {
    final Iterable<dynamic> items = valor is List ? valor : (valor is String ? valor.split(RegExp(r'[;\n]|,(?!\d)')) : const []);
    final vistos = <String>{};
    final resultado = <String>[];
    for (final item in items) {
      final t = _textoONulo(item);
      if (t != null && vistos.add(t.toLowerCase())) resultado.add(t);
    }
    return resultado;
  }

  static DateTime? _parseFecha(dynamic valor) {
    final t = _textoONulo(valor);
    if (t == null) return null;
    try {
      final f = DateTime.parse(t);
      // Descarta fechas imposibles (la IA a veces inventa) o del futuro.
      if (f.year < 1990 || f.isAfter(DateTime.now().add(const Duration(days: 1)))) return null;
      return DateTime(f.year, f.month, f.day);
    } catch (_) {
      return null;
    }
  }
}

/// Deja el nombre de un servicio como lo escribiría una persona: sin el prefijo
/// "Mano de obra" que traen muchas boletas.
///   "Mano de obra cambio de aceite" -> "Cambio de aceite"
///   "M.O. alineación"               -> "Alineación"
/// Si al quitar el prefijo no queda nada, se deja el texto original.
String limpiarNombreServicio(String nombre) {
  final original = nombre.trim();
  final sinPrefijo = original
      .replaceFirst(RegExp(r'^(mano\s+de\s+obra|m\.\s?o\.|m/o)\s*(de|para|:|-|–)?\s*', caseSensitive: false), '')
      .trim();
  if (sinPrefijo.isEmpty) return original;
  return sinPrefijo[0].toUpperCase() + sinPrefijo.substring(1);
}

/// Decide la categoría de la mantención. Se fía de lo que clasificó la IA si es
/// una categoría válida; si no, la deduce de las palabras de los servicios.
String clasificarTipoMantencion(String? tipoIa, List<String> servicios) {
  final t = tipoIa?.toLowerCase().trim();
  if (t != null && kTiposMantencion.containsKey(t) && t != 'otra') return t;

  final texto = servicios.join(' ').toLowerCase();
  if (texto.contains('aceite')) return 'aceite';
  if (RegExp(r'freno|pastilla|balata|disco').hasMatch(texto)) return 'frenos';
  if (RegExp(r'neum|llanta|alinea|balanceo|rotaci').hasMatch(texto)) return 'neumaticos';
  if (RegExp(r'preventiv|revisi|filtro|afinamiento|bujía|bujia|correa').hasMatch(texto)) return 'preventiva';

  // La IA dijo "otra" o algo que no es una categoría: se respeta si era "otra".
  return 'otra';
}

/// Lee boletas y facturas de talleres mecánicos (foto o PDF) con Gemini.
class MantencionIaService {
  final GeminiProxyService _proxy;

  MantencionIaService({GeminiProxyService? proxy}) : _proxy = proxy ?? GeminiProxyService();

  static const _prompt = '''
Eres un asistente experto en boletas y facturas de talleres mecánicos y
servicios automotrices en Chile. Se te entrega la foto o el PDF de un
comprobante. Extrae:

1. "taller": nombre del taller o empresa que hizo el servicio.
2. "fecha": fecha del servicio, formato "YYYY-MM-DD".
3. "servicios": lista con los servicios o trabajos realizados, cada uno con un
   nombre corto y claro, SIN prefijos como "Mano de obra" o "M.O.". Por ejemplo,
   si la boleta dice "Mano de obra cambio de aceite", escribe "Cambio de aceite".
   Ejemplo: ["Cambio de aceite", "Alineación"].
4. "repuestos": lista con los repuestos o insumos cobrados, por ejemplo
   ["Filtro de aceite", "Filtro de aire"].
5. "kilometraje": el kilometraje del vehículo, solo si aparece escrito.
6. "total": monto total pagado en pesos chilenos, solo el número, sin puntos de
   miles.
7. "tipo": clasifica la mantención en UNA de estas categorías exactas:
   "preventiva", "aceite", "frenos", "neumaticos" u "otra".

Usa null (o una lista vacía) para cualquier dato que no puedas determinar con
confianza: es preferible dejarlo en blanco a inventarlo.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con esta estructura exacta:
{
  "taller": "Taller Mecánico Los Aromos",
  "fecha": "2026-09-15",
  "servicios": ["Cambio de aceite"],
  "repuestos": ["Filtro de aceite", "Filtro de aire"],
  "kilometraje": 78500,
  "total": 129900,
  "tipo": "aceite"
}
''';

  /// Lanza una [LecturaBoletaException] con un mensaje amable si la IA no
  /// responde o no puede interpretar el archivo, para que la pantalla ofrezca el
  /// registro manual.
  Future<MantencionExtraidaIa> extraerBoleta({
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
      final mantencion = MantencionExtraidaIa.fromJson(Map<String, dynamic>.from(parsed));
      if (mantencion.vacia) {
        throw const LecturaBoletaException('No pude leer datos en el comprobante.');
      }
      return mantencion;
    } on LecturaBoletaException {
      rethrow;
    } catch (_) {
      throw const LecturaBoletaException('No pude interpretar el comprobante.');
    }
  }
}
