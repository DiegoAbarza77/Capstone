// Textos de las formas de cargar datos (a mano o con IA), iguales en todos los
// módulos para que se entienda lo mismo en cada pantalla.

/// Registro a mano.
const String kTextoManualTitulo = 'Registro manual';
const String kTextoManualDetalle = 'Escribe tú mismo los datos';

/// Lectura con IA: una frase corta que explica qué pasa, sin tecnicismos.
const String kTextoIaDetalle = 'Sube una foto o PDF y la IA completa los datos. Tú los revisas antes de guardar.';

/// Cuando el documento ya tiene datos y se vuelve a leer con IA.
const String kTextoIaDetalleReemplazo =
    'Sube un archivo nuevo y la IA lo lee. Los datos actuales cambian solo si confirmas.';

/// Aclara que adjuntar un archivo no lee ni cambia los datos.
const String kTextoSoloGuardarArchivo = 'Solo guarda el archivo para verlo después. No cambia los datos.';
