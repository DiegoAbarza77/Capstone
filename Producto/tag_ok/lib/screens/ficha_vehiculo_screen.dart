import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/services/vehiculo_documentos_service.dart';
import '../data/services/vehiculo_service.dart';
import 'combustible_screen.dart';
import 'documentos_vehiculo_screen.dart';
import 'vehiculo_edicion.dart';

const Color _bgColor = Color(0xFF0F172A);
const Color _primaryColor = Color(0xFF4F46E5);
const Color _navBgColor = Color(0xFF1E293B);
const Color _textMuted = Color(0xFF94A3B8);
const Color _textMain = Color(0xFFF8FAFC);
const Color _accentColor = Color(0xFF10B981);
const Color _iaColor = Color(0xFF8B5CF6);

/// Color asociado a cada estado de vencimiento (verde, ámbar, rojo, gris).
Color colorEstadoVencimiento(EstadoVencimiento estado) {
  switch (estado) {
    case EstadoVencimiento.alDia:
      return _accentColor;
    case EstadoVencimiento.atencion:
      return const Color(0xFFF59E0B);
    case EstadoVencimiento.vencido:
      return const Color(0xFFEF4444);
    case EstadoVencimiento.sinDatos:
      return _textMuted;
  }
}

/// Ficha central del vehículo: datos, estado general, documentos con su
/// vencimiento y accesos a los demás módulos. Reemplaza al cuadro emergente
/// que antes mostraba la información al tocar un vehículo de la lista.
class FichaVehiculoScreen extends StatefulWidget {
  final String vehiculoId;

  const FichaVehiculoScreen({
    super.key,
    required this.vehiculoId,
  });

  @override
  State<FichaVehiculoScreen> createState() => _FichaVehiculoScreenState();
}

class _FichaVehiculoScreenState extends State<FichaVehiculoScreen> {
  final VehiculoDocumentosService _documentosService = VehiculoDocumentosService();

  // Se crean una sola vez: si se armaran dentro de build(), cada redibujado
  // volvería a suscribirse y la pantalla parpadearía en "cargando".
  late final Stream<List<Map<String, dynamic>>> _vehiculoStream;
  late final Stream<List<DocumentoVehiculoModel>> _documentosStream;

  @override
  void initState() {
    super.initState();
    _vehiculoStream = Supabase.instance.client
        .from('vehiculos')
        .stream(primaryKey: ['id']).eq('id', widget.vehiculoId);
    _documentosStream = _documentosService.streamDocumentos(widget.vehiculoId);
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> vehiculo) async {
    final patente = (vehiculo['patente'] ?? '').toString();
    final alias = (vehiculo['alias'] as String?)?.trim();
    final nombre = alias != null && alias.isNotEmpty ? '$alias ($patente)' : patente;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _navBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar vehículo', style: TextStyle(color: _textMain)),
        content: Text(
          'Se eliminará $nombre junto con sus documentos, cargas de combustible y demás registros. Esta acción no se puede deshacer.',
          style: const TextStyle(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await VehiculoService().eliminar(vehiculoId: widget.vehiculoId, patente: patente);
      messenger.showSnackBar(
        const SnackBar(content: Text('Vehículo eliminado'), behavior: SnackBarBehavior.floating),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(mensajeErrorVehiculo(e)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _vehiculoStream,
      builder: (context, snapshot) {
        final vehiculo = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;

        return Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: _bgColor,
            elevation: 0,
            title: const Text('Mi vehículo', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (vehiculo != null) ...[
                IconButton(
                  tooltip: 'Editar vehículo',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => mostrarFormularioEditarVehiculo(context, vehiculo),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  color: _navBgColor,
                  onSelected: (valor) {
                    if (valor == 'eliminar') _confirmarEliminar(vehiculo);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text('Eliminar vehículo', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: _buildCuerpo(context, snapshot, vehiculo),
        );
      },
    );
  }

  Widget _buildCuerpo(
    BuildContext context,
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
    Map<String, dynamic>? vehiculo,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo cargar el vehículo. Revisa tu conexión e intenta de nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMain.withValues(alpha: 0.8)),
          ),
        ),
      );
    }
    if (vehiculo == null) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Text('Este vehículo ya no existe.', style: TextStyle(color: _textMuted)),
      );
    }

    final patente = (vehiculo['patente'] ?? '').toString();

    return StreamBuilder<List<DocumentoVehiculoModel>>(
      stream: _documentosStream,
      builder: (context, docsSnapshot) {
        final documentos = docsSnapshot.data ?? [];
        final estadoGeneral = documentos.isEmpty
            ? EstadoVencimiento.sinDatos
            : peorEstado(documentos.map((d) => d.estado).toList());

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildEncabezado(vehiculo, estadoGeneral),
            const SizedBox(height: 16),
            _buildDatos(vehiculo),
            const SizedBox(height: 24),
            const Text('Documentos', style: TextStyle(color: _textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            if (docsSnapshot.connectionState == ConnectionState.waiting && documentos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...documentos.map((doc) => _buildDocumento(context, doc, patente)),
            const SizedBox(height: 4),
            _buildBloqueIA(context, patente),
            const SizedBox(height: 20),
            _buildAccesos(context, patente),
            const SizedBox(height: 12),
            if (vehiculo['fecha_ingreso'] != null)
              Center(
                child: Text(
                  'Ingresado el ${_formatearFecha(vehiculo['fecha_ingreso'])}',
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEncabezado(Map<String, dynamic> vehiculo, EstadoVencimiento estadoGeneral) {
    final alias = (vehiculo['alias'] as String?)?.trim();
    final patente = (vehiculo['patente'] ?? '').toString();
    final titulo = alias != null && alias.isNotEmpty ? alias : patente;
    final marca = vehiculo['marca']?.toString();
    final modelo = vehiculo['modelo']?.toString();
    final descripcion = [
      if (marca != null && marca.isNotEmpty && marca != 'No especificada') marca,
      if (modelo != null && modelo.isNotEmpty) modelo,
    ].join(' ');
    final color = colorEstadoVencimiento(estadoGeneral);
    final fotoUrl = vehiculo['foto_url'] as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: _textMain, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                descripcion.isEmpty ? patente : '$descripcion · $patente',
                style: const TextStyle(color: _textMuted, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labelEstadoGeneralVehiculo(estadoGeneral),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 84,
            height: 84,
            color: _navBgColor,
            child: fotoUrl != null && fotoUrl.isNotEmpty
                ? Image.network(
                    fotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _fotoVacia(),
                  )
                : _fotoVacia(),
          ),
        ),
      ],
    );
  }

  Widget _fotoVacia() =>
      const Icon(Icons.directions_car_outlined, color: _textMuted, size: 36);

  Widget _buildDatos(Map<String, dynamic> vehiculo) {
    final km = vehiculo['kilometraje'] as num?;
    final kmTexto = km != null ? '${NumberFormat.decimalPattern('es').format(km.round())} km' : '—';
    final datos = <(String, String)>[
      ('Tipo', (vehiculo['categoria'] ?? '—').toString()),
      ('Combustible', (vehiculo['tipo_combustible'] ?? '—').toString()),
      ('Año', vehiculo['anio']?.toString() ?? '—'),
      ('Kilometraje', kmTexto),
    ];

    return Row(
      children: [
        for (var i = 0; i < datos.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: _navBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Text(datos[i].$1, style: const TextStyle(color: _textMuted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    datos[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumento(BuildContext context, DocumentoVehiculoModel doc, String patente) {
    final color = colorEstadoVencimiento(doc.estado);
    return Card(
      color: _navBgColor,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentosVehiculoScreen(
              vehiculoId: widget.vehiculoId,
              patente: patente,
              tipoInicial: doc.tipo,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  doc.label,
                  style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                doc.textoVencimiento,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: _textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBloqueIA(BuildContext context, String patente) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentosVehiculoScreen(
            vehiculoId: widget.vehiculoId,
            patente: patente,
            iniciarConIA: true,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _iaColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _iaColor.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: _iaColor, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agregar documento con IA',
                    style: TextStyle(color: _iaColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Fotografiar → revisar → guardar',
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesos(BuildContext context, String patente) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentColor,
              side: const BorderSide(color: _accentColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CombustibleScreen(vehiculoId: widget.vehiculoId, patente: patente),
              ),
            ),
            icon: const Icon(Icons.local_gas_station_outlined),
            label: const Text('Combustible'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: const BorderSide(color: _primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentosVehiculoScreen(vehiculoId: widget.vehiculoId, patente: patente),
              ),
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Documentos'),
          ),
        ),
      ],
    );
  }

  String _formatearFecha(dynamic valor) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(valor.toString()).toLocal());
    } catch (_) {
      return valor.toString();
    }
  }
}
