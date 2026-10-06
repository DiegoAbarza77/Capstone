import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente de la Edge Function "gemini-proxy": la clave de Gemini vive solo en
/// el servidor y la app nunca la ve. Lo usan los servicios que leen documentos
/// o boletas con IA (vehículo, combustible, y los módulos que vienen).
class GeminiProxyService {
  /// Envía [prompt] junto con un archivo (imagen o PDF) y devuelve el texto de
  /// la respuesta, que los llamadores esperan en formato JSON.
  Future<String> pedirTexto(
    String prompt, {
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'gemini-proxy',
      body: {
        'prompt': prompt,
        'imageBase64': base64Encode(fileBytes),
        'imageMimeType': mimeType,
      },
    );
    if (response.data is! Map) {
      throw Exception('Respuesta inesperada del servicio de IA.');
    }
    final text = ((response.data as Map)['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw Exception('El servicio de IA no devolvió contenido.');
    }
    return text;
  }
}
