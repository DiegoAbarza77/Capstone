import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/beneficio_model.dart';
import '../data/services/beneficios_service.dart';
import '../utils/beneficios_logica.dart';
import 'mantencion_ui.dart';

const Color _kDestacado = Color(0xFFF59E0B);

IconData iconoCategoriaBeneficio(String? categoria) {
  switch (categoria) {
    case 'combustible':
      return Icons.local_gas_station_outlined;
    case 'talleres':
      return Icons.build_outlined;
    case 'mantenciones':
      return Icons.build_circle_outlined;
    case 'estacionamiento':
      return Icons.local_parking_outlined;
    case 'lavado':
      return Icons.local_car_wash_outlined;
    case 'neumaticos':
      return Icons.tire_repair_outlined;
    case 'seguros':
      return Icons.shield_outlined;
    case 'accesorios':
      return Icons.shopping_bag_outlined;
    default:
      return Icons.card_giftcard_outlined;
  }
}

/// Catálogo de beneficios (CU15): descuentos y alianzas con comercios, con
/// filtros por categoría, ubicación y vigencia, y el detalle de cómo canjear cada
/// uno.
class BeneficiosScreen extends StatefulWidget {
  const BeneficiosScreen({super.key});

  @override
  State<BeneficiosScreen> createState() => _BeneficiosScreenState();
}

class _BeneficiosScreenState extends State<BeneficiosScreen> {
  final BeneficiosService _service = BeneficiosService();

  late Future<List<BeneficioModel>> _futuro;
  FiltrosBeneficios _filtros = const FiltrosBeneficios();

  @override
  void initState() {
    super.initState();
    _futuro = _service.obtenerVigentes();
  }

  void _recargar() => setState(() => _futuro = _service.obtenerVigentes());

  Future<void> _refrescar() async {
    final nuevo = _service.obtenerVigentes();
    setState(() => _futuro = nuevo);
    try {
      await nuevo;
    } catch (_) {
      // El error se muestra en pantalla con el botón "Reintentar".
    }
  }

  Future<void> _abrirFiltros(List<BeneficioModel> todos) async {
    final nuevos = await showModalBottomSheet<FiltrosBeneficios>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kMantTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HojaFiltros(
        filtros: _filtros,
        ubicaciones: ubicacionesDisponibles(todos),
      ),
    );
    if (nuevos != null) setState(() => _filtros = nuevos);
  }

  void _mostrarDetalle(BeneficioModel b) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kMantTarjeta,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DetalleBeneficio(beneficio: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BeneficioModel>>(
      future: _futuro,
      builder: (context, snap) {
        final todos = snap.data ?? const <BeneficioModel>[];
        final cargado = snap.connectionState == ConnectionState.done && !snap.hasError;

        return Scaffold(
          backgroundColor: kMantFondo,
          appBar: AppBar(
            backgroundColor: kMantFondo,
            elevation: 0,
            title: const Text('Beneficios', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (cargado && todos.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Filtros',
                      onPressed: () => _abrirFiltros(todos),
                      icon: const Icon(Icons.tune),
                    ),
                    if (_filtros.hayFiltros)
                      Positioned(
                        top: 8,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: kMantPrimario, shape: BoxShape.circle),
                          child: Text(
                            '${_filtros.cantidadActivos}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          body: _construirCuerpo(snap, todos),
        );
      },
    );
  }

  Widget _construirCuerpo(AsyncSnapshot<List<BeneficioModel>> snap, List<BeneficioModel> todos) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }

    // E2: falla de red al consultar el catálogo.
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: kMantTextoSuave, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar el catálogo. Revisa tu conexión e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMantTexto),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: _recargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (todos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refrescar,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.card_giftcard_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay beneficios disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMantTexto, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estamos sumando comercios aliados. Vuelve pronto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMantTextoSuave),
            ),
          ],
        ),
      );
    }

    final lista = aplicarFiltros(todos, _filtros);
    final categorias = categoriasConBeneficios(todos);

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final id = categorias[i];
                final activa = _filtros.categorias.contains(id);
                return FilterChip(
                  avatar: Icon(iconoCategoriaBeneficio(id), size: 16, color: activa ? Colors.white : kMantTextoSuave),
                  label: Text(kCategoriasBeneficio[id]!),
                  selected: activa,
                  showCheckmark: false,
                  selectedColor: kMantPrimario,
                  backgroundColor: kMantTarjeta,
                  labelStyle: TextStyle(color: activa ? Colors.white : kMantTextoSuave, fontSize: 13),
                  side: BorderSide(color: activa ? kMantPrimario : Colors.white.withValues(alpha: 0.08)),
                  onSelected: (v) {
                    final nuevas = {..._filtros.categorias};
                    v ? nuevas.add(id) : nuevas.remove(id);
                    setState(() => _filtros = _filtros.copyWith(categorias: nuevas));
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (lista.isEmpty)
            _buildSinResultados()
          else
            for (final b in lista) _buildTarjeta(b),
        ],
      ),
    );
  }

  /// E1: ningún beneficio coincide con los filtros.
  Widget _buildSinResultados() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text(
            'No se encontraron beneficios para estos criterios',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Prueba con otros filtros o restablécelos.', textAlign: TextAlign.center, style: TextStyle(color: kMantTextoSuave)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMantPrimario,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => setState(() => _filtros = const FiltrosBeneficios()),
            icon: const Icon(Icons.filter_alt_off_outlined, color: Colors.white),
            label: const Text('Restablecer filtros', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjeta(BeneficioModel b) {
    final dias = diasParaVencer(b);
    final porVencer = dias != null && dias <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _mostrarDetalle(b),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _ImagenBeneficio(beneficio: b, altura: 150),
                  if (b.destacado)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _kDestacado, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: kMantFondo),
                            SizedBox(width: 4),
                            Text('Destacado', style: TextStyle(color: kMantFondo, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.titulo, style: const TextStyle(color: kMantTexto, fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(b.comercio, style: const TextStyle(color: kMantTextoSuave, fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kMantPrimario.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(iconoCategoriaBeneficio(b.categoria), size: 14, color: kMantPrimario),
                              const SizedBox(width: 4),
                              Text(
                                etiquetaCategoriaBeneficio(b.categoria),
                                style: const TextStyle(color: kMantPrimario, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.schedule, size: 14, color: porVencer ? kMantAdvertencia : kMantTextoSuave),
                        const SizedBox(width: 4),
                        Text(
                          textoVigencia(b),
                          style: TextStyle(
                            color: porVencer ? kMantAdvertencia : kMantTextoSuave,
                            fontSize: 12,
                            fontWeight: porVencer ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
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

/// Imagen del beneficio, o un bloque con el ícono de su categoría si no tiene
/// imagen o no se pudo cargar.
class _ImagenBeneficio extends StatelessWidget {
  final BeneficioModel beneficio;
  final double altura;

  const _ImagenBeneficio({required this.beneficio, required this.altura});

  @override
  Widget build(BuildContext context) {
    final respaldo = Container(
      height: altura,
      width: double.infinity,
      color: kMantPrimario.withValues(alpha: 0.12),
      child: Icon(iconoCategoriaBeneficio(beneficio.categoria), size: 56, color: kMantPrimario.withValues(alpha: 0.6)),
    );

    final url = beneficio.imagenUrl;
    if (url == null) return respaldo;
    return Image.network(
      url,
      height: altura,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => respaldo,
      loadingBuilder: (context, child, progreso) => progreso == null ? child : SizedBox(height: altura, child: respaldo),
    );
  }
}

/// Hoja de filtros: ubicación y vigencia. Las categorías se eligen con los chips
/// de arriba de la lista.
class _HojaFiltros extends StatefulWidget {
  final FiltrosBeneficios filtros;
  final List<String> ubicaciones;

  const _HojaFiltros({required this.filtros, required this.ubicaciones});

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late FiltrosBeneficios _filtros;

  @override
  void initState() {
    super.initState();
    _filtros = widget.filtros;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filtros', style: TextStyle(color: kMantTexto, fontSize: 20, fontWeight: FontWeight.bold)),
            if (widget.ubicaciones.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Ubicación', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filtros.ubicacion == null,
                    onSelected: (_) => setState(() => _filtros = _filtros.copyWith(quitarUbicacion: true)),
                    selectedColor: kMantPrimario,
                    backgroundColor: kMantFondo,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: _filtros.ubicacion == null ? Colors.white : kMantTextoSuave),
                  ),
                  for (final u in widget.ubicaciones)
                    ChoiceChip(
                      label: Text(u),
                      selected: _filtros.ubicacion == u,
                      onSelected: (_) => setState(() => _filtros = _filtros.copyWith(ubicacion: u)),
                      selectedColor: kMantPrimario,
                      backgroundColor: kMantFondo,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: _filtros.ubicacion == u ? Colors.white : kMantTextoSuave),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Text('Vigencia', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in FiltroVigencia.values)
                  ChoiceChip(
                    label: Text(etiquetaFiltroVigencia(v)),
                    selected: _filtros.vigencia == v,
                    onSelected: (_) => setState(() => _filtros = _filtros.copyWith(vigencia: v)),
                    selectedColor: kMantPrimario,
                    backgroundColor: kMantFondo,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: _filtros.vigencia == v ? Colors.white : kMantTextoSuave),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kMantTexto,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    // Restablece solo lo de esta hoja; las categorías se conservan.
                    onPressed: () => setState(() {
                      _filtros = FiltrosBeneficios(categorias: _filtros.categorias);
                    }),
                    child: const Text('Restablecer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMantPrimario,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, _filtros),
                    child: const Text('Aplicar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de un beneficio: condiciones de uso, comercio, vigencia y cómo canjearlo.
class _DetalleBeneficio extends StatelessWidget {
  final BeneficioModel beneficio;

  const _DetalleBeneficio({required this.beneficio});

  @override
  Widget build(BuildContext context) {
    final b = beneficio;
    final dias = diasParaVencer(b);
    final porVencer = dias != null && dias <= 7;

    Widget bloque(String titulo, String texto) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(color: kMantTextoSuave, fontSize: 13)),
              const SizedBox(height: 6),
              Text(texto, style: const TextStyle(color: kMantTexto, fontSize: 14, height: 1.4)),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: _ImagenBeneficio(beneficio: b, altura: 170),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.titulo, style: const TextStyle(color: kMantTexto, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(b.comercio, style: const TextStyle(color: kMantTextoSuave, fontSize: 15)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(iconoCategoriaBeneficio(b.categoria), size: 16, color: kMantPrimario),
                        label: Text(etiquetaCategoriaBeneficio(b.categoria)),
                        backgroundColor: kMantPrimario.withValues(alpha: 0.15),
                        labelStyle: const TextStyle(color: kMantPrimario, fontSize: 12),
                        side: BorderSide.none,
                      ),
                      Chip(
                        avatar: Icon(Icons.schedule, size: 16, color: porVencer ? kMantAdvertencia : kMantTextoSuave),
                        label: Text(textoVigencia(b)),
                        backgroundColor: kMantFondo,
                        labelStyle: TextStyle(color: porVencer ? kMantAdvertencia : kMantTextoSuave, fontSize: 12),
                        side: BorderSide.none,
                      ),
                      if (b.ubicacion != null)
                        Chip(
                          avatar: const Icon(Icons.place_outlined, size: 16, color: kMantTextoSuave),
                          label: Text(b.ubicacion!),
                          backgroundColor: kMantFondo,
                          labelStyle: const TextStyle(color: kMantTextoSuave, fontSize: 12),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  if (b.descripcion != null) bloque('Descripción', b.descripcion!),
                  if (b.condiciones != null) bloque('Condiciones de uso', b.condiciones!),
                  if (b.codigoCanje != null) ...[
                    const SizedBox(height: 18),
                    const Text('Cómo canjearlo', style: TextStyle(color: kMantTextoSuave, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kMantOk.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kMantOk.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number_outlined, color: kMantOk),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              b.codigoCanje!,
                              style: const TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: b.codigoCanje!));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copiado'), behavior: SnackBarBehavior.floating),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copiar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kMantTexto,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
