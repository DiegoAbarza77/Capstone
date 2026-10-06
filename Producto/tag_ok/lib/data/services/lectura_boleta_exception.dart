/// La IA no pudo leer o interpretar un comprobante (boleta, factura, ticket).
/// Lleva un mensaje apto para mostrarle al usuario; la pantalla correspondiente
/// ofrece entonces el registro manual.
class LecturaBoletaException implements Exception {
  final String mensaje;
  const LecturaBoletaException(this.mensaje);

  @override
  String toString() => mensaje;
}
