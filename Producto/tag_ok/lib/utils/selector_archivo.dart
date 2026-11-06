import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Archivo elegido por el usuario, venga de la cámara o del selector de archivos.
class ArchivoElegido {
  final Uint8List? bytes;
  final String name;

  const ArchivoElegido({required this.bytes, required this.name});
}

enum _Origen { camara, archivo }

/// True si el celular puede abrir la cámara desde la app. En web y en
/// escritorio solo se ofrece el selector de archivos.
bool get _puedeUsarCamara =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Deja elegir entre tomar una foto y elegir un archivo ya guardado.
///
/// En el celular muestra un menú con "Tomar foto" y "Elegir archivo"; en web y
/// escritorio abre directo el selector de archivos. Devuelve null si la persona
/// cancela. [extensiones] se aplica solo al selector de archivos: una foto
/// tomada con la cámara siempre llega como JPG.
Future<ArchivoElegido?> elegirArchivoConCamara(
  BuildContext context, {
  required List<String> extensiones,
}) async {
  var origen = _Origen.archivo;

  if (_puedeUsarCamara) {
    final elegido = await showModalBottomSheet<_Origen>(
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
                title: const Text('Tomar foto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Abre la cámara del celular', style: TextStyle(color: Color(0xFF94A3B8))),
                onTap: () => Navigator.pop(sheetContext, _Origen.camara),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined, color: Color(0xFF4F46E5)),
                title: const Text('Elegir archivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Una foto o un PDF guardado en el celular',
                    style: TextStyle(color: Color(0xFF94A3B8))),
                onTap: () => Navigator.pop(sheetContext, _Origen.archivo),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido == null) return null;
    origen = elegido;
  }

  if (origen == _Origen.camara) {
    return _tomarFoto(context);
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

Future<ArchivoElegido?> _tomarFoto(BuildContext context) async {
  try {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
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
    if (!minusculas.endsWith('.jpg') && !minusculas.endsWith('.jpeg') && !minusculas.endsWith('.png')) {
      nombre = '$nombre.jpg';
    }
    return ArchivoElegido(bytes: bytes, name: nombre);
  } catch (e) {
    debugPrint('TAG_OK_CAMARA: no se pudo abrir la cámara: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la cámara. Revisa el permiso de cámara en los ajustes del celular.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return null;
  }
}
