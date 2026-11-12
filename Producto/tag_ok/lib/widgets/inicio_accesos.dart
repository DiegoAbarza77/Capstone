import 'dart:async';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/documento_vehiculo_model.dart';
import '../data/services/history_service.dart';
import '../data/services/vehiculo_documentos_service.dart';
import '../screens/combustible_form_screen.dart';
import '../screens/documentos_vehiculo_screen.dart';
import '../screens/estacionamiento_form_screen.dart';
import '../utils/inicio_alertas.dart';

/// Debajo del saludo de Inicio: avisos de documentos por vencer y botones para
/// registrar sin pasar por Mi Auto. Si no hay vehículo principal no muestra nada.
class InicioAccesos extends StatefulWidget {
  const InicioAccesos({super.key});

  @override
  State<InicioAccesos> createState() => _InicioAccesosState();
}

class _InicioAccesosState extends State<InicioAccesos> {
  Map<String, dynamic>? _vehiculo;
  StreamSubscription<List<DocumentoVehiculoModel>>? _sub;
  List<AlertaInicio> _alertas = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      var v = await HistoryService().getPrincipalVehicleInfo();
      // Sin vehículo principal se usa el primero que tenga registrado.
      if (v?['id'] == null) {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          final filas = await client.from('vehiculos').select().eq('usuario_id', uid).order('created_at').limit(1);
          v = filas.isNotEmpty ? filas.first : null;
        }
      }
      final id = v?['id'];
      if (!mounted || id == null) return;
      setState(() => _vehiculo = v);
      _sub = VehiculoDocumentosService().streamDocumentos(id as String).listen(
        (docs) {
          if (mounted) setState(() => _alertas = alertasDocumentos(docs));
        },
        onError: (_) {},
      );
    } catch (_) {
      // Es un atajo: si falla, Inicio sigue funcionando sin él.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _ir(Widget pantalla) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final v = _vehiculo;
    if (v == null) return const SizedBox.shrink();
    final id = v['id'] as String;
    final patente = (v['patente'] ?? '').toString();

    Widget boton(IconData icono, String texto, VoidCallback onTap) => ActionChip(
          avatar: Icon(icono, size: 16, color: Colors.white),
          label: Text(texto),
          onPressed: onTap,
          backgroundColor: const Color(0xFF1E293B),
          labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          side: const BorderSide(color: Color(0x554F46E5)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_alertas.isNotEmpty)
          GestureDetector(
            onTap: () => _ir(DocumentosVehiculoScreen(vehiculoId: id, patente: patente)),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xE61E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _alertas.first.urgente ? Colors.redAccent : const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: _alertas.first.urgente ? Colors.redAccent : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _alertas.length == 1
                          ? _alertas.first.texto
                          : '${_alertas.first.texto} · y ${_alertas.length - 1} más',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            boton(
              Icons.local_gas_station_outlined,
              'Cargar combustible',
              () => _ir(CombustibleFormScreen(
                vehiculoId: id,
                patente: patente,
                combustibleDelVehiculo: v['tipo_combustible'] as String?,
                kmActualVehiculo: (v['kilometraje'] as num?)?.toDouble(),
              )),
            ),
            boton(
              Icons.description_outlined,
              'Subir documento',
              () => _ir(DocumentosVehiculoScreen(vehiculoId: id, patente: patente)),
            ),
            boton(
              Icons.local_parking_outlined,
              'Estacionamiento',
              () => _ir(EstacionamientoFormScreen(vehiculoId: id, patente: patente)),
            ),
          ],
        ),
      ],
    );
  }
}
