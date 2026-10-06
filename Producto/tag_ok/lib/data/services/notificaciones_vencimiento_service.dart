import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/mantencion_model.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notificaciones locales preventivas de vencimiento para los 4 documentos
/// del vehículo (Permiso de Circulación, Revisión Técnica, SOAP, Seguro).
///
/// Son locales (no push) a propósito: no dependen de un servidor ni de que
/// el usuario tenga la sesión abierta en otro lado, y el dato que las
/// dispara (la fecha de vencimiento) ya vive en el dispositivo apenas se
/// guarda el documento.
class NotificacionesVencimientoService {
  static final NotificacionesVencimientoService _instance =
      NotificacionesVencimientoService._();
  factory NotificacionesVencimientoService() => _instance;
  NotificacionesVencimientoService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      // El proyecto es solo para Chile; fijamos la zona en vez de detectar
      // la del dispositivo, para que los avisos caigan siempre a la hora
      // esperada sin depender de que el teléfono tenga bien su huso horario.
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
    } catch (_) {
      // Si el nombre de zona no estuviera disponible, seguimos con la que
      // trae el paquete por defecto en vez de romper la inicialización.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  Future<void> solicitarPermiso() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// IDs deterministas a partir de "vehiculoId + tipo": permiten cancelar
  /// y reprogramar sin tener que guardar un registro aparte de qué se
  /// programó. Se reservan 2 ids consecutivos (pares) por documento: uno
  /// para el aviso de 30 días antes y otro para el aviso del mismo día.
  int _idBase(String vehiculoId, String tipo) {
    final hash = '${vehiculoId}_$tipo'.hashCode & 0x7FFFFFFF;
    return (hash ~/ 2) * 2;
  }

  Future<void> cancelarParaDocumento(String vehiculoId, String tipo) async {
    await init();
    final base = _idBase(vehiculoId, tipo);
    await _plugin.cancel(id: base);
    await _plugin.cancel(id: base + 1);
  }

  /// Programa los avisos de un documento (30 días antes de vencer y el
  /// mismo día de vencimiento), reemplazando cualquier aviso anterior para
  /// ese mismo documento. Si [vencimientoHabilitado] es false, si no hay
  /// [fechaVencimiento], o si esas fechas ya pasaron, simplemente no
  /// programa nada (el plugin no permite programar en el pasado).
  Future<void> programarParaDocumento({
    required String vehiculoId,
    required String tipo,
    required String etiquetaDocumento,
    required String patente,
    DateTime? fechaVencimiento,
    bool vencimientoHabilitado = true,
  }) async {
    await init();
    await cancelarParaDocumento(vehiculoId, tipo);

    if (!vencimientoHabilitado || fechaVencimiento == null) return;

    final base = _idBase(vehiculoId, tipo);
    final ahora = tz.TZDateTime.now(tz.local);
    final fechaFmt =
        '${fechaVencimiento.day.toString().padLeft(2, '0')}/${fechaVencimiento.month.toString().padLeft(2, '0')}/${fechaVencimiento.year}';

    final aviso30Dias = tz.TZDateTime(
      tz.local,
      fechaVencimiento.year,
      fechaVencimiento.month,
      fechaVencimiento.day,
      9,
    ).subtract(const Duration(days: 30));

    final avisoMismoDia = tz.TZDateTime(
      tz.local,
      fechaVencimiento.year,
      fechaVencimiento.month,
      fechaVencimiento.day,
      9,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vencimientos_documentos',
        'Vencimientos de documentos',
        channelDescription: 'Avisos preventivos antes de que venza un documento del vehículo.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // inexactAllowWhileIdle: no requiere el permiso especial de "alarmas
    // exactas" de Android 12+ -- una diferencia de minutos es aceptable
    // para un recordatorio preventivo, no crítico.
    if (aviso30Dias.isAfter(ahora)) {
      await _plugin.zonedSchedule(
        id: base,
        title: '$etiquetaDocumento próximo a vencer',
        body: '$etiquetaDocumento de $patente vence el $fechaFmt.',
        scheduledDate: aviso30Dias,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (avisoMismoDia.isAfter(ahora)) {
      await _plugin.zonedSchedule(
        id: base + 1,
        title: '$etiquetaDocumento vence hoy',
        body: '$etiquetaDocumento de $patente vence hoy. Renuévalo cuanto antes.',
        scheduledDate: avisoMismoDia,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }


  // ── Recordatorios de próxima mantención ─────────────────────────────

  Future<void> cancelarParaMantencion(String programadaId) async {
    await init();
    final base = _idBase('mantencion', programadaId);
    await _plugin.cancel(id: base);
    await _plugin.cancel(id: base + 1);
  }

  /// Programa los avisos de una mantención programada por fecha: [avisoDiasAntes]
  /// días antes y el mismo día, a las 9:00, reemplazando los anteriores. Si no
  /// tiene fecha, ya está completada o esas fechas ya pasaron, no programa nada.
  ///
  /// Los criterios por kilometraje no pueden avisarse por reloj (no se sabe cuándo
  /// se alcanzará el kilometraje): esos se muestran dentro de la app.
  Future<void> programarParaMantencion({
    required MantencionProgramadaModel programada,
    required String patente,
  }) async {
    await init();
    await cancelarParaMantencion(programada.id);

    final fecha = programada.fechaProgramada;
    if (programada.completada || fecha == null) return;

    final base = _idBase('mantencion', programada.id);
    final ahora = tz.TZDateTime.now(tz.local);
    final fechaFmt =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    final dia = tz.TZDateTime(tz.local, fecha.year, fecha.month, fecha.day, 9);
    final aviso = dia.subtract(Duration(days: programada.avisoDiasAntes));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mantenciones_programadas',
        'Próximas mantenciones',
        channelDescription: 'Recordatorios de las mantenciones que programaste para tu vehículo.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // Con 0 días de anticipación el aviso y el del mismo día coinciden: se envía uno.
    if (programada.avisoDiasAntes > 0 && aviso.isAfter(ahora)) {
      await _plugin.zonedSchedule(
        id: base,
        title: 'Mantención próxima: ${programada.titulo}',
        body: '${programada.titulo} de $patente está programada para el $fechaFmt.',
        scheduledDate: aviso,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (dia.isAfter(ahora)) {
      await _plugin.zonedSchedule(
        id: base + 1,
        title: 'Mantención programada para hoy',
        body: '${programada.titulo} de $patente está programada para hoy.',
        scheduledDate: dia,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
