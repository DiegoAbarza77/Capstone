import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/vehiculo_model.dart';
import '../utils/patente_chile.dart';

const Color _bgColor = Color(0xFF0F172A);
const Color _primaryColor = Color(0xFF4F46E5);
const Color _navBgColor = Color(0xFF1E293B);
const Color _textMuted = Color(0xFF94A3B8);
const Color _textMain = Color(0xFFF8FAFC);

/// Traduce un error de Supabase o de red a un mensaje que el usuario pueda
/// entender, sin mostrarle la excepción técnica.
String mensajeErrorVehiculo(Object e) {
  debugPrint('TAG_OK_VEHICULOS: $e');
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Ya tienes un vehículo con esa patente.';
    if (e.code == '42501') return 'No tienes permiso para hacer esto.';
  }
  final texto = e.toString();
  if (texto.contains('Failed to fetch') || texto.contains('SocketException') || texto.contains('ClientException')) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.';
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}

/// null si el año es válido (o está vacío, porque es opcional).
String? validarAnioVehiculo(String texto) {
  if (texto.isEmpty) return null;
  final anio = int.tryParse(texto);
  final maximo = DateTime.now().year + 1;
  if (anio == null || anio < 1950 || anio > maximo) {
    return 'El año debe estar entre 1950 y $maximo.';
  }
  return null;
}

/// Sube la foto a Storage en la ruta "uid/vehiculoId.ext" (mismo patrón de
/// bucket-público-lectura + RLS-por-carpeta-de-uid que ya usa el avatar de
/// perfil) y devuelve la URL pública con un parámetro de versión, para que
/// no quede cacheada la foto anterior con el mismo nombre de archivo.
Future<String> subirFotoVehiculo(String vehiculoId, XFile foto) async {
  final user = Supabase.instance.client.auth.currentUser!;
  final bytes = await foto.readAsBytes();
  final rawExt = foto.name.contains('.') ? foto.name.split('.').last.toLowerCase() : 'jpg';
  final ext = rawExt == 'jpg' || rawExt == 'jpeg' || rawExt == 'png' || rawExt == 'webp' ? rawExt : 'jpg';
  final path = '${user.id}/$vehiculoId.$ext';
  final storage = Supabase.instance.client.storage.from('vehiculo_fotos');

  await storage.uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(upsert: true, contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}'),
  );

  final publicUrl = storage.getPublicUrl(path);
  return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
}

Future<bool> _editarVehiculo(
  BuildContext context,
  String docId,
  String patente,
  String marca,
  String categoria, {
  String? modelo,
  int? anio,
  String? tipoCombustible,
  double? kilometraje,
  String? alias,
}) async {
  try {
    await Supabase.instance.client.from('vehiculos').update({
      'patente': patente,
      'categoria': categoria,
      'marca': marca.isNotEmpty ? marca : 'No especificada',
      'modelo': modelo,
      'anio': anio,
      'tipo_combustible': tipoCombustible,
      'kilometraje': kilometraje,
      'alias': alias,
    }).eq('id', docId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehículo actualizado exitosamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorVehiculo(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

void mostrarFormularioEditarVehiculo(BuildContext context, Map<String, dynamic> data) {
  final TextEditingController patenteCtrl = TextEditingController(text: data['patente']);
  final TextEditingController marcaCtrl = TextEditingController(text: data['marca'] == 'No especificada' ? '' : data['marca']);
  final TextEditingController modeloCtrl = TextEditingController(text: data['modelo']?.toString() ?? '');
  final TextEditingController anioCtrl = TextEditingController(text: data['anio']?.toString() ?? '');
  final TextEditingController kilometrajeCtrl = TextEditingController(text: data['kilometraje']?.toString() ?? '');
  final TextEditingController aliasCtrl = TextEditingController(text: data['alias']?.toString() ?? '');
  String categoriaSel = data['categoria'] ?? 'AUTO';
  String? tipoCombustibleSel = kTiposCombustible.contains(data['tipo_combustible']) ? data['tipo_combustible'] : null;
  String? fotoUrlActual = data['foto_url'];
  bool subiendoFoto = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> cambiarFoto() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 800,
              maxHeight: 800,
              imageQuality: 85,
            );
            if (picked == null) return;
            setModalState(() => subiendoFoto = true);
            try {
              final fotoUrl = await subirFotoVehiculo(data['id'], picked);
              await Supabase.instance.client.from('vehiculos').update({'foto_url': fotoUrl}).eq('id', data['id']);
              setModalState(() {
                fotoUrlActual = fotoUrl;
                subiendoFoto = false;
              });
            } catch (e) {
              setModalState(() => subiendoFoto = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(mensajeErrorVehiculo(e)), backgroundColor: Colors.redAccent),
                );
              }
            }
          }

          return AlertDialog(
            backgroundColor: _navBgColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Editar Vehículo', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: subiendoFoto ? null : cambiarFoto,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: _bgColor,
                        backgroundImage: fotoUrlActual != null ? NetworkImage(fotoUrlActual!) : null,
                        child: subiendoFoto
                            ? const CircularProgressIndicator()
                            : fotoUrlActual == null
                                ? Icon(Icons.add_a_photo_outlined, color: _textMuted, size: 28)
                                : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text('Toca para cambiar la foto', style: TextStyle(color: _textMuted, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: patenteCtrl,
                    style: TextStyle(color: _textMain),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return TextEditingValue(
                          text: newValue.text.toUpperCase(),
                          selection: newValue.selection,
                        );
                      }),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Patente (ej: ABCD12, AB1234, ABC12)',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: marcaCtrl,
                    style: TextStyle(color: _textMain),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Marca (ej: Toyota, Kia)',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoriaSel,
                    dropdownColor: _navBgColor,
                    style: TextStyle(color: _textMain),
                    decoration: InputDecoration(
                      labelText: 'Tipo de Vehículo',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'AUTO', child: Text('AUTO')),
                      DropdownMenuItem(value: 'CAMIONETA', child: Text('CAMIONETA')),
                      DropdownMenuItem(value: 'MOTO', child: Text('MOTO')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          categoriaSel = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modeloCtrl,
                    style: TextStyle(color: _textMain),
                    decoration: InputDecoration(
                      labelText: 'Modelo (ej: Corolla)',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: anioCtrl,
                    style: TextStyle(color: _textMain),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Año',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tipoCombustibleSel,
                    dropdownColor: _navBgColor,
                    style: TextStyle(color: _textMain),
                    hint: Text('Selecciona', style: TextStyle(color: _textMuted)),
                    decoration: InputDecoration(
                      labelText: 'Tipo de Combustible',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                    items: kTiposCombustible
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        tipoCombustibleSel = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kilometrajeCtrl,
                    style: TextStyle(color: _textMain),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Kilometraje actual',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aliasCtrl,
                    style: TextStyle(color: _textMain),
                    decoration: InputDecoration(
                      labelText: 'Alias (ej: Auto de la Sara)',
                      labelStyle: TextStyle(color: _textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _textMuted.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: TextStyle(color: _textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final p = normalizarPatente(patenteCtrl.text);
                  final m = marcaCtrl.text.trim();
                  if (!esPatenteValida(p)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(kMensajePatenteInvalida),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final errorAnio = validarAnioVehiculo(anioCtrl.text.trim());
                if (errorAnio != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorAnio), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                bool success = await _editarVehiculo(
                  context,
                    data['id'],
                    p,
                    m,
                    categoriaSel,
                    modelo: modeloCtrl.text.trim().isEmpty ? null : modeloCtrl.text.trim(),
                    anio: int.tryParse(anioCtrl.text.trim()),
                    tipoCombustible: tipoCombustibleSel,
                    kilometraje: double.tryParse(kilometrajeCtrl.text.trim()),
                    alias: aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim(),
                  );
                  if (success && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      );
    },
  );
}
