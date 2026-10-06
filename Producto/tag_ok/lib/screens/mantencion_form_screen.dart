import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/mantencion_model.dart';
import '../data/services/mantencion_ia_service.dart';
import '../data/services/mantencion_service.dart';
import '../utils/mantencion_calculos.dart';
import '../utils/numero_chile.dart';
import 'mantencion_ui.dart';

/// Archivo (boleta o factura) que se va a adjuntar a una mantención.
class ArchivoAdjunto {
  final Uint8List bytes;
  final String nombre;
  final String mime;

  const ArchivoAdjunto({required this.bytes, required this.nombre, required this.mime});
}

/// Formulario para registrar o modificar una mantención. Sirve para el registro
/// manual y también para la revisión de lo que leyó la IA: en ese caso llega
/// precargado y destaca los campos que la IA no pudo leer. Nada se guarda hasta
/// que el usuario pulsa "Guardar".
///
/// Al guardar cierra con un [ResultadoGuardadoMantencion].
class MantencionFormScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  /// Kilometraje actual del vehículo, solo para mostrarlo como referencia.
  final double? kmActualVehiculo;

  /// Mantenciones ya registradas, para detectar kilometrajes incoherentes.
  final List<MantencionModel> historial;

  /// Si viene, se está modificando esta mantención.
  final MantencionModel? existente;

  /// Datos leídos por la IA para precargar el formulario.
  final MantencionExtraidaIa? ia;

  /// Archivo adjunto (por ejemplo la boleta que se mandó a leer con la IA).
  final ArchivoAdjunto? archivo;

  /// Tipo con que arranca el formulario (al registrar una mantención programada).
  final String? tipoInicial;

  const MantencionFormScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
    required this.historial,
    this.kmActualVehiculo,
    this.existente,
    this.ia,
    this.archivo,
    this.tipoInicial,
  });

  @override
  State<MantencionFormScreen> createState() => _MantencionFormScreenState();
}

class _MantencionFormScreenState extends State<MantencionFormScreen> {
  static const _tamanoMaximoAdjunto = 10 * 1024 * 1024;

  final MantencionService _service = MantencionService();

  late DateTime _fecha;
  late String _tipo;
  late final TextEditingController _tallerCtrl;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _costoCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _observacionesCtrl;
  late List<String> _servicios;
  late List<String> _repuestos;

  ArchivoAdjunto? _archivo;
  bool _guardando = false;
  bool _intentoGuardar = false;
  String? _errorFecha;
  String? _errorKm;
  String? _errorCosto;
  String? _errorGuardado;

  bool get _esEdicion => widget.existente != null;
  bool get _desdeIa => widget.ia != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    final ia = widget.ia;
    final hoy = DateTime.now();

    _fecha = e?.fecha ?? ia?.fecha ?? DateTime(hoy.year, hoy.month, hoy.day);
    _tipo = e?.tipo ?? ia?.tipo ?? widget.tipoInicial ?? 'preventiva';
    _tallerCtrl = TextEditingController(text: e?.taller ?? ia?.taller ?? '');
    final km = e?.kilometraje ?? ia?.kilometraje;
    _kmCtrl = TextEditingController(text: km != null ? formatearMiles(km.round()) : '');
    final costo = e?.costo ?? ia?.total;
    _costoCtrl = TextEditingController(text: costo != null && costo > 0 ? formatearMiles(costo.round()) : '');
    _descripcionCtrl = TextEditingController(text: e?.descripcion ?? '');
    _observacionesCtrl = TextEditingController(text: e?.observaciones ?? '');
    _servicios = [...(e?.servicios ?? ia?.servicios ?? const <String>[])];
    _repuestos = [...(e?.repuestos ?? ia?.repuestos ?? const <String>[])];
    _archivo = widget.archivo;
  }

  @override
  void dispose() {
    _tallerCtrl.dispose();
    _kmCtrl.dispose();
    _costoCtrl.dispose();
    _descripcionCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  // ── Validación ──────────────────────────────────────────────────────

  /// Devuelve true si todo es válido, y deja los mensajes de error en pantalla.
  bool _validar() {
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);

    String? errorFecha;
    if (_fecha.isAfter(soloHoy)) errorFecha = 'La fecha no puede ser futura.';

    String? errorCosto;
    final textoCosto = _costoCtrl.text.trim();
    final costo = parseNumeroChile(textoCosto, puntoEsMiles: true);
    if (textoCosto.isEmpty) {
      errorCosto = 'Ingresa el costo del servicio.';
    } else if (costo == null) {
      errorCosto = 'El costo no es un número válido.';
    } else if (costo < 0) {
      errorCosto = 'El costo no puede ser negativo.';
    }

    String? errorKm;
    final textoKm = _kmCtrl.text.trim();
    if (textoKm.isNotEmpty) {
      final km = parseNumeroChile(textoKm, puntoEsMiles: true);
      if (km == null || km <= 0) errorKm = 'El kilometraje no es válido.';
    }

    setState(() {
      _intentoGuardar = true;
      _errorFecha = errorFecha;
      _errorCosto = errorCosto;
      _errorKm = errorKm;
      _errorGuardado = null;
    });
    return errorFecha == null && errorCosto == null && errorKm == null;
  }

  /// Si el kilometraje es menor al de la mantención anterior, pide confirmación.
  /// Devuelve true si se puede seguir guardando.
  Future<bool> _confirmarKilometraje(double km) async {
    final anterior = incongruenciaKilometraje(
      widget.historial,
      fecha: _fecha,
      km: km,
      excluirId: widget.existente?.id,
    );
    if (anterior == null) return true;

    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kMantTarjeta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: kMantAdvertencia),
            SizedBox(width: 10),
            Expanded(child: Text('Revisa el kilometraje', style: TextStyle(color: kMantTexto))),
          ],
        ),
        content: Text(
          'Ingresaste ${formatoKm(km)}, pero la mantención anterior '
          '(${formatoFechaCorta(anterior.fecha)}) tiene ${formatoKm(anterior.kilometraje!)}. '
          'Un kilometraje menor no es habitual. ¿Está bien?',
          style: const TextStyle(color: kMantTextoSuave),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Corregir', style: TextStyle(color: kMantTextoSuave)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar de todos modos', style: TextStyle(color: kMantAdvertencia)),
          ),
        ],
      ),
    );
    return continuar == true;
  }

  Future<void> _guardar() async {
    if (_guardando || !_validar()) return;

    final km = _kmCtrl.text.trim().isEmpty ? null : parseNumeroChile(_kmCtrl.text, puntoEsMiles: true);
    if (km != null && !await _confirmarKilometraje(km)) return;
    if (!mounted) return;

    final base = widget.existente;
    final mantencion = MantencionModel(
      id: base?.id ?? '',
      vehiculoId: widget.vehiculoId,
      fecha: _fecha,
      kilometraje: km,
      tipo: _tipo,
      taller: _tallerCtrl.text,
      costo: parseNumeroChile(_costoCtrl.text, puntoEsMiles: true) ?? 0,
      descripcion: _descripcionCtrl.text,
      observaciones: _observacionesCtrl.text,
      servicios: _servicios,
      repuestos: _repuestos,
      documentoPath: base?.documentoPath,
      documentoNombre: base?.documentoNombre,
      // Una mantención se marca como "ia" si viene de una lectura de la IA; al
      // modificar una existente se conserva su origen.
      origen: base?.origen ?? (_desdeIa ? 'ia' : 'manual'),
      aiCapturadoEn: base?.aiCapturadoEn ?? (_desdeIa ? DateTime.now() : null),
    );

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });
    try {
      final resultado = await _service.guardar(
        mantencion,
        archivoBytes: _archivo?.bytes,
        archivoNombre: _archivo?.nombre,
        archivoMime: _archivo?.mime,
      );
      if (mounted) Navigator.pop(context, resultado);
    } catch (e) {
      debugPrint('TAG_OK_MANTENCIONES: error al guardar: $e');
      // Los datos siguen en pantalla para poder reintentar.
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
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _errorFecha = null;
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
    // Con IA se destacan los campos que no pudo leer, para que el usuario los complete.
    bool faltaIa(TextEditingController c) => _desdeIa && c.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: kMantFondo,
      appBar: AppBar(
        backgroundColor: kMantFondo,
        elevation: 0,
        title: Text(
          _esEdicion ? 'Modificar mantención' : 'Registrar mantención',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_desdeIa) _bannerIa(),
            _seccion('Fecha y tipo'),
            InkWell(
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: decoracionMantencion('Fecha del servicio', error: _errorFecha, icono: Icons.calendar_today_outlined),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(formatoFechaCorta(_fecha), style: const TextStyle(color: kMantTexto, fontSize: 16)),
                    ),
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
                for (final entrada in kTiposMantencion.entries)
                  ChoiceChip(
                    avatar: Icon(
                      iconoTipoMantencion(entrada.key),
                      size: 18,
                      color: _tipo == entrada.key ? Colors.white : colorTipoMantencion(entrada.key),
                    ),
                    label: Text(entrada.value),
                    selected: _tipo == entrada.key,
                    onSelected: (_) => setState(() => _tipo = entrada.key),
                    selectedColor: kMantPrimario,
                    backgroundColor: kMantTarjeta,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: _tipo == entrada.key ? Colors.white : kMantTextoSuave),
                    side: BorderSide(color: _tipo == entrada.key ? kMantPrimario : Colors.white.withValues(alpha: 0.08)),
                  ),
              ],
            ),
            _seccion('Detalle'),
            TextField(
              controller: _tallerCtrl,
              style: const TextStyle(color: kMantTexto),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: decoracionMantencion(
                'Taller (opcional)',
                icono: Icons.storefront_outlined,
                resaltar: faltaIa(_tallerCtrl),
                ayuda: faltaIa(_tallerCtrl) ? 'La IA no lo pudo leer' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kmCtrl,
              style: const TextStyle(color: kMantTexto),
              keyboardType: TextInputType.number,
              inputFormatters: [MilesInputFormatter()],
              onChanged: (_) => setState(() => _errorKm = null),
              decoration: decoracionMantencion(
                'Kilometraje (opcional)',
                icono: Icons.speed_outlined,
                error: _errorKm,
                resaltar: faltaIa(_kmCtrl),
                ayuda: faltaIa(_kmCtrl)
                    ? 'La IA no lo pudo leer'
                    : (kmActual != null ? 'Odómetro actual del vehículo: ${formatoKm(kmActual)}' : null),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costoCtrl,
              style: const TextStyle(color: kMantTexto),
              keyboardType: TextInputType.number,
              inputFormatters: [MilesInputFormatter()],
              onChanged: (_) => setState(() => _errorCosto = null),
              decoration: decoracionMantencion(
                'Costo total (\$) *',
                icono: Icons.attach_money,
                error: _errorCosto,
                resaltar: faltaIa(_costoCtrl) && !_intentoGuardar,
                ayuda: faltaIa(_costoCtrl) ? 'La IA no lo pudo leer: ingrésalo' : null,
              ),
            ),
            _seccion('Servicios y repuestos'),
            _ListaEditable(
              titulo: 'Servicios realizados',
              ayuda: 'Ej: Cambio de aceite',
              elementos: _servicios,
              onCambio: (nueva) => setState(() => _servicios = nueva),
            ),
            const SizedBox(height: 16),
            _ListaEditable(
              titulo: 'Repuestos',
              ayuda: 'Ej: Filtro de aire',
              elementos: _repuestos,
              onCambio: (nueva) => setState(() => _repuestos = nueva),
            ),
            _seccion('Notas'),
            TextField(
              controller: _descripcionCtrl,
              style: const TextStyle(color: kMantTexto),
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoracionMantencion('Descripción (opcional)', icono: Icons.notes_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observacionesCtrl,
              style: const TextStyle(color: kMantTexto),
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoracionMantencion('Observaciones (opcional)', icono: Icons.comment_outlined),
            ),
            _seccion('Boleta o factura'),
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
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _errorGuardado != null ? 'Reintentar' : 'Guardar',
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

  Widget _bannerIa() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMantIA.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMantIA.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: kMantIA, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Leí estos datos del comprobante. Revísalos y completa los que falten antes de guardar.',
              style: TextStyle(color: kMantTexto, fontSize: 13),
            ),
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
        label: const Text('Adjuntar boleta o factura'),
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
          Expanded(
            child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMantTexto)),
          ),
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

/// Tipo MIME según la extensión del archivo.
String mimeDeArchivo(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Lista de textos (servicios, repuestos) a la que se agregan y quitan elementos.
class _ListaEditable extends StatefulWidget {
  final String titulo;
  final String ayuda;
  final List<String> elementos;
  final ValueChanged<List<String>> onCambio;

  const _ListaEditable({
    required this.titulo,
    required this.ayuda,
    required this.elementos,
    required this.onCambio,
  });

  @override
  State<_ListaEditable> createState() => _ListaEditableState();
}

class _ListaEditableState extends State<_ListaEditable> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _agregar() {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    final repetido = widget.elementos.any((e) => e.toLowerCase() == texto.toLowerCase());
    if (!repetido) widget.onCambio([...widget.elementos, texto]);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: kMantTexto),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _agregar(),
                decoration: decoracionMantencion(widget.titulo, ayuda: widget.ayuda),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Agregar',
              onPressed: _agregar,
              icon: const Icon(Icons.add_circle_outline, color: kMantPrimario),
            ),
          ],
        ),
        if (widget.elementos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in widget.elementos)
                Chip(
                  label: Text(e),
                  backgroundColor: kMantTarjeta,
                  labelStyle: const TextStyle(color: kMantTexto, fontSize: 13),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  deleteIconColor: kMantTextoSuave,
                  onDeleted: () => widget.onCambio(widget.elementos.where((x) => x != e).toList()),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
