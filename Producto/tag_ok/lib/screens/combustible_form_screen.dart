import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/carga_combustible_model.dart';
import '../data/services/combustible_ia_service.dart';
import '../data/services/combustible_service.dart';
import '../utils/combustible_calculos.dart';
import '../utils/numero_chile.dart';
import 'mantencion_form_screen.dart' show ArchivoAdjunto, mimeDeArchivo;
import 'mantencion_ui.dart';

/// Formulario para registrar o modificar una carga de combustible o de energía.
/// Sirve para el registro manual y también para revisar lo que la IA leyó de una
/// boleta: en ese caso llega precargado, muestra la tarjeta "Carga detectada" y
/// destaca lo que la IA no pudo leer. Nada se guarda hasta que el usuario confirma.
///
/// Es un registro parcial a propósito: basta con la cantidad o con el total; el
/// resto es opcional. Al guardar cierra con un [ResultadoGuardadoCarga].
class CombustibleFormScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  /// Combustible del vehículo (Bencina, Diésel, Híbrido o Eléctrico): define con
  /// qué tipo de energía y qué unidad arranca el formulario.
  final String? combustibleDelVehiculo;

  /// Kilometraje actual del vehículo, solo como referencia.
  final double? kmActualVehiculo;

  /// Si viene, se está modificando esta carga.
  final CargaCombustibleModel? existente;

  /// Datos leídos por la IA para precargar el formulario.
  final CargaExtraidaIa? ia;

  /// Boleta adjunta (por ejemplo la que se mandó a leer con la IA).
  final ArchivoAdjunto? archivo;

  const CombustibleFormScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
    this.combustibleDelVehiculo,
    this.kmActualVehiculo,
    this.existente,
    this.ia,
    this.archivo,
  });

  @override
  State<CombustibleFormScreen> createState() => _CombustibleFormScreenState();
}

class _CombustibleFormScreenState extends State<CombustibleFormScreen> {
  static const _tamanoMaximoAdjunto = 10 * 1024 * 1024;

  final CombustibleService _service = CombustibleService();

  late DateTime _fecha;
  late String _tipo;
  late final TextEditingController _estacionCtrl;
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _kmCtrl;
  bool _tanqueLleno = false;

  /// true cuando el total lo escribió una persona (o vino leído): deja de
  /// recalcularse solo al cambiar la cantidad o el precio.
  bool _totalAMano = false;

  ArchivoAdjunto? _archivo;
  bool _guardando = false;
  Map<String, String> _errores = {};
  String? _errorGuardado;

  bool get _esEdicion => widget.existente != null;
  bool get _desdeIa => widget.ia != null;
  String get _unidad => unidadParaTipo(_tipo);
  String get _etiquetaUnidad => _unidad == 'kwh' ? 'kWh' : 'Litros';

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    final ia = widget.ia;
    final hoy = DateTime.now();

    _fecha = e?.fecha ?? ia?.fecha ?? DateTime(hoy.year, hoy.month, hoy.day);

    final tipoGuardado = e?.tipoCombustible ?? ia?.tipoCombustible;
    _tipo = kTiposEnergiaCarga.contains(tipoGuardado) ? tipoGuardado! : tipoEnergiaPorDefecto(widget.combustibleDelVehiculo);

    _estacionCtrl = TextEditingController(text: e?.estacion ?? ia?.estacion ?? '');

    final cantidad = e != null ? (e.litros > 0 ? e.litros : null) : ia?.cantidad;
    final precio = e != null ? (e.precioLitro > 0 ? e.precioLitro : null) : ia?.precioUnidad;
    final total = e != null ? (e.total > 0 ? e.total : null) : ia?.total;
    final km = e?.kilometraje ?? ia?.kilometraje;

    _cantidadCtrl = TextEditingController(text: cantidad != null ? formatoCantidadEditable(cantidad) : '');
    _precioCtrl = TextEditingController(text: precio != null ? formatoCantidadEditable(precio) : '');
    _totalCtrl = TextEditingController(text: total != null ? formatearMiles(total.round()) : '');
    _kmCtrl = TextEditingController(text: km != null ? formatearMiles(km.round()) : '');
    _tanqueLleno = e?.tanqueLleno ?? false;
    _totalAMano = total != null;
    _archivo = widget.archivo;
  }

  @override
  void dispose() {
    _estacionCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _totalCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  /// "32,5" o "40" para mostrar en un campo editable.
  static String formatoCantidadEditable(double v) {
    final entero = v == v.roundToDouble();
    return entero ? v.round().toString() : v.toString().replaceAll('.', ',');
  }

  // ── Cálculo automático del total ────────────────────────────────────

  /// Recalcula el total (cantidad × precio) mientras el usuario no lo haya
  /// escrito a mano.
  void _recalcularTotal() {
    if (_totalAMano) return;
    final cantidad = parseNumeroChile(_cantidadCtrl.text);
    final precio = parseNumeroChile(_precioCtrl.text, puntoEsMiles: true);
    final m = completarMontos(cantidad: cantidad, precio: precio);
    final nuevo = (cantidad != null && precio != null && m.total > 0) ? formatearMiles(m.total.round()) : '';
    _totalCtrl.value = TextEditingValue(text: nuevo, selection: TextSelection.collapsed(offset: nuevo.length));
  }

  // ── Guardado ────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (_guardando) return;

    final errores = validarCarga(
      cantidad: _cantidadCtrl.text,
      precio: _precioCtrl.text,
      total: _totalCtrl.text,
      kilometraje: _kmCtrl.text,
      fecha: _fecha,
    );
    if (errores.isNotEmpty) {
      setState(() {
        _errores = errores;
        _errorGuardado = null;
      });
      return;
    }

    // Se completa el dato que falte a partir de los otros dos.
    final m = completarMontos(
      cantidad: parseNumeroChile(_cantidadCtrl.text),
      precio: parseNumeroChile(_precioCtrl.text, puntoEsMiles: true),
      total: parseNumeroChile(_totalCtrl.text, puntoEsMiles: true),
    );
    final km = _kmCtrl.text.trim().isEmpty ? null : parseNumeroChile(_kmCtrl.text, puntoEsMiles: true);
    final base = widget.existente;

    final carga = CargaCombustibleModel(
      id: base?.id ?? '',
      vehiculoId: widget.vehiculoId,
      vehiculoPatente: widget.patente,
      fecha: _fecha,
      kilometraje: km,
      estacion: _estacionCtrl.text.trim(),
      tipoCombustible: _tipo,
      litros: m.cantidad,
      precioLitro: m.precio,
      total: m.total,
      unidad: _unidad,
      origen: base?.origen ?? (_desdeIa ? 'ia' : 'manual'),
      aiCapturadoEn: base?.aiCapturadoEn ?? (_desdeIa ? DateTime.now() : null),
      archivoNombre: base?.archivoNombre ?? _archivo?.nombre,
      tanqueLleno: _tanqueLleno,
      documentoPath: base?.documentoPath,
      documentoNombre: base?.documentoNombre,
    );

    setState(() {
      _errores = {};
      _guardando = true;
      _errorGuardado = null;
    });
    try {
      final resultado = await _service.guardar(
        carga,
        archivoBytes: _archivo?.bytes,
        archivoNombre: _archivo?.nombre,
        archivoMime: _archivo?.mime,
      );
      if (mounted) Navigator.pop(context, resultado);
    } catch (e) {
      debugPrint('TAG_OK_COMBUSTIBLE: error al guardar: $e');
      // E4: los datos siguen en pantalla para poder reintentar.
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorGuardado = 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.';
        });
      }
    }
  }

  // ── Acciones ────────────────────────────────────────────────────────

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _errores.remove('fecha');
      });
    }
  }

  Future<void> _adjuntarArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) return;

    final archivo = resultado.files.first;
    final bytes = archivo.bytes;
    if (!mounted) return;
    if (bytes == null) {
      _avisar('No se pudo leer el archivo.');
      return;
    }
    if (bytes.length > _tamanoMaximoAdjunto) {
      _avisar('El archivo pesa más de 10 MB.');
      return;
    }
    setState(() => _archivo = ArchivoAdjunto(bytes: bytes, nombre: archivo.name, mime: mimeDeArchivo(archivo.name)));
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: kMantError, behavior: SnackBarBehavior.floating),
    );
  }

  // ── Interfaz ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final kmActual = widget.kmActualVehiculo;
    // Con IA se destacan los campos que no pudo leer.
    bool faltaIa(TextEditingController c) => _desdeIa && c.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: kMantFondo,
      appBar: AppBar(
        backgroundColor: kMantFondo,
        elevation: 0,
        title: Text(_esEdicion ? 'Modificar carga' : 'Registrar carga', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_desdeIa) _tarjetaDetectada(),
            _seccion('Fecha y energía'),
            InkWell(
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: decoracionMantencion('Fecha', error: _errores['fecha'], icono: Icons.calendar_today_outlined),
                child: Row(
                  children: [
                    Expanded(child: Text(formatoFechaCorta(_fecha), style: const TextStyle(color: kMantTexto, fontSize: 16))),
                    const Icon(Icons.edit_outlined, color: kMantPrimario, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tipo in kTiposEnergiaCarga)
                  ChoiceChip(
                    avatar: Icon(
                      tipo == 'Eléctrico' ? Icons.bolt_outlined : Icons.local_gas_station_outlined,
                      size: 18,
                      color: _tipo == tipo ? Colors.white : kMantTextoSuave,
                    ),
                    label: Text(tipo),
                    selected: _tipo == tipo,
                    onSelected: (_) => setState(() {
                      _tipo = tipo;
                      _errores.remove('cantidad');
                    }),
                    selectedColor: kMantPrimario,
                    backgroundColor: kMantTarjeta,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: _tipo == tipo ? Colors.white : kMantTextoSuave),
                    side: BorderSide(color: _tipo == tipo ? kMantPrimario : Colors.white.withValues(alpha: 0.08)),
                  ),
              ],
            ),
            if (widget.combustibleDelVehiculo == 'Híbrido')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tu vehículo es híbrido: elige bencina o eléctrico según lo que cargaste.',
                  style: TextStyle(color: kMantTextoSuave, fontSize: 12),
                ),
              ),
            _seccion('Estación'),
            TextField(
              controller: _estacionCtrl,
              style: const TextStyle(color: kMantTexto),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: decoracionMantencion(
                _unidad == 'kwh' ? 'Estación de carga (opcional)' : 'Estación de servicio (opcional)',
                icono: Icons.storefront_outlined,
                resaltar: faltaIa(_estacionCtrl),
                ayuda: faltaIa(_estacionCtrl) ? 'La IA no la pudo leer' : null,
              ),
            ),
            _seccion('Cantidad y monto'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _cantidadCtrl,
                    style: const TextStyle(color: kMantTexto),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => setState(() {
                      _errores.remove('cantidad');
                      _errores.remove('minimo');
                      _recalcularTotal();
                    }),
                    decoration: decoracionMantencion(
                      _etiquetaUnidad,
                      icono: Icons.water_drop_outlined,
                      error: _errores['cantidad'],
                      resaltar: faltaIa(_cantidadCtrl) && _errores['cantidad'] == null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _precioCtrl,
                    style: const TextStyle(color: kMantTexto),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => setState(() {
                      _errores.remove('precio');
                      _recalcularTotal();
                    }),
                    decoration: decoracionMantencion(
                      _unidad == 'kwh' ? 'Precio por kWh' : 'Precio por litro',
                      icono: Icons.sell_outlined,
                      error: _errores['precio'],
                      resaltar: faltaIa(_precioCtrl) && _errores['precio'] == null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalCtrl,
              style: const TextStyle(color: kMantTexto, fontSize: 18, fontWeight: FontWeight.bold),
              keyboardType: TextInputType.number,
              inputFormatters: [MilesInputFormatter()],
              onChanged: (_) => setState(() {
                _totalAMano = _totalCtrl.text.isNotEmpty;
                _errores.remove('total');
                _errores.remove('minimo');
              }),
              decoration: decoracionMantencion(
                'Total (\$)',
                icono: Icons.attach_money,
                error: _errores['total'],
                resaltar: faltaIa(_totalCtrl) && _errores['total'] == null,
                ayuda: _totalAMano || _totalCtrl.text.isNotEmpty
                    ? null
                    : 'Se calcula solo con la cantidad y el precio',
              ),
            ),
            if (_errores['minimo'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errores['minimo']!, style: const TextStyle(color: kMantError, fontSize: 13)),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Puedes dejar vacío lo que no tengas a mano: basta con la cantidad o el total.',
                style: TextStyle(color: kMantTextoSuave, fontSize: 12),
              ),
            ),
            _seccion('Odómetro'),
            TextField(
              controller: _kmCtrl,
              style: const TextStyle(color: kMantTexto),
              keyboardType: TextInputType.number,
              inputFormatters: [MilesInputFormatter()],
              onChanged: (_) => setState(() => _errores.remove('kilometraje')),
              decoration: decoracionMantencion(
                'Kilometraje (opcional)',
                icono: Icons.speed_outlined,
                error: _errores['kilometraje'],
                resaltar: faltaIa(_kmCtrl) && _errores['kilometraje'] == null,
                ayuda: faltaIa(_kmCtrl)
                    ? 'No aparece en la boleta: ingrésalo si lo tienes'
                    : (kmActual != null ? 'Odómetro actual del vehículo: ${formatoKm(kmActual)}' : null),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kMantPrimario,
              title: Text(_unidad == 'kwh' ? 'Cargué la batería completa' : 'Llené el estanque', style: const TextStyle(color: kMantTexto)),
              subtitle: const Text(
                'Con dos llenados y su kilometraje puedo calcular el rendimiento.',
                style: TextStyle(color: kMantTextoSuave, fontSize: 12),
              ),
              value: _tanqueLleno,
              onChanged: (v) => setState(() => _tanqueLleno = v),
            ),
            _seccion('Boleta'),
            _bloqueAdjunto(),
            const SizedBox(height: 28),
            if (_errorGuardado != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kMantError.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kMantError.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: kMantError, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorGuardado!, style: const TextStyle(color: kMantError, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMantPrimario,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _errorGuardado != null ? 'Reintentar' : (_desdeIa && !_esEdicion ? 'Confirmar y guardar' : 'Guardar'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(titulo, style: const TextStyle(color: kMantTextoSuave, fontSize: 13)),
      );

  /// Tarjeta "Carga detectada": lo que la IA leyó, antes de revisarlo abajo.
  Widget _tarjetaDetectada() {
    final ia = widget.ia!;
    final unidad = ia.unidad == 'kwh' ? 'kWh' : 'litros';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMantIA.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMantIA.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: kMantIA, size: 20),
              SizedBox(width: 8),
              Text('Carga detectada', style: TextStyle(color: kMantIA, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ia.tipoCombustible ?? 'Tipo de energía no detectado',
            style: const TextStyle(color: kMantTexto, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (ia.cantidad != null) '${formatoCantidad(ia.cantidad!)} $unidad',
              if (ia.precioUnidad != null) '${formatoPesos(ia.precioUnidad!)} / ${ia.unidad == 'kwh' ? 'kWh' : 'litro'}',
            ].join('  ·  '),
            style: const TextStyle(color: kMantTextoSuave, fontSize: 13),
          ),
          if (ia.total != null) ...[
            const SizedBox(height: 8),
            Text(formatoPesos(ia.total!), style: const TextStyle(color: kMantTexto, fontSize: 26, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 10),
          const Text(
            'Revisa los datos y corrígelos antes de guardar. Lo que no pude leer está marcado en ámbar.',
            style: TextStyle(color: kMantTextoSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _bloqueAdjunto() {
    final nuevo = _archivo;
    final guardado = widget.existente?.documentoNombre;
    final nombre = nuevo?.nombre ?? guardado;

    if (nombre == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: kMantPrimario,
          side: const BorderSide(color: kMantPrimario),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _adjuntarArchivo,
        icon: const Icon(Icons.attach_file),
        label: const Text('Adjuntar boleta'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: kMantPrimario),
          const SizedBox(width: 10),
          Expanded(child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMantTexto))),
          TextButton(onPressed: _adjuntarArchivo, child: const Text('Cambiar')),
          if (nuevo != null)
            IconButton(
              tooltip: 'Quitar',
              onPressed: () => setState(() => _archivo = null),
              icon: const Icon(Icons.close, color: kMantTextoSuave, size: 20),
            ),
        ],
      ),
    );
  }
}
