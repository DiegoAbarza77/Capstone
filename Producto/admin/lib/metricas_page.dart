import 'package:flutter/material.dart';

import 'admin_supabase_service.dart';
import 'metricas_logica.dart';

const Color _azul = Color(0xFF0EA5E9);
const Color _gris = Color(0xFF64748B);
const Color _verde = Color(0xFF10B981);
const Color _ambar = Color(0xFFF59E0B);
const Color _violeta = Color(0xFF8B5CF6);
const Color _rosa = Color(0xFFEC4899);

enum _Periodo { dias30, dias90, meses12, personalizado }

/// Sección "Métricas y Reportes" del panel (CU20): uso de la plataforma, solo con
/// datos agregados y anonimizados (cantidades y montos, nunca correos ni nombres).
class MetricasPage extends StatefulWidget {
  const MetricasPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<MetricasPage> createState() => _MetricasPageState();
}

class _MetricasPageState extends State<MetricasPage> {
  _Periodo _periodo = _Periodo.dias30;
  late DateTime _desde;
  late DateTime _hasta;
  late Future<MetricasUso> _futuro;

  @override
  void initState() {
    super.initState();
    _aplicarPeriodo(_Periodo.dias30);
  }

  void _aplicarPeriodo(_Periodo p) {
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    _periodo = p;
    _hasta = dia;
    switch (p) {
      case _Periodo.dias30:
        _desde = dia.subtract(const Duration(days: 29));
      case _Periodo.dias90:
        _desde = dia.subtract(const Duration(days: 89));
      case _Periodo.meses12:
        _desde = DateTime(dia.year - 1, dia.month + 1, 1);
      case _Periodo.personalizado:
        break; // se mantienen las fechas elegidas
    }
    _cargar();
  }

  void _cargar() {
    _futuro = widget.service.fetchMetricasUso(desde: _desde, hasta: _hasta);
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      helpText: 'Elige el período',
    );
    if (rango == null) return;
    setState(() {
      _desde = rango.start;
      _hasta = rango.end;
      _aplicarPeriodo(_Periodo.personalizado);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Métricas y Reportes',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            const SizedBox(height: 8),
            const Text(
              'Uso de la plataforma, con datos agregados: no incluye correos ni datos personales.',
              style: TextStyle(color: _gris, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildFiltros(),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<MetricasUso>(
                future: _futuro,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) return _buildError();
                  return _buildContenido(snap.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    Widget chip(String texto, _Periodo p) => ChoiceChip(
          label: Text(texto),
          selected: _periodo == p,
          onSelected: (_) => setState(() => _aplicarPeriodo(p)),
        );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('Últimos 30 días', _Periodo.dias30),
        chip('Últimos 90 días', _Periodo.dias90),
        chip('Últimos 12 meses', _Periodo.meses12),
        ChoiceChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(_periodo == _Periodo.personalizado ? '${_fechaCorta(_desde)} – ${_fechaCorta(_hasta)}' : 'Personalizado'),
          selected: _periodo == _Periodo.personalizado,
          onSelected: (_) => _elegirRango(),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => setState(_cargar),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  /// E1 del CU20: el dashboard queda vacío con un mensaje y la opción de reintentar.
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _gris),
          const SizedBox(height: 12),
          const Text('Error al cargar las métricas. Reintente en unos minutos.', style: TextStyle(fontSize: 16)),
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

  Widget _buildContenido(MetricasUso m) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _TarjetaDato(
                titulo: 'Usuarios activos',
                valor: formatoMilesEs(m.usuariosActivos),
                detalle: '${formatoMilesEs(m.usuariosNuevos)} nuevos · ${formatoMilesEs(m.usuariosTotales)} en total',
                icono: Icons.people_alt_outlined,
                color: _azul,
              ),
              _TarjetaDato(
                titulo: 'Vehículos registrados',
                valor: formatoMilesEs(m.vehiculosTotales),
                detalle: '${formatoMilesEs(m.vehiculosNuevos)} nuevos en el período',
                icono: Icons.directions_car_outlined,
                color: _verde,
              ),
              _TarjetaDato(
                titulo: 'Documentos procesados por IA',
                valor: formatoMilesEs(m.iaTotal),
                detalle: 'En el período',
                icono: Icons.auto_awesome,
                color: _violeta,
              ),
              _TarjetaDato(
                titulo: 'Registros creados',
                valor: formatoMilesEs(m.registrosTotal),
                detalle: 'Viajes, combustible, mantenciones y estacionamientos',
                icono: Icons.edit_note_outlined,
                color: _ambar,
              ),
              _TarjetaDato(
                titulo: 'Gasto registrado',
                valor: formatoPesosEs(m.gastoTotal),
                detalle: 'Suma de todas las categorías',
                icono: Icons.payments_outlined,
                color: _rosa,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _TarjetaBarras(
                titulo: 'Documentos procesados por IA, por módulo',
                valores: {for (final e in m.iaPorModulo.entries) e.key: e.value.toDouble()},
                formato: (v) => formatoMilesEs(v),
                color: _violeta,
              ),
              _TarjetaBarras(
                titulo: 'Gasto registrado, por categoría',
                valores: m.gastoPorCategoria,
                formato: formatoPesosEs,
                color: _rosa,
              ),
              _TarjetaBarras(
                titulo: 'Registros creados, por módulo',
                valores: {for (final e in m.registrosPorModulo.entries) e.key: e.value.toDouble()},
                formato: (v) => formatoMilesEs(v),
                color: _ambar,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCrecimiento(m),
          const SizedBox(height: 12),
          const Text(
            'Los usuarios activos son quienes registraron algo en el período. Todo se mide por la fecha en que se registró en la plataforma.',
            style: TextStyle(color: _gris, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCrecimiento(MetricasUso m) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crecimiento mensual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Mes')),
                  DataColumn(label: Text('Usuarios nuevos'), numeric: true),
                  DataColumn(label: Text('Vehículos nuevos'), numeric: true),
                  DataColumn(label: Text('Registros'), numeric: true),
                  DataColumn(label: Text('Documentos por IA'), numeric: true),
                ],
                rows: [
                  for (final f in m.crecimiento.reversed)
                    DataRow(cells: [
                      DataCell(Text(etiquetaMes(f.mes))),
                      DataCell(Text(formatoMilesEs(f.usuariosNuevos))),
                      DataCell(Text(formatoMilesEs(f.vehiculosNuevos))),
                      DataCell(Text(formatoMilesEs(f.registros))),
                      DataCell(Text(formatoMilesEs(f.documentosIa))),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
String _fechaCorta(DateTime f) => '${f.day} ${_mesesCortos[f.month - 1]} ${f.year}';

class _TarjetaDato extends StatelessWidget {
  const _TarjetaDato({
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

/// Barras horizontales simples: el largo de cada una es proporcional al mayor valor.
class _TarjetaBarras extends StatelessWidget {
  const _TarjetaBarras({
    required this.titulo,
    required this.valores,
    required this.formato,
    required this.color,
  });

  final String titulo;
  final Map<String, double> valores;
  final String Function(double) formato;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maximo = valores.values.fold<double>(0, (a, b) => b > a ? b : a);

    return SizedBox(
      width: 400,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              for (final e in valores.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                          Text(formato(e.value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: maximo > 0 ? e.value / maximo : 0,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
