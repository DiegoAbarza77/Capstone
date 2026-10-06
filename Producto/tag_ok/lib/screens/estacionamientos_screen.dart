import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/models/estacionamiento_model.dart';
import '../data/services/estacionamiento_ia_service.dart';
import '../data/services/estacionamiento_service.dart';
import '../data/services/lectura_boleta_exception.dart';
import '../data/services/ubicacion_service.dart';
import '../utils/estacionamiento_calculos.dart';
import '../utils/file_saver.dart';
import '../utils/numero_chile.dart';
import 'estacionamiento_form_screen.dart';
import 'mantencion_form_screen.dart' show ArchivoAdjunto, mimeDeArchivo;
import 'mantencion_ui.dart';
import 'mapa_ubicacion.dart';

const Color _kCronometro = Color(0xFF38BDF8);

/// Módulo Estacionamientos: cronómetro con ubicación GPS (CU11), registro manual
/// o con IA desde un ticket (CU10) e historial con el gasto del mes (CU12).
class EstacionamientosScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  const EstacionamientosScreen({super.key, required this.vehiculoId, required this.patente});

  @override
  State<EstacionamientosScreen> createState() => _EstacionamientosScreenState();
}

class _EstacionamientosScreenState extends State<EstacionamientosScreen> {
  static const _tamanoMaximoIa = 8 * 1024 * 1024;

  final EstacionamientoService _service = EstacionamientoService();

  late Stream<List<EstacionamientoModel>> _stream;

  /// Reloj que se actualiza cada segundo; solo se redibuja el texto del
  /// cronómetro, no la pantalla entera.
  final ValueNotifier<DateTime> _ahora = ValueNotifier(DateTime.now());
  Timer? _reloj;

  late DateTime _mes;
  bool _iniciando = false;
  bool _procesandoIa = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = DateTime(hoy.year, hoy.month);
    _stream = _service.streamPorVehiculo(widget.vehiculoId);
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _ahora.value = DateTime.now());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _ahora.dispose();
    super.dispose();
  }

  void _mensaje(String texto, {bool error = false, Duration? duracion}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? kMantError : null,
        behavior: SnackBarBehavior.floating,
        duration: duracion ?? const Duration(seconds: 4),
      ),
    );
  }

  // ── Cronómetro ──────────────────────────────────────────────────────

  Future<void> _iniciar() async {
    if (_iniciando) return;
    setState(() => _iniciando = true);

    // La ubicación es opcional (E2): si no hay permiso o el GPS está apagado, el
    // cronómetro corre igual, solo que sin coordenadas.
    final ubicacion = await UbicacionService().obtenerActual();
    try {
      await _service.iniciar(
        vehiculoId: widget.vehiculoId,
        lat: ubicacion.lat,
        lng: ubicacion.lng,
      );
      if (mounted) {
        _mensaje(
          ubicacion.obtenida
              ? 'Estacionamiento iniciado. Guardé la ubicación de tu auto.'
              : 'Estacionamiento iniciado sin ubicación. ${ubicacion.motivo ?? ''}'.trim(),
          duracion: const Duration(seconds: 6),
        );
      }
    } on EstacionamientoEnCursoException catch (e) {
      // E1: ya hay una sesión corriendo.
      if (mounted) _mensaje(e.toString(), error: true);
    } catch (e) {
      debugPrint('TAG_OK_ESTACIONAMIENTOS: error al iniciar: $e');
      if (mounted) _mensaje('No se pudo iniciar. Revisa tu conexión e intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _finalizar(EstacionamientoModel enCurso) async {
    // La hora de salida es cuando el usuario pulsa "Finalizar", no cuando termina
    // de llenar el formulario.
    final salida = DateTime.now();
    final guardado = await showDialog<EstacionamientoModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FinalizarDialog(enCurso: enCurso, salida: salida, service: _service),
    );
    if (guardado != null && mounted) {
      _mensaje('Estacionamiento guardado · ${formatoDuracion(guardado.duracion() ?? Duration.zero)} · ${formatoPesos(guardado.costo)}');
    }
  }

  Future<void> _descartar(EstacionamientoModel enCurso) async {
    final confirmado = await _confirmar(
      titulo: 'Descartar estacionamiento',
      mensaje: 'Se cancelará el cronómetro y no se guardará este estacionamiento. Esta acción no se puede deshacer.',
      textoAccion: 'Descartar',
    );
    if (confirmado != true || !mounted) return;
    try {
      await _service.cancelarEnCurso(enCurso.id);
    } catch (_) {
      if (mounted) _mensaje('No se pudo descartar. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  // ── Registrar ───────────────────────────────────────────────────────

  Future<void> _elegirMetodo() async {
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
              title: const Text('Escanear ticket o boleta con IA', style: TextStyle(color: kMantTexto)),
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
      await _abrirFormulario();
    } else {
      await _registrarConIa();
    }
  }

  Future<void> _registrarConIa() async {
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

    EstacionamientoExtraidoIa? leido;
    try {
      leido = await EstacionamientoIaService().extraerTicket(fileBytes: bytes, mimeType: adjunto.mime);
    } on LecturaBoletaException catch (e) {
      // E1: no se pudo leer. El archivo igual queda adjunto y el formulario se
      // abre vacío para completarlo a mano.
      if (mounted) _mensaje('${e.mensaje} Completa los datos manualmente.');
    } catch (_) {
      if (mounted) _mensaje('No pude leer el comprobante. Completa los datos manualmente.');
    }

    if (!mounted) return;
    setState(() => _procesandoIa = false);
    await _abrirFormulario(ia: leido, archivo: adjunto);
  }

  Future<void> _abrirFormulario({
    EstacionamientoModel? existente,
    EstacionamientoExtraidoIa? ia,
    ArchivoAdjunto? archivo,
  }) async {
    final resultado = await Navigator.push<ResultadoGuardadoEstacionamiento>(
      context,
      MaterialPageRoute(
        builder: (_) => EstacionamientoFormScreen(
          vehiculoId: widget.vehiculoId,
          patente: widget.patente,
          existente: existente,
          ia: ia,
          archivo: archivo,
        ),
      ),
    );
    if (resultado == null || !mounted) return;

    _mensaje(
      [
        existente != null ? 'Estacionamiento actualizado' : 'Estacionamiento guardado',
        if (resultado.fallaAdjunto) 'no se pudo adjuntar el comprobante',
      ].join(' · '),
      error: resultado.fallaAdjunto,
    );
  }

  // ── Detalle, modificar y eliminar ───────────────────────────────────

  Future<bool?> _confirmar({required String titulo, required String mensaje, String textoAccion = 'Eliminar'}) {
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
            child: Text(textoAccion, style: const TextStyle(color: kMantError)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminar(EstacionamientoModel e) async {
    final confirmado = await _confirmar(
      titulo: 'Eliminar estacionamiento',
      mensaje: 'Se eliminará "${e.titulo}" del ${formatoFechaCorta(e.fecha)}'
          '${e.tieneDocumento ? ' junto con su comprobante adjunto' : ''}. Esta acción no se puede deshacer.',
    );
    if (confirmado != true || !mounted) return;
    try {
      await _service.eliminar(e);
      if (mounted) _mensaje('Estacionamiento eliminado');
    } catch (_) {
      // El registro sigue intacto: la lista no cambia si falla.
      if (mounted) _mensaje('No se pudo eliminar. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  Future<void> _verDocumento(EstacionamientoModel e) async {
    final ruta = e.documentoPath;
    if (ruta == null) return;
    try {
      final bytes = await _service.descargarDocumento(ruta);
      if (!mounted) return;
      final nombre = e.documentoNombre ?? 'comprobante';
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
      if (mounted) _mensaje('No se pudo abrir el comprobante. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  void _mostrarDetalle(EstacionamientoModel e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kMantTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
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

        final duracion = e.duracion();
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
                      decoration: BoxDecoration(color: _kCronometro.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.local_parking_outlined, color: _kCronometro),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.titulo, style: const TextStyle(color: kMantTexto, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (e.origen == 'ia') const Icon(Icons.auto_awesome, color: kMantIA, size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                fila('Fecha', formatoFechaCorta(e.fecha)),
                if (e.horaEntrada != null) fila('Entrada', formatoHora(e.horaEntrada!)),
                if (e.horaSalida != null) fila('Salida', formatoHora(e.horaSalida!)),
                if (duracion != null) fila('Duración', formatoDuracion(duracion)),
                fila('Costo', formatoPesos(e.costo)),
                if (e.direccion != null) fila('Dirección', e.direccion!),
                if (e.observaciones != null) fila('Observaciones', e.observaciones!),
                if (e.tieneUbicacion) ...[
                  const SizedBox(height: 12),
                  MapaUbicacion(lat: e.lat!, lng: e.lng!, altura: 160),
                ],
                if (e.tieneDocumento) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kMantPrimario,
                      side: const BorderSide(color: kMantPrimario),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _verDocumento(e),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(e.documentoNombre ?? 'Ver comprobante adjunto', overflow: TextOverflow.ellipsis),
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
                          _abrirFormulario(existente: e);
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
                          _eliminar(e);
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
    return Scaffold(
      backgroundColor: kMantFondo,
      appBar: AppBar(
        backgroundColor: kMantFondo,
        elevation: 0,
        title: Text('Estacionamientos · ${widget.patente}', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fabRegistrarEstacionamiento',
        backgroundColor: kMantPrimario,
        onPressed: _procesandoIa ? null : _elegirMetodo,
        icon: _procesandoIa
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add, color: Colors.white),
        label: Text(
          _procesandoIa ? 'Analizando comprobante…' : 'Registrar estacionamiento',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<EstacionamientoModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return _buildError();
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final todos = snap.data!;
          final enCurso = estacionamientoEnCurso(todos);
          final delMes = estacionamientosDelMes(todos, _mes)..sort((a, b) => b.momento.compareTo(a.momento));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (enCurso != null) _buildEnCurso(enCurso) else _buildIniciar(),
              if (enCurso != null && enCurso.tieneUbicacion) ...[
                const SizedBox(height: 16),
                const Text('Tu auto está aquí', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
                const SizedBox(height: 8),
                MapaUbicacion(lat: enCurso.lat!, lng: enCurso.lng!),
              ],
              const SizedBox(height: 24),
              _buildResumen(delMes),
              const SizedBox(height: 24),
              const Text('Historial', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
              const SizedBox(height: 10),
              if (delMes.isEmpty) _buildVacio() else for (final e in delMes) _buildItem(e),
            ],
          );
        },
      ),
    );
  }

  /// E2 del CU12: falla de red al obtener los datos.
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: kMantTextoSuave, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los estacionamientos. Revisa tu conexión e intenta de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMantTexto),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _stream = _service.streamPorVehiculo(widget.vehiculoId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIniciar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Acabas de estacionar?', style: TextStyle(color: kMantTexto, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Inicia el cronómetro y guardaré dónde quedó tu auto.',
            style: TextStyle(color: kMantTextoSuave, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCronometro,
                foregroundColor: kMantFondo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _iniciando ? null : _iniciar,
              icon: _iniciando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kMantFondo))
                  : const Icon(Icons.timer_outlined),
              label: Text(
                _iniciando ? 'Obteniendo ubicación…' : 'Iniciar estacionamiento',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cronómetro: se calcula siempre "ahora menos la hora de inicio guardada", así
  /// sigue correcto aunque la app se haya cerrado (E3 del CU11).
  Widget _buildEnCurso(EstacionamientoModel e) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCronometro.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCronometro.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: _kCronometro, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Estacionamiento en curso', style: TextStyle(color: _kCronometro, fontWeight: FontWeight.bold)),
              ),
              PopupMenuButton<String>(
                color: kMantTarjeta,
                icon: const Icon(Icons.more_vert, color: kMantTextoSuave),
                onSelected: (_) => _descartar(e),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'descartar', child: Text('Descartar', style: TextStyle(color: kMantError))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: ValueListenableBuilder<DateTime>(
              valueListenable: _ahora,
              builder: (context, ahora, _) => Text(
                formatoCronometro(e.duracion(ahora: ahora) ?? Duration.zero),
                style: const TextStyle(
                  color: kMantTexto,
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Desde las ${e.horaEntrada != null ? formatoHora(e.horaEntrada!) : '--:--'}'
              '${e.tieneUbicacion ? ' · ubicación guardada' : ' · sin ubicación'}',
              style: const TextStyle(color: kMantTextoSuave, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMantPrimario,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _finalizar(e),
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
              label: const Text(
                'Finalizar estacionamiento',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen(List<EstacionamientoModel> delMes) {
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

    final hoy = DateTime.now();
    final esMesActual = _mes.year == hoy.year && _mes.month == hoy.month;
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month - 1)),
              icon: const Icon(Icons.chevron_left, color: kMantTexto),
            ),
            Text('${meses[_mes.month - 1]} ${_mes.year}',
                style: const TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: esMesActual ? null : () => setState(() => _mes = DateTime(_mes.year, _mes.month + 1)),
              icon: Icon(Icons.chevron_right, color: esMesActual ? kMantTextoSuave.withValues(alpha: 0.3) : kMantTexto),
            ),
          ],
        ),
        Row(
          children: [
            tarjeta('Gasto del mes', formatoPesos(gastoEstacionamientos(delMes)), Icons.payments_outlined, kMantOk),
            const SizedBox(width: 12),
            tarjeta('Tiempo estacionado', formatoDuracion(tiempoTotalEstacionado(delMes)), Icons.timer_outlined, _kCronometro),
          ],
        ),
      ],
    );
  }

  /// E1 del CU12: no hay registros en el mes.
  Widget _buildVacio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.local_parking_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          const Text('No hay estacionamientos registrados este mes',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMantPrimario,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _elegirMetodo,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Agregar estacionamiento', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(EstacionamientoModel e) {
    final duracion = e.duracion();
    final horas = e.horaEntrada != null
        ? ' · ${formatoHora(e.horaEntrada!)}${e.horaSalida != null ? '–${formatoHora(e.horaSalida!)}' : ''}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalle(e),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _kCronometro.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.local_parking_outlined, color: _kCronometro, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMantTexto, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatoFechaCorta(e.fecha)}$horas${duracion != null ? ' · ${formatoDuracion(duracion)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMantTextoSuave, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (e.tieneUbicacion)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.location_on_outlined, size: 16, color: kMantTextoSuave),
                  ),
                if (e.tieneDocumento)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.attach_file, size: 16, color: kMantTextoSuave),
                  ),
                if (e.origen == 'ia')
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.auto_awesome, size: 14, color: kMantIA),
                  ),
                Text(formatoPesos(e.costo), style: const TextStyle(color: kMantTexto, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo que aparece al finalizar el cronómetro: muestra la duración ya
/// calculada y pide el costo cobrado. Si el guardado falla, no se cierra y los
/// datos siguen ahí para reintentar (E4 del CU10).
class _FinalizarDialog extends StatefulWidget {
  final EstacionamientoModel enCurso;
  final DateTime salida;
  final EstacionamientoService service;

  const _FinalizarDialog({required this.enCurso, required this.salida, required this.service});

  @override
  State<_FinalizarDialog> createState() => _FinalizarDialogState();
}

class _FinalizarDialogState extends State<_FinalizarDialog> {
  final TextEditingController _costoCtrl = TextEditingController();
  final TextEditingController _lugarCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();
  bool _guardando = false;
  String? _errorCosto;
  String? _errorGuardado;

  Duration get _duracion => widget.salida.difference(widget.enCurso.horaEntrada ?? widget.salida);

  @override
  void dispose() {
    _costoCtrl.dispose();
    _lugarCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final texto = _costoCtrl.text.trim();
    final costo = parseNumeroChile(texto, puntoEsMiles: true);
    if (texto.isEmpty || costo == null || costo < 0) {
      setState(() => _errorCosto = 'Ingresa el costo cobrado (0 si fue gratis).');
      return;
    }

    setState(() {
      _guardando = true;
      _errorCosto = null;
      _errorGuardado = null;
    });
    try {
      final guardado = await widget.service.finalizar(
        widget.enCurso,
        horaSalida: widget.salida,
        costo: costo,
        lugar: _lugarCtrl.text,
        observaciones: _observacionesCtrl.text,
      );
      if (mounted) Navigator.pop(context, guardado);
    } catch (e) {
      debugPrint('TAG_OK_ESTACIONAMIENTOS: error al finalizar: $e');
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorGuardado = 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kMantTarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Finalizar estacionamiento',
          style: TextStyle(color: kMantTexto, fontWeight: FontWeight.bold, fontSize: 18)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCronometro.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: _kCronometro),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Estuviste estacionado ${formatoDuracion(_duracion)}',
                        style: const TextStyle(color: kMantTexto, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _costoCtrl,
                autofocus: true,
                style: const TextStyle(color: kMantTexto),
                keyboardType: TextInputType.number,
                inputFormatters: [MilesInputFormatter()],
                onChanged: (_) => setState(() => _errorCosto = null),
                decoration: decoracionMantencion('Costo cobrado (\$) *', icono: Icons.attach_money, error: _errorCosto),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lugarCtrl,
                style: const TextStyle(color: kMantTexto),
                textCapitalization: TextCapitalization.words,
                decoration: decoracionMantencion('Lugar (opcional)', icono: Icons.local_parking_outlined),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _observacionesCtrl,
                style: const TextStyle(color: kMantTexto),
                textCapitalization: TextCapitalization.sentences,
                decoration: decoracionMantencion('Observaciones (opcional)', icono: Icons.comment_outlined),
              ),
              if (_errorGuardado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errorGuardado!, style: const TextStyle(color: kMantError, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        // Cancelar solo cierra el formulario: el cronómetro sigue corriendo y la
        // hora de salida se tomará de nuevo la próxima vez que se pulse "Finalizar".
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: kMantTextoSuave)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kMantPrimario,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_errorGuardado != null ? 'Reintentar' : 'Guardar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
