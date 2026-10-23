import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/documento_vehiculo_model.dart';
import '../data/services/vehiculo_documentos_service.dart';
import 'documento_detalle_screen.dart';

class DocumentosVehiculoScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  const DocumentosVehiculoScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
  });

  @override
  State<DocumentosVehiculoScreen> createState() => _DocumentosVehiculoScreenState();
}

class _DocumentosVehiculoScreenState extends State<DocumentosVehiculoScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color iaColor = const Color(0xFF8B5CF6);

  final VehiculoDocumentosService _service = VehiculoDocumentosService();

  Color _colorEstado(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.alDia:
        return const Color(0xFF10B981);
      case EstadoVencimiento.atencion:
        return const Color(0xFFF59E0B);
      case EstadoVencimiento.vencido:
        return const Color(0xFFEF4444);
      case EstadoVencimiento.sinDatos:
        return textMuted;
    }
  }

  String _labelEstado(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.alDia:
        return 'Al día';
      case EstadoVencimiento.atencion:
        return 'Por vencer';
      case EstadoVencimiento.vencido:
        return 'Vencido';
      case EstadoVencimiento.sinDatos:
        return 'Sin datos';
    }
  }

  IconData _iconoEstado(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.alDia:
        return Icons.check_circle;
      case EstadoVencimiento.atencion:
        return Icons.warning_amber_rounded;
      case EstadoVencimiento.vencido:
        return Icons.error;
      case EstadoVencimiento.sinDatos:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Documentos · ${widget.patente}', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<DocumentoVehiculoModel>>(
        stream: _service.streamDocumentos(widget.vehiculoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar documentos: ${snapshot.error}', style: TextStyle(color: textMain)),
            );
          }

          final documentos = snapshot.data ?? [];
          final estadoGeneral = peorEstado(documentos.map((d) => d.estado).toList());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _colorEstado(estadoGeneral).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(_iconoEstado(estadoGeneral), color: _colorEstado(estadoGeneral), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estado general del vehículo', style: TextStyle(color: textMuted, fontSize: 12)),
                          Text(
                            labelEstadoGeneralVehiculo(estadoGeneral),
                            style: TextStyle(color: _colorEstado(estadoGeneral), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...documentos.map((doc) => _buildDocumentoCard(doc)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentoCard(DocumentoVehiculoModel doc) {
    final color = _colorEstado(doc.estado);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Card(
      color: navBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentoDetalleScreen(
              vehiculoId: widget.vehiculoId,
              patente: widget.patente,
              tipo: doc.tipo,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(
                  doc.origen == 'ia' ? Icons.auto_awesome : Icons.description_outlined,
                  color: doc.origen == 'ia' ? iaColor : primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.label, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    if (doc.numero != null && doc.numero!.isNotEmpty)
                      Text('N° ${doc.numero}', style: TextStyle(color: textMuted, fontSize: 12)),
                    if (doc.compania != null && doc.compania!.isNotEmpty)
                      Text(doc.compania!, style: TextStyle(color: textMuted, fontSize: 12)),
                    if (doc.fechaVencimiento != null)
                      Text('Vence: ${dateFmt.format(doc.fechaVencimiento!)}', style: TextStyle(color: textMuted, fontSize: 12))
                    else
                      Text('Toca para ver o agregar datos', style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _labelEstado(doc.estado),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
