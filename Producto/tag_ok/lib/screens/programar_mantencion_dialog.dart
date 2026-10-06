import 'package:flutter/material.dart';
import '../data/models/mantencion_model.dart';
import '../data/services/mantencion_service.dart';
import '../utils/numero_chile.dart';
import 'mantencion_ui.dart';

/// Diálogo para programar la próxima mantención por fecha, por kilometraje o por
/// ambos, y elegir con cuánta anticipación avisar. Devuelve la programación
/// guardada, o null si se cancela.
class ProgramarMantencionDialog extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  /// Kilometraje actual del vehículo, para validar y dar contexto.
  final double? kmActual;

  /// Si viene, se está modificando esta programación.
  final MantencionProgramadaModel? existente;

  /// Valores con que arranca el formulario al programar una nueva (por ejemplo
  /// la sugerencia calculada después de registrar una mantención).
  final String? tipoInicial;
  final DateTime? fechaInicial;
  final double? kmInicial;

  const ProgramarMantencionDialog({
    super.key,
    required this.vehiculoId,
    required this.patente,
    this.kmActual,
    this.existente,
    this.tipoInicial,
    this.fechaInicial,
    this.kmInicial,
  });

  @override
  State<ProgramarMantencionDialog> createState() => _ProgramarMantencionDialogState();
}

class _ProgramarMantencionDialogState extends State<ProgramarMantencionDialog> {
  static const _opcionesDias = [1, 3, 7, 15, 30];
  static const _opcionesKm = [200, 500, 1000, 2000];

  final MantencionService _service = MantencionService();

  late String _tipo;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _kmCtrl;
  late bool _usarFecha;
  late bool _usarKm;
  DateTime? _fecha;
  late int _avisoDias;
  late int _avisoKm;

  bool _guardando = false;
  String? _errorCriterio;
  String? _errorFecha;
  String? _errorKm;
  String? _errorGuardado;

  bool get _esEdicion => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _tipo = e?.tipo ?? widget.tipoInicial ?? 'preventiva';
    _descripcionCtrl = TextEditingController(text: e?.descripcion ?? '');

    _fecha = e?.fechaProgramada ?? widget.fechaInicial;
    final km = e?.kmProgramado ?? widget.kmInicial;
    _kmCtrl = TextEditingController(text: km != null ? formatearMiles(km.round()) : '');
    _usarFecha = _fecha != null;
    _usarKm = km != null;
    // Sin nada precargado se ofrece la fecha como criterio por defecto.
    if (!_usarFecha && !_usarKm) _usarFecha = true;

    _avisoDias = _opcionesDias.contains(e?.avisoDiasAntes) ? e!.avisoDiasAntes : 7;
    _avisoKm = e != null && _opcionesKm.contains(e.avisoKmAntes.round()) ? e.avisoKmAntes.round() : 500;
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final inicial = _fecha ?? DateTime(hoy.year, hoy.month + 6, hoy.day);
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial.isBefore(hoy) ? hoy : inicial,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 10),
    );
    if (elegida != null) {
      setState(() {
        _fecha = elegida;
        _errorFecha = null;
        _errorCriterio = null;
      });
    }
  }

  bool _validar() {
    String? errorCriterio;
    String? errorFecha;
    String? errorKm;

    if (!_usarFecha && !_usarKm) {
      errorCriterio = 'Elige al menos un criterio: fecha o kilometraje.';
    }
    if (_usarFecha && _fecha == null) errorFecha = 'Elige una fecha.';

    if (_usarKm) {
      final km = parseNumeroChile(_kmCtrl.text, puntoEsMiles: true);
      if (_kmCtrl.text.trim().isEmpty || km == null || km <= 0) {
        errorKm = 'Ingresa un kilometraje válido.';
      } else if (widget.kmActual != null && km <= widget.kmActual!) {
        errorKm = 'Debe ser mayor al kilometraje actual (${formatoKm(widget.kmActual!)}).';
      }
    }

    setState(() {
      _errorCriterio = errorCriterio;
      _errorFecha = errorFecha;
      _errorKm = errorKm;
      _errorGuardado = null;
    });
    return errorCriterio == null && errorFecha == null && errorKm == null;
  }

  Future<void> _guardar() async {
    if (_guardando || !_validar()) return;

    final base = widget.existente;
    final programada = MantencionProgramadaModel(
      id: base?.id ?? '',
      vehiculoId: widget.vehiculoId,
      tipo: _tipo,
      descripcion: _descripcionCtrl.text,
      fechaProgramada: _usarFecha ? _fecha : null,
      kmProgramado: _usarKm ? parseNumeroChile(_kmCtrl.text, puntoEsMiles: true) : null,
      avisoDiasAntes: _avisoDias,
      avisoKmAntes: _avisoKm.toDouble(),
      completada: base?.completada ?? false,
    );

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });
    try {
      final guardada = await _service.guardarProgramada(programada, patente: widget.patente);
      if (mounted) Navigator.pop(context, guardada);
    } catch (e) {
      debugPrint('TAG_OK_MANTENCIONES: error al programar: $e');
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
      title: Text(
        _esEdicion ? 'Modificar próxima mantención' : 'Programar próxima mantención',
        style: const TextStyle(color: kMantTexto, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entrada in kTiposMantencion.entries)
                    ChoiceChip(
                      label: Text(entrada.value),
                      selected: _tipo == entrada.key,
                      onSelected: (_) => setState(() => _tipo = entrada.key),
                      selectedColor: kMantPrimario,
                      backgroundColor: kMantFondo,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _tipo == entrada.key ? Colors.white : kMantTextoSuave,
                        fontSize: 12,
                      ),
                      side: BorderSide(color: _tipo == entrada.key ? kMantPrimario : Colors.white.withValues(alpha: 0.08)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcionCtrl,
                style: const TextStyle(color: kMantTexto),
                textCapitalization: TextCapitalization.sentences,
                decoration: decoracionMantencion('Descripción (opcional)', ayuda: 'Ej: Cambio de correa de distribución'),
              ),
              const SizedBox(height: 16),
              const Text('¿Cuándo te avisamos?', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kMantPrimario,
                title: const Text('Por fecha', style: TextStyle(color: kMantTexto)),
                value: _usarFecha,
                onChanged: (v) => setState(() {
                  _usarFecha = v;
                  _errorCriterio = null;
                }),
              ),
              if (_usarFecha) ...[
                InkWell(
                  onTap: _elegirFecha,
                  child: InputDecorator(
                    decoration: decoracionMantencion('Fecha', error: _errorFecha, icono: Icons.event_outlined),
                    child: Text(
                      _fecha != null ? formatoFechaCorta(_fecha!) : 'Elegir fecha',
                      style: TextStyle(color: _fecha != null ? kMantTexto : kMantTextoSuave, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _avisoDias,
                  dropdownColor: kMantTarjeta,
                  style: const TextStyle(color: kMantTexto),
                  decoration: decoracionMantencion('Avisarme con anticipación'),
                  items: [
                    for (final d in _opcionesDias)
                      DropdownMenuItem(value: d, child: Text(d == 1 ? '1 día antes' : '$d días antes')),
                  ],
                  onChanged: (v) => setState(() => _avisoDias = v ?? 7),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kMantPrimario,
                title: const Text('Por kilometraje', style: TextStyle(color: kMantTexto)),
                value: _usarKm,
                onChanged: (v) => setState(() {
                  _usarKm = v;
                  _errorCriterio = null;
                }),
              ),
              if (_usarKm) ...[
                TextField(
                  controller: _kmCtrl,
                  style: const TextStyle(color: kMantTexto),
                  keyboardType: TextInputType.number,
                  inputFormatters: [MilesInputFormatter()],
                  onChanged: (_) => setState(() {
                    _errorKm = null;
                    _errorCriterio = null;
                  }),
                  decoration: decoracionMantencion(
                    'Kilometraje de la mantención',
                    icono: Icons.speed_outlined,
                    error: _errorKm,
                    ayuda: widget.kmActual != null ? 'Odómetro actual: ${formatoKm(widget.kmActual!)}' : null,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _avisoKm,
                  dropdownColor: kMantTarjeta,
                  style: const TextStyle(color: kMantTexto),
                  decoration: decoracionMantencion('Avisarme con anticipación'),
                  items: [
                    for (final k in _opcionesKm) DropdownMenuItem(value: k, child: Text('$k km antes')),
                  ],
                  onChanged: (v) => setState(() => _avisoKm = v ?? 500),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'El aviso por kilometraje se muestra dentro de la app cuando el odómetro se acerca.',
                    style: TextStyle(color: kMantTextoSuave, fontSize: 12),
                  ),
                ),
              ],
              if (_errorCriterio != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorCriterio!, style: const TextStyle(color: kMantError, fontSize: 13)),
                ),
              if (_errorGuardado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorGuardado!, style: const TextStyle(color: kMantError, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
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
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_errorGuardado != null ? 'Reintentar' : 'Guardar', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

/// Atajo para abrir el diálogo y recibir la programación guardada.
Future<MantencionProgramadaModel?> mostrarProgramarMantencion(
  BuildContext context, {
  required String vehiculoId,
  required String patente,
  double? kmActual,
  MantencionProgramadaModel? existente,
  String? tipoInicial,
  DateTime? fechaInicial,
  double? kmInicial,
}) {
  return showDialog<MantencionProgramadaModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProgramarMantencionDialog(
      vehiculoId: vehiculoId,
      patente: patente,
      kmActual: kmActual,
      existente: existente,
      tipoInicial: tipoInicial,
      fechaInicial: fechaInicial,
      kmInicial: kmInicial,
    ),
  );
}
