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

/// Color propio de cada categoría: se usa en las tarjetas sin imagen, en las
/// etiquetas y en el detalle, para reconocer el tipo de beneficio de un vistazo.
Color colorCategoriaBeneficio(String? categoria) {
  switch (categoria) {
    case 'combustible':
      return const Color(0xFFF97316);
    case 'talleres':
      return const Color(0xFF3B82F6);
    case 'mantenciones':
      return const Color(0xFF14B8A6);
    case 'estacionamiento':
      return const Color(0xFF6366F1);
    case 'lavado':
      return const Color(0xFF0EA5E9);
    case 'neumaticos':
      return const Color(0xFFEAB308);
    case 'seguros':
      return const Color(0xFF10B981);
    case 'accesorios':
      return const Color(0xFFEC4899);
    default:
      return kMantIA;
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

  late Stream<List<BeneficioModel>> _stream;
  FiltrosBeneficios _filtros = const FiltrosBeneficios();

  @override
  void initState() {
    super.initState();
    _stream = _service.streamVigentes();
  }

  /// Vuelve a armar el flujo (botón "Reintentar" y deslizar para actualizar): consulta
  /// de inmediato en vez de esperar al refresco automático.
  void _recargar() => setState(() => _stream = _service.streamVigentes());

  Future<void> _refrescar() async {
    _recargar();
    // Da tiempo a que llegue la primera respuesta antes de ocultar el indicador.
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
    return StreamBuilder<List<BeneficioModel>>(
      stream: _stream,
      builder: (context, snap) {
        final todos = snap.data ?? const <BeneficioModel>[];
        final cargado = snap.hasData;

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
    // E2: falla de red al consultar el catálogo.
    if (snap.hasError && !snap.hasData) {
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

    if (!snap.hasData) {
      return const Center(child: CircularProgressIndicator());
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
    // Los destacados se muestran arriba solo cuando no hay filtros: con filtros el
    // usuario busca algo concreto y ve directamente los resultados.
    final destacados = _filtros.hayFiltros ? const <BeneficioModel>[] : todos.where((b) => b.destacado).toList();

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          //_buildEncabezado(todos.length),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final id = categorias[i];
                final activa = _filtros.categorias.contains(id);
                final color = colorCategoriaBeneficio(id);
                return FilterChip(
                  avatar: Icon(iconoCategoriaBeneficio(id), size: 16, color: activa ? Colors.white : color),
                  label: Text(kCategoriasBeneficio[id]!),
                  selected: activa,
                  showCheckmark: false,
                  selectedColor: color,
                  backgroundColor: kMantTarjeta,
                  labelStyle: TextStyle(
                    color: activa ? Colors.white : kMantTexto,
                    fontSize: 13,
                    fontWeight: activa ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(color: activa ? color : Colors.white.withValues(alpha: 0.08)),
                  onSelected: (v) {
                    final nuevas = {..._filtros.categorias};
                    v ? nuevas.add(id) : nuevas.remove(id);
                    setState(() => _filtros = _filtros.copyWith(categorias: nuevas));
                  },
                );
              },
            ),
          ),
          if (destacados.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildTituloSeccion('Destacados', icono: Icons.star_rounded, color: _kDestacado),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: destacados.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _TarjetaDestacada(
                  beneficio: destacados[i],
                  onTap: () => _mostrarDetalle(destacados[i]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _buildTituloSeccion(
            _filtros.hayFiltros ? 'Resultados' : 'Todos los beneficios',
            detalle: '${lista.length}',
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

  /// Encabezado con un resumen del catálogo.
  /*Widget _buildEncabezado(int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kMantPrimario, Color.lerp(kMantPrimario, kMantIA, 0.7)!],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beneficios para ti',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 1 ? '1 beneficio disponible con comercios aliados' : '$total beneficios disponibles con comercios aliados',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
*/
  Widget _buildTituloSeccion(String titulo, {IconData? icono, Color color = kMantPrimario, String? detalle}) {
    return Row(
      children: [
        if (icono != null) ...[
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 6),
        ] else ...[
          Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
        ],
        Text(titulo, style: const TextStyle(color: kMantTexto, fontSize: 17, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (detalle != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: kMantTarjeta, borderRadius: BorderRadius.circular(20)),
            child: Text(detalle, style: const TextStyle(color: kMantTextoSuave, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  /// E1: ningún beneficio coincide con los filtros.
  Widget _buildSinResultados() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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

  /// Tarjeta de la lista: miniatura a la izquierda y los datos a la derecha.
  Widget _buildTarjeta(BeneficioModel b) {
    final color = colorCategoriaBeneficio(b.categoria);
    final dias = diasParaVencer(b);
    final porVencer = dias != null && dias <= 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: kMantTarjeta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _mostrarDetalle(b),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _ImagenBeneficio(beneficio: b, altura: 92, ancho: 92, iconoGrande: false),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.comercio.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                            ),
                          ),
                          if (b.destacado) const Icon(Icons.star_rounded, size: 16, color: _kDestacado),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMantTexto, fontSize: 16, fontWeight: FontWeight.bold, height: 1.25),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Pildora(
                            icono: iconoCategoriaBeneficio(b.categoria),
                            texto: etiquetaCategoriaBeneficio(b.categoria),
                            color: color,
                          ),
                          _Pildora(
                            icono: Icons.schedule,
                            texto: textoVigencia(b),
                            color: porVencer ? kMantAdvertencia : kMantTextoSuave,
                            resaltada: porVencer,
                          ),
                          if (b.ubicacion != null)
                            _Pildora(icono: Icons.place_outlined, texto: b.ubicacion!, color: kMantTextoSuave),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 30),
                  child: Icon(Icons.chevron_right_rounded, color: kMantTextoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña con ícono y texto (categoría, vigencia, ubicación).
class _Pildora extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  final bool resaltada;

  const _Pildora({required this.icono, required this.texto, required this.color, this.resaltada = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: resaltada ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: resaltada ? FontWeight.w700 : FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta grande de la franja "Destacados": imagen a todo el fondo con el título
/// encima.
class _TarjetaDestacada extends StatelessWidget {
  final BeneficioModel beneficio;
  final VoidCallback onTap;

  const _TarjetaDestacada({required this.beneficio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = beneficio;
    final color = colorCategoriaBeneficio(b.categoria);
    final dias = diasParaVencer(b);
    final porVencer = dias != null && dias <= 7;

    return SizedBox(
      width: 280,
      child: Material(
        color: kMantTarjeta,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ImagenBeneficio(beneficio: b),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                    stops: [0.3, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _Pildora(
                  icono: iconoCategoriaBeneficio(b.categoria),
                  texto: etiquetaCategoriaBeneficio(b.categoria),
                  color: Colors.white,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: _kDestacado, shape: BoxShape.circle),
                  child: const Icon(Icons.star_rounded, size: 16, color: kMantFondo),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.comercio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13, color: porVencer ? kMantAdvertencia : Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          textoVigencia(b),
                          style: TextStyle(
                            color: porVencer ? kMantAdvertencia : Colors.white70,
                            fontSize: 12,
                            fontWeight: porVencer ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                          child: const Text('Ver', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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

/// Imagen del beneficio, o un degradado con el color e ícono de su categoría si no
/// tiene imagen o no se pudo cargar. Sin [altura] ni [ancho] ocupa todo el espacio
/// disponible.
class _ImagenBeneficio extends StatelessWidget {
  final BeneficioModel beneficio;
  final double? altura;
  final double? ancho;
  final bool iconoGrande;

  const _ImagenBeneficio({required this.beneficio, this.altura, this.ancho, this.iconoGrande = true});

  @override
  Widget build(BuildContext context) {
    final color = colorCategoriaBeneficio(beneficio.categoria);
    final icono = iconoCategoriaBeneficio(beneficio.categoria);

    final respaldo = Container(
      height: altura,
      width: ancho ?? double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, kMantFondo, 0.65)!],
        ),
      ),
      child: iconoGrande
          ? Stack(
              children: [
                Positioned(right: -14, bottom: -14, child: Icon(icono, size: 130, color: Colors.white.withValues(alpha: 0.16))),
              ],
            )
          : Center(child: Icon(icono, size: 36, color: Colors.white.withValues(alpha: 0.95))),
    );

    final url = beneficio.imagenUrl;
    if (url == null) return respaldo;
    return Image.network(
      url,
      height: altura,
      width: ancho ?? double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => respaldo,
      loadingBuilder: (context, child, progreso) => progreso == null ? child : respaldo,
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

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: beneficio.codigoCanje!));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = beneficio;
    final color = colorCategoriaBeneficio(b.categoria);
    final dias = diasParaVencer(b);
    final porVencer = dias != null && dias <= 7;

    Widget bloque(IconData icono, String titulo, String texto) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 18, color: kMantTextoSuave),
                  const SizedBox(width: 8),
                  Text(titulo, style: const TextStyle(color: kMantTexto, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(texto, style: const TextStyle(color: kMantTextoSuave, fontSize: 14, height: 1.5)),
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
              child: SizedBox(
                height: 210,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ImagenBeneficio(beneficio: b),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xD9000000)],
                          stops: [0.25, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                    if (b.destacado)
                      Positioned(
                        top: 24,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _kDestacado, borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: kMantFondo),
                              SizedBox(width: 4),
                              Text('Destacado', style: TextStyle(color: kMantFondo, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            b.comercio,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.titulo,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pildora(icono: iconoCategoriaBeneficio(b.categoria), texto: etiquetaCategoriaBeneficio(b.categoria), color: color),
                      _Pildora(
                        icono: Icons.schedule,
                        texto: textoVigencia(b),
                        color: porVencer ? kMantAdvertencia : kMantTextoSuave,
                        resaltada: porVencer,
                      ),
                      if (b.ubicacion != null) _Pildora(icono: Icons.place_outlined, texto: b.ubicacion!, color: kMantTextoSuave),
                    ],
                  ),
                  if (b.codigoCanje != null) ...[
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.06)],
                        ),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.confirmation_number_outlined, size: 18, color: color),
                              const SizedBox(width: 8),
                              const Text('Cómo canjearlo', style: TextStyle(color: kMantTexto, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(color: kMantFondo, borderRadius: BorderRadius.circular(12)),
                            child: SelectableText(
                              b.codigoCanje!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: kMantTexto, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _copiar(context),
                              icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                              label: const Text('Copiar código', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (b.descripcion != null) bloque(Icons.info_outline_rounded, 'Descripción', b.descripcion!),
                  if (b.condiciones != null) bloque(Icons.rule_rounded, 'Condiciones de uso', b.condiciones!),
                  const SizedBox(height: 22),
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
                      child: const Text('Cerrar'),
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
