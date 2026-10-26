import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/carga_combustible_model.dart';
import '../data/services/combustible_ia_service.dart';
import '../data/services/combustible_service.dart';
import '../utils/combustible_metricas.dart';
import '../utils/file_saver.dart';
import '../utils/numero_chile.dart';
import 'combustible_form_screen.dart';
import 'mantencion_form_screen.dart' show ArchivoAdjunto, mimeDeArchivo;
import 'mantencion_ui.dart';

const Color _kCombustible = Color(0xFF10B981);

/// Módulo Combustible y carga: registro manual o con IA desde una boleta (CU13),
/// historial por mes con el gasto y el rendimiento (CU14), y modificar o eliminar
/// cargas (CU17). Sirve también para vehículos híbridos y eléctricos (kWh).
class CombustibleScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  const CombustibleScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
  });

  @override
  State<CombustibleScreen> createState() => _CombustibleScreenState();
}

class _CombustibleScreenState extends State<CombustibleScreen> {
  static const _tamanoMaximoIa = 8 * 1024 * 1024;

  final CombustibleService _service = CombustibleService();

  late Stream<List<CargaCombustibleModel>> _cargasStream;
  late Stream<List<Map<String, dynamic>>> _vehiculoStream;
  late DateTime _mes;
  bool _procesandoIa = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = DateTime(hoy.year, hoy.month);
    _crearStreams();
  }

  /// Los streams se crean una sola vez (y de nuevo al "Reintentar"): si se armaran
  /// dentro de build() cada redibujado volvería a suscribirse.
  void _crearStreams() {
    _cargasStream = _service.streamPorVehiculo(widget.vehiculoId);
    _vehiculoStream = Supabase.instance.client
        .from('vehiculos')
        .stream(primaryKey: ['id']).eq('id', widget.vehiculoId);
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

  // ── Registrar ───────────────────────────────────────────────────────

  Future<void> _elegirMetodo({String? combustible, double? kmActual}) async {
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
              subtitle: const Text('Completa los datos que tengas a mano', style: TextStyle(color: kMantTextoSuave)),
              onTap: () => Navigator.pop(sheetContext, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: kMantIA),
              title: const Text('Escanear boleta con IA', style: TextStyle(color: kMantTexto)),
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
      await _abrirFormulario(combustible: combustible, kmActual: kmActual);
    } else {
      await _registrarConIa(combustible: combustible, kmActual: kmActual);
    }
  }

  Future<void> _registrarConIa({String? combustible, double? kmActual}) async {
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

    CargaExtraidaIa? leida;
    try {
      leida = await CombustibleIaService().extraerBoleta(fileBytes: bytes, mimeType: adjunto.mime);
    } on LecturaBoletaException catch (e) {
      // E1: no se pudo leer. La boleta igual queda adjunta y el formulario se abre
      // vacío para completarlo a mano.
      if (mounted) _mensaje('${e.mensaje} Completa los datos manualmente.');
    } catch (_) {
      if (mounted) _mensaje('No pude leer la boleta. Completa los datos manualmente.');
    }

    if (!mounted) return;
    setState(() => _procesandoIa = false);
    await _abrirFormulario(combustible: combustible, kmActual: kmActual, ia: leida, archivo: adjunto);
  }

  Future<void> _abrirFormulario({
    String? combustible,
    double? kmActual,
    CargaCombustibleModel? existente,
    CargaExtraidaIa? ia,
    ArchivoAdjunto? archivo,
  }) async {
    final resultado = await Navigator.push<ResultadoGuardadoCarga>(
      context,
      MaterialPageRoute(
        builder: (_) => CombustibleFormScreen(
          vehiculoId: widget.vehiculoId,
          patente: widget.patente,
          combustibleDelVehiculo: combustible,
          kmActualVehiculo: kmActual,
          existente: existente,
          ia: ia,
          archivo: archivo,
        ),
      ),
    );
    if (resultado == null || !mounted) return;

    final guardada = resultado.carga;
    final partes = <String>[existente != null ? 'Carga actualizada' : 'Carga guardada'];
    if (resultado.odometroActualizado && guardada.kilometraje != null) {
      partes.add('odómetro actualizado a ${formatoKm(guardada.kilometraje!)}');
    }
    if (resultado.fallaAdjunto) partes.add('no se pudo adjuntar la boleta');
    _mensaje(partes.join(' · '), error: resultado.fallaAdjunto, duracion: const Duration(seconds: 6));

    // Si la carga guardada es de otro mes, se muestra ese mes para que el usuario
    // la vea de inmediato.
    final mesCarga = DateTime(guardada.fecha.year, guardada.fecha.month);
    if (mesCarga != _mes) setState(() => _mes = mesCarga);
  }

  // ── Detalle, modificar y eliminar (CU17) ────────────────────────────

  Future<bool?> _confirmarEliminar(CargaCombustibleModel c) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kMantTarjeta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar carga', style: TextStyle(color: kMantTexto)),
        content: Text(
          'Se eliminará la carga del ${formatoFechaCorta(c.fecha)} (${formatoPesos(c.total)})'
          '${c.tieneDocumento ? ' junto con su boleta adjunta' : ''}. Esta acción no se puede deshacer.',
          style: const TextStyle(color: kMantTextoSuave),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: kMantTextoSuave)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar eliminación', style: TextStyle(color: kMantError)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminar(CargaCombustibleModel c) async {
    final confirmado = await _confirmarEliminar(c);
    if (confirmado != true || !mounted) return;
    try {
      await _service.eliminar(c);
      if (mounted) _mensaje('Carga eliminada');
    } catch (_) {
      // El registro sigue intacto: la lista no cambia si falla.
      if (mounted) _mensaje('No se pudo eliminar. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  Future<void> _verDocumento(CargaCombustibleModel c) async {
    final ruta = c.documentoPath;
    if (ruta == null) return;
    try {
      final bytes = await _service.descargarDocumento(ruta);
      if (!mounted) return;
      final nombre = c.documentoNombre ?? 'boleta';
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

  void _mostrarDetalle(CargaCombustibleModel c, {String? combustible, double? kmActual}) {
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
                  SizedBox(width: 120, child: Text(etiqueta, style: const TextStyle(color: kMantTextoSuave))),
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
                      decoration: BoxDecoration(color: _kCombustible.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(
                        c.unidad == 'kwh' ? Icons.bolt_outlined : Icons.local_gas_station_outlined,
                        color: _kCombustible,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.estacion.isNotEmpty ? c.estacion : (c.tipoCombustible ?? 'Carga'),
                        style: const TextStyle(color: kMantTexto, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (c.origen == 'ia') const Icon(Icons.auto_awesome, color: kMantIA, size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                fila('Fecha', formatoFechaCorta(c.fecha)),
                if (c.tipoCombustible != null) fila('Energía', c.tipoCombustible!),
                if (c.cantidad > 0) fila(c.unidad == 'kwh' ? 'kWh cargados' : 'Litros', '${formatoCantidad(c.cantidad)} ${c.etiquetaCantidad}'),
                if (c.precioLitro > 0) fila(c.unidad == 'kwh' ? 'Precio por kWh' : 'Precio por litro', formatoPesos(c.precioLitro)),
                fila('Total', formatoPesos(c.total)),
                if (c.kilometraje != null) fila('Kilometraje', formatoKm(c.kilometraje!)),
                if (c.tanqueLleno) fila(c.unidad == 'kwh' ? 'Batería' : 'Estanque', 'Lleno'),
                if (c.tieneDocumento) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kMantPrimario,
                      side: const BorderSide(color: kMantPrimario),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _verDocumento(c),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(c.documentoNombre ?? 'Ver boleta adjunta', overflow: TextOverflow.ellipsis),
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
                          _abrirFormulario(combustible: combustible, kmActual: kmActual, existente: c);
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
                          _eliminar(c);
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
        final vehiculo = vehiculoSnap.data?.isNotEmpty == true ? vehiculoSnap.data!.first : null;
        final combustible = vehiculo?['tipo_combustible'] as String?;
        final kmActual = (vehiculo?['kilometraje'] as num?)?.toDouble();

        return StreamBuilder<List<CargaCombustibleModel>>(
          stream: _cargasStream,
          builder: (context, snap) {
            return Scaffold(
              backgroundColor: kMantFondo,
              appBar: AppBar(
                backgroundColor: kMantFondo,
                elevation: 0,
                title: Text('Combustible · ${widget.patente}', style: const TextStyle(color: Colors.white)),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              floatingActionButton: FloatingActionButton.extended(
                heroTag: 'fabAgregarCarga',
                backgroundColor: kMantPrimario,
                onPressed: _procesandoIa || !snap.hasData ? null : () => _elegirMetodo(combustible: combustible, kmActual: kmActual),
                icon: _procesandoIa
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, color: Colors.white),
                label: Text(
                  _procesandoIa ? 'Analizando boleta…' : 'Registrar carga',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              body: _construirCuerpo(snap, combustible, kmActual),
            );
          },
        );
      },
    );
  }

  Widget _construirCuerpo(AsyncSnapshot<List<CargaCombustibleModel>> snap, String? combustible, double? kmActual) {
    // E2 del CU14: error al recuperar los datos, con la opción de reintentar.
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: kMantTextoSuave, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar las cargas. Revisa tu conexión e intenta de nuevo.',
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

    final todas = snap.data!;
    final delMes = cargasDelMes(todas, _mes)..sort((a, b) => b.fecha.compareTo(a.fecha));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _buildSelectorMes(),
        _buildResumen(delMes),
        _buildRendimiento(todas),
        const SizedBox(height: 24),
        const Text('Historial de cargas', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
        const SizedBox(height: 10),
        if (delMes.isEmpty)
          _buildVacio(combustible, kmActual)
        else
          for (final c in delMes) _buildItem(c, combustible, kmActual),
      ],
    );
  }

  Widget _buildSelectorMes() {
    final hoy = DateTime.now();
    final esMesActual = _mes.year == hoy.year && _mes.month == hoy.month;
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];

    return Row(
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
    );
  }

  Widget _tarjetaDato(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
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
            Text(valor, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kMantTexto, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen(List<CargaCombustibleModel> delMes) {
    final litros = cantidadTotal(delMes, 'litros');
    final kwh = cantidadTotal(delMes, 'kwh');
    final partes = [
      if (litros > 0 || kwh == 0) '${formatoCantidad(litros)} L',
      if (kwh > 0) '${formatoCantidad(kwh)} kWh',
    ];

    return Row(
      children: [
        _tarjetaDato('Gasto del mes', formatoPesos(gastoTotal(delMes)), Icons.payments_outlined, _kCombustible),
        const SizedBox(width: 12),
        _tarjetaDato('Cargado en el mes', partes.join(' · '), Icons.water_drop_outlined, kMantPrimario),
      ],
    );
  }

  /// Rendimiento promedio del vehículo, con todas sus cargas y no solo las del
  /// mes (CU14, paso 6): necesita al menos dos llenados con kilometraje. Si
  /// aún no hay datos suficientes, no se muestra nada.
  Widget _buildRendimiento(List<CargaCombustibleModel> todas) {
    final r = calcularRendimiento(todas, unidad: 'litros') ?? calcularRendimiento(todas, unidad: 'kwh');
    if (r == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed_outlined, color: kMantAdvertencia, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rendimiento estimado', style: TextStyle(color: kMantTextoSuave, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '${formatoCantidad(double.parse(r.kmPorUnidad.toStringAsFixed(1)))} ${r.etiqueta}',
                  style: const TextStyle(color: kMantTexto, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Promedio de ${r.tramos} ${r.tramos == 1 ? 'tramo' : 'tramos'} entre llenados',
                  style: const TextStyle(color: kMantTextoSuave, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// E1 del CU14: no hay cargas en el período.
  Widget _buildVacio(String? combustible, double? kmActual) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.local_gas_station_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          const Text('No hay abastecimientos registrados en este periodo',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMantPrimario,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _elegirMetodo(combustible: combustible, kmActual: kmActual),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Registrar carga', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(CargaCombustibleModel c, String? combustible, double? kmActual) {
    final partes = [
      formatoFechaCorta(c.fecha),
      if (c.cantidad > 0) '${formatoCantidad(c.cantidad)} ${c.etiquetaCantidad}',
      if (c.tipoCombustible != null) c.tipoCombustible!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalle(c, combustible: combustible, kmActual: kmActual),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _kCombustible.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(
                    c.unidad == 'kwh' ? Icons.bolt_outlined : Icons.local_gas_station_outlined,
                    color: _kCombustible,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.estacion.isNotEmpty ? c.estacion : (c.tipoCombustible ?? 'Carga'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMantTexto, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partes.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMantTextoSuave, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (c.tieneDocumento)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.attach_file, size: 16, color: kMantTextoSuave),
                  ),
                if (c.origen == 'ia')
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.auto_awesome, size: 14, color: kMantIA),
                  ),
                Text(formatoPesos(c.total), style: const TextStyle(color: kMantTexto, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
