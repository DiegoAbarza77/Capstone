import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/carga_combustible_model.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/models/estacionamiento_model.dart';
import '../data/models/trip_history.dart';
import '../data/services/beneficios_service.dart';
import '../data/services/cache_offline.dart';
import '../data/services/combustible_service.dart';
import '../data/services/history_service.dart';
import '../data/services/estacionamiento_service.dart';
import '../utils/dashboard_resumen.dart';
import '../utils/estacionamiento_calculos.dart';
import '../utils/numero_chile.dart';
import '../data/models/mantencion_model.dart';
import '../data/services/mantencion_service.dart';
import '../data/services/vehiculo_documentos_service.dart';
import '../utils/mantencion_calculos.dart';
import 'beneficios_screen.dart';
import 'combustible_form_screen.dart';
import 'combustible_screen.dart';
import 'documentos_vehiculo_screen.dart';
import 'estacionamiento_form_screen.dart';
import 'estacionamientos_screen.dart';
import 'ficha_vehiculo_screen.dart';
import 'mantencion_form_screen.dart';
import 'mantencion_ui.dart';
import 'mantenciones_screen.dart';
import 'vehiculos_screen.dart';

const Color _bgColor = Color(0xFF0F172A);
const Color _primaryColor = Color(0xFF4F46E5);
const Color _navBgColor = Color(0xFF1E293B);
const Color _textMuted = Color(0xFF94A3B8);
const Color _textMain = Color(0xFFF8FAFC);
const Color _accentColor = Color(0xFF10B981);
const Color _colorCronometro = Color(0xFF38BDF8);

/// Pestaña "Mi Auto": el punto de partida de todo lo relacionado con el
/// vehículo. Muestra el vehículo elegido con su estado y, debajo, los accesos
/// a cada módulo (documentos, combustible, mantenciones, estacionamientos,
/// beneficios) para que el usuario los encuentre en un solo lugar.
class MiAutoScreen extends StatefulWidget {
  const MiAutoScreen({super.key});

  @override
  State<MiAutoScreen> createState() => _MiAutoScreenState();
}

class _MiAutoScreenState extends State<MiAutoScreen> {
  Stream<List<Map<String, dynamic>>>? _vehiculosStream;
  Stream<List<Map<String, dynamic>>>? _usuarioStream;
  String? _vehiculoSeleccionadoId;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _vehiculosStream = CacheOffline.filas(
        'vehiculos',
        Supabase.instance.client.from('vehiculos').stream(primaryKey: ['id']).eq('usuario_id', user.id),
      );
      _usuarioStream = CacheOffline.filas(
        'usuario',
        Supabase.instance.client.from('usuarios').stream(primaryKey: ['id']).eq('id', user.id),
      );
    }
  }

  Map<String, dynamic> _resolverSeleccionado(
    List<Map<String, dynamic>> vehiculos,
    String? patentePrincipal,
  ) {
    if (_vehiculoSeleccionadoId != null) {
      for (final v in vehiculos) {
        if (v['id'] == _vehiculoSeleccionadoId) return v;
      }
    }
    if (patentePrincipal != null) {
      for (final v in vehiculos) {
        if (v['patente'] == patentePrincipal) return v;
      }
    }
    return vehiculos.first;
  }

  void _abrirMisVehiculos() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiculosScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final vehiculosStream = _vehiculosStream;
    final usuarioStream = _usuarioStream;
    if (vehiculosStream == null || usuarioStream == null) {
      return const Center(child: Text('No autenticado', style: TextStyle(color: _textMuted)));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: vehiculosStream,
      builder: (context, vehiculosSnap) {
        if (vehiculosSnap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar tus vehículos. Revisa tu conexión e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted),
              ),
            ),
          );
        }
        if (!vehiculosSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final vehiculos = vehiculosSnap.data!;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: usuarioStream,
          builder: (context, usuarioSnap) {
            final patentePrincipal = usuarioSnap.data?.isNotEmpty == true
                ? usuarioSnap.data!.first['vehiculo_principal_patente'] as String?
                : null;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                const Text(
                  'Mi Auto',
                  style: TextStyle(color: _textMain, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (vehiculos.isEmpty)
                  _buildSinVehiculos()
                else
                  ..._buildConVehiculos(vehiculos, patentePrincipal),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSinVehiculos() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _navBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          const Text(
            'Agrega tu primer vehículo',
            style: TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aquí verás sus documentos, gastos y alertas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _abrirMisVehiculos,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Agregar vehículo', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BeneficiosScreen())),
            icon: const Icon(Icons.card_giftcard_outlined, size: 18),
            label: const Text('Ver beneficios'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConVehiculos(List<Map<String, dynamic>> vehiculos, String? patentePrincipal) {
    final seleccionado = _resolverSeleccionado(vehiculos, patentePrincipal);

    // El principal primero, el resto por patente.
    final ordenados = [...vehiculos]..sort((a, b) {
        final aPrincipal = a['patente'] == patentePrincipal ? 0 : 1;
        final bPrincipal = b['patente'] == patentePrincipal ? 0 : 1;
        if (aPrincipal != bPrincipal) return aPrincipal.compareTo(bPrincipal);
        return (a['patente'] ?? '').toString().compareTo((b['patente'] ?? '').toString());
      });

    return [
      if (vehiculos.length > 1) ...[
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ordenados.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final v = ordenados[i];
              final activo = v['id'] == seleccionado['id'];
              final alias = (v['alias'] as String?)?.trim();
              final etiqueta = alias != null && alias.isNotEmpty ? alias : (v['patente'] ?? '').toString();
              return ChoiceChip(
                label: Text(etiqueta),
                selected: activo,
                onSelected: (_) => setState(() => _vehiculoSeleccionadoId = v['id']),
                selectedColor: _primaryColor,
                backgroundColor: _navBgColor,
                labelStyle: TextStyle(color: activo ? Colors.white : _textMuted, fontWeight: FontWeight.w600),
                side: BorderSide(color: activo ? _primaryColor : Colors.white.withValues(alpha: 0.08)),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
      _PanelVehiculo(
        key: ValueKey(seleccionado['id']),
        vehiculo: seleccionado,
        totalVehiculos: vehiculos.length,
        onMisVehiculos: _abrirMisVehiculos,
      ),
    ];
  }
}

/// Resumen del vehículo elegido y cuadrícula de módulos. Es un widget aparte,
/// con su propia clave, para crear una sola vez el flujo de documentos de ese
/// vehículo (al cambiar de vehículo se recrea con el flujo del nuevo).
class _PanelVehiculo extends StatefulWidget {
  final Map<String, dynamic> vehiculo;
  final int totalVehiculos;
  final VoidCallback onMisVehiculos;

  const _PanelVehiculo({
    super.key,
    required this.vehiculo,
    required this.totalVehiculos,
    required this.onMisVehiculos,
  });

  @override
  State<_PanelVehiculo> createState() => _PanelVehiculoState();
}

class _PanelVehiculoState extends State<_PanelVehiculo> {
  late final Stream<List<DocumentoVehiculoModel>> _documentosStream;
  late final Stream<List<MantencionProgramadaModel>> _programadasStream;
  late final Stream<List<EstacionamientoModel>> _estacionamientosStream;

  // Datos de apoyo para los gastos del mes. Si alguno falla, su categoría
  // queda en $0 y el resto del tablero sigue funcionando.
  final List<StreamSubscription<dynamic>> _suscripciones = [];
  List<CargaCombustibleModel> _cargas = const [];
  List<MantencionModel> _mantenciones = const [];
  List<TripHistory> _viajes = const [];
  List<EstacionamientoModel> _estacionamientos = const [];

  /// Cantidad de beneficios disponibles; null mientras carga o si falló.
  int? _beneficiosDisponibles;

  String get _vehiculoId => widget.vehiculo['id'] as String;
  String get _patente => (widget.vehiculo['patente'] ?? '').toString();
  double? get _kmActual => (widget.vehiculo['kilometraje'] as num?)?.toDouble();

  @override
  void initState() {
    super.initState();
    _documentosStream = VehiculoDocumentosService().streamDocumentos(_vehiculoId);
    _programadasStream = MantencionService().streamProgramadas(_vehiculoId);
    _estacionamientosStream = EstacionamientoService().streamPorVehiculo(_vehiculoId).asBroadcastStream();
    _escuchar(CombustibleService().streamPorVehiculo(_vehiculoId), (d) => _cargas = d);
    _escuchar(MantencionService().streamPorVehiculo(_vehiculoId), (d) => _mantenciones = d);
    _escuchar(HistoryService().getTripHistory(), (d) => _viajes = d);
    _escuchar(_estacionamientosStream, (d) => _estacionamientos = d);
    // Es solo un dato de apoyo para la tarjeta: si falla, la tarjeta sigue
    // funcionando y muestra el texto genérico.
    BeneficiosService().obtenerVigentes().then((lista) {
      if (mounted) setState(() => _beneficiosDisponibles = lista.length);
    }).catchError((_) {});
  }

  void _escuchar<T>(Stream<List<T>> flujo, void Function(List<T>) guardar) {
    _suscripciones.add(flujo.listen(
      (datos) {
        if (mounted) setState(() => guardar(datos));
      },
      onError: (_) {},
    ));
  }

  @override
  void dispose() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    super.dispose();
  }

  void _ir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentoVehiculoModel>>(
      stream: _documentosStream,
      builder: (context, snapshot) {
        final documentos = snapshot.data ?? [];
        return StreamBuilder<List<MantencionProgramadaModel>>(
          stream: _programadasStream,
          builder: (context, progSnap) {
            return StreamBuilder<List<EstacionamientoModel>>(
              stream: _estacionamientosStream,
              builder: (context, estSnap) {
                final estadoGeneral = documentos.isEmpty
                    ? EstadoVencimiento.sinDatos
                    : peorEstado(documentos.map((d) => d.estado).toList());

                // Mantenciones programadas pendientes, evaluadas contra hoy y el odómetro.
                final programadas = [
                  for (final p in (progSnap.data ?? const <MantencionProgramadaModel>[]).where((p) => !p.completada))
                    (p, evaluarProgramada(p, kmActual: _kmActual)),
                ];
                final enCurso = estacionamientoEnCurso(estSnap.data ?? const <EstacionamientoModel>[]);

                final avisos = <_Aviso>[
                  for (final d in documentos)
                    if (d.estado == EstadoVencimiento.vencido || d.estado == EstadoVencimiento.atencion)
                      _Aviso(
                        texto: '${d.label} · ${d.textoVencimiento}',
                        color: colorEstadoVencimiento(d.estado),
                        vencido: d.estado == EstadoVencimiento.vencido,
                        abrir: () => _ir(DocumentosVehiculoScreen(vehiculoId: _vehiculoId, patente: _patente)),
                      ),
                  for (final (p, e) in programadas)
                    if (e.estado != EstadoProgramada.alDia)
                      _Aviso(
                        texto: 'Mantención: ${p.titulo} · ${descripcionCriterios(p, e).join(' · ')}',
                        color: colorEstadoProgramada(e.estado),
                        vencido: e.estado == EstadoProgramada.vencida,
                        abrir: _abrirMantenciones,
                      ),
                  if (enCurso != null)
                    _Aviso(
                      texto: 'Estacionamiento en curso'
                          '${enCurso.horaEntrada != null ? ' · desde las ${formatoHora(enCurso.horaEntrada!)}' : ''}',
                      color: _colorCronometro,
                      vencido: false,
                      informativo: true,
                      abrir: _abrirEstacionamientos,
                    ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResumen(estadoGeneral),
                    if (avisos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAlertas(avisos),
                    ],
                    const SizedBox(height: 16),
                    _buildTarjetas(documentos, [for (final (_, e) in programadas) e]),
                    const SizedBox(height: 16),
                    _buildGastosMes(),
                    const SizedBox(height: 16),
                    _buildAccionesRapidas(),
                    const SizedBox(height: 24),
                    const Text('Módulos', style: TextStyle(color: _textMuted, fontSize: 13)),
                    const SizedBox(height: 10),
                    _buildModulos(documentos, [for (final (_, e) in programadas) e], enCurso != null),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTarjetas(List<DocumentoVehiculoModel> documentos, List<EvaluacionProgramada> evaluaciones) {
    final gastos = _gastosMes();
    final mantencion = resumenProximaMantencion(evaluaciones);
    final dias = diasProximoVencimiento(documentos);
    final String textoVenc;
    final bool vencUrgente;
    if (dias == null) {
      textoVenc = documentos.isEmpty ? 'Sin documentos' : 'Al día';
      vencUrgente = false;
    } else if (dias < 0) {
      textoVenc = 'Vencido';
      vencUrgente = true;
    } else {
      textoVenc = '$dias ${dias == 1 ? 'día' : 'días'}';
      vencUrgente = dias <= 30;
    }
    final beneficios = _beneficiosDisponibles;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        _TarjetaIndicador(
          valor: formatoPesos(gastos.total),
          etiqueta: 'Gasto movilidad este mes',
          color: _primaryColor,
        ),
        _TarjetaIndicador(
          valor: mantencion.texto,
          etiqueta: 'Próxima mantención',
          color: mantencion.urgente ? colorEstadoProgramada(EstadoProgramada.vencida) : const Color(0xFFF59E0B),
          onTap: _abrirMantenciones,
        ),
        _TarjetaIndicador(
          valor: textoVenc,
          etiqueta: 'Próximo vencimiento',
          color: vencUrgente ? colorEstadoVencimiento(EstadoVencimiento.vencido) : _accentColor,
          onTap: () => _ir(DocumentosVehiculoScreen(vehiculoId: _vehiculoId, patente: _patente)),
        ),
        _TarjetaIndicador(
          valor: beneficios == null ? '—' : '$beneficios',
          etiqueta: 'Beneficios disponibles',
          color: const Color(0xFFEC4899),
          onTap: () => _ir(const BeneficiosScreen()),
        ),
      ],
    );
  }

  GastosMes _gastosMes() => calcularGastosMes(
        mes: DateTime.now(),
        patente: _patente,
        viajes: _viajes,
        cargas: _cargas,
        estacionamientos: _estacionamientos,
        mantenciones: _mantenciones,
      );

  Widget _buildGastosMes() {
    final g = _gastosMes();
    final filas = [
      ('TAG', g.tag, _primaryColor),
      ('Combustible', g.combustible, _accentColor),
      ('Estacionamientos', g.estacionamientos, _colorCronometro),
      ('Mantenciones', g.mantenciones, const Color(0xFFF59E0B)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gastos del mes', style: TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final (nombre, monto, color) in filas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(nombre, style: const TextStyle(color: _textMuted, fontSize: 13))),
                      Text(
                        formatoPesos(monto),
                        style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(g.fraccion(monto) * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: _textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.fraccion(monto),
                      minHeight: 6,
                      color: color,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    Widget boton(IconData icono, String texto, VoidCallback onTap) => ActionChip(
          avatar: Icon(icono, size: 18, color: Colors.white),
          label: Text(texto),
          onPressed: onTap,
          backgroundColor: _navBgColor,
          labelStyle: const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
          side: BorderSide(color: _primaryColor.withValues(alpha: 0.5)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Acciones rápidas', style: TextStyle(color: _textMuted, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            boton(
              Icons.local_gas_station_outlined,
              'Registrar combustible',
              () => _ir(CombustibleFormScreen(
                vehiculoId: _vehiculoId,
                patente: _patente,
                combustibleDelVehiculo: widget.vehiculo['tipo_combustible'] as String?,
                kmActualVehiculo: _kmActual,
              )),
            ),
            boton(
              Icons.local_parking_outlined,
              'Registrar estacionamiento',
              () => _ir(EstacionamientoFormScreen(vehiculoId: _vehiculoId, patente: _patente)),
            ),
            boton(
              Icons.build_outlined,
              'Agregar mantención',
              () => _ir(MantencionFormScreen(
                vehiculoId: _vehiculoId,
                patente: _patente,
                kmActualVehiculo: _kmActual,
                historial: _mantenciones,
              )),
            ),
            boton(Icons.card_giftcard_outlined, 'Ver beneficios', () => _ir(const BeneficiosScreen())),
          ],
        ),
      ],
    );
  }

  void _abrirMantenciones() => _ir(MantencionesScreen(vehiculoId: _vehiculoId, patente: _patente));

  void _abrirEstacionamientos() => _ir(EstacionamientosScreen(vehiculoId: _vehiculoId, patente: _patente));

  Widget _buildResumen(EstadoVencimiento estadoGeneral) {
    final alias = (widget.vehiculo['alias'] as String?)?.trim();
    final titulo = alias != null && alias.isNotEmpty ? alias : _patente;
    final marca = widget.vehiculo['marca']?.toString();
    final modelo = widget.vehiculo['modelo']?.toString();
    final descripcion = [
      if (marca != null && marca.isNotEmpty && marca != 'No especificada') marca,
      if (modelo != null && modelo.isNotEmpty) modelo,
    ].join(' ');
    final color = colorEstadoVencimiento(estadoGeneral);
    final fotoUrl = widget.vehiculo['foto_url'] as String?;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _ir(FichaVehiculoScreen(vehiculoId: _vehiculoId)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _navBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: _bgColor,
              backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null || fotoUrl.isEmpty
                  ? const Icon(Icons.directions_car_outlined, color: _textMuted, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textMain, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descripcion.isEmpty ? _patente : '$descripcion · $_patente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      labelEstadoGeneralVehiculo(estadoGeneral),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertas(List<_Aviso> avisos) {
    final hayVencido = avisos.any((a) => a.vencido);
    final hayAtencion = avisos.any((a) => !a.informativo && !a.vencido);
    // Rojo si hay algo vencido, ámbar si hay algo por vencer y azul si solo hay
    // avisos informativos (por ejemplo, un estacionamiento en curso).
    final colorBorde = hayVencido
        ? colorEstadoVencimiento(EstadoVencimiento.vencido)
        : (hayAtencion ? colorEstadoVencimiento(EstadoVencimiento.atencion) : _colorCronometro);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: colorBorde.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorBorde.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (final aviso in avisos)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: aviso.abrir,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      aviso.informativo
                          ? Icons.timer_outlined
                          : (aviso.vencido ? Icons.error_outline : Icons.warning_amber_rounded),
                      color: aviso.color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        aviso.texto,
                        style: TextStyle(color: aviso.color, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _textMuted, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Resumen corto del estado de los documentos para la tarjeta del módulo.
  (String, Color) _resumenDocumentos(List<DocumentoVehiculoModel> documentos) {
    final vencidos = documentos.where((d) => d.estado == EstadoVencimiento.vencido).length;
    final porVencer = documentos.where((d) => d.estado == EstadoVencimiento.atencion).length;
    if (vencidos > 0) {
      return ('$vencidos ${vencidos == 1 ? 'vencido' : 'vencidos'}', colorEstadoVencimiento(EstadoVencimiento.vencido));
    }
    if (porVencer > 0) {
      return ('$porVencer por vencer', colorEstadoVencimiento(EstadoVencimiento.atencion));
    }
    if (documentos.isEmpty || documentos.every((d) => d.estado == EstadoVencimiento.sinDatos)) {
      return ('Sin datos', _textMuted);
    }
    return ('Todo al día', _accentColor);
  }

  /// Resumen corto de las mantenciones programadas para la tarjeta del módulo.
  (String, Color) _resumenMantenciones(List<EvaluacionProgramada> evaluaciones) {
    final vencidas = evaluaciones.where((e) => e.estado == EstadoProgramada.vencida).length;
    final proximas = evaluaciones.where((e) => e.estado == EstadoProgramada.proxima).length;
    if (vencidas > 0) {
      return ('$vencidas ${vencidas == 1 ? 'vencida' : 'vencidas'}', colorEstadoProgramada(EstadoProgramada.vencida));
    }
    if (proximas > 0) {
      return ('$proximas ${proximas == 1 ? 'próxima' : 'próximas'}', colorEstadoProgramada(EstadoProgramada.proxima));
    }
    return ('Historial y recordatorios', _textMuted);
  }

  Widget _buildModulos(
    List<DocumentoVehiculoModel> documentos,
    List<EvaluacionProgramada> mantenciones,
    bool estacionamientoEnCurso,
  ) {
    final (textoDocs, colorDocs) = _resumenDocumentos(documentos);
    final (textoMant, colorMant) = _resumenMantenciones(mantenciones);

    final tiles = [
      _ModuloTile(
        icono: Icons.description_outlined,
        titulo: 'Documentos',
        subtitulo: textoDocs,
        colorSubtitulo: colorDocs,
        color: _primaryColor,
        onTap: () => _ir(DocumentosVehiculoScreen(vehiculoId: _vehiculoId, patente: _patente)),
      ),
      _ModuloTile(
        icono: Icons.local_gas_station_outlined,
        titulo: 'Combustible',
        subtitulo: 'Cargas y gasto',
        color: _accentColor,
        onTap: () => _ir(CombustibleScreen(vehiculoId: _vehiculoId, patente: _patente)),
      ),
      _ModuloTile(
        icono: Icons.build_outlined,
        titulo: 'Mantenciones',
        subtitulo: textoMant,
        colorSubtitulo: colorMant,
        color: const Color(0xFFF59E0B),
        onTap: _abrirMantenciones,
      ),
      _ModuloTile(
        icono: Icons.local_parking_outlined,
        titulo: 'Estacionamientos',
        subtitulo: estacionamientoEnCurso ? 'En curso' : 'Cronómetro e historial',
        colorSubtitulo: estacionamientoEnCurso ? _colorCronometro : null,
        color: _colorCronometro,
        onTap: _abrirEstacionamientos,
      ),
      _ModuloTile(
        icono: Icons.card_giftcard_outlined,
        titulo: 'Beneficios',
        subtitulo: _beneficiosDisponibles == null
            ? 'Descuentos y alianzas'
            : (_beneficiosDisponibles == 0
                ? 'Sin beneficios por ahora'
                : '$_beneficiosDisponibles ${_beneficiosDisponibles == 1 ? 'disponible' : 'disponibles'}'),
        color: const Color(0xFFEC4899),
        onTap: () => _ir(const BeneficiosScreen()),
      ),
      _ModuloTile(
        icono: Icons.directions_car_outlined,
        titulo: 'Mis vehículos',
        subtitulo: '${widget.totalVehiculos} ${widget.totalVehiculos == 1 ? 'registrado' : 'registrados'}',
        color: _textMuted,
        onTap: widget.onMisVehiculos,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: tiles,
    );
  }
}

/// Una línea del recuadro de alertas: qué pasa, de qué color y a dónde lleva.
class _Aviso {
  final String texto;
  final Color color;
  final bool vencido;

  /// true para avisos que no son un problema (por ejemplo, un estacionamiento en curso).
  final bool informativo;
  final VoidCallback abrir;

  const _Aviso({
    required this.texto,
    required this.color,
    required this.vencido,
    required this.abrir,
    this.informativo = false,
  });
}

class _TarjetaIndicador extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final Color color;
  final VoidCallback? onTap;

  const _TarjetaIndicador({required this.valor, required this.etiqueta, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navBgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(etiqueta,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuloTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color? colorSubtitulo;
  final Color color;
  final VoidCallback onTap;

  const _ModuloTile({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
    this.colorSubtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navBgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorSubtitulo ?? _textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
