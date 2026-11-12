import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Archivo elegido por el usuario, venga de la cámara, la galería o el selector
/// de archivos.
class ArchivoElegido {
  final Uint8List? bytes;
  final String name;

  const ArchivoElegido({required this.bytes, required this.name});
}

enum _Origen { camara, galeria, archivo }

/// True si el celular puede abrir la cámara y la galería desde la app. En web y
/// en escritorio solo se ofrece el selector de archivos.
bool get _puedeUsarCamara =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Deja elegir de dónde viene el archivo: una foto tomada en el momento, una foto
/// de la galería o un archivo guardado (PDF, y Excel o CSV donde corresponda).
///
/// En el celular muestra un menú con "Tomar foto", "Elegir de la galería" y
/// "Elegir archivo"; en web y escritorio abre directo el selector de archivos.
/// Devuelve null si la persona cancela. [extensiones] se aplica solo al selector
/// de archivos: las fotos de la cámara y de la galería siempre llegan como imagen.
Future<ArchivoElegido?> elegirArchivoConCamara(
  BuildContext context, {
  required List<String> extensiones,
}) async {
  var origen = _Origen.archivo;

  if (_puedeUsarCamara) {
    final elegido = await _preguntarOrigen(
      context,
      galeria: true,
      tituloArchivo: 'Elegir archivo',
      detalleArchivo: _detalleArchivo(extensiones),
    );
    if (elegido == null) return null;
    origen = elegido;
  }

  if (origen == _Origen.camara || origen == _Origen.galeria) {
    if (!context.mounted) return null;
    return _fotoComoArchivo(context, origen == _Origen.camara ? ImageSource.camera : ImageSource.gallery);
  }

  final resultado = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensiones,
    withData: true,
  );
  if (resultado == null || resultado.files.isEmpty) return null;
  final archivo = resultado.files.first;
  return ArchivoElegido(bytes: archivo.bytes, name: archivo.name);
}

/// Texto de apoyo de "Elegir archivo": dice qué tipos de archivo acepta.
String _detalleArchivo(List<String> extensiones) {
  final conPlanillas = extensiones.contains('xlsx') || extensiones.contains('csv');
  return conPlanillas ? 'Un PDF, Excel o CSV guardado en el celular' : 'Un PDF guardado en el celular';
}

/// Menú de origen. Siempre ofrece "Tomar foto"; la galería y el archivo se
/// agregan según corresponda. Devuelve null si la persona lo cierra sin elegir.
Future<_Origen?> _preguntarOrigen(
  BuildContext context, {
  bool galeria = false,
  String? tituloArchivo,
  String? detalleArchivo,
}) {
  const textoTitulo = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
  const textoDetalle = TextStyle(color: Color(0xFF94A3B8));

  return showModalBottomSheet<_Origen>(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF8B5CF6)),
              title: const Text('Tomar foto', style: textoTitulo),
              subtitle: const Text('Abre la cámara del celular', style: textoDetalle),
              onTap: () => Navigator.pop(sheetContext, _Origen.camara),
            ),
            if (galeria)
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF10B981)),
                title: const Text('Elegir de la galería', style: textoTitulo),
                subtitle: const Text('Una foto guardada en el celular', style: textoDetalle),
                onTap: () => Navigator.pop(sheetContext, _Origen.galeria),
              ),
            if (tituloArchivo != null)
              ListTile(
                leading: const Icon(Icons.folder_open_outlined, color: Color(0xFF4F46E5)),
                title: Text(tituloArchivo, style: textoTitulo),
                subtitle: Text(detalleArchivo ?? '', style: textoDetalle),
                onTap: () => Navigator.pop(sheetContext, _Origen.archivo),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Para las fotos de perfil y del vehículo: en el celular deja elegir entre
/// tomar una foto y elegirla de la galería; en web y escritorio abre directo la
/// galería. Devuelve null si la persona cancela.
Future<XFile?> elegirFotoConCamara(
  BuildContext context, {
  double? maxWidth,
  double? maxHeight,
  int imageQuality = 85,
}) async {
  var fuente = ImageSource.gallery;

  if (_puedeUsarCamara) {
    final elegido = await _preguntarOrigen(context, galeria: true);
    if (elegido == null) return null;
    if (elegido == _Origen.camara) fuente = ImageSource.camera;
  }

  try {
    return await ImagePicker().pickImage(
      source: fuente,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  } catch (e) {
    // Una galería que falla se informa como antes; el aviso es solo para la cámara.
    if (fuente != ImageSource.camera) rethrow;
    debugPrint('TAG_OK_CAMARA: no se pudo abrir la cámara: $e');
    if (context.mounted) _avisarFallo(context, 'cámara');
    return null;
  }
}

void _avisarFallo(BuildContext context, String que) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('No se pudo abrir la $que. Revisa el permiso en los ajustes del celular.'),
      backgroundColor: Colors.redAccent,
    ),
  );
}

/// Toma una foto con la cámara o la elige de la galería y la devuelve como un
/// [ArchivoElegido] con nombre de imagen.
Future<ArchivoElegido?> _fotoComoArchivo(BuildContext context, ImageSource fuente) async {
  final queAbre = fuente == ImageSource.camera ? 'cámara' : 'galería';
  try {
    final foto = await ImagePicker().pickImage(
      source: fuente,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (foto == null) return null;

    final bytes = await foto.readAsBytes();
    // Solo el nombre del archivo, sin la ruta, aunque la plataforma la incluya.
    var nombre = foto.name.trim().split(RegExp(r'[\\/]')).last;
    if (nombre.isEmpty) nombre = 'foto.jpg';
    final minusculas = nombre.toLowerCase();
    if (!minusculas.endsWith('.jpg') &&
        !minusculas.endsWith('.jpeg') &&
        !minusculas.endsWith('.png') &&
        !minusculas.endsWith('.webp')) {
      nombre = '$nombre.jpg';
    }
    return ArchivoElegido(bytes: bytes, name: nombre);
  } catch (e) {
    debugPrint('TAG_OK_CAMARA: no se pudo abrir la $queAbre: $e');
    if (context.mounted) _avisarFallo(context, queAbre);
    return null;
  }
}
