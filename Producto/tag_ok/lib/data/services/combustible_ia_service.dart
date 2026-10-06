import 'dart:convert';
import 'dart:typed_data';
import '../../utils/numero_chile.dart';
import 'gemini_proxy_service.dart';
import 'lectura_boleta_exception.dart';

export 'lectura_boleta_exception.dart';

/// Datos que la IA pudo leer de una boleta de combustible o de carga eléctrica.
/// Todos son opcionales: lo que no se pudo leer queda en null y el usuario lo
/// completa en la pantalla de revisión (nada se guarda sin que él confirme).
class CargaExtraidaIa {
  final DateTime? fecha;
  final String? estacion;
  final String? tipoCombustible;
  final double? cantidad;
  final String unidad;
  final double? precioUnidad;
  final double? total;
  final double? kilometraje;

  const CargaExtraidaIa({
    this.fecha,
    this.estacion,
    this.tipoCombustible,
    this.cantidad,
    this.unidad = 'litros',
    this.precioUnidad,
    this.total,
    this.kilometraje,
  });

  /// true si la IA no logró leer ningún dato útil (boleta borrosa o que no es de
  /// combustible).
  bool get vacia =>
      fecha == null &&
      (estacion == null || estacion!.isEmpty) &&
      tipoCombustible == null &&
      cantidad == null &&
      precioUnidad == null &&
      total == null &&
      kilometraje == null;

  factory CargaExtraidaIa.fromJson(Map<String, dynamic> json) {
    final tipo = normalizarTipoEnergia(json['tipo_combustible']?.toString());
    final unidadLeida = json['unidad']?.toString().toLowerCase().trim();
    final unidad = unidadLeida == 'kwh' || unidadLeida == 'kw/h' || tipo == 'Eléctrico' ? 'kwh' : 'litros';

    return CargaExtraidaIa(
      fecha: _parseFecha(json['fecha']),
      estacion: _textoONulo(json['estacion']),
      tipoCombustible: tipo,
      cantidad: parseNumeroChile(json['cantidad']),
      unidad: unidad,
      precioUnidad: parseNumeroChile(json['precio_unidad'], puntoEsMiles: true),
      total: parseNumeroChile(json['total'], puntoEsMiles: true),
      kilometraje: parseNumeroChile(json['kilometraje'], puntoEsMiles: true),
    );
  }

  /// Convierte lo que escribió la boleta ("Gasolina 95", "DIESEL", "Carga
  /// eléctrica") a uno de los tipos de la app, o null si no se reconoce.
  static String? normalizarTipoEnergia(String? texto) {
    if (texto == null) return null;
    final t = texto.toLowerCase();
    if (t.contains('eléctric') || t.contains('electric') || t.contains('kwh')) return 'Eléctrico';
    if (t.contains('diésel') || t.contains('diesel') || t.contains('petróleo') || t.contains('petroleo')) {
      return 'Diésel';
    }
    if (t.contains('bencina') || t.contains('gasolina') || RegExp(r'\b(93|95|97)\b').hasMatch(t)) {
      return 'Bencina';
    }
    return null;
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

/// Lee boletas de combustible o de carga eléctrica (foto o PDF) con Gemini.
class CombustibleIaService {
  final GeminiProxyService _proxy;

  CombustibleIaService({GeminiProxyService? proxy}) : _proxy = proxy ?? GeminiProxyService();

  static const _prompt = '''
Eres un asistente experto en boletas de combustible y de carga de vehículos
eléctricos en Chile. Se te entrega la foto o el PDF de un comprobante de una
estación de servicio (Copec, Shell, Petrobras, Enex, etc.) o de una carga
eléctrica. Extrae:

1. "fecha": fecha de la compra, formato "YYYY-MM-DD".
2. "estacion": nombre de la estación o de la empresa.
3. "tipo_combustible": uno de "Bencina", "Diésel" o "Eléctrico".
4. "cantidad": litros cargados o kWh cargados, solo el número.
5. "unidad": "litros" o "kwh".
6. "precio_unidad": precio por litro o por kWh, solo el número.
7. "total": monto total pagado en pesos chilenos, solo el número, sin puntos
   de miles.
8. "kilometraje": el kilometraje del odómetro, solo si aparece escrito.

Usa null (no un texto vacío) para cualquier campo que no puedas determinar con
confianza: es preferible dejarlo en blanco a inventar un dato.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con esta estructura exacta:
{
  "fecha": "2026-09-15",
  "estacion": "Copec",
  "tipo_combustible": "Bencina",
  "cantidad": 32.5,
  "unidad": "litros",
  "precio_unidad": 1350,
  "total": 43875,
  "kilometraje": null
}
''';

  /// Lanza una excepción con un mensaje amable si la IA no responde o no puede
  /// interpretar el archivo, para que la pantalla ofrezca el registro manual.
  Future<CargaExtraidaIa> extraerBoleta({
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
      final carga = CargaExtraidaIa.fromJson(Map<String, dynamic>.from(parsed));
      if (carga.vacia) {
        throw const LecturaBoletaException('No pude leer datos en el comprobante.');
      }
      return carga;
    } on LecturaBoletaException {
      rethrow;
    } catch (_) {
      throw const LecturaBoletaException('No pude interpretar el comprobante.');
    }
  }
}
