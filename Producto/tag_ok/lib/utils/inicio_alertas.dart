import '../data/models/documento_vehiculo_model.dart';

/// Un aviso de la pantalla de Inicio: un documento vencido o por vencer.
class AlertaInicio {
  final String texto;
  final bool urgente;

  const AlertaInicio({required this.texto, required this.urgente});
}

/// Documentos que piden atención, los vencidos primero y luego los que vencen
/// antes. Los que no tienen fecha o están al día no generan aviso.
List<AlertaInicio> alertasDocumentos(Iterable<DocumentoVehiculoModel> documentos) {
  final pendientes = documentos
      .where((d) => d.estado == EstadoVencimiento.vencido || d.estado == EstadoVencimiento.atencion)
      .toList()
    ..sort((a, b) => (a.diasParaVencer ?? 0).compareTo(b.diasParaVencer ?? 0));
  return [
    for (final d in pendientes)
      AlertaInicio(
        texto: '${d.label}: ${d.textoVencimiento}',
        urgente: d.estado == EstadoVencimiento.vencido,
      ),
  ];
}
