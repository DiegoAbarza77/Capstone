import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/imagen_para_ia.dart';

/// Traduce un fallo al llamar a la IA en un mensaje que dice qué pasó, en vez
/// de "revisa tu conexión" para todo. Incluye un código corto entre paréntesis
/// para poder diagnosticar el problema desde lo que vea el usuario.
String mensajeErrorIa(Object error) {
  if (error is FunctionException) {
    final estado = error.status;
    if (estado == 401) return 'Tu sesión venció. Cierra sesión y vuelve a entrar. (401)';
    if (estado == 429) return 'Hiciste muchas lecturas seguidas. Espera un minuto e inténtalo de nuevo. (429)';
    if (estado == 413 || estado == 415) {
      return 'El archivo no se pudo enviar (muy pesado o de un tipo no admitido). Prueba con otra foto o el registro manual. ($estado)';
    }
    if (estado >= 500) {
      return 'La IA no está disponible en este momento. Intenta en unos minutos o usa el registro manual. ($estado)';
    }
    return 'La IA rechazó la solicitud. Usa el registro manual. ($estado)';
  }
  return 'No se pudo contactar al servicio de IA. Revisa tu conexión a internet. (${error.runtimeType})';
}

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
