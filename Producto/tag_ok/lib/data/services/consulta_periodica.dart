import 'dart:async';

import 'package:flutter/foundation.dart';

/// Avisa a las pantallas abiertas que los datos de un módulo cambiaron, para que
/// vuelvan a consultarlos de inmediato sin esperar al refresco periódico.
class AvisoDeCambios extends ChangeNotifier {
  void avisar() => notifyListeners();
}

/// Flujo de datos que consulta directamente la base de datos, sin depender de
/// Supabase Realtime (que solo funciona si la tabla está publicada en el proyecto).
///
/// Consulta al abrir, cada [cada], y de inmediato cuando [alCambiar] avisa de un
/// cambio. Si una consulta falla después de haber recibido datos, se conserva lo
/// último recibido y se reintenta en el siguiente ciclo; si falla antes de recibir
/// algo, el error llega al flujo.
Stream<T> consultaPeriodica<T>(
  Future<T> Function() consulta, {
  Duration cada = const Duration(seconds: 15),
  Listenable? alCambiar,
}) {
  late final StreamController<T> salida;
  Timer? temporizador;
  var consultando = false;
  var pendiente = false;
  var tuvoDatos = false;

  Future<void> cargar() async {
    // Un cambio que llega mientras se consulta obliga a consultar otra vez: la
    // consulta en vuelo pudo haberse hecho antes de ese cambio.
    if (consultando) {
      pendiente = true;
      return;
    }
    consultando = true;
    try {
      do {
        pendiente = false;
        try {
          final datos = await consulta();
          if (salida.isClosed) return;
          tuvoDatos = true;
          salida.add(datos);
        } catch (error, pila) {
          if (salida.isClosed) return;
          if (!tuvoDatos) salida.addError(error, pila);
        }
      } while (pendiente && !salida.isClosed);
    } finally {
      consultando = false;
    }
  }

  void alRecibirAviso() => cargar();

  salida = StreamController<T>(
    onListen: () {
      cargar();
      temporizador = Timer.periodic(cada, (_) => cargar());
      alCambiar?.addListener(alRecibirAviso);
    },
    onCancel: () {
      temporizador?.cancel();
      alCambiar?.removeListener(alRecibirAviso);
    },
  );
  return salida.stream;
}
