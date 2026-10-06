import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/mantencion_model.dart';
import '../data/services/lectura_boleta_exception.dart';
import '../data/services/mantencion_ia_service.dart';
import '../data/services/mantencion_service.dart';
import '../utils/file_saver.dart';
import '../utils/mantencion_calculos.dart';
import '../utils/numero_chile.dart';
import 'mantencion_form_screen.dart';
import 'mantencion_ui.dart';
import 'programar_mantencion_dialog.dart';

/// Módulo Mantenciones: línea de tiempo del historial (CU8), registro manual o
/// con IA (CU7) y programación de la próxima mantención con recordatorios (CU9).
class MantencionesScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  const MantencionesScreen({super.key, required this.vehiculoId, required this.patente});

  @override
  State<MantencionesScreen> createState() => _MantencionesScreenState();
}

class _MantencionesScreenState extends State<MantencionesScreen> {
  static const _tamanoMaximoIa = 8 * 1024 * 1024;

  final MantencionService _service = MantencionService();

  late Stream<List<MantencionModel>> _historialStream;
  late Stream<List<MantencionProgramadaModel>> _programadasStream;
  late Stream<List<Map<String, dynamic>>> _vehiculoStream;

  bool _procesandoIa = false;

  @override
  void initState() {
    super.initState();
    _crearStreams();
  }

  /// Los streams se crean una sola vez (y de nuevo al "Reintentar"): si se
  /// armaran dentro de build() cada redibujado volvería a suscribirse.
  void _crearStreams() {
    _historialStream = _service.streamPorVehiculo(widget.vehiculoId);
    _programadasStream = _service.streamProgramadas(widget.vehiculoId);
    _vehiculoStream = Supabase.instance.client
        .from('vehiculos')
        .stream(primaryKey: ['id']).eq('id', widget.vehiculoId);
  }

  void _mensaje(String texto, {bool error = false, SnackBarAction? accion, Duration? duracion}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? kMantError : null,
        behavior: SnackBarBehavior.floating,
        action: accion,
        duration: duracion ?? const Duration(seconds: 4),
      ),
    );
  }

  // ── Registrar ───────────────────────────────────────────────────────

  Future<void> _elegirMetodo(List<MantencionModel> historial, double? kmActual) async {
    final metodo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kMantTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined, color: kMantPrimario),
              title: const Text('Registro manual', style: TextStyle(color: kMantTexto)),
              subtitle: const Text('Completa los datos tú mismo', style: TextStyle(color: kMantTextoSuave)),
              onTap: () => Navigator.pop(sheetContext, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: kMantIA),
              title: const Text('Escanear boleta o factura con IA', style: TextStyle(color: kMantTexto)),
              subtitle: const Text('Fotografiar → revisar → guardar', style: TextStyle(color: kMantTextoSuave)),
              onTap: () => Navigator.pop(sheetContext, 'ia'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (metodo == null || !mounted) return;

    if (metodo == 'manual') {
      await _abrirFormulario(historial: historial, kmActual: kmActual);
    } else {
      await _registrarConIa(historial: historial, kmActual: kmActual);
    }
  }

  Future<void> _registrarConIa({required List<MantencionModel> historial, double? kmActual}) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty || !mounted) return;

    final archivo = resultado.files.first;
    final bytes = archivo.bytes;
    if (bytes == null) {
      _mensaje('No se pudo leer el archivo.', error: true);
      return;
    }
    if (bytes.length > _tamanoMaximoIa) {
      _mensaje('El archivo pesa más de 8 MB. Elige uno más liviano.', error: true);
      return;
    }

    final adjunto = ArchivoAdjunto(bytes: bytes, nombre: archivo.name, mime: mimeDeArchivo(archivo.name));
    setState(() => _procesandoIa = true);

    MantencionExtraidaIa? leida;
    try {
      leida = await MantencionIaService().extraerBoleta(fileBytes: bytes, mimeType: adjunto.mime);
    } on LecturaBoletaException catch (e) {
      // E2: no se pudo leer. El archivo igual queda adjunto y el formulario se
      // abre vacío para completarlo a mano.
      if (mounted) _mensaje('${e.mensaje} Completa los datos manualmente.');
    } catch (_) {
      if (mounted) _mensaje('No pude leer el comprobante. Completa los datos manualmente.');
    }

    if (!mounted) return;
    setState(() => _procesandoIa = false);
    await _abrirFormulario(historial: historial, kmActual: kmActual, ia: leida, archivo: adjunto);
  }

  Future<void> _abrirFormulario({
    required List<MantencionModel> historial,
    double? kmActual,
    MantencionModel? existente,
    MantencionExtraidaIa? ia,
    ArchivoAdjunto? archivo,
    MantencionProgramadaModel? programada,
  }) async {
    final resultado = await Navigator.push<ResultadoGuardadoMantencion>(
      context,
      MaterialPageRoute(
        builder: (_) => MantencionFormScreen(
          vehiculoId: widget.vehiculoId,
          patente: widget.patente,
          kmActualVehiculo: kmActual,
          historial: historial,
          existente: existente,
          ia: ia,
          archivo: archivo,
          tipoInicial: programada?.tipo,
        ),
      ),
    );
    if (resultado == null || !mounted) return;

    // Si se registró una mantención que estaba programada, esa programación
    // queda cumplida.
    if (programada != null) {
      try {
        await _service.marcarProgramadaCompletada(programada);
      } catch (_) {
        // La mantención ya quedó guardada; la programación se puede cerrar a mano.
      }
    }
    if (!mounted) return;

    final guardada = resultado.mantencion;
    final partes = <String>[existente != null ? 'Mantención actualizada' : 'Mantención guardada'];
    if (resultado.odometroActualizado && guardada.kilometraje != null) {
      partes.add('odómetro actualizado a ${formatoKm(guardada.kilometraje!)}');
    }
    if (resultado.fallaAdjunto) {
      partes.add('no se pudo adjuntar la boleta');
    }

    // Después de un servicio nuevo se ofrece programar el siguiente.
    final ofrecerProgramar = existente == null && programada == null;
    _mensaje(
      partes.join(' · '),
      error: resultado.fallaAdjunto,
      duracion: const Duration(seconds: 8),
      accion: ofrecerProgramar
          ? SnackBarAction(
              label: 'Programar próxima',
              onPressed: () => _programar(
                kmActual: guardada.kilometraje ?? kmActual,
                tipoInicial: guardada.tipo,
                sugerirDesde: guardada,
              ),
            )
          : null,
    );
  }

  // ── Programar próxima mantención ────────────────────────────────────

  Future<void> _programar({
    double? kmActual,
    MantencionProgramadaModel? existente,
    String? tipoInicial,
    MantencionModel? sugerirDesde,
  }) async {
    DateTime? fecha;
    double? km;
    if (sugerirDesde != null) {
      final s = sugerirProximaMantencion(
        sugerirDesde.tipo,
        fechaBase: sugerirDesde.fecha,
        kmBase: sugerirDesde.kilometraje,
      );
      fecha = s.fecha;
      km = s.km;
      // Si la fecha sugerida ya pasó (se registró un servicio antiguo), no sirve.
      if (fecha.isBefore(DateTime.now())) fecha = null;
    }

    final guardada = await mostrarProgramarMantencion(
      context,
      vehiculoId: widget.vehiculoId,
      patente: widget.patente,
      kmActual: kmActual,
      existente: existente,
      tipoInicial: tipoInicial,
      fechaInicial: fecha,
      kmInicial: km,
    );
    if (guardada != null && mounted) _mensaje('Próxima mantención programada');
  }

  Future<void> _eliminarProgramada(MantencionProgramadaModel p) async {
    final confirmado = await _confirmar(
      titulo: 'Eliminar programación',
      mensaje: 'Se eliminará "${p.titulo}" y sus recordatorios. Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;
    try {
      await _service.eliminarProgramada(p.id);
    } catch (_) {
      if (mounted) _mensaje('No se pudo eliminar. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  // ── Detalle, modificar y eliminar (CU17) ────────────────────────────

  Future<bool?> _confirmar({required String titulo, required String mensaje}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kMantTarjeta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo, style: const TextStyle(color: kMantTexto)),
        content: Text(mensaje, style: const TextStyle(color: kMantTextoSuave)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: kMantTextoSuave)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: kMantError)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminar(MantencionModel m) async {
    final confirmado = await _confirmar(
      titulo: 'Eliminar mantención',
      mensaje: 'Se eliminará "${m.titulo}" del ${formatoFechaCorta(m.fecha)}'
          '${m.tieneDocumento ? ' junto con su boleta adjunta' : ''}. Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;
    try {
      await _service.eliminar(m);
      if (mounted) _mensaje('Mantención eliminada');
    } catch (_) {
      // El registro sigue intacto: la lista no cambia si falla.
      if (mounted) _mensaje('No se pudo eliminar. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  Future<void> _verDocumento(MantencionModel m) async {
    final ruta = m.documentoPath;
    if (ruta == null) return;
    try {
      final bytes = await _service.descargarDocumento(ruta);
      if (!mounted) return;
      final nombre = m.documentoNombre ?? 'boleta';
      if (nombre.toLowerCase().endsWith('.pdf')) {
        await saveFileBytes(bytes: bytes, fileName: nombre);
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            backgroundColor: kMantFondo,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) _mensaje('No se pudo abrir la boleta. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  void _mostrarDetalle(MantencionModel m, List<MantencionModel> historial, double? kmActual) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kMantTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        final color = colorTipoMantencion(m.tipo);
        Widget fila(String etiqueta, String valor) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(etiqueta, style: const TextStyle(color: kMantTextoSuave))),
                  Expanded(child: Text(valor, style: const TextStyle(color: kMantTexto))),
                ],
              ),
            );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(iconoTipoMantencion(m.tipo), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.titulo, style: const TextStyle(color: kMantTexto, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(etiquetaTipoMantencion(m.tipo), style: TextStyle(color: color, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (m.origen == 'ia') const Icon(Icons.auto_awesome, color: kMantIA, size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                fila('Fecha', formatoFechaCorta(m.fecha)),
                fila('Costo', formatoPesos(m.costo)),
                if (m.kilometraje != null) fila('Kilometraje', formatoKm(m.kilometraje!)),
                if (m.taller != null) fila('Taller', m.taller!),
                if (m.servicios.isNotEmpty) fila('Servicios', m.servicios.join('\n')),
                if (m.repuestos.isNotEmpty) fila('Repuestos', m.repuestos.join('\n')),
                if (m.descripcion != null) fila('Descripción', m.descripcion!),
                if (m.observaciones != null) fila('Observaciones', m.observaciones!),
                if (m.tieneDocumento) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kMantPrimario,
                      side: const BorderSide(color: kMantPrimario),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _verDocumento(m),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(m.documentoNombre ?? 'Ver boleta adjunta', overflow: TextOverflow.ellipsis),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMantTexto,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _abrirFormulario(historial: historial, kmActual: kmActual, existente: m);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modificar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMantError,
                          side: BorderSide(color: kMantError.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _eliminar(m);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Interfaz ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _vehiculoStream,
      builder: (context, vehiculoSnap) {
        final kmActual = vehiculoSnap.data?.isNotEmpty == true
            ? (vehiculoSnap.data!.first['kilometraje'] as num?)?.toDouble()
            : null;

        return StreamBuilder<List<MantencionModel>>(
          stream: _historialStream,
          builder: (context, historialSnap) {
            final historial = historialSnap.data ?? const <MantencionModel>[];

            return Scaffold(
              backgroundColor: kMantFondo,
              appBar: AppBar(
                backgroundColor: kMantFondo,
                elevation: 0,
                title: Text('Mantenciones · ${widget.patente}', style: const TextStyle(color: Colors.white)),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              floatingActionButton: FloatingActionButton.extended(
                heroTag: 'fabRegistrarMantencion',
                backgroundColor: kMantPrimario,
                onPressed: _procesandoIa || !historialSnap.hasData ? null : () => _elegirMetodo(historial, kmActual),
                icon: _procesandoIa
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add, color: Colors.white),
                label: Text(
                  _procesandoIa ? 'Analizando comprobante…' : 'Registrar mantención',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              body: _construirCuerpo(historialSnap, historial, kmActual),
            );
          },
        );
      },
    );
  }

  Widget _construirCuerpo(
    AsyncSnapshot<List<MantencionModel>> snap,
    List<MantencionModel> historial,
    double? kmActual,
  ) {
    if (snap.hasError) {
      // E2 del CU8: falla de red al obtener los datos.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: kMantTextoSuave, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar las mantenciones. Revisa tu conexión e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMantTexto),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(_crearStreams),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<MantencionProgramadaModel>>(
      stream: _programadasStream,
      builder: (context, progSnap) {
        final pendientes = (progSnap.data ?? const <MantencionProgramadaModel>[]).where((p) => !p.completada).toList();
        // Las más urgentes primero: vencidas, luego próximas, luego al día.
        final evaluadas = [
          for (final p in pendientes) (p, evaluarProgramada(p, kmActual: kmActual)),
        ]..sort((a, b) {
            final porEstado = b.$2.estado.index.compareTo(a.$2.estado.index);
            if (porEstado != 0) return porEstado;
            final fa = a.$1.fechaProgramada;
            final fb = b.$1.fechaProgramada;
            if (fa != null && fb != null) return fa.compareTo(fb);
            return fa != null ? -1 : (fb != null ? 1 : 0);
          });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _buildResumen(historial),
            const SizedBox(height: 24),
            _tituloSeccion('Próxima mantención'),
            if (evaluadas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('No tienes mantenciones programadas.', style: TextStyle(color: kMantTextoSuave)),
              )
            else
              for (final (p, e) in evaluadas) _buildProgramada(p, e, historial, kmActual),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kMantPrimario,
                side: const BorderSide(color: kMantPrimario),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _programar(kmActual: kmActual),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Programar próxima mantención'),
            ),
            const SizedBox(height: 24),
            _tituloSeccion('Historial'),
            if (historial.isEmpty)
              _buildVacio(historial, kmActual)
            else
              for (var i = 0; i < historial.length; i++)
                _buildItemLineaTiempo(historial[i], historial, kmActual, esUltimo: i == historial.length - 1),
          ],
        );
      },
    );
  }

  Widget _tituloSeccion(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texto, style: const TextStyle(color: kMantTextoSuave, fontSize: 13)),
      );

  Widget _buildResumen(List<MantencionModel> historial) {
    Widget tarjeta(String titulo, String valor, IconData icono, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kMantTarjeta,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMantTextoSuave, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMantTexto, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );

    final ultima = historial.isEmpty ? null : historial.first;
    return Row(
      children: [
        tarjeta('Gasto total', formatoPesos(costoTotalMantenciones(historial)), Icons.payments_outlined, kMantOk),
        const SizedBox(width: 12),
        tarjeta('Última mantención', ultima != null ? formatoFechaCorta(ultima.fecha) : '—', Icons.history, kMantPrimario),
      ],
    );
  }

  Widget _buildProgramada(
    MantencionProgramadaModel p,
    EvaluacionProgramada e,
    List<MantencionModel> historial,
    double? kmActual,
  ) {
    final color = colorEstadoProgramada(e.estado);
    final criterios = descripcionCriterios(p, e);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(iconoTipoMantencion(p.tipo), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMantTexto, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(etiquetaEstadoProgramada(e.estado),
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final linea in criterios)
                  Text(linea, style: const TextStyle(color: kMantTextoSuave, fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: kMantTarjeta,
            icon: const Icon(Icons.more_vert, color: kMantTextoSuave),
            onSelected: (valor) {
              switch (valor) {
                case 'realizada':
                  _abrirFormulario(historial: historial, kmActual: kmActual, programada: p);
                case 'editar':
                  _programar(kmActual: kmActual, existente: p);
                case 'eliminar':
                  _eliminarProgramada(p);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'realizada', child: Text('Registrar como realizada', style: TextStyle(color: kMantTexto))),
              PopupMenuItem(value: 'editar', child: Text('Modificar', style: TextStyle(color: kMantTexto))),
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: kMantError))),
            ],
          ),
        ],
      ),
    );
  }

  /// E1 del CU8: la bitácora está vacía.
  Widget _buildVacio(List<MantencionModel> historial, double? kmActual) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.build_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          const Text('No existen servicios registrados en la bitácora',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Registra la primera mantención para empezar tu historial.',
              textAlign: TextAlign.center, style: TextStyle(color: kMantTextoSuave)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMantPrimario,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _elegirMetodo(historial, kmActual),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Registrar mantención', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Un servicio de la línea de tiempo: punto y línea a la izquierda, tarjeta a la derecha.
  Widget _buildItemLineaTiempo(
    MantencionModel m,
    List<MantencionModel> historial,
    double? kmActual, {
    required bool esUltimo,
  }) {
    final color = colorTipoMantencion(m.tipo);
    final detalles = [
      if (m.taller != null) m.taller!,
      if (m.kilometraje != null) formatoKm(m.kilometraje!),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!esUltimo)
                  Expanded(child: Container(width: 2, color: Colors.white.withValues(alpha: 0.1))),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: kMantTarjeta,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _mostrarDetalle(m, historial, kmActual),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(formatoFechaCorta(m.fecha), style: const TextStyle(color: kMantTextoSuave, fontSize: 12)),
                            const Spacer(),
                            if (m.tieneDocumento)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.attach_file, size: 16, color: kMantTextoSuave),
                              ),
                            if (m.origen == 'ia')
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.auto_awesome, size: 14, color: kMantIA),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(etiquetaTipoMantencion(m.tipo),
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(m.titulo, style: const TextStyle(color: kMantTexto, fontSize: 15, fontWeight: FontWeight.bold)),
                        if (m.servicios.length > 1 || m.repuestos.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              [...m.servicios.skip(1), ...m.repuestos].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kMantTextoSuave, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(detalles, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: kMantTextoSuave, fontSize: 12)),
                            ),
                            Text(formatoPesos(m.costo),
                                style: const TextStyle(color: kMantTexto, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
