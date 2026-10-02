import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/services/documento_ia_service.dart';
import '../data/services/notificaciones_vencimiento_service.dart';
import '../data/services/vehiculo_documentos_service.dart';

class DocumentosVehiculoScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  /// Si es true, al abrir lanza directamente el flujo "Agregar documento con IA".
  final bool iniciarConIA;

  /// Si viene (ej. 'soap'), al abrir muestra el formulario de ese documento.
  final String? tipoInicial;

  const DocumentosVehiculoScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
    this.iniciarConIA = false,
    this.tipoInicial,
  });

  @override
  State<DocumentosVehiculoScreen> createState() => _DocumentosVehiculoScreenState();
}

class _DocumentosVehiculoScreenState extends State<DocumentosVehiculoScreen> {
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
    // Pedir el permiso de notificaciones recién aquí (no en el arranque de
    // la app) para no interrumpir el primer login con un diálogo del SO.
    _notifService.solicitarPermiso();
    _cargarPreferenciaNotificaciones();

    // Acciones iniciales pedidas por quien abre esta pantalla (la ficha del
    // vehículo): se ejecutan cuando ya se dibujó el primer frame.
    if (widget.iniciarConIA) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _agregarDocumentoConIA();
      });
    } else if (widget.tipoInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirFormularioInicial());
    }
  }

  Future<void> _abrirFormularioInicial() async {
    try {
      final documentos = await _service.streamDocumentos(widget.vehiculoId).first;
      if (!mounted) return;
      final doc = documentos.where((d) => d.tipo == widget.tipoInicial).firstOrNull;
      if (doc != null) _mostrarFormularioDocumento(doc);
    } catch (e) {
      debugPrint('TAG_OK_DOCUMENTOS: no se pudo abrir el formulario inicial: $e');
    }
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

  String _labelEstado(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.alDia:
        return 'Al día';
      case EstadoVencimiento.atencion:
        return 'Por vencer';
      case EstadoVencimiento.vencido:
        return 'Vencido';
      case EstadoVencimiento.sinDatos:
        return 'Sin datos';
    }
  }

  IconData _iconoEstado(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.alDia:
        return Icons.check_circle;
      case EstadoVencimiento.atencion:
        return Icons.warning_amber_rounded;
      case EstadoVencimiento.vencido:
        return Icons.error;
      case EstadoVencimiento.sinDatos:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Documentos · ${widget.patente}', style: const TextStyle(color: Colors.white)),
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
              child: Text('Error al cargar documentos: ${snapshot.error}', style: TextStyle(color: textMain)),
            );
          }

          final documentos = snapshot.data ?? [];
          final estadoGeneral = peorEstado(documentos.map((d) => d.estado).toList());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _colorEstado(estadoGeneral).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(_iconoEstado(estadoGeneral), color: _colorEstado(estadoGeneral), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estado general del vehículo', style: TextStyle(color: textMuted, fontSize: 12)),
                          Text(
                            labelEstadoGeneralVehiculo(estadoGeneral),
                            style: TextStyle(color: _colorEstado(estadoGeneral), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...documentos.map((doc) => _buildDocumentoCard(doc)),
              const SizedBox(height: 8),
              _buildTarjetaAgregarConIA(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentoCard(DocumentoVehiculoModel doc) {
    final color = _colorEstado(doc.estado);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Card(
      color: navBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarFormularioDocumento(doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(
                  doc.origen == 'ia' ? Icons.auto_awesome : Icons.description_outlined,
                  color: doc.origen == 'ia' ? iaColor : primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.label, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    if (doc.numero != null && doc.numero!.isNotEmpty)
                      Text('N° ${doc.numero}', style: TextStyle(color: textMuted, fontSize: 12)),
                    if (doc.compania != null && doc.compania!.isNotEmpty)
                      Text(doc.compania!, style: TextStyle(color: textMuted, fontSize: 12)),
                    if (doc.fechaVencimiento != null)
                      Text('Vence: ${dateFmt.format(doc.fechaVencimiento!)}', style: TextStyle(color: textMuted, fontSize: 12))
                    else
                      Text('Toca para agregar datos', style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _labelEstado(doc.estado),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaAgregarConIA() {
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
                    _isProcessingIA ? 'Analizando documento…' : 'Agregar documento con IA',
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
    const tiposValidos = {'permiso_circulacion', 'revision_tecnica', 'soap', 'seguro'};
    String? tipoDetectado = extraido['tipo']?.toString();
    String tipoSel = tiposValidos.contains(tipoDetectado) ? tipoDetectado! : 'permiso_circulacion';
    final bool tipoIncierto = !tiposValidos.contains(tipoDetectado);

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
                      if (tipoIncierto) ...[
                        const SizedBox(height: 10),
                        _avisoRevision('No se pudo identificar el tipo de documento con certeza. Selecciónalo manualmente.'),
                      ],
                      if (patenteNoCoincide) ...[
                        const SizedBox(height: 10),
                        _avisoRevision('La patente detectada ($patenteDetectada) no coincide con ${widget.patente}. Verifica que sea el documento correcto.'),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: tipoSel,
                        dropdownColor: navBgColor,
                        style: TextStyle(color: textMain),
                        decoration: InputDecoration(
                          labelText: 'Tipo de documento',
                          labelStyle: TextStyle(color: textMuted),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                        ),
                        items: kTiposDocumentoVehiculo
                            .map((t) => DropdownMenuItem(value: t['id'], child: Text(t['label']!)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setModalState(() => tipoSel = value);
                        },
                      ),
                      const SizedBox(height: 12),
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
                  onPressed: guardando
                      ? null
                      : () async {
                          setModalState(() => guardando = true);
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
                          await _guardarYNotificar(nuevoDoc);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
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
    await _notifService.programarParaDocumento(
      vehiculoId: widget.vehiculoId,
      tipo: doc.tipo,
      etiquetaDocumento: doc.label,
      patente: widget.patente,
      fechaVencimiento: doc.fechaVencimiento,
      vencimientoHabilitado: _notifVencimientosHabilitado,
    );
  }

  void _mostrarFormularioDocumento(DocumentoVehiculoModel doc) {
    final numeroCtrl = TextEditingController(text: doc.numero ?? '');
    final companiaCtrl = TextEditingController(text: doc.compania ?? '');
    DateTime? fechaEmision = doc.fechaEmision;
    DateTime? fechaVencimiento = doc.fechaVencimiento;
    final dateFmt = DateFormat('dd/MM/yyyy');

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
                    await _guardarYNotificar(nuevoDoc);
                    if (context.mounted) Navigator.pop(context);
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
