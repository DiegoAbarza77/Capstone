import 'dart:convert';
import 'dart:typed_data';
import 'gemini_proxy_service.dart';

/// Extrae datos de documentos del vehículo (Permiso de Circulación, Revisión
/// Técnica, SOAP, Seguro) a partir de una foto o PDF, usando la misma Edge
/// Function "gemini-proxy" que ya usa audit_screen.dart para las boletas de
/// peaje -- así GEMINI_API_KEY nunca viaja al cliente.
class DocumentoIaService {
  final GeminiProxyService _proxy = GeminiProxyService();

  Future<String> _callGeminiProxy(
    String prompt, {
    required Uint8List fileBytes,
    required String mimeType,
  }) {
    return _proxy.pedirTexto(prompt, fileBytes: fileBytes, mimeType: mimeType);
  }

  /// [mimeType] acepta imágenes (image/jpeg, image/png) o "application/pdf" --
  /// Gemini puede leer ambos directamente, sin extracción de texto local.
  Future<Map<String, dynamic>> extraerDocumento({
    required Uint8List fileBytes,
    required String mimeType,
    required String fileName,
  }) async {
    const prompt = '''
Eres un asistente experto en documentos vehiculares chilenos. Se te entrega
una foto o PDF de uno de estos 4 tipos de documento:
- "permiso_circulacion" (Permiso de Circulación municipal)
- "revision_tecnica" (Certificado de Revisión Técnica / Plantas de Revisión)
- "soap" (Seguro Obligatorio de Accidentes Personales)
- "seguro" (Seguro Automotriz de una compañía aseguradora)

Analiza el documento y extrae:
1. "tipo": cuál de los 4 valores de arriba corresponde. Si no puedes
   determinarlo con confianza, usa "desconocido".
2. "patente": la patente del vehículo (formato chileno, ej. "ABCD12"), si
   aparece en el documento.
3. "compania": la entidad emisora (nombre de la aseguradora, la
   municipalidad, o la planta de revisión técnica).
4. "numero": el número de documento, folio o póliza.
5. "fecha_emision": fecha de emisión en formato "YYYY-MM-DD".
6. "fecha_vencimiento": fecha de vencimiento/caducidad en formato "YYYY-MM-DD".

Usa null (no un string vacío) para cualquier campo que no puedas determinar
con confianza -- es preferible dejarlo en blanco a inventar un dato.

Devuelve EXCLUSIVAMENTE un objeto JSON válido con esta estructura exacta:
{
  "tipo": "seguro",
  "patente": "ABCD12",
  "compania": "Nombre de la compañía",
  "numero": "123456",
  "fecha_emision": "2026-01-01",
  "fecha_vencimiento": "2027-01-01"
}
''';

    final responseText = await _callGeminiProxy(
      prompt,
      fileBytes: fileBytes,
      mimeType: mimeType,
    );

    try {
      final parsed = jsonDecode(responseText);
      if (parsed is! Map) {
        throw const FormatException('La respuesta no es un objeto JSON.');
      }
      return Map<String, dynamic>.from(parsed);
    } catch (e) {
      throw Exception('La IA no pudo interpretar el documento "$fileName". Intenta con el formulario manual.');
    }
  }
}
