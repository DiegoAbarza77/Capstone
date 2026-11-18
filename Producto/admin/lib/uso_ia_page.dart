import 'package:flutter/material.dart';

import 'admin_supabase_service.dart';
import 'metricas_logica.dart' show formatoMilesEs;
import 'uso_ia_logica.dart';
import 'usuario_datos_logica.dart' show formatoFecha;

const Color _gris = Color(0xFF64748B);
const Color _azul = Color(0xFF0EA5E9);
const Color _verde = Color(0xFF10B981);
const Color _ambar = Color(0xFFF59E0B);
const Color _rojo = Color(0xFFEF4444);
const Color _violeta = Color(0xFF8B5CF6);

enum _Periodo { dias7, dias30, dias90 }

/// Sección "Uso de IA" del panel: cuántas veces se usó la IA, cuántas veces
/// falló y por qué, y quiénes la usan más. Sirve para controlar el costo.
///
/// Muestra nombres y correos de los usuarios que más la usan, por eso solo la ve
/// el super administrador.
class UsoIaPage extends StatefulWidget {
  const UsoIaPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<UsoIaPage> createState() => _UsoIaPageState();
}

class _UsoIaPageState extends State<UsoIaPage> {
  _Periodo _periodo = _Periodo.dias30;
  late Future<UsoIaDatos> _futuro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  int get _dias {
    switch (_periodo) {
      case _Periodo.dias7:
        return 7;
      case _Periodo.dias30:
        return 30;
      case _Periodo.dias90:
        return 90;
    }
  }

  void _cargar() {
    final hoy = DateTime.now();
    final hasta = DateTime(hoy.year, hoy.month, hoy.day);
    final desde = hasta.subtract(Duration(days: _dias - 1));
    _futuro = widget.service.fetchUsoIa(desde: desde, hasta: hasta);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Uso de IA',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            const SizedBox(height: 8),
            const Text(
              'Cada lectura de un documento, boleta o ticket es una llamada a la IA (OpenAI).',
              style: TextStyle(color: _gris, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _filtros(),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<UsoIaDatos>(
                future: _futuro,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return _error(snapshot.error);
                  return _contenido(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    Widget chip(String texto, _Periodo p) => ChoiceChip(
          label: Text(texto),
          selected: _periodo == p,
          onSelected: (_) => setState(() {
            _periodo = p;
            _cargar();
          }),
        );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('Últimos 7 días', _Periodo.dias7),
        chip('Últimos 30 días', _Periodo.dias30),
        chip('Últimos 90 días', _Periodo.dias90),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => setState(_cargar),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _error(Object? error) {
    // Si falta aplicar la migración 0019, la tabla todavía no existe.
    final faltaTabla = error.toString().contains('uso_ia');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _gris),
          const SizedBox(height: 12),
          Text(
            faltaTabla
                ? 'Todavía no existe el registro de uso. Aplica la migración 0019_uso_ia.sql en Supabase.'
                : 'Error al cargar el uso de la IA. Reintenta en unos minutos.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(_cargar),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _contenido(UsoIaDatos datos) {
    final r = datos.resumen;

    if (r.estaVacio) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no hay llamadas registradas en este período.\n\n'
            'El registro empieza a llenarse cuando se publica la versión actualizada de la función '
            'gemini-proxy y alguien usa la IA.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _gris, fontSize: 15),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Dato(
                titulo: 'Llamadas a la IA',
                valor: formatoMilesEs(r.total),
                detalle: '${formatoMilesEs(r.usuarios)} ${r.usuarios == 1 ? 'usuario' : 'usuarios'} · '
                    '${formatoMilesEs(r.conArchivo)} con foto o PDF',
                icono: Icons.auto_awesome,
                color: _violeta,
              ),
              _Dato(
                titulo: 'Tasa de éxito',
                valor: '${r.tasaExito.round()}%',
                detalle: '${formatoMilesEs(r.exitosas)} bien · ${formatoMilesEs(r.fallidas)} con problema',
                icono: Icons.check_circle_outline,
                color: r.tasaExito >= 90 ? _verde : (r.tasaExito >= 70 ? _ambar : _rojo),
              ),
              _Dato(
                titulo: 'Límite por minuto alcanzado',
                valor: formatoMilesEs(r.limitadas),
                detalle: 'Llamadas frenadas por el límite de 10 por minuto',
                icono: Icons.speed_outlined,
                color: r.limitadas == 0 ? _gris : _ambar,
              ),
              _Dato(
                titulo: 'Tiempo promedio',
                valor: formatoDuracionIa(r.duracionPromedioMs),
                detalle: 'De las llamadas que salieron bien',
                icono: Icons.timer_outlined,
                color: _azul,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _tarjeta('Llamadas por día', _barrasPorDia(r)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(width: 420, child: _tarjeta('Por qué fallaron', _errores(r))),
              SizedBox(width: 420, child: _tarjeta('Quiénes la usan más', _topUsuarios(r, datos.usuarios))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(String titulo, Widget hijo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            hijo,
          ],
        ),
      ),
    );
  }

  /// Una barra por día: en azul las llamadas que salieron bien y, encima, en rojo
  /// las que tuvieron problemas.
  Widget _barrasPorDia(UsoIaResumen r) {
    final maximo = r.porDia.fold<int>(0, (m, d) => d.llamadas > m ? d.llamadas : m);
    const alto = 140.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: alto,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final dia in r.porDia)
                Expanded(
                  child: Tooltip(
                    message: '${formatoFecha(dia.fecha.toIso8601String())}: '
                        '${dia.llamadas} ${dia.llamadas == 1 ? 'llamada' : 'llamadas'}'
                        '${dia.fallidas > 0 ? ' (${dia.fallidas} con problema)' : ''}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (dia.fallidas > 0)
                            Container(height: alto * dia.fallidas / maximo, color: _rojo),
                          Container(
                            height: alto * (dia.llamadas - dia.fallidas) / maximo,
                            color: _violeta,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatoFecha(r.porDia.first.fecha.toIso8601String()),
                style: const TextStyle(color: _gris, fontSize: 12)),
            const Row(
              children: [
                Icon(Icons.square, size: 10, color: _violeta),
                SizedBox(width: 4),
                Text('Bien', style: TextStyle(color: _gris, fontSize: 12)),
                SizedBox(width: 12),
                Icon(Icons.square, size: 10, color: _rojo),
                SizedBox(width: 4),
                Text('Con problema', style: TextStyle(color: _gris, fontSize: 12)),
              ],
            ),
            Text(formatoFecha(r.porDia.last.fecha.toIso8601String()),
                style: const TextStyle(color: _gris, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _errores(UsoIaResumen r) {
    if (r.erroresPorTipo.isEmpty) {
      return const Text('Ninguna llamada falló en este período.', style: TextStyle(color: _gris));
    }
    return Column(
      children: [
        for (final e in r.erroresPorTipo.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: _ambar),
                const SizedBox(width: 8),
                Expanded(child: Text(e.key)),
                Text(formatoMilesEs(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _topUsuarios(UsoIaResumen r, Map<String, Map<String, dynamic>> usuarios) {
    if (r.topUsuarios.isEmpty) {
      return const Text('Sin usuarios en este período.', style: TextStyle(color: _gris));
    }
    return Column(
      children: [
        for (final u in r.topUsuarios)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (usuarios[u.usuarioId]?['nombre_mostrar'] ?? 'Usuario eliminado').toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        (usuarios[u.usuarioId]?['email'] ?? '').toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _gris, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${formatoMilesEs(u.llamadas)} ${u.llamadas == 1 ? 'llamada' : 'llamadas'}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (u.fallidas > 0)
                      Text('${formatoMilesEs(u.fallidas)} con problema',
                          style: const TextStyle(color: _rojo, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.icono,
    required this.color,
  });

  final String titulo;
  final String valor;
  final String detalle;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color),
              const SizedBox(height: 14),
              Text(valor, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(detalle, style: const TextStyle(color: _gris, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
