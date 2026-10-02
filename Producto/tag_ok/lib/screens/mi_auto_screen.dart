import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/services/vehiculo_documentos_service.dart';
import 'combustible_screen.dart';
import 'documentos_vehiculo_screen.dart';
import 'ficha_vehiculo_screen.dart';
import 'vehiculos_screen.dart';

const Color _bgColor = Color(0xFF0F172A);
const Color _primaryColor = Color(0xFF4F46E5);
const Color _navBgColor = Color(0xFF1E293B);
const Color _textMuted = Color(0xFF94A3B8);
const Color _textMain = Color(0xFFF8FAFC);
const Color _accentColor = Color(0xFF10B981);

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
      _vehiculosStream = Supabase.instance.client
          .from('vehiculos')
          .stream(primaryKey: ['id']).eq('usuario_id', user.id);
      _usuarioStream = Supabase.instance.client
          .from('usuarios')
          .stream(primaryKey: ['id']).eq('id', user.id);
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

  String get _vehiculoId => widget.vehiculo['id'] as String;
  String get _patente => (widget.vehiculo['patente'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _documentosStream = VehiculoDocumentosService().streamDocumentos(_vehiculoId);
  }

  void _ir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  void _proximamente(String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$modulo estará disponible pronto.'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentoVehiculoModel>>(
      stream: _documentosStream,
      builder: (context, snapshot) {
        final documentos = snapshot.data ?? [];
        final estadoGeneral = documentos.isEmpty
            ? EstadoVencimiento.sinDatos
            : peorEstado(documentos.map((d) => d.estado).toList());
        final conAviso = documentos
            .where((d) => d.estado == EstadoVencimiento.vencido || d.estado == EstadoVencimiento.atencion)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumen(estadoGeneral),
            if (conAviso.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAlertas(conAviso),
            ],
            const SizedBox(height: 24),
            const Text('Módulos', style: TextStyle(color: _textMuted, fontSize: 13)),
            const SizedBox(height: 10),
            _buildModulos(documentos),
          ],
        );
      },
    );
  }

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

  Widget _buildAlertas(List<DocumentoVehiculoModel> conAviso) {
    final hayVencido = conAviso.any((d) => d.estado == EstadoVencimiento.vencido);
    final color = colorEstadoVencimiento(hayVencido ? EstadoVencimiento.vencido : EstadoVencimiento.atencion);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _ir(DocumentosVehiculoScreen(vehiculoId: _vehiculoId, patente: _patente)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(hayVencido ? Icons.error_outline : Icons.warning_amber_rounded, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final doc in conAviso)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${doc.label} · ${doc.textoVencimiento}',
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textMuted, size: 20),
          ],
        ),
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

  Widget _buildModulos(List<DocumentoVehiculoModel> documentos) {
    final (textoDocs, colorDocs) = _resumenDocumentos(documentos);

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
        subtitulo: 'Próximamente',
        color: const Color(0xFFF59E0B),
        proximamente: true,
        onTap: () => _proximamente('Mantenciones'),
      ),
      _ModuloTile(
        icono: Icons.local_parking_outlined,
        titulo: 'Estacionamientos',
        subtitulo: 'Próximamente',
        color: const Color(0xFF38BDF8),
        proximamente: true,
        onTap: () => _proximamente('Estacionamientos'),
      ),
      _ModuloTile(
        icono: Icons.card_giftcard_outlined,
        titulo: 'Beneficios',
        subtitulo: 'Próximamente',
        color: const Color(0xFFEC4899),
        proximamente: true,
        onTap: () => _proximamente('Beneficios'),
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

class _ModuloTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color? colorSubtitulo;
  final Color color;
  final bool proximamente;
  final VoidCallback onTap;

  const _ModuloTile({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
    this.colorSubtitulo,
    this.proximamente = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: proximamente ? 0.6 : 1,
      child: Material(
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
      ),
    );
  }
}
