// Elige la implementación según la plataforma: el panel corre en el navegador y
// usa su selector de archivos, sin depender de paquetes nativos.
export 'selector_imagen_stub.dart' if (dart.library.html) 'selector_imagen_web.dart';
