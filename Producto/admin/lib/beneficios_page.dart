import 'package:flutter/material.dart';

import 'admin_supabase_service.dart';
import 'beneficio_logica.dart';
import 'imagen_elegida.dart';
import 'selector_imagen.dart';

const Color _azul = Color(0xFF0EA5E9);
const Color _gris = Color(0xFF64748B);
const Color _verde = Color(0xFF10B981);
const Color _ambar = Color(0xFFF59E0B);
const Color _rojo = Color(0xFFEF4444);

Color _colorEstado(EstadoBeneficio e) {
  switch (e) {
    case EstadoBeneficio.activo:
      return _verde;
    case EstadoBeneficio.programado:
      return _azul;
    case EstadoBeneficio.vencido:
      return _ambar;
    case EstadoBeneficio.inactivo:
      return _gris;
  }
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String _fechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "1 sep 2026 → 30 sep 2026", "Desde el 1 sep 2026", "Hasta el 30 sep 2026" o
/// "Sin fecha límite".
String _textoVigencia(Beneficio b) {
  final d = b.vigenciaDesde;
  final h = b.vigenciaHasta;
  if (d != null && h != null) return '${_fechaCorta(d)} → ${_fechaCorta(h)}';
  if (d != null) return 'Desde el ${_fechaCorta(d)}';
  if (h != null) return 'Hasta el ${_fechaCorta(h)}';
  return 'Sin fecha límite';
}

/// Sección "Beneficios y Alianzas" del panel (CU19): lista con su estado y
/// formulario para crear, editar, activar, desactivar y destacar beneficios. Lo
/// que se guarda aquí se refleja en la app de los conductores.
class BeneficiosPage extends StatefulWidget {
  const BeneficiosPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<BeneficiosPage> createState() => _BeneficiosPageState();
}

class _BeneficiosPageState extends State<BeneficiosPage> {
  late Stream<List<Beneficio>> _stream;
  final TextEditingController _busquedaCtrl = TextEditingController();
  String? _categoria;
  EstadoBeneficio? _estado;

  @override
  void initState() {
    super.initState();
    _stream = widget.service.streamBeneficios();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? _rojo : null, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _abrirFormulario({Beneficio? existente}) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioBeneficio(service: widget.service, existente: existente),
    );
    if (guardado == true && mounted) {
      _mensaje(existente == null ? 'Beneficio creado' : 'Beneficio actualizado');
    }
  }

  Future<void> _cambiar(Beneficio b, {bool? activo, bool? destacado}) async {
    try {
      await widget.service.cambiarEstadoBeneficio(b, activo: activo, destacado: destacado);
    } catch (_) {
      if (mounted) _mensaje('No se pudo actualizar. Revisa tu conexión e intenta de nuevo.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Beneficios y Alianzas',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                      SizedBox(height: 8),
                      Text(
                        'Crea y administra los beneficios que ven los conductores en la app.',
                        style: TextStyle(color: _gris, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _abrirFormulario(),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear nuevo beneficio'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFiltros(),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Beneficio>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) return _buildError();
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                  final todos = snap.data!;
                  final lista = filtrarBeneficios(
                    todos,
                    texto: _busquedaCtrl.text,
                    categoria: _categoria,
                    estado: _estado,
                  );

                  if (todos.isEmpty) return _buildVacio('Aún no hay beneficios. Crea el primero.');
                  if (lista.isEmpty) return _buildVacio('Ningún beneficio coincide con los filtros.');

                  return ListView.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _buildFila(lista[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por título o comercio',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            initialValue: _categoria,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
              for (final e in kCategoriasBeneficio.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _categoria = v),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<EstadoBeneficio?>(
            initialValue: _estado,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<EstadoBeneficio?>(value: null, child: Text('Todos')),
              for (final e in EstadoBeneficio.values)
                DropdownMenuItem<EstadoBeneficio?>(value: e, child: Text(etiquetaEstadoBeneficio(e))),
            ],
            onChanged: (v) => setState(() => _estado = v),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: _gris),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar los beneficios. Revisa tu conexión e intenta de nuevo.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _stream = widget.service.streamBeneficios()),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard_outlined, size: 56, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(mensaje, style: const TextStyle(color: _gris, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFila(Beneficio b) {
    final estado = estadoBeneficio(b);
    final color = _colorEstado(estado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFFF1F5F9),
                child: b.imagenUrl != null
                    ? Image.network(
                        b.imagenUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: _gris),
                      )
                    : const Icon(Icons.image_outlined, color: _gris),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          b.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      if (b.destacado)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.star, color: _ambar, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(b.comercio, style: const TextStyle(color: _gris)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(etiquetaCategoria(b.categoria)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(_textoVigencia(b), style: const TextStyle(color: _gris)),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    etiquetaEstadoBeneficio(estado),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: b.destacado ? 'Quitar de destacados' : 'Marcar como destacado',
              onPressed: () => _cambiar(b, destacado: !b.destacado),
              icon: Icon(b.destacado ? Icons.star : Icons.star_border, color: b.destacado ? _ambar : _gris),
            ),
            Tooltip(
              message: b.activo ? 'Desactivar' : 'Activar',
              child: Switch(value: b.activo, onChanged: (v) => _cambiar(b, activo: v)),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: () => _abrirFormulario(existente: b),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario para crear o editar un beneficio.
///  - E1: la fecha de término anterior a la de inicio bloquea el guardado.
///  - E2: faltan campos obligatorios (título, comercio o categoría).
///  - E3: error al subir la imagen (formato o peso no válidos).
class _FormularioBeneficio extends StatefulWidget {
  const _FormularioBeneficio({required this.service, this.existente});

  final AdminSupabaseService service;
  final Beneficio? existente;

  @override
  State<_FormularioBeneficio> createState() => _FormularioBeneficioState();
}

class _FormularioBeneficioState extends State<_FormularioBeneficio> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _comercioCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _ubicacionCtrl;
  late final TextEditingController _condicionesCtrl;
  late final TextEditingController _codigoCtrl;
  String? _categoria;
  DateTime? _desde;
  DateTime? _hasta;
  bool _destacado = false;
  bool _activo = true;

  /// Imagen nueva elegida (aún sin subir) y la que ya tenía el beneficio.
  ImagenElegida? _imagenNueva;
  String? _imagenActual;
  bool _quitarImagen = false;

  Map<String, String> _errores = {};
  String? _errorImagen;
  String? _errorGuardado;
  bool _guardando = false;

  bool get _esEdicion => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _tituloCtrl = TextEditingController(text: e?.titulo ?? '');
    _comercioCtrl = TextEditingController(text: e?.comercio ?? '');
    _descripcionCtrl = TextEditingController(text: e?.descripcion ?? '');
    _ubicacionCtrl = TextEditingController(text: e?.ubicacion ?? '');
    _condicionesCtrl = TextEditingController(text: e?.condiciones ?? '');
    _codigoCtrl = TextEditingController(text: e?.codigoCanje ?? '');
    _categoria = e?.categoria;
    _desde = e?.vigenciaDesde;
    _hasta = e?.vigenciaHasta;
    _destacado = e?.destacado ?? false;
    _activo = e?.activo ?? true;
    _imagenActual = e?.imagenUrl;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _comercioCtrl.dispose();
    _descripcionCtrl.dispose();
    _ubicacionCtrl.dispose();
    _condicionesCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({required bool inicio}) async {
    final actual = inicio ? _desde : _hasta;
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? hoy,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year + 10),
    );
    if (elegida != null) {
      setState(() {
        if (inicio) {
          _desde = elegida;
        } else {
          _hasta = elegida;
        }
        _errores.remove('vigencia');
      });
    }
  }

  Future<void> _elegirImagen() async {
    try {
      final imagen = await elegirImagen();
      if (imagen == null || !mounted) return;

      // E3: se valida el formato y el peso antes de intentar subirla.
      final problema = validarImagenBeneficio(nombre: imagen.nombre, bytes: imagen.bytes.length);
      setState(() {
        if (problema != null) {
          _errorImagen = problema;
        } else {
          _errorImagen = null;
          _imagenNueva = imagen;
          _quitarImagen = false;
        }
      });
    } on UnsupportedError {
      if (mounted) setState(() => _errorImagen = 'Elegir imágenes solo está disponible en el panel web.');
    } catch (_) {
      if (mounted) setState(() => _errorImagen = 'No se pudo leer la imagen. Intenta con otro archivo.');
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final errores = validarBeneficio(
      titulo: _tituloCtrl.text,
      comercio: _comercioCtrl.text,
      categoria: _categoria,
      vigenciaDesde: _desde,
      vigenciaHasta: _hasta,
    );
    if (errores.isNotEmpty) {
      setState(() {
        _errores = errores;
        _errorGuardado = null;
      });
      return;
    }

    setState(() {
      _errores = {};
      _guardando = true;
      _errorGuardado = null;
    });

    String? urlImagen = _quitarImagen ? null : _imagenActual;
    final nueva = _imagenNueva;
    if (nueva != null) {
      try {
        urlImagen = await widget.service.subirImagenBeneficio(bytes: nueva.bytes, nombre: nueva.nombre);
      } catch (_) {
        // E3: Storage rechazó la imagen. No se guarda nada hasta que se corrija.
        if (mounted) {
          setState(() {
            _guardando = false;
            _errorImagen = 'No se pudo subir la imagen. Revisa que sea JPG, PNG o WebP y pese menos de 2 MB.';
          });
        }
        return;
      }
    }

    final beneficio = Beneficio(
      id: widget.existente?.id ?? '',
      titulo: _tituloCtrl.text,
      comercio: _comercioCtrl.text,
      categoria: _categoria,
      descripcion: _descripcionCtrl.text,
      ubicacion: _ubicacionCtrl.text,
      condiciones: _condicionesCtrl.text,
      codigoCanje: _codigoCtrl.text,
      imagenUrl: urlImagen,
      vigenciaDesde: _desde,
      vigenciaHasta: _hasta,
      destacado: _destacado,
      activo: _activo,
    );

    try {
      await widget.service.guardarBeneficio(beneficio);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      // Los datos siguen en el formulario para poder reintentar.
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
    final hayImagen = !_quitarImagen && (_imagenNueva != null || _imagenActual != null);

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar beneficio' : 'Crear nuevo beneficio'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _tituloCtrl,
                decoration: InputDecoration(
                  labelText: 'Título *',
                  border: const OutlineInputBorder(),
                  errorText: _errores['titulo'],
                ),
                onChanged: (_) => setState(() => _errores.remove('titulo')),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _comercioCtrl,
                      decoration: InputDecoration(
                        labelText: 'Comercio *',
                        border: const OutlineInputBorder(),
                        errorText: _errores['comercio'],
                      ),
                      onChanged: (_) => setState(() => _errores.remove('comercio')),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: InputDecoration(
                        labelText: 'Categoría *',
                        border: const OutlineInputBorder(),
                        errorText: _errores['categoria'],
                      ),
                      items: [
                        for (final e in kCategoriasBeneficio.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() {
                        _categoria = v;
                        _errores.remove('categoria');
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descripcionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ubicacionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ubicación aplicable (opcional)',
                  hintText: 'Ej: Santiago, Región Metropolitana',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Vigencia', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _campoFecha('Desde', _desde, () => _elegirFecha(inicio: true), () => setState(() => _desde = null))),
                  const SizedBox(width: 14),
                  Expanded(child: _campoFecha('Hasta', _hasta, () => _elegirFecha(inicio: false), () => setState(() => _hasta = null))),
                ],
              ),
              if (_errores['vigencia'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_errores['vigencia']!, style: const TextStyle(color: _rojo, fontSize: 13)),
                ),
              const SizedBox(height: 18),
              TextField(
                controller: _condicionesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Términos y condiciones (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codigoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código o forma de canje (opcional)',
                  hintText: 'Ej: Código TAGOK10, o "Muestra la app en caja"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Imagen', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 96,
                      height: 96,
                      color: const Color(0xFFF1F5F9),
                      child: !hayImagen
                          ? const Icon(Icons.image_outlined, color: _gris, size: 32)
                          : (_imagenNueva != null
                              ? Image.memory(_imagenNueva!.bytes, fit: BoxFit.cover)
                              : Image.network(
                                  _imagenActual!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: _gris),
                                )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _guardando ? null : _elegirImagen,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text(hayImagen ? 'Cambiar imagen' : 'Elegir imagen'),
                      ),
                      if (hayImagen)
                        TextButton(
                          onPressed: () => setState(() {
                            _imagenNueva = null;
                            _quitarImagen = true;
                            _errorImagen = null;
                          }),
                          child: const Text('Quitar imagen'),
                        ),
                      const Text('JPG, PNG o WebP · máximo 2 MB', style: TextStyle(color: _gris, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              if (_errorImagen != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorImagen!, style: const TextStyle(color: _rojo, fontSize: 13)),
                ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Destacado'),
                subtitle: const Text('Aparece primero en la app'),
                value: _destacado,
                onChanged: (v) => setState(() => _destacado = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                subtitle: const Text('Los conductores solo ven los beneficios activos y vigentes'),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
              if (_errorGuardado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorGuardado!, style: const TextStyle(color: _rojo, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_errorGuardado != null ? 'Reintentar' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _campoFecha(String etiqueta, DateTime? valor, VoidCallback alElegir, VoidCallback alQuitar) {
    return InkWell(
      onTap: alElegir,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          border: OutlineInputBorder(borderSide: BorderSide(color: _errores['vigencia'] != null ? _rojo : Colors.grey)),
          suffixIcon: valor != null
              ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: alQuitar)
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(valor != null ? _fechaCorta(valor) : 'Sin definir', style: TextStyle(color: valor != null ? null : _gris)),
      ),
    );
  }
}
