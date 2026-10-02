import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'route_setup_screen.dart';
import 'profile_screen.dart';
import 'mi_auto_screen.dart';
import 'audit_screen.dart';
import '../data/models/route_model.dart';
import '../data/models/trip_history.dart';
import '../data/services/history_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  
  // Colores extraídos de tu diseño dark mode
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);

  // Controladores y estado del mapa
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  
  
  RouteData? _currentRoute;
  List<LatLng> _remainingPolyline = []; // Coordenadas restantes de la ruta activa
  List<LatLng> _passedPolyline = []; // Coordenadas ya recorridas (línea gris)
  bool _isNavigating = false; // Estado de navegación activa
  bool _hasStartedTrip = false; // Indica si el viaje actual ya fue confirmado y comenzó
  bool _isFollowingUser = true; // Si el mapa debe seguir al usuario
  double _currentSpeedKmH = 0.0; // Velocidad actual
  Map<String, dynamic>? _selectedVehicle; // Vehículo para el viaje actual

  // Variables para Interpolación Inercial (Dead Reckoning)
  Timer? _inertialTimer;
  DateTime? _lastGpsUpdateTime;
  bool _isGpsWeak = false;
  Future<void>? _locationInitializationFuture;

  // Notificaciones y Ciclo de vida
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePermissions();
    _loadNavigationState();
    // Verificar si el usuario tiene vehículos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVehiclesAndAlert();
    });
  }

  Future<void> _initializePermissions() async {
    await _initNotifications();
    await _determinePosition();
    _startInertialTimer();
  }

  void _startInertialTimer() {
    _inertialTimer?.cancel();
    _inertialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isNavigating || _lastGpsUpdateTime == null || _currentPosition == null) return;
      
      final secondsSinceLastUpdate = DateTime.now().difference(_lastGpsUpdateTime!).inSeconds;
      if (secondsSinceLastUpdate > 3) {
        // Si la velocidad era casi 0 (ej: detenido en un semáforo o probando en el PC)
        // NO simulamos avance ni mostramos alerta de GPS débil, porque simplemente no nos estamos moviendo.
        if (_currentSpeedKmH < 5.0) {
          if (_isGpsWeak) {
            setState(() { _isGpsWeak = false; });
          }
          return;
        }

        if (!_isGpsWeak) {
          setState(() {
            _isGpsWeak = true;
          });
        }
        
        // Distancia a mover en 1 segundo = velocidad / 3.6 (m/s)
        double distanceMeters = _currentSpeedKmH / 3.6;
        _simulateMovement(distanceMeters);
      } else {
        if (_isGpsWeak) {
          setState(() {
            _isGpsWeak = false;
          });
        }
      }
    });
  }

  void _simulateMovement(double distanceMeters) {
    if (_remainingPolyline.isEmpty) return;
    
    LatLng current = _currentPosition!;
    double remainingDist = distanceMeters;
    
    while (remainingDist > 0 && _remainingPolyline.isNotEmpty) {
      LatLng nextPoint = _remainingPolyline.first;
      double distToNext = _calculateDistance(current, nextPoint);
      
      if (distToNext > remainingDist) {
        double fraction = remainingDist / distToNext;
        double lat = current.latitude + (nextPoint.latitude - current.latitude) * fraction;
        double lng = current.longitude + (nextPoint.longitude - current.longitude) * fraction;
        current = LatLng(lat, lng);
        remainingDist = 0;
      } else {
        current = nextPoint;
        remainingDist -= distToNext;
        _passedPolyline.add(nextPoint);
        _remainingPolyline.removeAt(0);
      }
    }
    
    setState(() {
      _currentPosition = current;
    });
    
    if (_isFollowingUser) {
      _mapController.move(_currentPosition!, 17.0);
    }
    _checkTollCrossings(_currentPosition!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _inertialTimer?.cancel();
    WakelockPlus.disable();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appLifecycleState = state;
    });
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) {
      debugPrint('TAG_OK_NOTIFICATION: Notificaciones locales omitidas en Web.');
      return;
    }
    
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
      
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();

      // Crear el canal v4 con sonido y vibración personalizados
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'toll_crossings_sound_v4', 
        'Cobros de Peaje',
        description: 'Notificaciones cuando cruzas un peaje',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('peaje'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Tres ráfagas de 1 segundo de vibración
      );

      await androidImplementation?.createNotificationChannel(channel);
      debugPrint('TAG_OK_NOTIFICATION: Canal v4 de notificaciones registrado con éxito.');
    } catch (e) {
      debugPrint('TAG_OK_NOTIFICATION: Error al inicializar notificaciones: $e');
    }
  }

  Future<void> _saveNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isNavigating && _currentRoute != null) {
      prefs.setBool('isNavigating', true);
      prefs.setString('currentRoute', jsonEncode(_currentRoute!.toJson()));
      if (_selectedVehicle != null) {
        prefs.setString('selectedVehicle', jsonEncode(_selectedVehicle));
      } else {
        prefs.remove('selectedVehicle');
      }
    } else {
      prefs.remove('isNavigating');
      prefs.remove('currentRoute');
      prefs.remove('selectedVehicle');
    }
  }

  Future<void> _loadNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isNav = prefs.getBool('isNavigating');
    final String? routeStr = prefs.getString('currentRoute');
    final String? vehicleStr = prefs.getString('selectedVehicle');

    if (isNav == true && routeStr != null) {
      try {
        final decodedRoute = jsonDecode(routeStr);
        final route = RouteData.fromJson(decodedRoute);
        Map<String, dynamic>? vehicle;
        if (vehicleStr != null) {
          vehicle = jsonDecode(vehicleStr);
        }

        if (mounted) {
          setState(() {
            _currentRoute = route;
            _isNavigating = true;
            _hasStartedTrip = true;
            _selectedVehicle = vehicle;
            _remainingPolyline = List<LatLng>.from(route.polyline);
            _passedPolyline = [];
          });
          WakelockPlus.enable();
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_currentPosition != null) {
              _mapController.move(_currentPosition!, 17.0);
              _updateRemainingPolyline(_currentPosition!);
            } else if (route.polyline.isNotEmpty) {
              final bounds = LatLngBounds.fromPoints(route.polyline);
              _mapController.fitCamera(CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50.0),
              ));
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.restore, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Viaje recuperado tras cierre inesperado')),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error recovering state: $e');
      }
    }
  }

  /// Pide permisos e inicia el seguimiento en tiempo real
  Future<void> _determinePosition() async {
    // Evitar ejecuciones simultáneas esperando a la inicialización en curso
    if (_locationInitializationFuture != null) {
      await _locationInitializationFuture;
      return;
    }

    final Completer<void> completer = Completer<void>();
    _locationInitializationFuture = completer.future;

    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Cancelar la suscripción previa si existe para evitar duplicados y fugas de memoria
      if (_positionStreamSubscription != null) {
        await _positionStreamSubscription!.cancel();
        _positionStreamSubscription = null;
        debugPrint('TAG_OK_GPS: Suscripción GPS previa cancelada.');
      }

      // Verifica si el GPS está activado
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('El servicio de ubicación está deshabilitado.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, activa el GPS / ubicación en tu celular.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Verifica permisos
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permisos de ubicación denegados.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Para usar la app, debes permitir el acceso a la ubicación.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permisos de ubicación denegados permanentemente.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permisos bloqueados en el sistema. Habilítalos en los Ajustes del celular.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // 1. Obtener última ubicación conocida de forma inmediata para cargar el mapa rápido
      try {
        final Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted && _currentPosition == null) {
          setState(() {
            _currentPosition = LatLng(lastPos.latitude, lastPos.longitude);
          });
          _centerOnUser();
        }
      } catch (e) {
        debugPrint('TAG_OK_GPS: Error al obtener última ubicación conocida: $e');
      }

      // 2. Obtener ubicación inicial para despertar el GPS del celular y actualizar de inmediato
      try {
        final Position initialPos = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          ),
        );
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(initialPos.latitude, initialPos.longitude);
            _lastGpsUpdateTime = DateTime.now();
          });
          _centerOnUser();
        }
      } catch (e) {
        debugPrint('TAG_OK_GPS: Error al obtener ubicación inicial (getCurrentPosition): $e');
      }

      // Si tenemos permiso, nos suscribimos a los cambios de ubicación
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (_isNavigating) {
          // En navegación: usar Foreground Service para recibir ubicación en segundo plano
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.best, // Máxima precisión
            distanceFilter: 0, // En 0 para actualizaciones constantes en movimiento
            forceLocationManager: false,
            intervalDuration: const Duration(milliseconds: 500), // Cada 500ms para máxima fluidez
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: "TAG-OK está monitoreando los pórticos en tu ruta.",
              notificationTitle: "Monitoreo de ruta activo",
              enableWakeLock: true,
              notificationIcon: AndroidResource(
                name: 'ic_launcher',
                defType: 'mipmap',
              ),
            ),
          );
        } else {
          // En reposo (viendo mapa): ubicación estándar sin servicio en primer plano
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.best, // Máxima precisión
            distanceFilter: 0, // En 0 para que actualice rápido apenas se mueva el usuario
            forceLocationManager: false,
            intervalDuration: const Duration(seconds: 1), // Cada 1 segundo para fluidez en el mapa
          );
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: _isNavigating,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
      }

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          if (!mounted) return;
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _currentSpeedKmH = position.speed > 0 ? position.speed * 3.6 : 0.0;
            _lastGpsUpdateTime = DateTime.now();
            if (_isGpsWeak) _isGpsWeak = false;
          });
          
          // Si estamos navegando, el mapa sigue al usuario automáticamente y recorta la ruta recorrida
          if (_isNavigating && _currentPosition != null) {
            if (_isFollowingUser) {
              _mapController.move(_currentPosition!, 17.0);
            }
            _updateRemainingPolyline(_currentPosition!);
            _checkTollCrossings(_currentPosition!);
          }

          // Si es la primera vez que obtenemos la ubicación, centramos el mapa ahí
          if (_currentPosition != null && !_hasCenteredMapInitially) {
            _centerOnUser();
            _hasCenteredMapInitially = true;
          }
        },
        onError: (error) {
          debugPrint('TAG_OK_GPS: Error en el flujo de ubicación: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error de ubicación: $error'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
      );
      debugPrint('TAG_OK_GPS: Nuevo flujo de ubicación iniciado. Navegación activa: $_isNavigating');
    } catch (e) {
      debugPrint('TAG_OK_GPS: Error al inicializar el flujo de ubicación: $e');
    } finally {
      completer.complete();
      _locationInitializationFuture = null;
    }
  }

  bool _hasCenteredMapInitially = false;

  void _centerOnUser() {
    setState(() {
      _isFollowingUser = true;
    });
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _isNavigating ? 17.0 : 15.0);
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double kLat = 111320.0;
    final double kLon = 111320.0 * math.cos(p1.latitude * math.pi / 180.0);
    final double dx = (p1.longitude - p2.longitude) * kLon;
    final double dy = (p1.latitude - p2.latitude) * kLat;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _distanceToSegment(LatLng p, LatLng v, LatLng w) {
    const double kLat = 111320.0;
    final double kLon = 111320.0 * math.cos(v.latitude * math.pi / 180.0);
    
    final double dx = (w.longitude - v.longitude) * kLon;
    final double dy = (w.latitude - v.latitude) * kLat;
    final double l2 = dx * dx + dy * dy;
    
    if (l2 == 0) return _calculateDistance(p, v);
    
    // Dot product
    double t = (((p.longitude - v.longitude) * kLon * dx) + ((p.latitude - v.latitude) * kLat * dy)) / l2;
    t = math.max(0, math.min(1, t));
    
    // Projection
    final double projX = v.longitude * kLon + t * dx;
    final double projY = v.latitude * kLat + t * dy;
    
    final double pdx = (p.longitude * kLon) - projX;
    final double pdy = (p.latitude * kLat) - projY;
    
    return math.sqrt(pdx * pdx + pdy * pdy);
  }

  double _distanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) return _calculateDistance(point, polyline.first);
    
    double minDistance = double.infinity;
    // Revisar primeros 50 segmentos de _remainingPolyline para eficiencia
    int limit = math.min(polyline.length - 1, 50);
    for (int i = 0; i < limit; i++) {
      double d = _distanceToSegment(point, polyline[i], polyline[i+1]);
      if (d < minDistance) minDistance = d;
    }
    return minDistance;
  }

  void _updateRemainingPolyline(LatLng userLocation) {
    if (_remainingPolyline.isEmpty) return;

    // Buscamos el punto más cercano en la lista restante
    int closestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < _remainingPolyline.length; i++) {
      final double dist = _calculateDistance(userLocation, _remainingPolyline[i]);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Para evitar saltos erráticos si el usuario se desvía levemente,
    // usamos un umbral de proximidad de 200 metros.
    // Si el punto más cercano es más adelante en la ruta, recortamos lo recorrido.
    if (closestIndex > 0 && minDistance < 200.0) {
      setState(() {
        _passedPolyline.addAll(_remainingPolyline.sublist(0, closestIndex));
        _remainingPolyline.removeRange(0, closestIndex);
      });
    }
  }

  void _checkTollCrossings(LatLng userLocation) {
    if (_currentRoute == null || !_isNavigating) return;

    for (var toll in _currentRoute!.tolls) {
      if (!toll.isCrossed) {
        double dist = _calculateDistance(userLocation, toll.location);
        if (dist <= 45.0) { // Radio optimizado a 45m
          setState(() {
            toll.isCrossed = true;
            toll.crossedAt = DateTime.now();
          });
          _saveNavigationState(); // Guardar estado de peaje cruzado
          
          // Feedback de vibración de alta intensidad para el conductor (3 ráfagas fuertes)
          Future.microtask(() async {
            try {
              if (await Vibration.hasVibrator() ?? false) {
                await Vibration.vibrate(
                  pattern: [0, 800, 200, 800, 200, 800],
                  intensities: [0, 255, 0, 255, 0, 255],
                );
              } else {
                HapticFeedback.heavyImpact();
              }
            } catch (e) {
              debugPrint('TAG_OK_VIBRATION: Error al vibrar: $e');
              HapticFeedback.heavyImpact();
            }
          });
          
          // Siempre disparar la notificación para reproducir el sonido (tanto abierta como en 2do plano)
          _showLocalNotification(toll);
          
          if (_appLifecycleState == AppLifecycleState.resumed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Peaje cobrado: ${toll.name} (\$${toll.cost})')),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _showLocalNotification(TollData toll) async {
    if (kIsWeb) return;
    
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'toll_crossings_sound_v4', // Canal v4 para asegurar recreación con la nueva configuración
        'Cobros de Peaje',
        channelDescription: 'Notificaciones cuando cruzas un peaje',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('peaje'), // peaje.mp3 en android/app/src/main/res/raw/
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Tres ráfagas de 1 segundo de vibración
        ticker: 'ticker',
      );
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        id: toll.sequence ?? 0,
        title: '✅ Peaje Cobrado',
        body: '${toll.name} - \$${toll.cost.toStringAsFixed(0)} CLP',
        notificationDetails: platformChannelSpecifics,
      );
      debugPrint('TAG_OK_NOTIFICATION: Notificación de peaje mostrada para: ${toll.name}');
    } catch (e) {
      debugPrint('TAG_OK_NOTIFICATION: Error al disparar notificación local: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // Contenido principal de la pantalla según la pestaña seleccionada
      body: SafeArea(
        child: _buildBodyTab(),
      ),
      
      // El botón central flotante y grande (Iniciar Ruta / Mapa)
      floatingActionButton: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'fabRutaCentral',
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RouteSetupScreen(initialOrigin: _currentPosition)),
            );
            
            if (result is Map) {
              final routeData = result['route'] as RouteData;
              final vehicleMap = result['vehicle'] as Map<String, dynamic>?;

              setState(() {
                _currentRoute = routeData;
                _remainingPolyline = List<LatLng>.from(routeData.polyline);
                _passedPolyline = [];
                _selectedVehicle = vehicleMap;
                
                // NO Iniciar el viaje automáticamente, solo cargar la ruta
                _isNavigating = false;
                _hasStartedTrip = false;
              });
              
              WakelockPlus.disable();
              _saveNavigationState();
              _determinePosition();
              
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, 17.0);
              } else if (routeData.polyline.isNotEmpty) {
                final bounds = LatLngBounds.fromPoints(routeData.polyline);
                _mapController.fitCamera(CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50.0),
                ));
              }
            }
          },
          backgroundColor: primaryColor,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.map_outlined,
            size: 34,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // Menú de navegación inferior con el "hueco" en el medio
      bottomNavigationBar: BottomAppBar(
        color: navBgColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavIcon(Icons.dashboard_outlined, 0, 'Inicio'),
              _buildNavIcon(Icons.receipt_long_outlined, 1, 'Auditoría'),
              
              const SizedBox(width: 50), // Espacio para el botón central flotante
              
              _buildNavIcon(Icons.directions_car_outlined, 2, 'Mi Auto'),
              _buildNavIcon(Icons.person_outline, 3, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : textMuted,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyTab() {
    if (_selectedIndex == 0) return _buildMapTab();
    if (_selectedIndex == 1) return const AuditScreen();
    if (_selectedIndex == 2) return const MiAutoScreen();
    if (_selectedIndex == 3) return const ProfileScreen();
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForIndex(_selectedIndex),
            size: 80,
            color: textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            _getTitleForIndex(_selectedIndex),
            style: TextStyle(
              color: textMain,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    
    return Stack(
      children: [
        // 1. El Mapa en sí
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(-33.4489, -70.6693), // Santiago, Chile (fallback)
            initialZoom: 12.0,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && _isFollowingUser) {
                setState(() {
                  _isFollowingUser = false;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken",
              tileSize: 512,
              zoomOffset: -1,
              userAgentPackageName: 'com.tagok.app',
            ),
            // Capa de la Ruta (Línea Gris y Azul)
            if (_currentRoute != null)
              PolylineLayer(
                polylines: [
                  // Tramo recorrido (Gris)
                  if (_passedPolyline.isNotEmpty)
                    Polyline(
                      points: [
                        ..._passedPolyline,
                        if (_isNavigating && _currentPosition != null) _currentPosition!,
                      ],
                      strokeWidth: 6.0,
                      color: Colors.grey.withValues(alpha: 0.6),
                    ),
                  // Tramo restante (Azul)
                  if (_remainingPolyline.isNotEmpty)
                    Polyline(
                      points: [
                        if (_isNavigating && _currentPosition != null) _currentPosition!,
                        ..._remainingPolyline,
                      ],
                      strokeWidth: 6.0,
                      color: const Color(0xFF3B82F6),
                    ),
                ],
              ),
              
            // Capa de los Pórticos (Íconos) y Marcadores de Inicio/Fin
            if (_currentRoute != null)
              MarkerLayer(
                markers: [
                  // Marcador de Inicio (Verde)
                  if (_currentRoute!.polyline.isNotEmpty)
                    Marker(
                      point: _currentRoute!.polyline.first,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.radio_button_checked, color: Color(0xFF10B981), size: 30),
                    ),
                  
                  // Marcador de Fin (Rojo)
                  if (_currentRoute!.polyline.isNotEmpty)
                    Marker(
                      point: _currentRoute!.polyline.last,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 35),
                    ),

                  // Marcadores de Pórticos
                  ..._currentRoute!.tolls.map((toll) => Marker(
                    point: toll.location,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: toll.isCrossed ? const Color(0xFF10B981) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Icon(
                        toll.isCrossed ? Icons.check : Icons.monetization_on, 
                        color: toll.isCrossed ? Colors.white : const Color(0xFFF59E0B), 
                        size: 20
                      ),
                    ),
                  )),
                ],
              ),

            // 2. Capa de Marcadores (Punto azul del usuario)
            if (_currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition!,
                    width: 60,
                    height: 60,
                    child: _buildLocationMarker(),
                  ),
                ],
              ),
          ],
        ),
        
        // --- PANEL SUPERIOR FLOTANTE (Solo si no hay ruta activa) ---
        if (_currentRoute == null) _buildTopFloatingHeader(),

        // --- PANEL INFERIOR DE RESUMEN (Solo si no hay ruta activa) ---
        if (_currentRoute == null) _buildBottomInfoCard(),

        // Tarjeta resumen de la ruta
        if (_currentRoute != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: navBgColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Costo Total Estimado', style: TextStyle(color: textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('\$${_currentRoute!.totalCost.toStringAsFixed(0)} CLP', style: const TextStyle(color: Color(0xFF10B981), fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Distancia / Tiempo', style: TextStyle(color: textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${_currentRoute!.distanceKm.toStringAsFixed(1)} km • ${_currentRoute!.durationText}', style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  if (_isNavigating) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final nextToll = _currentRoute!.tolls.cast<TollData?>().firstWhere((t) => !(t!.isCrossed), orElse: () => null);
                      if (nextToll != null) {
                        return Row(
                          children: [
                            const Icon(Icons.sensors, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Próximo peaje: ${nextToll.name}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                  if (!_isNavigating) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        if (_hasStartedTrip) {
                          setState(() {
                            _isNavigating = true;
                          });
                          WakelockPlus.enable();
                          _saveNavigationState();
                          _determinePosition();
                        } else {
                          _confirmVehicleAndStart(context);
                        }
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF818CF8)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_hasStartedTrip ? Icons.play_arrow : Icons.navigation, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(_hasStartedTrip ? 'CONTINUAR VIAJE' : 'INICIAR VIAJE', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Botón Pausar/Seguir
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isNavigating = !_isNavigating;
                              });
                              if (_isNavigating) {
                                WakelockPlus.enable();
                              } else {
                                WakelockPlus.disable();
                              }
                              _saveNavigationState();
                              _determinePosition();
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                              ),
                              child: Icon(
                                _isNavigating ? Icons.pause : Icons.play_arrow, 
                                color: primaryColor
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón Finalizar Viaje (Limpia todo y guarda historial)
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () async {
                              // Guardar en el historial antes de limpiar
                              if (_currentRoute != null) {
                                final historyService = HistoryService();
                                final trip = TripHistory(
                                  id: '', // Se genera en la base de datos
                                  date: DateTime.now(),
                                  totalCost: _currentRoute!.tolls.where((t) => t.isCrossed).fold(0.0, (sum, t) => sum + t.cost),
                                  distanceKm: _currentRoute!.distanceKm,
                                  duration: _currentRoute!.durationText,
                                  vehicleName: _selectedVehicle != null 
                                    ? '${_selectedVehicle!['marca']} (${_selectedVehicle!['patente']})'
                                    : 'Vehículo Principal',
                                  tolls: _currentRoute!.tolls
                                    .where((t) => t.isCrossed)
                                    .map((t) => TollRecord(
                                      name: t.name,
                                      cost: t.cost, // Usamos el costo base o el que se haya aplicado
                                      timestamp: t.crossedAt ?? DateTime.now(),
                                    )).toList(),
                                );
                                await historyService.saveTrip(trip);
                                
                                // Lógica de Notificación de Límite
                                final allTrips = await historyService.getTripHistory().first;
                                final double newTotal = allTrips.fold(0, (sum, t) => sum + t.totalCost);
                                final double limit = await historyService.getMonthlyLimit().first;
                                
                                if (mounted) {
                                  _checkAndShowLimitAlert(context, newTotal, limit);
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Viaje guardado en el historial'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              }

                              setState(() {
                                _isNavigating = false;
                                _hasStartedTrip = false;
                                _currentRoute = null;
                                _remainingPolyline = [];
                                _passedPolyline = [];
                                _selectedVehicle = null;
                              });
                              WakelockPlus.disable();
                              _saveNavigationState(); // Limpia la caché
                              _determinePosition();
                              _centerOnUser();
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'FINALIZAR VIAJE', 
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        
        // 3. Botón flotante para centrar la ubicación
        Positioned(
          bottom: 186,
          right: 16,
          child: FloatingActionButton(
            heroTag: "centerLocationBtn", // Evita conflictos de hero con el boton central
            mini: true,
            backgroundColor: navBgColor,
            onPressed: _centerOnUser,
            child: Icon(
              Icons.my_location,
              color: _isFollowingUser ? primaryColor : textMuted,
            ),
          ),
        ),
        
        // 4. Velocímetro y Banner de GPS Débil
        if (_isNavigating)
          Positioned(
            bottom: 250,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isGpsWeak)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.satellite_alt, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Simulando avance',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isGpsWeak ? Colors.orange.shade900.withValues(alpha: 0.9) : navBgColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isGpsWeak ? Colors.orange : primaryColor.withValues(alpha: 0.5), 
                      width: 2
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentSpeedKmH.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, height: 1.1),
                  ),
                ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Diseño del punto azul con sombra/halo
  Future<void> _confirmVehicleAndStart(BuildContext context) async {
    // Si ya seleccionó el vehículo en RouteSetupScreen, iniciar de inmediato
    if (_selectedVehicle != null) {
      setState(() {
        _isNavigating = true;
        _hasStartedTrip = true;
      });
      WakelockPlus.enable();
      _saveNavigationState();
      _determinePosition();
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, 17.0);
      }
      return;
    }

    final historyService = HistoryService();
    final principal = await historyService.getPrincipalVehicleInfo();
    
    if (!mounted) return;

    if (principal == null) {
      // Si no tiene vehículos, iniciamos igual o avisamos
      setState(() {
        _isNavigating = true;
        _hasStartedTrip = true;
      });
      WakelockPlus.enable();
      _saveNavigationState();
      _determinePosition();
      _mapController.move(_currentPosition ?? _currentRoute!.polyline.first, 17.0);
      return;
    }

    _selectedVehicle = principal;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: navBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.directions_car, color: primaryColor),
            const SizedBox(width: 10),
            const Text("Confirmar Vehículo", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("¿Vas en tu vehículo principal?", style: TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${principal['marca']} (${principal['patente']})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _showVehicleSelector(context);
            },
            child: Text("CAMBIAR", style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isNavigating = true;
                _hasStartedTrip = true;
              });
              WakelockPlus.enable();
              _saveNavigationState();
              _determinePosition();
              _mapController.move(_currentPosition ?? _currentRoute!.polyline.first, 17.0);
            },
            child: const Text("SÍ, COMENZAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleSelector(BuildContext context) async {
    final historyService = HistoryService();
    final vehicles = await historyService.getUserVehicles();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: navBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Seleccionar Vehículo", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(vehicles.length * 72.0, MediaQuery.of(context).size.height * 0.6),
          child: ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final v = vehicles[index];
              return ListTile(
                leading: const Icon(Icons.directions_car, color: Colors.white70),
                title: Text(v['patente'], style: const TextStyle(color: Colors.white)),
                subtitle: Text(v['marca'], style: TextStyle(color: textMuted)),
                onTap: () {
                  setState(() {
                    _selectedVehicle = v;
                    _isNavigating = true;
                    _hasStartedTrip = true;
                  });
                  _saveNavigationState();
                  _determinePosition();
                  Navigator.pop(context);
                  _mapController.move(_currentPosition ?? _currentRoute!.polyline.first, 17.0);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _checkVehiclesAndAlert() async {
    final historyService = HistoryService();
    final vehicles = await historyService.getUserVehicles();
    
    if (vehicles.isEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // Obligatorio para que no se lo salten
        builder: (context) => AlertDialog(
          backgroundColor: navBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 10),
              const Text("Configuración Inicial", style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            "¡Bienvenido! Para poder usar Tag OK y calcular tus cobros, primero debes registrar tu vehículo.",
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                              _selectedIndex = 2; // Nos lleva a la pestaña Mi Auto
                });
              },
              child: const Text("REGISTRAR AHORA", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _checkAndShowLimitAlert(BuildContext context, double total, double limit) async {
    final double percentage = (total / limit) * 100;
    String? message;
    Color alertColor = Colors.blue;
    int threshold = 0;

    if (percentage >= 100) {
      message = "¡Has alcanzado el 100% de tu límite mensual!";
      alertColor = Colors.redAccent;
      threshold = 100;
    } else if (percentage >= 90) {
      message = "Atención: Llevas el 90% de tu límite gastado.";
      alertColor = Colors.orangeAccent;
      threshold = 90;
    } else if (percentage >= 75) {
      message = "Aviso: Llevas el 75% de tu presupuesto consumido.";
      alertColor = Colors.yellowAccent;
      threshold = 75;
    } else if (percentage >= 50) {
      message = "Informativo: Has llegado al 50% de tu presupuesto mensual.";
      threshold = 50;
    }

    if (message != null && threshold > 0) {
      final historyService = HistoryService();
      
      // Verificamos si ya notificamos esta alerta este mes
      final alreadyNotified = await historyService.hasAlertBeenNotified(threshold);
      
      if (!alreadyNotified && context.mounted) {
        // Marcamos como notificada antes de mostrar para evitar colisiones
        await historyService.markAlertAsNotified(threshold);
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: alertColor),
                const SizedBox(width: 10),
                const Text("Alerta de Presupuesto", style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: Text(message!, style: const TextStyle(color: Color(0xFF94A3B8))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("ENTENDIDO", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.3),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helpers para los textos temporales del centro
  String _getTitleForIndex(int index) {
    switch (index) {
      case 0: return 'Panel de Inicio';
      case 1: return 'Auditoría de Boletas (IA)';
      case 2: return 'Mi Auto';
      case 3: return 'Mi Perfil';
      default: return '';
    }
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.dashboard_outlined;
      case 1: return Icons.receipt_long_outlined;
      case 2: return Icons.directions_car_outlined;
      case 3: return Icons.person_outline;
      default: return Icons.error;
    }
  }

  Widget _buildTopFloatingHeader() {
    final user = Supabase.instance.client.auth.currentUser;
    return Positioned(
      top: 20,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: navBgColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor,
                  radius: 18,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Hola, ${user?.email?.split('@')[0] ?? 'Usuario'}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Text(
                        "Protección de TAG Activa",
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.notifications_none, color: Colors.white70, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfoCard() {
    return Positioned(
      bottom: 96,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: navBgColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car, color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: HistoryService().getPrincipalVehicleInfo(),
                    builder: (context, snapshot) {
                      final patente = snapshot.data?['patente'] ?? 'Sin asignar';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Vehículo Principal", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                          Text(patente, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      );
                    },
                  ),
                ),
                _buildMiniProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProgressIndicator() {
    return StreamBuilder<List<TripHistory>>(
      stream: HistoryService().getTripHistory(),
      builder: (context, snapshot) {
        final List<TripHistory> trips = snapshot.data ?? [];
        final double total = trips.fold<double>(0.0, (sum, t) => sum + t.totalCost);
        
        return StreamBuilder<double>(
          stream: HistoryService().getMonthlyLimit(),
          builder: (context, limitSnapshot) {
            final double limit = limitSnapshot.data ?? 0.0;
            final double progress = (limit > 0) ? (total / limit).clamp(0.0, 1.1) : 0.0;
            
            // Lógica de colores sincronizada
            Color progressColor = const Color(0xFF4F46E5); // Violeta
            if (progress >= 1.0) {
              progressColor = Colors.redAccent;
            } else if (progress >= 0.9) progressColor = Colors.orangeAccent;
            else if (progress >= 0.75) progressColor = Colors.yellowAccent;
            else if (progress >= 0.5) progressColor = const Color(0xFF10B981);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${(progress * 100).round()}%", 
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
