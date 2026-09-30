import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color accentColor = const Color(
    0xFF10B981,
  ); // Verde para el presupuesto

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el usuario que inició sesión en este momento
    final user = Supabase.instance.client.auth.currentUser;

    // Si por alguna razón no hay sesión activa, evitamos errores
    if (user == null) {
      return Center(
        child: Text(
          "No hay un usuario logueado",
          style: TextStyle(color: textMain),
        ),
      );
    }

    // Usamos un stream de Realtime para escuchar la fila de este usuario
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('usuarios')
          .stream(primaryKey: ['id'])
          .eq('id', user.id),
      builder: (context, snapshot) {
        // Mientras carga desde Supabase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('TAG_OK_PROFILE: Error al escuchar usuarios/${user.id}: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error al cargar perfil:\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        // Datos por defecto (por si acaso el documento está vacío en algunas partes)
        String nombre = 'Usuario Tag OK';
        String email = user.email ?? 'Sin correo';
        int limiteNum = 50000;
        String limitePresupuesto = '\$50.000'; // Default si no tiene límite
        String vehiculoPrincipal = 'Ninguno';
        String miembroDesde = 'Reciente';
        String telefono = 'Sin registrar';
        String? fotoUrl;

        Map<String, dynamic> userData = {};
        // Si Supabase devolvió la data exitosamente, reescribimos los valores
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          userData = snapshot.data!.first;
          final data = userData;

          if (data['nombre_mostrar'] != null &&
              data['nombre_mostrar'].toString().isNotEmpty) {
            nombre = data['nombre_mostrar'];
          }

          if (data['email'] != null) {
            email = data['email'];
          }

          if (data['limite_presupuesto_mensual'] != null) {
            final val = data['limite_presupuesto_mensual'];
            if (val is num) {
              limiteNum = val.toInt();
            } else if (val is String) {
              limiteNum = int.tryParse(val) ?? 50000;
            }
            limitePresupuesto = '\$$limiteNum';
          }

          if (data['vehiculo_principal_patente'] != null &&
              data['vehiculo_principal_patente'].toString().isNotEmpty) {
            vehiculoPrincipal = data['vehiculo_principal_patente'];
          }

          if (data['telefono'] != null &&
              data['telefono'].toString().isNotEmpty) {
            telefono = data['telefono'];
          }

          if (data['foto_url'] != null &&
              data['foto_url'].toString().isNotEmpty) {
            fotoUrl = data['foto_url'];
          }

          if (data['fecha_creacion'] != null) {
            final DateTime date = DateTime.parse(data['fecha_creacion']);
            // Formatear mes en español
            final meses = [
              'Ene',
              'Feb',
              'Mar',
              'Abr',
              'May',
              'Jun',
              'Jul',
              'Ago',
              'Sep',
              'Oct',
              'Nov',
              'Dic',
            ];
            miembroDesde = '${meses[date.month - 1]} ${date.year}';
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Foto de Perfil con botón de edición flotante
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: navBgColor,
                      backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                      child: fotoUrl == null
                          ? Text(
                              nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: textMain,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _mostrarOpcionesAvatar(
                        context,
                        user.id,
                        nombre == 'Usuario Tag OK' ? '' : nombre,
                        limiteNum,
                        telefono == 'Sin registrar' ? '' : telefono,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: bgColor,
                            width: 3,
                          ), // Borde para que resalte
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nombre y Correo
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(email, style: TextStyle(fontSize: 14, color: textMuted)),
              const SizedBox(height: 32),

              // 2. Panel de Resumen (Tarjetas)
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Límite Mensual',
                      value: limitePresupuesto,
                      icon: Icons.account_balance_wallet_outlined,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Vehículo Principal',
                      value: vehiculoPrincipal,
                      icon: Icons.directions_car_outlined,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Teléfono',
                      value: telefono,
                      icon: Icons.phone_outlined,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Miembro desde',
                      value: miembroDesde,
                      icon: Icons.calendar_month_outlined,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 3. Opciones del Menú
              _buildProfileOption(
                icon: Icons.notifications_none_outlined,
                title: 'Notificaciones / Alertas',
                onTap: () => _mostrarOpcionesNotificaciones(context, user.id, userData),
              ),
              const SizedBox(height: 16),
              _buildProfileOption(
                icon: Icons.lock_outline,
                title: 'Seguridad y Contraseña',
                onTap: () => _mostrarDialogoCambiarContrasena(context, ref, user.email ?? ''),
              ),
              const SizedBox(height: 32),

              // 4. Botón de Cerrar Sesión
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Cerrar sesión real en Supabase y limpiar el estado
                    await ref.read(authNotifierProvider.notifier).signOut();

                    // Volver a la pantalla de inicio de sesión eliminando el historial
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarOpcionesNotificaciones(BuildContext context, String uid, Map<String, dynamic> userData) {
    bool cobros = userData['notif_cobros'] ?? true;
    bool presupuesto = userData['notif_presupuesto'] ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: navBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificaciones y Alertas',
                    style: TextStyle(color: textMain, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Administra qué alertas quieres recibir en tu dispositivo.',
                    style: TextStyle(color: textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    activeThumbColor: primaryColor,
                    title: Text('Nuevos cobros de TAG', style: TextStyle(color: textMain)),
                    subtitle: Text('Recibe una alerta cada vez que pases por un pórtico.', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: cobros,
                    onChanged: (val) async {
                      setModalState(() => cobros = val);
                      try {
                        await Supabase.instance.client
                            .from('usuarios')
                            .update({'notif_cobros': val}).eq('id', uid);
                      } catch (e) {
                        setModalState(() => cobros = !val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo guardar la preferencia.')),
                          );
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    activeThumbColor: primaryColor,
                    title: Text('Alertas de Presupuesto', style: TextStyle(color: textMain)),
                    subtitle: Text('Te avisaremos cuando te acerques a tu límite mensual.', style: TextStyle(color: textMuted, fontSize: 12)),
                    value: presupuesto,
                    onChanged: (val) async {
                      setModalState(() => presupuesto = val);
                      try {
                        await Supabase.instance.client
                            .from('usuarios')
                            .update({'notif_presupuesto': val}).eq('id', uid);
                      } catch (e) {
                        setModalState(() => presupuesto = !val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo guardar la preferencia.')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Listo', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }

  // --- MENÚ QUE ABRE EL LÁPIZ SOBRE EL AVATAR ---
  void _mostrarOpcionesAvatar(
    BuildContext context,
    String uid,
    String nombreActual,
    int limiteActual,
    String telefonoActual,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: navBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: primaryColor),
                  title: Text('Cambiar foto de perfil', style: TextStyle(color: textMain)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _cambiarFotoPerfil(context, uid);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: primaryColor),
                  title: Text('Editar datos personales', style: TextStyle(color: textMain)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _mostrarDialogoEdicion(context, uid, nombreActual, limiteActual, telefonoActual);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- SELECCIONAR Y SUBIR UNA FOTO DE PERFIL A SUPABASE STORAGE ---
  Future<void> _cambiarFotoPerfil(BuildContext context, String uid) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await picked.readAsBytes();
      // Extensión tomada del archivo elegido; si no viene ninguna (típico en
      // web al pegar/soltar), usamos jpg como formato por defecto.
      final rawExt = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final ext = rawExt == 'jpg' || rawExt == 'jpeg' || rawExt == 'png' || rawExt == 'webp' ? rawExt : 'jpg';
      final path = '$uid/avatar.$ext';
      final storage = Supabase.instance.client.storage.from('avatars');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
        ),
      );

      // El path no cambia entre fotos (siempre "<uid>/avatar.<ext>"), así que
      // agregamos un parámetro de versión para evitar que quede cacheada la
      // imagen anterior en el dispositivo o en el CDN.
      final publicUrl = storage.getPublicUrl(path);
      final fotoUrlConVersion = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client
          .from('usuarios')
          .update({'foto_url': fotoUrlConVersion})
          .eq('id', uid);

      if (context.mounted) Navigator.pop(context); // cierra el loading
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // cierra el loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar la foto: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- CAMBIAR CONTRASEÑA ---
  void _mostrarDialogoCambiarContrasena(BuildContext context, WidgetRef ref, String email) {
    final TextEditingController actualCtrl = TextEditingController();
    final TextEditingController nuevaCtrl = TextEditingController();
    final TextEditingController confirmarCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Cambiar contraseña',
                style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: actualCtrl,
                    obscureText: true,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      labelStyle: TextStyle(color: textMuted),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nuevaCtrl,
                    obscureText: true,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      labelStyle: TextStyle(color: textMuted),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: confirmarCtrl,
                    obscureText: true,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      labelStyle: TextStyle(color: textMuted),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: textMuted),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancelar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final actual = actualCtrl.text.trim();
                          final nueva = nuevaCtrl.text.trim();
                          final confirmar = confirmarCtrl.text.trim();

                          if (actual.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Completa los tres campos.'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          if (nueva.length < 6) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('La nueva contraseña debe tener al menos 6 caracteres.'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          if (nueva != confirmar) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Las contraseñas nuevas no coinciden.'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }

                          setModalState(() => isLoading = true);
                          final authRepository = ref.read(authRepositoryProvider);
                          try {
                            // Confirma que la contraseña actual es correcta antes de
                            // cambiarla (Supabase no lo exige para updateUser, ya que
                            // la sesión ya está autenticada).
                            await authRepository.reauthenticate(email, actual);
                            await authRepository.updatePassword(nueva);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Contraseña actualizada correctamente.'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isLoading = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Cambiar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNCIÓN PARA MOSTRAR LA VENTANA EMERGENTE DE EDICIÓN ---
  void _mostrarDialogoEdicion(
    BuildContext context,
    String uid,
    String nombreActual,
    int limiteActual,
    String telefonoActual,
  ) {
    final TextEditingController nombreController = TextEditingController(
      text: nombreActual,
    );
    final TextEditingController limiteController = TextEditingController(
      text: limiteActual.toString(),
    );
    final TextEditingController telefonoController = TextEditingController(
      text: telefonoActual,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Editar Perfil',
            style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize
                .min, // Para que el cuadro no ocupe toda la pantalla
            children: [
              TextField(
                controller: nombreController,
                style: TextStyle(color: textMain),
                decoration: InputDecoration(
                  labelText: 'Nombre a mostrar',
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  prefixIcon: Icon(Icons.person_outline, color: textMuted),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: telefonoController,
                style: TextStyle(color: textMain),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  prefixIcon: Icon(Icons.phone_outlined, color: textMuted),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: limiteController,
                style: TextStyle(color: textMain),
                keyboardType:
                    TextInputType.number, // Muestra el teclado numérico
                decoration: InputDecoration(
                  labelText: 'Límite Mensual (\$)',
                  labelStyle: TextStyle(color: textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  prefixIcon: Icon(Icons.attach_money, color: textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final nuevoNombre = nombreController.text.trim();
                final nuevoLimite =
                    int.tryParse(limiteController.text.trim()) ?? limiteActual;
                final nuevoTelefono = telefonoController.text.trim();

                // Actualizar en Supabase la tabla de "usuarios"
                await Supabase.instance.client.from('usuarios').update({
                  'nombre_mostrar': nuevoNombre,
                  'limite_presupuesto_mensual': nuevoLimite,
                  'telefono': nuevoTelefono,
                }).eq('id', uid);

                if (context.mounted) {
                  Navigator.pop(context); // Cerrar el diálogo cuando termine
                }
              },
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- HELPERS PARA EL DISEÑO ---
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: navBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
