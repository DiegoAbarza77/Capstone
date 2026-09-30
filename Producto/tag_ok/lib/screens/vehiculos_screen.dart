import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/vehiculo_model.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/services/vehiculo_documentos_service.dart';
import 'documentos_vehiculo_screen.dart';
import 'combustible_screen.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color accentColor = const Color(0xFF10B981);

  final TextEditingController _patenteController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _anioController = TextEditingController();
  final TextEditingController _kilometrajeController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  String _categoriaSeleccionada = 'AUTO';
  String? _tipoCombustibleSeleccionado;

  final VehiculoDocumentosService _documentosService = VehiculoDocumentosService();

  String _vehiculoPrincipalActual = '';

  @override
  void initState() {
    super.initState();
    _cargarVehiculoPrincipal();
  }

  @override
  void dispose() {
    _patenteController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _kilometrajeController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _cargarVehiculoPrincipal() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final row = await Supabase.instance.client
          .from('usuarios')
          .select('vehiculo_principal_patente')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null && row['vehiculo_principal_patente'] != null) {
        setState(() {
          _vehiculoPrincipalActual = row['vehiculo_principal_patente'] ?? '';
        });
      }
    }
  }

  Future<void> _setVehiculoPrincipal(String patente) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.from('usuarios').update({
        'vehiculo_principal_patente': patente,
      }).eq('id', user.id);
      setState(() {
        _vehiculoPrincipalActual = patente;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vehículo principal actualizado a $patente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Sube la foto a Storage en la ruta "uid/vehiculoId.ext" (mismo patrón de
  /// bucket-público-lectura + RLS-por-carpeta-de-uid que ya usa el avatar de
  /// perfil) y devuelve la URL pública con un parámetro de versión, para que
  /// no quede cacheada la foto anterior con el mismo nombre de archivo.
  Future<String> _subirFotoVehiculo(String vehiculoId, XFile foto) async {
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

  Future<bool> _agregarVehiculo({XFile? foto}) async {
    final patente = _patenteController.text.trim().toUpperCase();
    final categoria = _categoriaSeleccionada;
    final marca = _marcaController.text.trim();
    final user = Supabase.instance.client.auth.currentUser;

    if (patente.isEmpty || user == null) return false;

    // Validación de patente (4 letras y 2 números)
    final patenteRegex = RegExp(r'^[A-Z]{4}\d{2}$');
    if (!patenteRegex.hasMatch(patente)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formato inválido (ej: ABCD12)'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    try {
      // .select().single() para obtener el id generado: la foto se sube
      // recién después, porque su ruta en Storage usa el id del vehículo.
      final inserted = await Supabase.instance.client
          .from('vehiculos')
          .insert({
            'patente': patente,
            'categoria': categoria,
            'marca': marca.isNotEmpty ? marca : 'No especificada',
            'modelo': _modeloController.text.trim().isEmpty ? null : _modeloController.text.trim(),
            'anio': int.tryParse(_anioController.text.trim()),
            'tipo_combustible': _tipoCombustibleSeleccionado,
            'kilometraje': double.tryParse(_kilometrajeController.text.trim()),
            'alias': _aliasController.text.trim().isEmpty ? null : _aliasController.text.trim(),
            'usuario_id': user.id,
          })
          .select()
          .single();

      if (foto != null) {
        try {
          final fotoUrl = await _subirFotoVehiculo(inserted['id'], foto);
          await Supabase.instance.client.from('vehiculos').update({'foto_url': fotoUrl}).eq('id', inserted['id']);
        } catch (e) {
          // El vehículo ya se creó correctamente; que falle solo la foto no
          // debería impedir el flujo -- se puede agregar después editando.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Vehículo creado, pero no se pudo subir la foto: $e'), backgroundColor: Colors.orange),
            );
          }
        }
      }

      _patenteController.clear();
      _marcaController.clear();
      _modeloController.clear();
      _anioController.clear();
      _kilometrajeController.clear();
      _aliasController.clear();
      setState(() {
        _categoriaSeleccionada = 'AUTO';
        _tipoCombustibleSeleccionado = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehículo agregado exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar vehículo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _editarVehiculo(
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehículo actualizado exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  void _mostrarInfoVehiculo(Map<String, dynamic> data) {
    final alias = (data['alias'] as String?)?.trim();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            alias != null && alias.isNotEmpty ? alias : 'Información del Vehículo',
            style: TextStyle(color: textMain),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['foto_url'] != null) ...[
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        data['foto_url'],
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Patente: ${data['patente']}', style: TextStyle(color: textMain, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Tipo: ${data['categoria']}', style: TextStyle(color: textMuted, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Marca: ${data['marca'] ?? 'No especificada'}', style: TextStyle(color: textMuted, fontSize: 16)),
                if (data['modelo'] != null && data['modelo'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Modelo: ${data['modelo']}', style: TextStyle(color: textMuted, fontSize: 16)),
                ],
                if (data['anio'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Año: ${data['anio']}', style: TextStyle(color: textMuted, fontSize: 16)),
                ],
                if (data['tipo_combustible'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Combustible: ${data['tipo_combustible']}', style: TextStyle(color: textMuted, fontSize: 16)),
                ],
                if (data['kilometraje'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Kilometraje: ${(data['kilometraje'] as num).toStringAsFixed(0)} km', style: TextStyle(color: textMuted, fontSize: 16)),
                ],
                const SizedBox(height: 8),
                Text(
                  'Ingresado: ${data['fecha_ingreso'] != null ? _formatearFecha(data['fecha_ingreso']) : 'No registrada'}',
                  style: TextStyle(color: textMuted, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentosVehiculoScreen(
                            vehiculoId: data['id'],
                            patente: data['patente'] ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Ver Documentos y Vencimientos'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CombustibleScreen(
                            vehiculoId: data['id'],
                            patente: data['patente'] ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_gas_station_outlined),
                    label: const Text('Ver Combustible'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _mostrarFormularioEditarVehiculo(data);
              },
              child: const Text('Editar', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioEditarVehiculo(Map<String, dynamic> data) {
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
                final fotoUrl = await _subirFotoVehiculo(data['id'], picked);
                await Supabase.instance.client.from('vehiculos').update({'foto_url': fotoUrl}).eq('id', data['id']);
                setModalState(() {
                  fotoUrlActual = fotoUrl;
                  subiendoFoto = false;
                });
              } catch (e) {
                setModalState(() => subiendoFoto = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo actualizar la foto: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Editar Vehículo', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
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
                          backgroundColor: bgColor,
                          backgroundImage: fotoUrlActual != null ? NetworkImage(fotoUrlActual!) : null,
                          child: subiendoFoto
                              ? const CircularProgressIndicator()
                              : fotoUrlActual == null
                                  ? Icon(Icons.add_a_photo_outlined, color: textMuted, size: 28)
                                  : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text('Toca para cambiar la foto', style: TextStyle(color: textMuted, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: patenteCtrl,
                      style: TextStyle(color: textMain),
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
                        labelText: 'Patente (ej: ABCD55)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: marcaCtrl,
                      style: TextStyle(color: textMain),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Marca (ej: Toyota, Kia)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoriaSel,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Vehículo',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
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
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Modelo (ej: Corolla)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: anioCtrl,
                      style: TextStyle(color: textMain),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Año',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipoCombustibleSel,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      hint: Text('Selecciona', style: TextStyle(color: textMuted)),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Combustible',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
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
                      style: TextStyle(color: textMain),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Kilometraje actual',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aliasCtrl,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Alias (ej: Auto de la Sara)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final p = patenteCtrl.text.trim().toUpperCase();
                    final m = marcaCtrl.text.trim();
                    final patenteRegex = RegExp(r'^[A-Z]{4}\d{2}$');
                    if (!patenteRegex.hasMatch(p)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Formato inválido (ej: ABCD12)'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    bool success = await _editarVehiculo(
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

  void _mostrarSelectorVehiculoPrincipal(List<String> patentes) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Seleccionar Vehículo Principal', style: TextStyle(color: textMain)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patentes.length,
              itemBuilder: (context, index) {
                final pat = patentes[index];
                return ListTile(
                  title: Text(pat, style: TextStyle(color: textMain)),
                  trailing: _vehiculoPrincipalActual == pat
                      ? Icon(Icons.check_circle, color: accentColor)
                      : null,
                  onTap: () {
                    _setVehiculoPrincipal(pat);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioAgregarVehiculo() {
    XFile? fotoSeleccionada;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Agregar Nuevo Vehículo', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 85,
                          );
                          if (picked != null) setModalState(() => fotoSeleccionada = picked);
                        },
                        child: FutureBuilder<Uint8List>(
                          future: fotoSeleccionada?.readAsBytes(),
                          builder: (context, snapshot) {
                            return CircleAvatar(
                              radius: 40,
                              backgroundColor: bgColor,
                              backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
                              child: snapshot.hasData
                                  ? null
                                  : Icon(Icons.add_a_photo_outlined, color: textMuted, size: 28),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text('Foto (opcional)', style: TextStyle(color: textMuted, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _patenteController,
                      style: TextStyle(color: textMain),
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
                        labelText: 'Patente (ej: ABCD55)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _marcaController,
                      style: TextStyle(color: textMain),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Marca (ej: Toyota, Kia)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoriaSeleccionada,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Vehículo',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'AUTO', child: Text('AUTO')),
                        DropdownMenuItem(value: 'CAMIONETA', child: Text('CAMIONETA')),
                        DropdownMenuItem(value: 'MOTO', child: Text('MOTO')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            _categoriaSeleccionada = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modeloController,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Modelo (ej: Corolla)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _anioController,
                      style: TextStyle(color: textMain),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Año',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoCombustibleSeleccionado,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      hint: Text('Selecciona', style: TextStyle(color: textMuted)),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Combustible',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                      items: kTiposCombustible
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          _tipoCombustibleSeleccionado = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _kilometrajeController,
                      style: TextStyle(color: textMain),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Kilometraje actual',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _aliasController,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Alias (opcional)',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    bool success = await _agregarVehiculo(foto: fotoSeleccionada);
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Agregar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("No autenticado")));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('Mis Vehículos', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAgregarVehiculo,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TÍTULO LISTA ---
            Text('Tus Autos Registrados', style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // --- LISTA DE VEHÍCULOS ---
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('vehiculos')
                    .stream(primaryKey: ['id'])
                    .eq('usuario_id', user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildListaVehiculos(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'Aún no hay vehículos',
            style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón + para agregar uno',
            style: TextStyle(color: textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildListaVehiculos(List<Map<String, dynamic>> docs) {
    // Extraemos las patentes para el selector
    List<String> patentes = docs.map((data) {
      return data['patente']?.toString() ?? 'Sin patente';
    }).toList();

    return Column(
      children: [
        // --- BOTÓN PARA ELEGIR VEHÍCULO PRINCIPAL ---
        if (patentes.isNotEmpty)
          InkWell(
            onTap: () => _mostrarSelectorVehiculoPrincipal(patentes),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehículo Principal', style: TextStyle(color: textMuted, fontSize: 12)),
                        Text(
                          _vehiculoPrincipalActual.isNotEmpty ? _vehiculoPrincipalActual : 'Seleccionar',
                          style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: textMain),
                ],
              ),
            ),
          ),
          
        Expanded(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final patente = data['patente'] ?? 'Desconocida';
              final categoria = data['categoria'] ?? 'Auto';

              return Card(
                color: navBgColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: data['foto_url'] != null
                      ? CircleAvatar(
                          backgroundColor: bgColor,
                          backgroundImage: NetworkImage(data['foto_url']),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.directions_car, color: primaryColor),
                        ),
                  title: Text(
                    (data['alias'] as String?)?.trim().isNotEmpty == true ? data['alias'] : patente,
                    style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${data['marca'] ?? 'Sin marca'} • $categoria', style: TextStyle(color: textMuted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEstadoDocumentosDot(data['id']),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _mostrarInfoVehiculo(data),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoDocumentosDot(String vehiculoId) {
    return StreamBuilder<List<DocumentoVehiculoModel>>(
      stream: _documentosService.streamDocumentos(vehiculoId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 10, height: 10);
        final estado = peorEstado(snapshot.data!.map((d) => d.estado).toList());
        Color color;
        switch (estado) {
          case EstadoVencimiento.alDia:
            color = const Color(0xFF10B981);
            break;
          case EstadoVencimiento.atencion:
            color = const Color(0xFFF59E0B);
            break;
          case EstadoVencimiento.vencido:
            color = const Color(0xFFEF4444);
            break;
          case EstadoVencimiento.sinDatos:
            color = Colors.grey;
            break;
        }
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      },
    );
  }
}
