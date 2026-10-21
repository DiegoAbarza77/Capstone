import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/imagen_para_ia.dart';

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
    // Todas las lecturas con IA pasan por aquí: las fotos se reducen antes de
    // enviarse (RNF-06). Los PDF no se tocan.
    final archivo = await comprimirParaIa(fileBytes, mimeType);
    final response = await Supabase.instance.client.functions.invoke(
      'gemini-proxy',
      body: {
        'prompt': prompt,
        'imageBase64': base64Encode(archivo.bytes),
        'imageMimeType': archivo.mimeType,
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
