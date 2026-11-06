import 'package:flutter/material.dart';

import 'admin_supabase_service.dart';
import 'usuario_datos_logica.dart';

const Color _tinta = Color(0xFF0F172A);
const Color _gris = Color(0xFF64748B);
const Color _borde = Color(0xFFE2E8F0);
const Color _fondoSuave = Color(0xFFF8FAFC);
const Color _azul = Color(0xFF0EA5E9);
const Color _verde = Color(0xFF10B981);
const Color _ambar = Color(0xFFF59E0B);
const Color _rojo = Color(0xFFEF4444);
const Color _violeta = Color(0xFF8B5CF6);

/// Muestra, solo para leer, lo que un conductor ha registrado en la app
/// (CU18, gestión de cuentas): vehículos con sus documentos, mantenciones,
/// combustible y estacionamientos.
Future<void> mostrarDatosUsuario(
  BuildContext context, {
  required AdminSupabaseService service,
  required String usuarioId,
  required String nombre,
  required String correo,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => UsuarioDatosDialog(service: service, usuarioId: usuarioId, nombre: nombre, correo: correo),
  );
}

class UsuarioDatosDialog extends StatefulWidget {
  const UsuarioDatosDialog({
    super.key,
    required this.service,
    required this.usuarioId,
    required this.nombre,
    required this.correo,
  });

  final AdminSupabaseService service;
  final String usuarioId;
  final String nombre;
  final String correo;

  @override
  State<UsuarioDatosDialog> createState() => _UsuarioDatosDialogState();
}

class _UsuarioDatosDialogState extends State<UsuarioDatosDialog> {
  late Future<DatosUsuario> _futuro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futuro = widget.service.fetchDatosUsuario(usuarioId: widget.usuarioId, nombre: widget.nombre);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _encabezado(context),
            const Divider(height: 1, color: _borde),
            Flexible(
              child: FutureBuilder<DatosUsuario>(
                future: _futuro,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: _rojo, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudieron cargar los datos: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _gris),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: () => setState(_cargar), child: const Text('Reintentar')),
                        ],
                      ),
                    );
                  }
                  return _contenido(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos registrados en la app',
                  style: TextStyle(color: _gris, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _tinta, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(widget.correo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gris)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, color: _gris),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _contenido(DatosUsuario datos) {
    if (datos.estaVacio) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: Text(
            'Este usuario todavía no ha registrado nada en la app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _gris),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _resumen(datos),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _azul,
            unselectedLabelColor: _gris,
            indicatorColor: _azul,
            tabs: [
              Tab(text: 'Vehículos y documentos'),
              Tab(text: 'Mantenciones'),
              Tab(text: 'Combustible'),
              Tab(text: 'Estacionamientos'),
            ],
          ),
          const Divider(height: 1, color: _borde),
          Flexible(
            child: SizedBox(
              height: 420,
              child: TabBarView(
                children: [
                  _pestanaVehiculos(datos),
                  _pestanaLista(
                    datos.mantenciones,
                    vacio: 'Sin mantenciones registradas.',
                    nota: datos.hayRegistrosOcultos ? _notaLimite : null,
                    itemBuilder: _mantencion,
                  ),
                  _pestanaLista(
                    datos.cargas,
                    vacio: 'Sin cargas de combustible registradas.',
                    nota: datos.hayRegistrosOcultos ? _notaLimite : null,
                    itemBuilder: _carga,
                  ),
                  _pestanaLista(
                    datos.estacionamientos,
                    vacio: 'Sin estacionamientos registrados.',
                    nota: datos.hayRegistrosOcultos ? _notaLimite : null,
                    itemBuilder: _estacionamiento,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const String _notaLimite = 'Se muestran los últimos ${DatosUsuario.limiteFilas} registros de cada módulo.';

  // ── Resumen ─────────────────────────────────────────────────────────

  Widget _resumen(DatosUsuario datos) {
    final alertas = datos.documentosConAlerta();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _dato('Vehículos', '${datos.vehiculos.length}', _azul),
          _dato(
            'Documentos con alerta',
            '$alertas',
            alertas > 0 ? _ambar : _verde,
          ),
          _dato('Gasto en mantenciones', formatoPesos(datos.gastoMantenciones), _violeta),
          _dato('Gasto en combustible', formatoPesos(datos.gastoCombustible), _verde),
          _dato('Gasto en estacionamientos', formatoPesos(datos.gastoEstacionamientos), _azul),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fondoSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(titulo, style: const TextStyle(color: _gris, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Vehículos y documentos ──────────────────────────────────────────

  Widget _pestanaVehiculos(DatosUsuario datos) {
    if (datos.vehiculos.isEmpty) {
      return const Center(child: Text('Sin vehículos registrados.', style: TextStyle(color: _gris)));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [for (final vehiculo in datos.vehiculos) _vehiculo(vehiculo, datos)],
    );
  }

  Widget _vehiculo(Map<String, dynamic> vehiculo, DatosUsuario datos) {
    final patente = (vehiculo['patente'] ?? 'Sin patente').toString();
    final titulo = [vehiculo['marca'], vehiculo['modelo'], vehiculo['anio']]
        .where((e) => e != null && e.toString().trim().isNotEmpty && e.toString() != 'No especificada')
        .join(' ');
    final km = vehiculo['kilometraje'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_filled_outlined, color: _gris, size: 20),
              const SizedBox(width: 8),
              Text(patente, style: const TextStyle(color: _tinta, fontSize: 16, fontWeight: FontWeight.bold)),
              if (titulo.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(titulo, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gris)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (vehiculo['categoria'] != null) _pildora(vehiculo['categoria'].toString(), _gris),
              if (vehiculo['tipo_combustible'] != null) _pildora(vehiculo['tipo_combustible'].toString(), _gris),
              if (km != null) _pildora('${formatoCantidad(km)} km', _gris),
            ],
          ),
          const SizedBox(height: 12),
          for (final doc in datos.documentosDe(vehiculo['id'].toString())) _documento(doc),
        ],
      ),
    );
  }

  Widget _documento(Map<String, dynamic> doc) {
    final vence = DateTime.tryParse(doc['fecha_vencimiento']?.toString() ?? '');
    final estado = estadoDocumento(vence);
    final color = _colorEstado(estado);
    final detalle = [
      if ((doc['numero'] ?? '').toString().isNotEmpty) 'N° ${doc['numero']}',
      if ((doc['compania'] ?? '').toString().isNotEmpty) doc['compania'].toString(),
      if (vence != null) 'Vence ${formatoFecha(doc['fecha_vencimiento'])}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        kEtiquetaDocumento[doc['tipo']] ?? doc['tipo'].toString(),
                        style: const TextStyle(color: _tinta, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (doc['origen'] == 'ia') ...[const SizedBox(width: 6), _pildora('IA', _violeta)],
                  ],
                ),
                if (detalle.isNotEmpty) Text(detalle, style: const TextStyle(color: _gris, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _pildora(etiquetaEstadoDocumento(estado), color),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoDocumento estado) {
    switch (estado) {
      case EstadoDocumento.alDia:
        return _verde;
      case EstadoDocumento.porVencer:
        return _ambar;
      case EstadoDocumento.vencido:
        return _rojo;
      case EstadoDocumento.sinDatos:
        return _gris;
    }
  }

  // ── Listas de registros ─────────────────────────────────────────────

  Widget _pestanaLista(
    List<Map<String, dynamic>> filas, {
    required String vacio,
    required Widget Function(Map<String, dynamic>) itemBuilder,
    String? nota,
  }) {
    if (filas.isEmpty) {
      return Center(child: Text(vacio, style: const TextStyle(color: _gris)));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (nota != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(nota, style: const TextStyle(color: _gris, fontSize: 12)),
          ),
        for (final fila in filas) itemBuilder(fila),
      ],
    );
  }

  Widget _tarjeta({
    required String titulo,
    required String subtitulo,
    required String monto,
    List<Widget> etiquetas = const [],
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        titulo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _tinta, fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final e in etiquetas) ...[const SizedBox(width: 6), e],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitulo, style: const TextStyle(color: _gris, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(monto, style: const TextStyle(color: _tinta, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _mantencion(Map<String, dynamic> m) {
    final titulo = (m['descripcion'] ?? '').toString().trim().isNotEmpty
        ? m['descripcion'].toString()
        : (m['tipo'] ?? 'Mantención').toString();
    final subtitulo = [
      formatoFecha(m['fecha']),
      if ((m['taller'] ?? '').toString().isNotEmpty) m['taller'].toString(),
      if (m['kilometraje'] != null) '${formatoCantidad(m['kilometraje'])} km',
    ].join(' · ');
    return _tarjeta(
      titulo: titulo,
      subtitulo: subtitulo,
      monto: formatoPesos(m['costo'] is num ? m['costo'] as num : 0),
      etiquetas: [if (m['origen'] == 'ia') _pildora('IA', _violeta)],
    );
  }

  Widget _carga(Map<String, dynamic> c) {
    final unidad = c['unidad'] == 'kwh' ? 'kWh' : 'L';
    final subtitulo = [
      formatoFecha(c['fecha']),
      '${formatoCantidad(c['litros'])} $unidad',
      if ((c['tipo_combustible'] ?? '').toString().isNotEmpty) c['tipo_combustible'].toString(),
      if (c['kilometraje'] != null) '${formatoCantidad(c['kilometraje'])} km',
    ].join(' · ');
    return _tarjeta(
      titulo: (c['estacion'] ?? '').toString().isNotEmpty ? c['estacion'].toString() : 'Carga de combustible',
      subtitulo: subtitulo,
      monto: formatoPesos(c['total'] is num ? c['total'] as num : 0),
      etiquetas: [
        if (c['tanque_lleno'] == true) _pildora('Estanque lleno', _azul),
        if (c['origen'] == 'ia') _pildora('IA', _violeta),
      ],
    );
  }

  Widget _estacionamiento(Map<String, dynamic> e) {
    final lugar = (e['lugar'] ?? '').toString().trim();
    final direccion = (e['direccion'] ?? '').toString().trim();
    final subtitulo = [
      formatoFecha(e['fecha']),
      if (direccion.isNotEmpty && direccion != lugar) direccion,
      if (e['duracion_minutos'] != null) formatoDuracion(e['duracion_minutos']),
    ].join(' · ');
    return _tarjeta(
      titulo: lugar.isNotEmpty ? lugar : 'Estacionamiento',
      subtitulo: subtitulo,
      monto: formatoPesos(e['costo'] is num ? e['costo'] as num : 0),
      etiquetas: [
        if (e['en_curso'] == true) _pildora('En curso', _ambar),
        if (e['origen'] == 'ia') _pildora('IA', _violeta),
      ],
    );
  }

  Widget _pildora(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
