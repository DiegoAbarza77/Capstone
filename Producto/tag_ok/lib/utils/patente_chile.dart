/// Formatos de patente chilena aceptados:
///  - Auto actual:   4 letras + 2 números  (ABCD12)
///  - Auto antiguo:  2 letras + 4 números  (AB1234)
///  - Moto actual:   3 letras + 2 números  (ABC12)
///  - Moto antigua:  2 letras + 3 números  (AB123)
final RegExp _formatoPatente = RegExp(
  r'^(?:[A-Z]{4}\d{2}|[A-Z]{2}\d{4}|[A-Z]{3}\d{2}|[A-Z]{2}\d{3})$',
);

const String kMensajePatenteInvalida =
    'Formato de patente inválido (ej: ABCD12, AB1234, ABC12 o AB123)';

/// Deja la patente en mayúsculas y sin espacios ni guiones, para que
/// "abcd-12" y "ABCD 12" se guarden igual que "ABCD12".
String normalizarPatente(String texto) =>
    texto.toUpperCase().replaceAll(RegExp(r'[\s\-.]'), '');

/// true si [patente] (ya normalizada) cumple alguno de los 4 formatos.
bool esPatenteValida(String patente) => _formatoPatente.hasMatch(patente);
