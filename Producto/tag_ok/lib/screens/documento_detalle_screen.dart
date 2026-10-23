import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/services/documento_ia_service.dart';
import '../data/services/notificaciones_vencimiento_service.dart';
import '../data/services/vehiculo_documentos_service.dart';

/// Detalle de un documento del vehículo (permiso, revisión técnica, SOAP o
/// seguro): muestra lo cargado y permite subirlo con IA o editarlo a mano.
class DocumentoDetalleScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;
  final String tipo;

  const DocumentoDetalleScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
    required this.tipo,
  });

  @override
  State<DocumentoDetalleScreen> createState() => _DocumentoDetalleScreenState();
}

class _DocumentoDetalleScreenState extends State<DocumentoDetalleScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color accentColor = const Color(0xFF10B981);
  final Color iaColor = const Color(0xFF8B5CF6);

  final VehiculoDocumentosService _service = VehiculoDocumentosService();
  final DocumentoIaService _iaService = DocumentoIaService();
  final NotificacionesVencimientoService _notifService = NotificacionesVencimientoService();

  bool _isProcessingIA = false;
  bool _notifVencimientosHabilitado = true;

  @override
  void initState() {
    super.initState();
    _notifService.solicitarPermiso();
    _cargarPreferenciaNotificaciones();
  }

  Future<void> _cargarPreferenciaNotificaciones() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final row = await Supabase.instance.client
        .from('usuarios')
        .select('notif_vencimientos')
        .eq('id', userId)
        .maybeSingle();
    if (mounted && row != null) {
      setState(() {
        _notifVencimientosHabilitado = row['notif_vencimientos'] ?? true;
      });
    }
  }

  Color _colorEstado(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.alDia:
        return const Color(0xFF10B981);
      case EstadoVencimiento.atencion:
        return const Color(0xFFF59E0B);
      case EstadoVencimiento.vencido:
        return const Color(0xFFEF4444);
      case EstadoVencimiento.sinDatos:
        return textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta = kTiposDocumentoVehiculo.firstWhere(
      (t) => t['id'] == widget.tipo,
      orElse: () => {'id': widget.tipo, 'label': widget.tipo},
    )['label']!;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('$etiqueta · ${widget.patente}', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<DocumentoVehiculoModel>>(
        stream: _service.streamDocumentos(widget.vehiculoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar el documento: ${snapshot.error}', style: TextStyle(color: textMain)),
            );
          }
          final doc = (snapshot.data ?? []).where((d) => d.tipo == widget.tipo).firstOrNull ??
              DocumentoVehiculoModel(tipo: widget.tipo);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildResumen(doc),
              const SizedBox(height: 16),
              _buildTarjetaSubirConIA(doc),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _mostrarFormularioDocumento(doc),
                icon: const Icon(Icons.edit_outlined),
                label: Text(_tieneDatos(doc) ? 'Editar datos manualmente' : 'Ingresar datos manualmente'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _tieneDatos(DocumentoVehiculoModel doc) =>
      doc.numero != null || doc.compania != null || doc.fechaEmision != null || doc.fechaVencimiento != null;

  Widget _buildResumen(DocumentoVehiculoModel doc) {
    final color = _colorEstado(doc.estado);
    final dateFmt = DateFormat('dd/MM/yyyy');

    Widget fila(String label, String? valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: Text(label, style: TextStyle(color: textMuted, fontSize: 13))),
              Expanded(
                child: Text(
                  valor == null || valor.isEmpty ? 'Sin datos' : valor,
                  style: TextStyle(
                    color: valor == null || valor.isEmpty ? textMuted.withValues(alpha: 0.7) : textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(doc.origen == 'ia' ? Icons.auto_awesome : Icons.description_outlined,
                  color: doc.origen == 'ia' ? iaColor : primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(doc.label, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(doc.textoVencimiento, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          fila('Número', doc.numero),
          fila('Compañía / Emisor', doc.compania),
          fila('Fecha de emisión', doc.fechaEmision != null ? dateFmt.format(doc.fechaEmision!) : null),
          fila('Vencimiento', doc.fechaVencimiento != null ? dateFmt.format(doc.fechaVencimiento!) : null),
          if (doc.origen == 'ia' && doc.archivoNombre != null) fila('Archivo', doc.archivoNombre),
        ],
      ),
    );
  }

  Widget _buildTarjetaSubirConIA(DocumentoVehiculoModel doc) {
    return InkWell(
      onTap: _isProcessingIA ? null : _agregarDocumentoConIA,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: iaColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iaColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              child: _isProcessingIA
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: iaColor),
                    )
                  : Icon(Icons.auto_awesome, color: iaColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isProcessingIA ? 'Analizando documento…' : _tieneDatos(doc) ? 'Reemplazar con IA' : 'Subir con IA',
                    style: TextStyle(color: iaColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fotografiar → revisar → guardar',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarDocumentoConIA() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No se pudieron leer los bytes del archivo seleccionado.');
      }

      final nameLower = file.name.toLowerCase();
      final String mimeType = nameLower.endsWith('.pdf')
          ? 'application/pdf'
          : nameLower.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';

      setState(() => _isProcessingIA = true);

      final extraido = await _iaService.extraerDocumento(
        fileBytes: bytes,
        mimeType: mimeType,
        fileName: file.name,
      );

      if (!mounted) return;
      setState(() => _isProcessingIA = false);

      await _mostrarRevisionDocumentoIA(extraido, nombreArchivo: file.name);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingIA = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// Paso de revisión y confirmación: la IA precarga el formulario, pero
  /// nada se guarda hasta que el usuario confirma acá -- la misma regla
  /// "Manual + IA → Revisión → Confirmar → Guardar" que ya usa audit_screen.
  Future<void> _mostrarRevisionDocumentoIA(
    Map<String, dynamic> extraido, {
    required String nombreArchivo,
  }) async {
    final String tipoSel = widget.tipo;
    final String? tipoDetectado = extraido['tipo']?.toString();
    final bool tipoNoCoincide = tipoDetectado != null && tipoDetectado.isNotEmpty && tipoDetectado != widget.tipo;

    final String? patenteDetectada = extraido['patente']?.toString();
    final bool patenteNoCoincide = patenteDetectada != null &&
        patenteDetectada.trim().isNotEmpty &&
        patenteDetectada.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '') !=
            widget.patente.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final numeroCtrl = TextEditingController(text: extraido['numero']?.toString() ?? '');
    final companiaCtrl = TextEditingController(text: extraido['compania']?.toString() ?? '');
    DateTime? fechaEmision = _parseFechaSegura(extraido['fecha_emision']);
    DateTime? fechaVencimiento = _parseFechaSegura(extraido['fecha_vencimiento']);
    final dateFmt = DateFormat('dd/MM/yyyy');
    bool guardando = false;
    String? errorGuardado;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            Future<void> pickDate(bool esVencimiento) async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: (esVencimiento ? fechaVencimiento : fechaEmision) ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  if (esVencimiento) {
                    fechaVencimiento = picked;
                  } else {
                    fechaEmision = picked;
                  }
                });
              }
            }

            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: iaColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Revisar antes de guardar', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'La IA extrajo estos datos de "$nombreArchivo". Corrígelos si algo no calza antes de guardar.',
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                      if (tipoNoCoincide) ...[
                        const SizedBox(height: 10),
                        _avisoRevision('La IA cree que este archivo es otro tipo de documento (${_etiquetaTipo(tipoDetectado)}). Verifica que sea el correcto.'),
                      ],
                      if (patenteNoCoincide) ...[
                        const SizedBox(height: 10),
                        _avisoRevision('La patente detectada ($patenteDetectada) no coincide con ${widget.patente}. Verifica que sea el documento correcto.'),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: numeroCtrl,
                        style: TextStyle(color: textMain),
                        decoration: InputDecoration(
                          labelText: 'Número de documento',
                          labelStyle: TextStyle(color: textMuted),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: companiaCtrl,
                        style: TextStyle(color: textMain),
                        decoration: InputDecoration(
                          labelText: 'Compañía / Emisor',
                          labelStyle: TextStyle(color: textMuted),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDateRow(
                        label: 'Fecha de emisión',
                        valor: fechaEmision != null ? dateFmt.format(fechaEmision!) : 'Sin definir',
                        onTap: () => pickDate(false),
                      ),
                      const SizedBox(height: 12),
                      _buildDateRow(
                        label: 'Fecha de vencimiento',
                        valor: fechaVencimiento != null ? dateFmt.format(fechaVencimiento!) : 'Sin definir',
                        onTap: () => pickDate(true),
                      ),
                      if (validarFechasDocumento(fechaEmision, fechaVencimiento) != null)
                        _textoError(validarFechasDocumento(fechaEmision, fechaVencimiento)!),
                      if (errorGuardado != null) _textoError(errorGuardado!),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(dialogContext),
                  child: Text('Descartar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iaColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: guardando || validarFechasDocumento(fechaEmision, fechaVencimiento) != null
                      ? null
                      : () async {
                          setModalState(() {
                            guardando = true;
                            errorGuardado = null;
                          });
                          final nuevoDoc = DocumentoVehiculoModel(
                            tipo: tipoSel,
                            numero: numeroCtrl.text.trim().isEmpty ? null : numeroCtrl.text.trim(),
                            compania: companiaCtrl.text.trim().isEmpty ? null : companiaCtrl.text.trim(),
                            fechaEmision: fechaEmision,
                            fechaVencimiento: fechaVencimiento,
                            origen: 'ia',
                            aiCapturadoEn: DateTime.now(),
                            archivoNombre: nombreArchivo,
                          );
                          try {
                            await _guardarYNotificar(nuevoDoc);
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          } catch (e) {
                            debugPrint('TAG_OK_DOCUMENTOS: error al guardar: $e');
                            // Los datos siguen en pantalla para poder reintentar.
                            if (dialogContext.mounted) {
                              setModalState(() {
                                guardando = false;
                                errorGuardado = 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.';
                              });
                            }
                          }
                        },
                  child: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmar y guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _etiquetaTipo(String id) => kTiposDocumentoVehiculo
      .firstWhere((t) => t['id'] == id, orElse: () => {'id': id, 'label': id})['label']!;

  Widget _textoError(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(texto, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
    );
  }

  /// Pide confirmación y borra el documento junto con sus recordatorios.
  /// Devuelve true si quedó eliminado.
  Future<bool> _eliminarDocumento(DocumentoVehiculoModel doc) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: navBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar ${doc.label}', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        content: Text(
          'Se borrarán los datos de este documento y sus recordatorios de vencimiento. Esta acción no se puede deshacer.',
          style: TextStyle(color: textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar eliminación', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmado != true) return false;
    try {
      await _service.eliminarDocumento(widget.vehiculoId, doc.tipo);
      await _notifService.cancelarParaDocumento(widget.vehiculoId, doc.tipo);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar. Revisa tu conexión e intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }

  Widget _avisoRevision(String texto) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12))),
        ],
      ),
    );
  }

  DateTime? _parseFechaSegura(dynamic valor) {
    if (valor == null) return null;
    try {
      return DateTime.parse(valor.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarYNotificar(DocumentoVehiculoModel doc) async {
    await _service.guardarDocumento(widget.vehiculoId, doc);
    // El documento ya quedó guardado: si falla el recordatorio local (por
    // ejemplo en web, que no soporta notificaciones programadas), no se
    // debe mostrar como error de guardado.
    try {
      await _notifService.programarParaDocumento(
        vehiculoId: widget.vehiculoId,
        tipo: doc.tipo,
        etiquetaDocumento: doc.label,
        patente: widget.patente,
        fechaVencimiento: doc.fechaVencimiento,
        vencimientoHabilitado: _notifVencimientosHabilitado,
      );
    } catch (e) {
      debugPrint('TAG_OK_DOCUMENTOS: no se pudo programar el recordatorio: $e');
    }
  }

  void _mostrarFormularioDocumento(DocumentoVehiculoModel doc) {
    final numeroCtrl = TextEditingController(text: doc.numero ?? '');
    final companiaCtrl = TextEditingController(text: doc.compania ?? '');
    DateTime? fechaEmision = doc.fechaEmision;
    DateTime? fechaVencimiento = doc.fechaVencimiento;
    final dateFmt = DateFormat('dd/MM/yyyy');
    final existe = doc.numero != null || doc.compania != null || doc.fechaEmision != null || doc.fechaVencimiento != null;
    bool guardando = false;
    String? errorGuardado;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate(bool esVencimiento) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: (esVencimiento ? fechaVencimiento : fechaEmision) ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  if (esVencimiento) {
                    fechaVencimiento = picked;
                  } else {
                    fechaEmision = picked;
                  }
                });
              }
            }

            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(doc.label, style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: numeroCtrl,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Número de documento',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: companiaCtrl,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Compañía / Emisor',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDateRow(
                      label: 'Fecha de emisión',
                      valor: fechaEmision != null ? dateFmt.format(fechaEmision!) : 'Sin definir',
                      onTap: () => pickDate(false),
                    ),
                    const SizedBox(height: 12),
                    _buildDateRow(
                      label: 'Fecha de vencimiento',
                      valor: fechaVencimiento != null ? dateFmt.format(fechaVencimiento!) : 'Sin definir',
                      onTap: () => pickDate(true),
                    ),
                    if (validarFechasDocumento(fechaEmision, fechaVencimiento) != null)
                      _textoError(validarFechasDocumento(fechaEmision, fechaVencimiento)!),
                    if (errorGuardado != null) _textoError(errorGuardado!),
                  ],
                ),
              ),
              actions: [
                if (existe)
                  TextButton(
                    onPressed: guardando
                        ? null
                        : () async {
                            final eliminado = await _eliminarDocumento(doc);
                            if (eliminado && context.mounted) Navigator.pop(context);
                          },
                    child: const Text('Eliminar', style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: guardando || validarFechasDocumento(fechaEmision, fechaVencimiento) != null
                      ? null
                      : () async {
                    setModalState(() {
                      guardando = true;
                      errorGuardado = null;
                    });
                    final nuevoDoc = DocumentoVehiculoModel(
                      tipo: doc.tipo,
                      numero: numeroCtrl.text.trim().isEmpty ? null : numeroCtrl.text.trim(),
                      compania: companiaCtrl.text.trim().isEmpty ? null : companiaCtrl.text.trim(),
                      fechaEmision: fechaEmision,
                      fechaVencimiento: fechaVencimiento,
                      // Origen vuelve a "manual": si el documento venía de una
                      // extracción de IA, editarlo a mano ya lo desvincula de
                      // ese origen -- ahora es un dato que el usuario tecleó.
                    );
                    try {
                      await _guardarYNotificar(nuevoDoc);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('TAG_OK_DOCUMENTOS: error al guardar: $e');
                      if (context.mounted) {
                        setModalState(() {
                          guardando = false;
                          errorGuardado = 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.';
                        });
                      }
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateRow({required String label, required String valor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: textMuted, fontSize: 11)),
                  Text(valor, style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.edit, color: primaryColor, size: 16),
          ],
        ),
      ),
    );
  }
}
