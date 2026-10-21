import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/cache_offline.dart';
import '../../data/services/conexion_servidor_service.dart';

/// Envuelve toda la app y muestra un aviso arriba cuando no hay conexión con
/// el servidor. Se usa desde MaterialApp.builder, así cubre todas las pantallas.
class BannerSinConexion extends StatelessWidget {
  final Widget child;

  const BannerSinConexion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConexionServidorService.instance.conectado,
      builder: (context, conectado, _) {
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: conectado
                  ? const SizedBox(width: double.infinity)
                  : Material(
                      color: const Color(0xFFB45309),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: ValueListenableBuilder<DateTime?>(
                                  valueListenable: CacheOffline.datosGuardadosDesde,
                                  builder: (context, desde, _) => Text(
                                    desde == null
                                        ? 'Sin conexión con el servidor, reintentando…'
                                        : 'Sin conexión · datos guardados al ${DateFormat('dd/MM HH:mm').format(desde)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(
              // Mientras el aviso está visible ya ocupa la zona de la barra de
              // estado, así que se quita ese margen del resto para no duplicarlo.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !conectado,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
