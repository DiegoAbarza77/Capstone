import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/models/estacionamiento_model.dart';
import '../data/services/estacionamiento_ia_service.dart';
import '../data/services/estacionamiento_service.dart';
import '../data/services/ubicacion_service.dart';
import '../utils/estacionamiento_calculos.dart';
import '../utils/numero_chile.dart';
import 'mantencion_form_screen.dart' show ArchivoAdjunto, mimeDeArchivo;
import 'mantencion_ui.dart';
import 'mapa_ubicacion.dart';

/// Formulario para registrar o modificar un estacionamiento. Sirve para el
/// registro manual y también para la revisión de lo que leyó la IA de un ticket:
/// en ese caso llega precargado y destaca lo que la IA no pudo leer. Nada se
/// guarda hasta que el usuario pulsa "Guardar".
///
/// Al guardar cierra con un [ResultadoGuardadoEstacionamiento].
class EstacionamientoFormScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  /// Si viene, se está modificando este estacionamiento.
  final EstacionamientoModel? existente;

  /// Datos leídos por la IA para precargar el formulario.
  final EstacionamientoExtraidoIa? ia;

  /// Archivo adjunto (por ejemplo el ticket que se mandó a leer con la IA).
  final ArchivoAdjunto? archivo;

  const EstacionamientoFormScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
    this.existente,
    this.ia,
    this.archivo,
  });

  @override
  State<EstacionamientoFormScreen> createState() => _EstacionamientoFormScreenState();
}

class _EstacionamientoFormScreenState extends State<EstacionamientoFormScreen> {
  static const _tamanoMaximoAdjunto = 10 * 1024 * 1024;

  final EstacionamientoService _service = EstacionamientoService();

  late DateTime _fecha;
  late final TextEditingController _lugarCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _costoCtrl;
  late final TextEditingController _observacionesCtrl;
  TimeOfDay? _entrada;
  TimeOfDay? _salida;
  int? _duracionLeidaMinutos;
  double? _lat;
  double? _lng;

  ArchivoAdjunto? _archivo;
  bool _guardando = false;
  bool _buscandoUbicacion = false;
  String? _errorFecha;
  String? _errorLugar;
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
    _lugarCtrl = TextEditingController(text: e?.lugar ?? ia?.lugar ?? '');
    _direccionCtrl = TextEditingController(text: e?.direccion ?? ia?.direccion ?? '');
    final costo = e?.costo ?? ia?.monto;
    _costoCtrl = TextEditingController(text: costo != null && costo > 0 ? formatearMiles(costo.round()) : '');
    _observacionesCtrl = TextEditingController(text: e?.observaciones ?? '');

    if (e != null) {
      _entrada = e.horaEntrada != null ? TimeOfDay.fromDateTime(e.horaEntrada!) : null;
      _salida = e.horaSalida != null ? TimeOfDay.fromDateTime(e.horaSalida!) : null;
      _duracionLeidaMinutos = e.duracionMinutos;
    } else if (ia != null) {
      _entrada = ia.horaEntrada != null ? TimeOfDay(hour: ia.horaEntrada!.hora, minute: ia.horaEntrada!.minuto) : null;
      _salida = ia.horaSalida != null ? TimeOfDay(hour: ia.horaSalida!.hora, minute: ia.horaSalida!.minuto) : null;
      _duracionLeidaMinutos = ia.duracionMinutos;
    }
    _lat = e?.lat;
    _lng = e?.lng;
    _archivo = widget.archivo;
  }

  @override
  void dispose() {
    _lugarCtrl.dispose();
    _direccionCtrl.dispose();
    _costoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  // ── Cálculo de horas ────────────────────────────────────────────────

  /// Entrada y salida resueltas contra el día elegido, o null si faltan las dos.
  ({DateTime entrada, DateTime salida, bool diaSiguiente})? get _horas {
    final e = _entrada;
    final s = _salida;
    if (e == null || s == null) return null;
    return resolverEntradaSalida(
      _fecha,
      horaEntrada: e.hour,
      minutoEntrada: e.minute,
      horaSalida: s.hour,
      minutoSalida: s.minute,
    );
  }

  /// Texto con la duración que se va a guardar.
  String? get _textoDuracion {
    final h = _horas;
    if (h != null) {
      final base = formatoDuracion(h.salida.difference(h.entrada));
      return h.diaSiguiente ? '$base (sale al día siguiente)' : base;
    }
    if (_duracionLeidaMinutos != null) return '${formatoDuracion(Duration(minutes: _duracionLeidaMinutos!))} (leída del ticket)';
    return null;
  }

  // ── Validación y guardado ───────────────────────────────────────────

  bool _validar() {
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);

    String? errorFecha;
    if (_fecha.isAfter(soloHoy)) errorFecha = 'La fecha no puede ser futura.';

    String? errorLugar;
    if (_lugarCtrl.text.trim().isEmpty) errorLugar = 'Ingresa el lugar o el nombre del estacionamiento.';

    String? errorCosto;
    final textoCosto = _costoCtrl.text.trim();
    final costo = parseNumeroChile(textoCosto, puntoEsMiles: true);
    if (textoCosto.isEmpty) {
      errorCosto = 'Ingresa el costo (0 si fue gratis).';
    } else if (costo == null) {
      errorCosto = 'El costo no es un número válido.';
    } else if (costo < 0) {
      errorCosto = 'El costo no puede ser negativo.';
    }

    setState(() {
      _errorFecha = errorFecha;
      _errorLugar = errorLugar;
      _errorCosto = errorCosto;
      _errorGuardado = null;
    });
    return errorFecha == null && errorLugar == null && errorCosto == null;
  }

  Future<void> _guardar() async {
    if (_guardando || !_validar()) return;

    DateTime? entrada;
    DateTime? salida;
    int? duracion;
    final horas = _horas;
    if (horas != null) {
      entrada = horas.entrada;
      salida = horas.salida;
    } else {
      // Con una sola hora se guarda esa; la duración leída solo sirve si no hay
      // las dos horas, porque con ambas se calcula sola.
      if (_entrada != null) entrada = combinarFechaHora(_fecha, _entrada!.hour, _entrada!.minute);
      if (_salida != null) salida = combinarFechaHora(_fecha, _salida!.hour, _salida!.minute);
      duracion = _duracionLeidaMinutos;
    }

    final base = widget.existente;
    final estacionamiento = EstacionamientoModel(
      id: base?.id ?? '',
      vehiculoId: widget.vehiculoId,
      fecha: _fecha,
      lugar: _lugarCtrl.text,
      direccion: _direccionCtrl.text,
      lat: _lat,
      lng: _lng,
      horaEntrada: entrada,
      horaSalida: salida,
      duracionMinutos: duracion,
      costo: parseNumeroChile(_costoCtrl.text, puntoEsMiles: true) ?? 0,
      observaciones: _observacionesCtrl.text,
      documentoPath: base?.documentoPath,
      documentoNombre: base?.documentoNombre,
      origen: base?.origen ?? (_desdeIa ? 'ia' : 'manual'),
      aiCapturadoEn: base?.aiCapturadoEn ?? (_desdeIa ? DateTime.now() : null),
    );

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });
    try {
      final resultado = await _service.guardar(
        estacionamiento,
        archivoBytes: _archivo?.bytes,
        archivoNombre: _archivo?.nombre,
        archivoMime: _archivo?.mime,
      );
      if (mounted) Navigator.pop(context, resultado);
    } catch (e) {
      debugPrint('TAG_OK_ESTACIONAMIENTOS: error al guardar: $e');
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
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _errorFecha = null;
      });
    }
  }

  Future<void> _elegirHora({required bool entrada}) async {
    final actual = entrada ? _entrada : _salida;
    final elegida = await showTimePicker(
      context: context,
      initialTime: actual ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (elegida != null) {
      setState(() {
        if (entrada) {
          _entrada = elegida;
        } else {
          _salida = elegida;
        }
      });
    }
  }

  Future<void> _guardarUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    final r = await UbicacionService().obtenerActual();
    if (!mounted) return;
    setState(() {
      _buscandoUbicacion = false;
      if (r.obtenida) {
        _lat = r.lat;
        _lng = r.lng;
      }
    });
    if (!r.obtenida) _avisar(r.motivo ?? 'No se pudo obtener tu ubicación.');
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
    final duracion = _textoDuracion;

    return Scaffold(
      backgroundColor: kMantFondo,
      appBar: AppBar(
        backgroundColor: kMantFondo,
        elevation: 0,
        title: Text(
          _esEdicion ? 'Modificar estacionamiento' : 'Registrar estacionamiento',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_desdeIa) _bannerIa(),
            _seccion('Dónde y cuándo'),
            TextField(
              controller: _lugarCtrl,
              style: const TextStyle(color: kMantTexto),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _errorLugar = null),
              decoration: decoracionMantencion(
                'Lugar *',
                icono: Icons.local_parking_outlined,
                error: _errorLugar,
                resaltar: _desdeIa && _lugarCtrl.text.trim().isEmpty && _errorLugar == null,
                ayuda: _desdeIa && _lugarCtrl.text.trim().isEmpty ? 'La IA no lo pudo leer: ingrésalo' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionCtrl,
              style: const TextStyle(color: kMantTexto),
              textCapitalization: TextCapitalization.words,
              decoration: decoracionMantencion('Dirección (opcional)', icono: Icons.place_outlined),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: decoracionMantencion('Fecha', error: _errorFecha, icono: Icons.calendar_today_outlined),
                child: Row(
                  children: [
                    Expanded(child: Text(formatoFechaCorta(_fecha), style: const TextStyle(color: kMantTexto, fontSize: 16))),
                    const Icon(Icons.edit_outlined, color: kMantPrimario, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _campoHora('Hora de entrada', _entrada, () => _elegirHora(entrada: true), () => setState(() => _entrada = null))),
                const SizedBox(width: 12),
                Expanded(child: _campoHora('Hora de salida', _salida, () => _elegirHora(entrada: false), () => setState(() => _salida = null))),
              ],
            ),
            if (duracion != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: kMantTextoSuave),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Duración: $duracion', style: const TextStyle(color: kMantTextoSuave))),
                  ],
                ),
              ),
            _seccion('Costo'),
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
                resaltar: _desdeIa && _costoCtrl.text.trim().isEmpty && _errorCosto == null,
                ayuda: _desdeIa && _costoCtrl.text.trim().isEmpty ? 'La IA no lo pudo leer: ingrésalo' : null,
              ),
            ),
            _seccion('Ubicación del auto'),
            _bloqueUbicacion(),
            _seccion('Observaciones'),
            TextField(
              controller: _observacionesCtrl,
              style: const TextStyle(color: kMantTexto),
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoracionMantencion('Observaciones (opcional)', icono: Icons.comment_outlined),
            ),
            _seccion('Ticket o boleta'),
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

  Widget _campoHora(String etiqueta, TimeOfDay? valor, VoidCallback alElegir, VoidCallback alQuitar) {
    final faltaIa = _desdeIa && valor == null;
    return InkWell(
      onTap: alElegir,
      child: InputDecorator(
        decoration: decoracionMantencion(
          etiqueta,
          icono: Icons.schedule_outlined,
          resaltar: faltaIa,
          ayuda: faltaIa ? 'La IA no la pudo leer' : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valor != null ? '${valor.hour.toString().padLeft(2, '0')}:${valor.minute.toString().padLeft(2, '0')}' : '--:--',
                style: TextStyle(color: valor != null ? kMantTexto : kMantTextoSuave, fontSize: 16),
              ),
            ),
            if (valor != null)
              GestureDetector(
                onTap: alQuitar,
                child: const Icon(Icons.close, size: 18, color: kMantTextoSuave),
              ),
          ],
        ),
      ),
    );
  }

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

  Widget _bloqueUbicacion() {
    final lat = _lat;
    final lng = _lng;
    if (lat != null && lng != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MapaUbicacion(lat: lat, lng: lng, altura: 150),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _lat = null;
                _lng = null;
              }),
              icon: const Icon(Icons.location_off_outlined, size: 18),
              label: const Text('Quitar ubicación'),
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: kMantPrimario,
        side: const BorderSide(color: kMantPrimario),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _buscandoUbicacion ? null : _guardarUbicacion,
      icon: _buscandoUbicacion
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.my_location_outlined),
      label: Text(_buscandoUbicacion ? 'Buscando ubicación…' : 'Guardar mi ubicación actual'),
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
        label: const Text('Adjuntar ticket o boleta'),
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
