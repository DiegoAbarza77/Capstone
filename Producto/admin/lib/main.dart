import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'file_downloader.dart';

import 'login_screen.dart';
import 'admin_supabase_service.dart';
import 'beneficios_page.dart';
import 'metricas_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde el archivo .env local (no versionado)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('TAG_OK_ADMIN: no se pudo cargar .env: $e');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const TagOkAdminApp());
}

class TagOkAdminApp extends StatelessWidget {
  const TagOkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TAG OK Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}

class SidebarItem {
  final String title;
  final IconData icon;
  final Widget Function(AdminSupabaseService service) pageBuilder;

  const SidebarItem({
    required this.title,
    required this.icon,
    required this.pageBuilder,
  });
}

class AdminShell extends StatefulWidget {
  final String role;
  const AdminShell({super.key, required this.role});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final AdminSupabaseService _service = AdminSupabaseService();
  int _selectedIndex = 0;
  late final List<SidebarItem> _sidebarItems;

  @override
  void initState() {
    super.initState();
    _sidebarItems = _getSidebarItems(widget.role);
  }

  List<SidebarItem> _getSidebarItems(String role) {
    final String r = role.toLowerCase().trim();
    final bool isSuper =
        r == 'super_admin' ||
        r == 'super_administrador' ||
        r == 'superadmin' ||
        r == 'super administrador';

    final List<SidebarItem> all = [
      SidebarItem(
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
        pageBuilder: (s) => DashboardPage(service: s),
      ),
      SidebarItem(
        title: 'Usuarios',
        icon: Icons.people_alt_outlined,
        pageBuilder: (s) => UsersPage(service: s),
      ),
      SidebarItem(
        title: 'Pórticos',
        icon: Icons.toll_outlined,
        pageBuilder: (s) => PorticosPage(service: s),
      ),
      SidebarItem(
        title: 'Tarifas',
        icon: Icons.payments_outlined,
        pageBuilder: (s) => TariffsPage(service: s),
      ),
      SidebarItem(
        title: 'Reportes',
        icon: Icons.bar_chart_outlined,
        pageBuilder: (s) => ReportsPage(service: s),
      ),
      SidebarItem(
        title: 'Métricas',
        icon: Icons.insights_outlined,
        pageBuilder: (s) => MetricasPage(service: s),
      ),
      SidebarItem(
        title: 'Beneficios',
        icon: Icons.card_giftcard_outlined,
        pageBuilder: (s) => BeneficiosPage(service: s),
      ),
      SidebarItem(
        title: 'Auditoría',
        icon: Icons.receipt_long_outlined,
        pageBuilder: (s) => AuditLogPage(service: s),
      ),
      SidebarItem(
        title: 'Admins',
        icon: Icons.admin_panel_settings_outlined,
        pageBuilder: (s) => AdminsManagementPage(service: s),
      ),
    ];

    if (isSuper) {
      return all;
    } else {
      // Operator gets Dashboard, Pórticos, Tarifas, Reportes, Métricas y Beneficios
      return all
          .where(
            (item) =>
                item.title == 'Dashboard' ||
                item.title == 'Pórticos' ||
                item.title == 'Tarifas' ||
                item.title == 'Reportes' ||
                item.title == 'Métricas' ||
                item.title == 'Beneficios',
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex >= _sidebarItems.length) {
      _selectedIndex = 0;
    }

    final item = _sidebarItems[_selectedIndex];
    final Widget content = item.pageBuilder(_service);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF111827)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _WindowControls(),
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: _BrandBlock(),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Backoffice',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _sidebarItems.length,
                      itemBuilder: (context, index) {
                        final bool selected = _selectedIndex == index;
                        final sidebarItem = _sidebarItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            selected: selected,
                            selectedTileColor: const Color(0xFF1E293B),
                            iconColor: selected
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFCBD5E1),
                            textColor: selected
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                            leading: Icon(sidebarItem.icon),
                            title: Text(sidebarItem.title),
                            onTap: () => setState(() => _selectedIndex = index),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Color(0xFF1E293B)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: _UserProfileCard(role: widget.role),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      iconColor: const Color(0xFFEF4444),
                      textColor: const Color(0xFFEF4444),
                      leading: const Icon(Icons.logout),
                      title: const Text('Cerrar sesión'),
                      onTap: () async {
                        await Supabase.instance.client.auth.signOut();
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: _AdminHintCard(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LogoMark(),
        SizedBox(height: 16),
        Text(
          'TAG OK',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Panel de administración web',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.route_outlined,
        color: Color(0xFF38BDF8),
        size: 32,
      ),
    );
  }
}

class _AdminHintCard extends StatelessWidget {
  const _AdminHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acceso interno',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Este panel comparte la misma base de datos Supabase que la app final. Usa roles para restringir edición y publicación.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final String role;
  const _UserProfileCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final String email =
        Supabase.instance.client.auth.currentUser?.email ?? 'admin@tagok.cl';
    final String r = role.toLowerCase().trim();
    final bool isSuper =
        r == 'super_admin' ||
        r == 'super_administrador' ||
        r == 'superadmin' ||
        r == 'super administrador';

    final String roleLabel = isSuper
        ? 'Super Administrador'
        : 'Administrador Operacional';
    final Color badgeBg = isSuper
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
        : const Color(0xFFF59E0B).withValues(alpha: 0.12);
    final Color badgeText = isSuper
        ? const Color(0xFF38BDF8)
        : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: badgeBg,
            radius: 16,
            child: Icon(
              isSuper ? Icons.admin_panel_settings : Icons.person_outline,
              color: badgeText,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _activeTabIndex = 0;
  final List<String> _tabs = ['Resumen', 'Analíticas', 'Historial'];

  String _formatFecha(dynamic dateVal) {
    if (dateVal == null) return '-';
    if (dateVal is String) {
      return dateVal.length >= 16 ? dateVal.substring(0, 16) : dateVal;
    }
    return dateVal.toString();
  }

  DateTime? parseTripDate(dynamic dateVal) {
    if (dateVal == null) return null;
    if (dateVal is String) {
      return DateTime.tryParse(dateVal);
    }
    return null;
  }

  String _classifyHighway(String tollName) {
    final name = tollName.toLowerCase();
    if (name.contains('autopista de conexión') || name.contains('conexión')) {
      return 'Conexión / Otras';
    }
    if (name.startsWith('pa') ||
        name.contains('autopista central') ||
        name.contains('ruta 5')) {
      return 'Autopista Central';
    }
    if (name.contains('costanera') ||
        name.contains('vivaceta') ||
        name.contains('lo saldes') ||
        name.contains('la dehesa') ||
        name.contains('estoril') ||
        name.contains('padre arteaga') ||
        name.contains('tranqueras') ||
        name.contains('carrascal') ||
        name.contains('padre hurtado') ||
        name.startsWith('ev ') ||
        name.startsWith('sv ')) {
      return 'Costanera Norte';
    }
    if (name.contains('avo') ||
        name.contains('kennedy') ||
        name.contains('p101') ||
        name.contains('p102') ||
        name.contains('vespucio oriente')) {
      return 'Vespucio Oriente (AVO)';
    }
    if (name.contains('vespucio norte') ||
        name.contains('guanaco') ||
        name.contains('el salto') ||
        name.contains('lo boza') ||
        name.contains('recabal') ||
        name.contains('enea') ||
        name.contains('p14') ||
        name.contains('p13') ||
        name.contains('p12') ||
        name.contains('p15')) {
      return 'Vespucio Norte';
    }
    if (name.contains('vespucio sur') ||
        name.contains('pvs') ||
        name.contains('velásquez') ||
        name.contains('velasquez') ||
        name.contains('gran avenida') ||
        name.contains('santa rosa') ||
        name.contains('vicuña mackenna') ||
        name.contains('alderete') ||
        name.contains('2a transversal') ||
        name.contains('los mares') ||
        name.contains('coronel') ||
        name.contains('camino a melipilla')) {
      return 'Vespucio Sur';
    }
    if (name.contains('ruta 68')) {
      return 'Conexión / Otras';
    }
    if (name.contains('ruta 78') || name.contains('autopista del sol')) {
      return 'Conexión / Otras';
    }
    return 'Conexión / Otras';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.service.streamUserTrips(),
      builder: (context, tripsSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.service.streamUsers(),
          builder: (context, usersSnapshot) {
            if (tripsSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error en viajes: ${tripsSnapshot.error}')),
              );
            }
            if (usersSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error en usuarios: ${usersSnapshot.error}')),
              );
            }

            if (tripsSnapshot.connectionState == ConnectionState.waiting ||
                usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final trips = tripsSnapshot.data ?? [];
            final usersDocs = usersSnapshot.data ?? [];

            double totalTollCost = 0.0;
            final Map<String, double> costByHighway = {
              'Autopista Central': 0.0,
              'Costanera Norte': 0.0,
              'Vespucio Norte': 0.0,
              'Vespucio Sur': 0.0,
              'Vespucio Oriente (AVO)': 0.0,
              'Conexión / Otras': 0.0,
            };

            for (var data in trips) {
              final double tripCost = double.tryParse(data['total_cost']?.toString() ?? '0') ?? 0.0;
              totalTollCost += tripCost;

              final List<dynamic> tollsList = data['tolls'] as List<dynamic>? ?? [];
              for (var tollRaw in tollsList) {
                if (tollRaw is Map) {
                  final String tollName = (tollRaw['name'] ?? '').toString();
                  final double tollCost = double.tryParse(tollRaw['cost']?.toString() ?? '0') ?? 0.0;
                  final String highway = _classifyHighway(tollName);

                  if (costByHighway.containsKey(highway)) {
                    costByHighway[highway] = costByHighway[highway]! + tollCost;
                  } else {
                    costByHighway['Conexión / Otras'] = costByHighway['Conexión / Otras']! + tollCost;
                  }
                }
              }
            }

            final Map<String, int> dailyCounts = {};
            final List<DateTime> last7Days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
            for (var day in last7Days) {
              final key = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
              dailyCounts[key] = 0;
            }
            for (var data in trips) {
              final date = parseTripDate(data['date']);
              if (date != null) {
                final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                if (dailyCounts.containsKey(key)) {
                  dailyCounts[key] = dailyCounts[key]! + 1;
                }
              }
            }

            final String adminEmail = Supabase.instance.client.auth.currentUser?.email ?? 'admin@tagok.cl';

            Widget contentWidget;
            if (_activeTabIndex == 1) {
              contentWidget = FutureBuilder<AdminOverview>(
                future: widget.service.fetchOverview(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final overview = snapshot.data;
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _StatCard(
                            label: 'Usuarios Registrados',
                            value: overview?.users ?? 0,
                            icon: Icons.people_alt_outlined,
                          ),
                          _StatCard(
                            label: 'Vehículos Asociados',
                            value: overview?.vehicles ?? 0,
                            icon: Icons.directions_car_outlined,
                          ),
                          _StatCard(
                            label: 'Pórticos Activos',
                            value: overview?.porticos ?? 0,
                            icon: Icons.toll_outlined,
                          ),
                          _StatCard(
                            label: 'Tarifas Vigentes',
                            value: overview?.tariffs ?? 0,
                            icon: Icons.payments_outlined,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } else if (_activeTabIndex == 2) {
              contentWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Historial de Peajes Cobrados (Tiempo Real)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: trips.length,
                                itemBuilder: (context, index) {
                                  final data = trips[index];
                                  final String vehiculo = (data['vehicle_name'] ?? 'Desconocido').toString();
                                  final String fecha = _formatFecha(data['date']);
                                  final int totalCost = (num.tryParse(data['total_cost']?.toString() ?? '0') ?? 0).round();

                                  final List<dynamic> tollsList = data['tolls'] as List<dynamic>? ?? [];
                                  String highway = 'Otras';
                                  if (tollsList.isNotEmpty && tollsList[0] is Map) {
                                    highway = _classifyHighway((tollsList[0]['name'] ?? '').toString());
                                  }

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    color: const Color(0xFFF8FAFC),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Color(0xFFE0F2FE),
                                        child: Icon(Icons.directions_car_outlined, color: Color(0xFF0284C7)),
                                      ),
                                      title: Text(vehiculo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('$highway • $fecha'),
                                      trailing: Text(
                                        '\$$totalCost',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF065F46),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              final Widget card1 = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Viajes Recientes por Día',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BarChart(
                          dailyCounts: dailyCounts,
                          last7Days: last7Days,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final Widget card2 = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distribución de Costos por Autopista',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: DonutChart(
                          costByHighway: costByHighway,
                          totalCost: totalTollCost,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final Widget card3 = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uso y Distribución de Cobros',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: HighwayProgressBars(
                          costByHighway: costByHighway,
                          totalCost: totalTollCost,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              contentWidget = Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 900) {
                            return Column(
                              children: [
                                SizedBox(height: 230, child: card1),
                                const SizedBox(height: 16),
                                SizedBox(height: 230, child: card2),
                                const SizedBox(height: 16),
                                SizedBox(height: 230, child: card3),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: SizedBox(height: 230, child: card1)),
                              const SizedBox(width: 16),
                              Expanded(child: SizedBox(height: 230, child: card2)),
                              const SizedBox(width: 16),
                              Expanded(child: SizedBox(height: 230, child: card3)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final Widget left = Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tránsitos Recientes',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: trips.length > 5 ? 5 : trips.length,
                                    itemBuilder: (context, index) {
                                      final data = trips[index];
                                      final String vehiculo = (data['vehicle_name'] ?? 'Desconocido').toString();
                                      final String fecha = _formatFecha(data['date']);
                                      final int totalCost = (num.tryParse(data['total_cost']?.toString() ?? '0') ?? 0).round();

                                      final List<dynamic> tollsList = data['tolls'] as List<dynamic>? ?? [];
                                      String highway = 'Otras';
                                      if (tollsList.isNotEmpty && tollsList[0] is Map) {
                                        highway = _classifyHighway((tollsList[0]['name'] ?? '').toString());
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Color(0xFFE0F2FE),
                                              child: Icon(Icons.directions_car_outlined, size: 16, color: Color(0xFF0284C7)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    vehiculo,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                  Text(
                                                    fecha,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                highway,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFA7F3D0)),
                                              ),
                                              child: Text(
                                                '\$$totalCost',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF065F46),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Procesado',
                                                style: TextStyle(
                                                  color: Color(0xFF2563EB),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );

                          final Widget right = Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Usuarios Recientes',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: usersDocs.length > 5 ? 5 : usersDocs.length,
                                    itemBuilder: (context, index) {
                                      final data = usersDocs[index];
                                      final String email = (data['email'] ?? 'Usuario sin correo').toString();
                                      final String nombre = (data['nombre_mostrar'] ?? 'Usuario de TAG OK').toString();
                                      final String initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    nombre,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    email,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (constraints.maxWidth < 1000) {
                            return Column(
                              children: [left, const SizedBox(height: 16), right],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: left),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: right),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(_tabs.length, (index) {
                                final isSelected = _activeTabIndex == index;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: InkWell(
                                    onTap: () => setState(() => _activeTabIndex = index),
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _tabs[index],
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 24,
                                          height: 2,
                                          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    adminEmail,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const CircleAvatar(
                              backgroundColor: Color(0xFFF1F5F9),
                              child: Icon(Icons.person_outline_rounded, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_activeTabIndex == 2)
                      Expanded(child: contentWidget)
                    else
                      contentWidget,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0.0, (acc, val) => acc + val);
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 12;

    if (total == 0) {
      final Paint paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -3.14159 / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * 3.14159;
      final Paint paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChart extends StatelessWidget {
  final Map<String, double> costByHighway;
  final double totalCost;

  const DonutChart({
    super.key,
    required this.costByHighway,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> highways = costByHighway.keys.toList();
    final List<double> values = costByHighway.values.toList();

    final List<Color> colors = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF64748B),
    ];

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: DonutChartPainter(
                    values: values,
                    colors: colors,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Total Peajes',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${totalCost.round()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(highways.length, (index) {
              if (index >= colors.length) return const SizedBox.shrink();
              final double cost = values[index];
              final double pct = totalCost > 0 ? (cost / totalCost) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors[index],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        highways[index],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class BarChart extends StatelessWidget {
  final Map<String, int> dailyCounts;
  final List<DateTime> last7Days;

  const BarChart({
    super.key,
    required this.dailyCounts,
    required this.last7Days,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final List<int> counts = last7Days.map((day) {
      final key = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      return dailyCounts[key] ?? 0;
    }).toList();

    final int maxCount = counts.fold(0, (max, val) => val > max ? val : max);
    final double chartHeight = 95.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final day = last7Days[index];
        final count = counts[index];
        final String dayLabel = weekdays[day.weekday % 7];
        final double barHeight = maxCount > 0 ? (count / maxCount) * chartHeight : 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 14,
              height: barHeight > 4 ? barHeight : 4.0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dayLabel,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class HighwayProgressBars extends StatelessWidget {
  final Map<String, double> costByHighway;
  final double totalCost;

  const HighwayProgressBars({
    super.key,
    required this.costByHighway,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = costByHighway.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayList = sorted.take(4).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayList.length, (index) {
        final entry = displayList[index];
        final double cost = entry.value;
        final double pct = totalCost > 0 ? (cost / totalCost) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${cost.round()} (${(pct * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: const Color(0xFF2563EB),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedBudgetFilter = 'Todos'; // 'Todos', '> 50.000', '< = 50.000'
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final nombre = (data['nombre_mostrar'] ?? '').toString().toLowerCase();
    final correo = (data['email'] ?? '').toString().toLowerCase();
    if (_searchQuery.isNotEmpty &&
        !nombre.contains(_searchQuery) &&
        !correo.contains(_searchQuery)) {
      return false;
    }

    final int presupuesto =
        int.tryParse(data['limite_presupuesto_mensual']?.toString() ?? '0') ??
        0;
    if (_selectedBudgetFilter == '> 50.000' && presupuesto <= 50000) {
      return false;
    }
    if (_selectedBudgetFilter == '< = 50.000' && presupuesto > 50000) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageScaffold(
      title: 'Usuarios',
      subtitle:
          'Gestión de cuentas. (Por seguridad, las contraseñas están encriptadas. Usa las acciones para resetearlas).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Buscar usuario...',
                        hintText: 'Buscar por nombre o correo',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBudgetFilter,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Presupuesto Mensual',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Todos',
                          child: Text('Todos los presupuestos'),
                        ),
                        DropdownMenuItem(
                          value: '> 50.000',
                          child: Text('> \$50.000'),
                        ),
                        DropdownMenuItem(
                          value: '< = 50.000',
                          child: Text('≤ \$50.000'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedBudgetFilter = val;
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.service.streamUsers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error al leer datos: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final docs = snapshot.data!;
                final filteredDocs = docs
                    .where((doc) => _matchesFilters(doc))
                    .toList();

                if (filteredDocs.isEmpty) {
                  return Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Usuario no encontrado'
                              : 'No se encontraron usuarios con los filtros aplicados.',
                        ),
                      ),
                    ),
                  );
                }

                final int totalPages = (filteredDocs.length / _rowsPerPage)
                    .ceil();
                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1;
                }

                final int startIndex = _currentPage * _rowsPerPage;
                final int endIndex =
                    (startIndex + _rowsPerPage) > filteredDocs.length
                    ? filteredDocs.length
                    : (startIndex + _rowsPerPage);
                final pageDocs = filteredDocs.sublist(startIndex, endIndex);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Usuario')),
                                  DataColumn(label: Text('Presupuesto')),
                                  DataColumn(label: Text('Vehículo Principal')),
                                  DataColumn(label: Text('Estado')),
                                  DataColumn(label: Text('Acciones')),
                                ],
                                rows: pageDocs.map((doc) {
                                  final Map<String, dynamic> data = doc;
                                  final String docId = doc['id'] as String;
                                  final String nombre =
                                      (data['nombre_mostrar'] ?? 'Sin nombre')
                                          .toString();
                                  final String correo =
                                      (data['email'] ?? 'Sin correo')
                                          .toString();
                                  final int presupuesto =
                                      int.tryParse(
                                        data['limite_presupuesto_mensual']
                                                ?.toString() ??
                                            '0',
                                      ) ??
                                      0;
                                  final String vehiculoPrincipal =
                                      (data['vehiculo_principal_patente'] ??
                                              'Ninguno')
                                          .toString();
                                  final bool suspendido =
                                      data['estado'] == 'suspendido';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor:
                                                  _getColorFromName(nombre),
                                              child: Text(
                                                nombre.isNotEmpty
                                                    ? nombre[0].toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  nombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Text(
                                                  correo,
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: presupuesto > 50000
                                                ? const Color(0xFFEEF2FF)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: presupuesto > 50000
                                                  ? const Color(0xFFC7D2FE)
                                                  : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Text(
                                            '\$${_formatNumber(presupuesto)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: presupuesto > 50000
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFF475569),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons
                                                  .directions_car_filled_outlined,
                                              size: 16,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              vehiculoPrincipal,
                                              style: const TextStyle(
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: suspendido
                                                ? const Color(0xFFFEE2E2)
                                                : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            suspendido ? 'Suspendida' : 'Activa',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: suspendido
                                                  ? const Color(0xFFB91C1C)
                                                  : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Colors.blue,
                                                size: 20,
                                              ),
                                              tooltip: 'Editar Presupuesto',
                                              onPressed: () {
                                                _mostrarDialogoEdicion(
                                                  context,
                                                  docId,
                                                  nombre,
                                                  presupuesto,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.lock_reset_outlined,
                                                color: Colors.orange,
                                                size: 20,
                                              ),
                                              tooltip: 'Restablecer Contraseña',
                                              onPressed: () {
                                                _enviarResetPassword(
                                                  context,
                                                  correo,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                suspendido
                                                    ? Icons.lock_open_outlined
                                                    : Icons.block_outlined,
                                                color: suspendido
                                                    ? Colors.green
                                                    : Colors.deepOrange,
                                                size: 20,
                                              ),
                                              tooltip: suspendido
                                                  ? 'Reactivar cuenta'
                                                  : 'Suspender cuenta',
                                              onPressed: () {
                                                _confirmarCambioEstado(
                                                  context,
                                                  docId,
                                                  nombre,
                                                  suspender: !suspendido,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              tooltip: 'Eliminar Usuario',
                                              onPressed: () {
                                                _mostrarDialogoEliminar(
                                                  context,
                                                  docId,
                                                  nombre,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                        _TablePaginationControls(
                          currentPage: _currentPage,
                          rowsPerPage: _rowsPerPage,
                          totalItems: filteredDocs.length,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          onPageChanged: (page) =>
                              setState(() => _currentPage = page),
                          onRowsPerPageChanged: (rows) => setState(() {
                            _rowsPerPage = rows;
                            _currentPage = 0;
                          }),
                          itemLabel: 'usuarios',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEdicion(
    BuildContext context,
    String docId,
    String nombreActual,
    int limiteActual,
  ) {
    final TextEditingController nombreCtrl = TextEditingController(
      text: nombreActual,
    );
    final TextEditingController limiteCtrl = TextEditingController(
      text: limiteActual.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Editar Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre a mostrar'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limiteCtrl,
              decoration: const InputDecoration(
                labelText: 'Límite Mensual (\$)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
            ),
            onPressed: () async {
              final nuevoLimite = int.tryParse(limiteCtrl.text) ?? limiteActual;
              await Supabase.instance.client.from('usuarios').update({
                'nombre_mostrar': nombreCtrl.text,
                'limite_presupuesto_mensual': nuevoLimite,
              }).eq('id', docId);
              await widget.service.logAction(
                action: 'EDIT_USER',
                target: nombreActual,
                details:
                    'Presupuesto: \$${_formatNumber(limiteActual)} -> \$${_formatNumber(nuevoLimite)}. Nombre: $nombreActual -> ${nombreCtrl.text}.',
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarCambioEstado(
    BuildContext context,
    String docId,
    String nombre, {
    required bool suspender,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(suspender ? 'Suspender cuenta' : 'Reactivar cuenta'),
        content: Text(
          suspender
              ? '$nombre no podrá iniciar sesión hasta que reactives su cuenta. Sus datos no se borran.'
              : '$nombre podrá volver a iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: suspender ? Colors.deepOrange : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await widget.service.cambiarEstadoCuenta(
                  userId: docId,
                  nombre: nombre,
                  suspender: suspender,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        suspender
                            ? 'Cuenta de $nombre suspendida.'
                            : 'Cuenta de $nombre reactivada.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo cambiar el estado: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              suspender ? 'Sí, suspender' : 'Sí, reactivar',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _enviarResetPassword(BuildContext context, String correo) async {
    if (correo == 'Sin correo') return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(correo);
      widget.service.logAction(
        action: 'RESET_PASSWORD',
        target: correo,
        details: 'Se envió un correo de restablecimiento de contraseña.',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Correo de restablecimiento enviado a $correo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar correo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoEliminar(
    BuildContext context,
    String docId,
    String nombre,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Eliminar Usuario'),
        content: Text(
          '¿Estás seguro que deseas eliminar el registro y los datos de $nombre? Esta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
            ),
            onPressed: () async {
              try {
                // Pasa por la Edge Function "delete-user" para borrar tambien
                // la cuenta de Auth (no solo la fila de "usuarios"); un delete
                // directo aqui dejaria la cuenta de Auth huerfana.
                final response = await Supabase.instance.client.functions
                    .invoke('delete-user', body: {'userId': docId});
                if (response.status != 200) {
                  throw Exception(response.data?.toString() ?? 'Error desconocido');
                }
                await widget.service.logAction(
                  action: 'DELETE_USER',
                  target: nombre,
                  details: 'Se eliminó definitivamente el usuario y sus datos.',
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar usuario: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Sí, Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class PorticosPage extends StatefulWidget {
  const PorticosPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<PorticosPage> createState() => _PorticosPageState();
}

class _PorticosPageState extends State<PorticosPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedHighwayFilter = 'Todas';
  String _selectedDirectionFilter = 'Todos';
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
    if (_searchQuery.isNotEmpty && !nombre.contains(_searchQuery)) {
      return false;
    }

    final autopista = (data['autopista'] ?? '').toString();
    if (_selectedHighwayFilter != 'Todas' &&
        autopista != _selectedHighwayFilter) {
      return false;
    }

    final sentido = (data['sentido'] ?? '').toString();
    if (_selectedDirectionFilter != 'Todos' &&
        sentido != _selectedDirectionFilter) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageScaffold(
      title: 'Pórticos',
      subtitle:
          'Catálogo operativo compartido con la app final. Administra las tarifas aquí.',
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.service.streamPorticos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error al leer datos: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final docs = snapshot.data!;

          final Set<String> highwaysSet = {};
          for (var data in docs) {
            final String h = (data['autopista'] ?? '').toString();
            if (h.isNotEmpty) {
              highwaysSet.add(h);
            }
          }
          final List<String> uniqueHighways = highwaysSet.toList()..sort();

          if (_selectedHighwayFilter != 'Todas' &&
              !highwaysSet.contains(_selectedHighwayFilter)) {
            _selectedHighwayFilter = 'Todas';
          }

          final filteredDocs = docs
              .where((doc) => _matchesFilters(doc))
              .toList();

          final int totalPages = (filteredDocs.length / _rowsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }

          final int startIndex = _currentPage * _rowsPerPage;
          final int endIndex = (startIndex + _rowsPerPage) > filteredDocs.length
              ? filteredDocs.length
              : (startIndex + _rowsPerPage);
          final pageDocs = filteredDocs.sublist(startIndex, endIndex);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Buscar pórtico...',
                            hintText: 'Buscar por nombre',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedHighwayFilter,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Autopista',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'Todas',
                              child: Text('Todas las autopistas'),
                            ),
                            ...uniqueHighways.map(
                              (h) => DropdownMenuItem(value: h, child: Text(h)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedHighwayFilter = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDirectionFilter,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Sentido',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Todos',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(value: 'N-S', child: Text('N-S')),
                            DropdownMenuItem(value: 'S-N', child: Text('S-N')),
                            DropdownMenuItem(value: 'O-P', child: Text('O-P')),
                            DropdownMenuItem(value: 'P-O', child: Text('P-O')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedDirectionFilter = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filteredDocs.isEmpty
                    ? const Card(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No se encontraron pórticos con los filtros aplicados.',
                            ),
                          ),
                        ),
                      )
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      dataRowMinHeight: 60,
                                      dataRowMaxHeight: 85,
                                      columns: const [
                                        DataColumn(label: Text('Pórtico')),
                                        DataColumn(label: Text('Sentido')),
                                        DataColumn(label: Text('Tarifa Base')),
                                        DataColumn(label: Text('Tarifa Punta')),
                                        DataColumn(
                                          label: Text('Tarifa Saturación'),
                                        ),
                                        DataColumn(label: Text('Acciones')),
                                      ],
                                      rows: pageDocs.map((data) {
                                        final String docId =
                                            data['id'] as String;

                                        final String nombre =
                                            (data['nombre'] ?? 'Sin nombre')
                                                .toString();
                                        final String autopista =
                                            (data['autopista'] ?? '')
                                                .toString();
                                        final String sentido =
                                            (data['sentido'] ?? '-').toString();
                                        final String base =
                                            (data['costo'] ?? '0').toString();
                                        final String punta =
                                            (data['costo_punta'] ?? '0')
                                                .toString();
                                        final String saturacion =
                                            (data['costo_saturacion'] ?? '0')
                                                .toString();

                                        final String lat =
                                            (data['lat'] ?? '').toString();
                                        final String lng =
                                            (data['lng'] ?? '').toString();
                                        final String grupo =
                                            (data['grupo'] ?? '').toString();
                                        final String secuencia =
                                            (data['secuencia'] ?? '')
                                                .toString();

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      nombre,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF0F172A,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        _getHighwayBadge(
                                                          autopista,
                                                        ),
                                                        if (grupo.isNotEmpty)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFFF1F5F9,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              grupo,
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Color(
                                                                  0xFF64748B,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        if (secuencia
                                                            .isNotEmpty)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFFF8FAFC,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFFE2E8F0,
                                                                    ),
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              'Seq: $secuencia',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Color(
                                                                  0xFF64748B,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    if (lat.isNotEmpty &&
                                                        lng.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '$lat, $lng',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Color(
                                                            0xFF94A3B8,
                                                          ),
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  sentido,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF475569),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              _buildTariffBadge(
                                                'Base',
                                                _formatNumber(
                                                  double.tryParse(
                                                        base,
                                                      )?.round() ??
                                                      0,
                                                ),
                                                const Color(0xFFEFF6FF),
                                                const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                            DataCell(
                                              _buildTariffBadge(
                                                'Punta',
                                                _formatNumber(
                                                  double.tryParse(
                                                        punta,
                                                      )?.round() ??
                                                      0,
                                                ),
                                                const Color(0xFFFFF7ED),
                                                const Color(0xFFC2410C),
                                              ),
                                            ),
                                            DataCell(
                                              _buildTariffBadge(
                                                'Sat.',
                                                _formatNumber(
                                                  double.tryParse(
                                                        saturacion,
                                                      )?.round() ??
                                                      0,
                                                ),
                                                const Color(0xFFFFF1F2),
                                                const Color(0xFFBE123C),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      color: Colors.blue,
                                                      size: 20,
                                                    ),
                                                    tooltip: 'Editar Pórtico',
                                                    onPressed: () {
                                                      _mostrarDialogoEdicion(
                                                        context,
                                                        docId,
                                                        data,
                                                      );
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    tooltip: 'Eliminar Pórtico',
                                                    onPressed: () {
                                                      _mostrarDialogoEliminar(
                                                        context,
                                                        docId,
                                                        nombre,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(),
                              _TablePaginationControls(
                                currentPage: _currentPage,
                                rowsPerPage: _rowsPerPage,
                                totalItems: filteredDocs.length,
                                totalPages: totalPages,
                                startIndex: startIndex,
                                endIndex: endIndex,
                                onPageChanged: (page) =>
                                    setState(() => _currentPage = page),
                                onRowsPerPageChanged: (rows) => setState(() {
                                  _rowsPerPage = rows;
                                  _currentPage = 0;
                                }),
                                itemLabel: 'pórticos',
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoEdicion(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final String nombreActual = (data['nombre'] ?? 'Sin nombre').toString();
    final String autopistaActual = (data['autopista'] ?? '').toString();
    final String sentidoActual = (data['sentido'] ?? '').toString();
    final String baseActual = (data['costo'] ?? '0').toString();
    final String puntaActual = (data['costo_punta'] ?? '0').toString();
    final String saturacionActual =
        (data['costo_saturacion'] ?? '0').toString();

    final String latActual = (data['lat'] ?? '').toString();
    final String lngActual = (data['lng'] ?? '').toString();
    final String grupoActual = (data['grupo'] ?? '').toString();
    final String secuenciaActual = (data['secuencia'] ?? '').toString();

    final TextEditingController nombreCtrl = TextEditingController(
      text: nombreActual,
    );
    final TextEditingController autopistaCtrl = TextEditingController(
      text: autopistaActual,
    );
    final TextEditingController baseCtrl = TextEditingController(
      text: baseActual,
    );
    final TextEditingController puntaCtrl = TextEditingController(
      text: puntaActual,
    );
    final TextEditingController saturacionCtrl = TextEditingController(
      text: saturacionActual,
    );
    final TextEditingController latCtrl = TextEditingController(
      text: latActual,
    );
    final TextEditingController lngCtrl = TextEditingController(
      text: lngActual,
    );
    final TextEditingController grupoCtrl = TextEditingController(
      text: grupoActual,
    );
    final TextEditingController secuenciaCtrl = TextEditingController(
      text: secuenciaActual,
    );
    String selectedSentido = sentidoActual;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Editar Pórtico'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Identificación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Pórtico',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: autopistaCtrl,
                decoration: const InputDecoration(labelText: 'Autopista'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    ['N-S', 'S-N', 'O-P', 'P-O'].contains(selectedSentido)
                    ? selectedSentido
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Sentido de Circulación',
                ),
                items: const [
                  DropdownMenuItem(value: 'N-S', child: Text('N-S')),
                  DropdownMenuItem(value: 'S-N', child: Text('S-N')),
                  DropdownMenuItem(value: 'O-P', child: Text('O-P')),
                  DropdownMenuItem(value: 'P-O', child: Text('P-O')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    selectedSentido = val;
                  }
                },
              ),
              const Divider(height: 32),
              const Text(
                'Ubicación Geográfica',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: latCtrl,
                decoration: const InputDecoration(labelText: 'Latitud'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lngCtrl,
                decoration: const InputDecoration(labelText: 'Longitud'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const Divider(height: 32),
              const Text(
                'Clasificación Operativa',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: grupoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grupo / Concesión',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secuenciaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Secuencia (Orden)',
                ),
                keyboardType: TextInputType.number,
              ),
              const Divider(height: 32),
              const Text(
                'Tarifas Especiales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: baseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tarifa Base (\$)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: puntaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tarifa Punta (\$)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: saturacionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tarifa Saturación (\$)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
            ),
            onPressed: () async {
              final double? nBase = double.tryParse(
                baseCtrl.text.replaceAll(',', '.'),
              );
              final double? nPunta = double.tryParse(
                puntaCtrl.text.replaceAll(',', '.'),
              );
              final double? nSaturacion = double.tryParse(
                saturacionCtrl.text.replaceAll(',', '.'),
              );

              final double? nLat = double.tryParse(
                latCtrl.text.replaceAll(',', '.'),
              );
              final double? nLng = double.tryParse(
                lngCtrl.text.replaceAll(',', '.'),
              );

              final String newNombre = nombreCtrl.text.trim();
              final String newAutopista = autopistaCtrl.text.trim();
              final String newSentido = selectedSentido;
              final String newGrupo = grupoCtrl.text.trim();
              final String newSecuencia = secuenciaCtrl.text.trim();

              final Map<String, dynamic> updates = {
                'nombre': newNombre,
                'autopista': newAutopista,
                'sentido': newSentido,
                'grupo': newGrupo,
                'secuencia': newSecuencia,
              };

              if (nLat != null && nLng != null) {
                updates['lat'] = nLat;
                updates['lng'] = nLng;
              }
              if (nBase != null) updates['costo'] = nBase;
              if (nPunta != null) updates['costo_punta'] = nPunta;
              if (nSaturacion != null) updates['costo_saturacion'] = nSaturacion;

              final StringBuffer logDetails = StringBuffer();
              logDetails.write('Edición de pórtico.');
              if (nombreActual != newNombre) {
                logDetails.write(' Nombre: $nombreActual -> $newNombre.');
              }
              if (autopistaActual != newAutopista) {
                logDetails.write(
                  ' Autopista: $autopistaActual -> $newAutopista.',
                );
              }
              if (sentidoActual != newSentido) {
                logDetails.write(' Sentido: $sentidoActual -> $newSentido.');
              }
              if (latActual != latCtrl.text || lngActual != lngCtrl.text) {
                logDetails.write(
                  ' Ubicación: $latActual, $lngActual -> ${latCtrl.text}, ${lngCtrl.text}.',
                );
              }
              if (grupoActual != newGrupo) {
                logDetails.write(' Grupo: $grupoActual -> $newGrupo.');
              }
              if (secuenciaActual != secuenciaCtrl.text) {
                logDetails.write(
                  ' Secuencia: $secuenciaActual -> ${secuenciaCtrl.text}.',
                );
              }

              logDetails.write(
                ' Tarifa Base: \$$baseActual -> \$${baseCtrl.text}.',
              );
              logDetails.write(
                ' Tarifa Punta: \$$puntaActual -> \$${puntaCtrl.text}.',
              );
              logDetails.write(
                ' Tarifa Sat.: \$$saturacionActual -> \$${saturacionCtrl.text}.',
              );

              await Supabase.instance.client
                  .from('porticos')
                  .update(updates)
                  .eq('id', docId);

              await widget.service.logAction(
                action: 'EDIT_TARIFF',
                target: newNombre,
                details: logDetails.toString(),
              );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEliminar(
    BuildContext context,
    String docId,
    String nombre,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Eliminar Pórtico'),
        content: Text(
          '¿Estás seguro que deseas eliminar el pórtico "$nombre"? Esta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Supabase.instance.client.from('porticos').delete().eq('id', docId);
              await widget.service.logAction(
                action: 'DELETE_PORTICO',
                target: nombre,
                details: 'Se eliminó el pórtico master de la base de datos.',
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Sí, Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class TariffsPage extends StatelessWidget {
  const TariffsPage({super.key, required this.service});

  final AdminSupabaseService service;

  String _formatFecha(dynamic dateVal) {
    if (dateVal == null) return '-';
    final String str = dateVal.toString();
    if (str.length >= 16) {
      return str.substring(0, 16).replaceAll('T', ' ');
    }
    return str;
  }

  void _mostrarDetalleViaje(
    BuildContext context,
    Map<String, dynamic> tripData,
  ) {
    final List<dynamic> tollsList = tripData['tolls'] as List<dynamic>? ?? [];
    final String vehiculo = (tripData['vehicle_name'] ?? 'Desconocido')
        .toString();
    final String fecha = _formatFecha(tripData['date']);
    final int totalCost =
        (num.tryParse(tripData['total_cost']?.toString() ?? '0') ?? 0).round();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.route_outlined,
              color: Color(0xFF0EA5E9),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detalle de Peajes - $vehiculo',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: $fecha',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Costo Total: \$${_formatNumber(totalCost)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                ),
              ),
              const Divider(height: 24),
              const Text(
                'Pórticos Cruzados:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              if (tollsList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No hay pórticos registrados en este viaje.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tollsList.length,
                    itemBuilder: (context, index) {
                      final toll = tollsList[index];
                      if (toll is! Map) return const SizedBox();
                      final String name = (toll['name'] ?? 'Pórtico')
                          .toString();
                      final int cost =
                          int.tryParse(toll['cost']?.toString() ?? '0') ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '\$${_formatNumber(cost)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: Color(0xFF0EA5E9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageScaffold(
      title: 'Tarifas y Viajes de Usuarios',
      subtitle:
          'Historial de cobros y viajes de los usuarios registrado por GPS.',
      child: _FirestoreListTable(
        stream: service.streamUserTrips(),
        emptyMessage: 'No hay viajes registrados aún.',
        itemLabel: 'viajes',
        columns: const [
          'Vehículo',
          'Fecha',
          'Distancia',
          'Duración',
          'Cobro Total',
          'Acciones',
        ],
        rowBuilder: (data) {
          final String vehiculo = (data['vehicle_name'] ?? 'Desconocido')
              .toString();
          final String fecha = _formatFecha(data['date']);
          final double distance =
              double.tryParse(data['distance_km']?.toString() ?? '0') ?? 0.0;
          final String duracion = (data['duration'] ?? '-').toString();
          final int totalCost =
              (num.tryParse(data['total_cost']?.toString() ?? '0') ?? 0).round();

          return [
            DataCell(
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_filled_outlined,
                    size: 18,
                    color: Color(0xFF0EA5E9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vehiculo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            DataCell(
              Text(
                fecha,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.linear_scale_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    duracion,
                    style: const TextStyle(color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '\$${_formatNumber(totalCost)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            DataCell(
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF0EA5E9),
                    ),
                    tooltip: 'Ver Detalle de Peajes',
                    onPressed: () {
                      _mostrarDetalleViaje(context, data);
                    },
                  );
                },
              ),
            ),
          ];
        },
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<ReportMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = widget.service.fetchReportMetrics();
  }

  void _refresh() {
    setState(() {
      _metricsFuture = widget.service.fetchReportMetrics();
    });
  }

  String _formatCurrency(double val) {
    final int value = val.round();
    final String str = value.toString();
    final StringBuffer buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '\$${buffer.toString().split('').reversed.join('')}';
  }

  Future<void> _exportToCSV(BuildContext context, ReportMetrics metrics) async {
    try {
      final StringBuffer csvBuffer = StringBuffer();
      csvBuffer.write('\uFEFF');

      csvBuffer.writeln('REPORTE GENERAL DE MÉTRICAS Y ESTADÍSTICAS - TAG OK');
      csvBuffer.writeln('Fecha de Generación: ${DateTime.now().toLocal()}');
      csvBuffer.writeln();

      csvBuffer.writeln('MÉTRICA,VALOR');
      csvBuffer.writeln('Total Usuarios,${metrics.totalUsers}');
      csvBuffer.writeln('Total Vehículos,${metrics.totalVehicles}');
      csvBuffer.writeln('Total Viajes,${metrics.totalTrips}');
      csvBuffer.writeln(
        'Costo Total Peajes (\$),${metrics.totalTollCost.toStringAsFixed(0)}',
      );
      csvBuffer.writeln(
        'Costo Promedio por Viaje (\$),${metrics.averageCostPerTrip.toStringAsFixed(0)}',
      );
      csvBuffer.writeln();

      csvBuffer.writeln('DISTRIBUCIÓN POR AUTOPISTA');
      csvBuffer.writeln('Autopista,Costo Total (\$),Porcentaje (%)');

      final double total = metrics.totalTollCost;
      metrics.costByHighway.forEach((highway, cost) {
        final double pct = total > 0 ? (cost / total) * 100 : 0.0;
        csvBuffer.writeln(
          '$highway,${cost.toStringAsFixed(0)},${pct.toStringAsFixed(2)}%',
        );
      });

      saveFile(csvBuffer.toString(), 'reporte_tag_ok.csv');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Reporte descargado exitosamente'
                  : 'Reporte exportado exitosamente a: C:/Users/igna_/Downloads/reporte_tag_ok.csv',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'CERRAR',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Color> _getGradientForHighway(String highway) {
    switch (highway) {
      case 'Autopista Central':
        return [const Color(0xFF0EA5E9), const Color(0xFF2563EB)];
      case 'Costanera Norte':
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      case 'Vespucio Norte':
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case 'Vespucio Sur':
        return [const Color(0xFFEC4899), const Color(0xFFD946EF)];
      case 'Vespucio Oriente (AVO)':
        return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
      default:
        return [const Color(0xFF64748B), const Color(0xFF475569)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageScaffold(
      title: 'Reportes y Estadísticas',
      subtitle:
          'Monitoreo consolidado de ingresos por peaje, uso de vías y descargas de informes.',
      child: FutureBuilder<ReportMetrics>(
        future: _metricsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Error al cargar reportes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Cargando y consolidando métricas...',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          final metrics = snapshot.data;
          if (metrics == null) {
            return const Card(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay datos disponibles.'),
                ),
              ),
            );
          }

          final sortedHighways = metrics.costByHighway.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () => _exportToCSV(context, metrics),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Exportar Resumen a CSV',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar Datos',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ReportStatCard(
                      title: 'Usuarios',
                      value: metrics.totalUsers.toString(),
                      icon: Icons.people_outline_rounded,
                      iconColor: const Color(0xFF0EA5E9),
                      gradientColors: const [
                        Color(0xFF0EA5E9),
                        Color(0xFF38BDF8),
                      ],
                    ),
                    _ReportStatCard(
                      title: 'Vehículos',
                      value: metrics.totalVehicles.toString(),
                      icon: Icons.directions_car_outlined,
                      iconColor: const Color(0xFF10B981),
                      gradientColors: const [
                        Color(0xFF10B981),
                        Color(0xFF34D399),
                      ],
                    ),
                    _ReportStatCard(
                      title: 'Total Viajes',
                      value: metrics.totalTrips.toString(),
                      icon: Icons.route_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      gradientColors: const [
                        Color(0xFFF59E0B),
                        Color(0xFFFBBF24),
                      ],
                    ),
                    _ReportStatCard(
                      title: 'Total Peajes',
                      value: _formatCurrency(metrics.totalTollCost),
                      icon: Icons.monetization_on_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      gradientColors: const [
                        Color(0xFF8B5CF6),
                        Color(0xFFA78BFA),
                      ],
                    ),
                    _ReportStatCard(
                      title: 'Promedio por Viaje',
                      value: _formatCurrency(metrics.averageCostPerTrip),
                      icon: Icons.analytics_outlined,
                      iconColor: const Color(0xFFEC4899),
                      gradientColors: const [
                        Color(0xFFEC4899),
                        Color(0xFFF472B6),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 900;

                    final Widget chartWidget = Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Distribución de Costos por Autopista',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ...sortedHighways.map((entry) {
                              final double pct = metrics.totalTollCost > 0
                                  ? (entry.value / metrics.totalTollCost)
                                  : 0.0;
                              final List<Color> colors = _getGradientForHighway(
                                entry.key,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        Text(
                                          '${_formatCurrency(entry.value)} (${(pct * 100).toStringAsFixed(1)}%)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 12,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: pct,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: colors,
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colors[0].withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );

                    final Widget tableWidget = Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen Tabular de Ingresos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(1),
                              },
                              border: const TableBorder(
                                horizontalInside: BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              children: [
                                const TableRow(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'Autopista',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'Gasto',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'Porcentaje',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ...sortedHighways.map((entry) {
                                  final double pct = metrics.totalTollCost > 0
                                      ? (entry.value / metrics.totalTollCost) *
                                            100
                                      : 0.0;
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            color: Color(0xFF334155),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          _formatCurrency(entry.value),
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          '${pct.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          chartWidget,
                          const SizedBox(height: 24),
                          tableWidget,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: chartWidget),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: tableWidget),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  const _ReportStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 215,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradientColors[0].withValues(alpha: 0.15),
                      gradientColors[1].withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPageScaffold extends StatelessWidget {
  const _AdminPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF0EA5E9)),
              const SizedBox(height: 18),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminsManagementPage extends StatefulWidget {
  const AdminsManagementPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<AdminsManagementPage> createState() => _AdminsManagementPageState();
}

class _AdminsManagementPageState extends State<AdminsManagementPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'Todos';
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final String email = (data['email'] ?? '').toString().toLowerCase();
    final String role = (data['rol'] ?? 'operador').toString().toLowerCase();

    if (_searchQuery.isNotEmpty && !email.contains(_searchQuery)) {
      return false;
    }

    if (_selectedRoleFilter != 'Todos') {
      if (_selectedRoleFilter == 'super_admin' &&
          role != 'super_admin' &&
          role != 'super_administrador' &&
          role != 'superadmin' &&
          role != 'super administrador') {
        return false;
      }
      if (_selectedRoleFilter == 'operador' &&
          role != 'operador' &&
          role != 'operario' &&
          role != 'operator') {
        return false;
      }
    }

    return true;
  }

  Widget _getRoleBadge(String role) {
    final String r = role.toLowerCase().trim();
    final bool isSuper =
        r == 'super_admin' ||
        r == 'super_administrador' ||
        r == 'superadmin' ||
        r == 'super administrador';

    final Color bgColor = isSuper
        ? const Color(0xFFE0F2FE)
        : const Color(0xFFFEF3C7);
    final Color textColor = isSuper
        ? const Color(0xFF0369A1)
        : const Color(0xFFD97706);
    final String label = isSuper ? 'Super Administrador' : 'Administrador Operacional';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _createAdminAccount(String email, String password, String role) async {
    try {
      // Delega la creación al Edge Function "create-admin": corre con la
      // service-role key en el servidor, así que no afecta la sesión del
      // admin actual (a diferencia del viejo truco de la segunda FirebaseApp).
      final response = await Supabase.instance.client.functions.invoke(
        'create-admin',
        body: {'email': email, 'password': password, 'rol': role},
      );

      if (response.status != 200) {
        throw Exception(response.data?.toString() ?? 'Error desconocido');
      }

      final String uid = (response.data as Map)['uid'].toString();

      await widget.service.logAction(
        action: 'CREATE_ADMIN',
        target: email,
        details: 'Admin creado exitosamente. UID: $uid. Rol: $role.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Administrador $email creado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear administrador: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeAdminRole(String docId, String email, String newRole) async {
    try {
      await widget.service.updateAdminRole(docId, newRole);
      await widget.service.logAction(
        action: 'EDIT_ADMIN_ROLE',
        target: email,
        details: 'Rol modificado a: $newRole',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol de $email actualizado a $newRole.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar rol: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeAdminAccess(String docId, String email) async {
    try {
      await widget.service.deleteAdmin(docId);
      await widget.service.logAction(
        action: 'DELETE_ADMIN',
        target: email,
        details: 'Acceso revocado (cuenta eliminada)',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acceso para $email revocado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al revocar acceso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetAdminPassword(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      await widget.service.logAction(
        action: 'RESET_ADMIN_PASSWORD',
        target: email,
        details: 'Enviado enlace de recuperación de contraseña',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enlace para restablecer contraseña enviado a $email.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar restablecimiento de contraseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddAdminDialog() {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'operador';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar Nuevo Administrador'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isSaving,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El correo es requerido';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                            return 'Ingrese un correo electrónico válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        enabled: !isSaving,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La contraseña es requerida';
                          }
                          if (value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rol del Administrador',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Administrador'),
                          ),
                          DropdownMenuItem(
                            value: 'operador',
                            child: Text('Administrador Operacional (Operador)'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedRole = val;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isSaving = true;
                            });
                            await _createAdminAccount(
                              emailCtrl.text.trim(),
                              passCtrl.text,
                              selectedRole,
                            );
                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Crear', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditRoleDialog(Map<String, dynamic> data) {
    final String email = (data['email'] ?? '').toString();
    final String currentRole = (data['rol'] ?? 'operador').toString();
    String selectedRole = currentRole == 'super_admin' ? 'super_admin' : 'operador';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Editar Rol de $email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'super_admin',
                        child: Text('Super Administrador'),
                      ),
                      DropdownMenuItem(
                        value: 'operador',
                        child: Text('Administrador Operacional (Operador)'),
                      ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedRole = val;
                              });
                            }
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });
                          await _changeAdminRole(data['id'] as String, email, selectedRole);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> data) {
    final String email = (data['email'] ?? '').toString();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar Revocación'),
              content: Text(
                '¿Está seguro de que desea revocar el acceso de administrador para $email? '
                'Esta acción le impedirá el ingreso al panel inmediatamente.',
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });
                          await _revokeAdminAccess(data['id'] as String, email);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                  child: const Text('Revocar Acceso', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentAdminEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

    return _AdminPageScaffold(
      title: 'Gestión de Administradores',
      subtitle: 'Administra los roles y accesos al panel backoffice de TAG OK.',
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.service.streamAdministradores(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error al leer datos: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final docs = snapshot.data!;
          final filteredDocs = docs
              .where((doc) => _matchesFilters(doc))
              .toList();

          if (filteredDocs.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFiltersCard(),
                const Expanded(
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay administradores registrados que coincidan con los filtros.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final int totalPages = (filteredDocs.length / _rowsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }

          final int startIndex = _currentPage * _rowsPerPage;
          final int endIndex = (startIndex + _rowsPerPage) > filteredDocs.length
              ? filteredDocs.length
              : (startIndex + _rowsPerPage);
          final pageDocs = filteredDocs.sublist(startIndex, endIndex);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFiltersCard(),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Rol')),
                                  DataColumn(label: Text('Acciones')),
                                ],
                                rows: pageDocs.map((data) {
                                  final String email = (data['email'] ?? '').toString();
                                  final String role = (data['rol'] ?? 'operador').toString();
                                  final bool isCurrentUser = email.toLowerCase() == currentAdminEmail.toLowerCase();

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DataCell(_getRoleBadge(role)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                              tooltip: isCurrentUser ? 'No puedes cambiar tu propio rol' : 'Cambiar Rol',
                                              onPressed: isCurrentUser ? null : () => _showEditRoleDialog(data),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.lock_reset, color: Colors.amber),
                                              tooltip: 'Restablecer Contraseña',
                                              onPressed: () => _resetAdminPassword(email),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              tooltip: isCurrentUser ? 'No puedes revocar tu propio acceso' : 'Revocar Acceso',
                                              onPressed: isCurrentUser ? null : () => _showDeleteConfirmDialog(data),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                        _TablePaginationControls(
                          currentPage: _currentPage,
                          rowsPerPage: _rowsPerPage,
                          totalItems: filteredDocs.length,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          onPageChanged: (page) =>
                              setState(() => _currentPage = page),
                          onRowsPerPageChanged: (rows) => setState(() {
                            _rowsPerPage = rows;
                            _currentPage = 0;
                          }),
                          itemLabel: 'administradores',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Buscar Administrador...',
                  hintText: 'Buscar por correo electrónico',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedRoleFilter,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Filtrar por Rol',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Todos',
                    child: Text('Todos los roles'),
                  ),
                  DropdownMenuItem(
                    value: 'super_admin',
                    child: Text('Super Administrador'),
                  ),
                  DropdownMenuItem(
                    value: 'operador',
                    child: Text('Administrador Operacional'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRoleFilter = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _showAddAdminDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Agregar Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, required this.service});

  final AdminSupabaseService service;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedActionFilter = 'Todos';
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final String adminEmail = (data['admin_email'] ?? '')
        .toString()
        .toLowerCase();
    final String target = (data['target'] ?? '').toString().toLowerCase();
    final String details = (data['details'] ?? '').toString().toLowerCase();
    final String action = (data['action'] ?? '').toString();

    if (_searchQuery.isNotEmpty &&
        !adminEmail.contains(_searchQuery) &&
        !target.contains(_searchQuery) &&
        !details.contains(_searchQuery)) {
      return false;
    }

    if (_selectedActionFilter != 'Todos' && action != _selectedActionFilter) {
      return false;
    }

    return true;
  }

  String _formatFecha(dynamic dateVal) {
    if (dateVal == null) return '-';
    return dateVal.toString();
  }

  Widget _getActionBadge(String action) {
    Color bgColor;
    Color textColor;
    String label;
    switch (action) {
      case 'EDIT_USER':
        bgColor = const Color(0xFFE0E7FF);
        textColor = const Color(0xFF4338CA);
        label = 'Editar Usuario';
        break;
      case 'RESET_PASSWORD':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'Resetear Clave';
        break;
      case 'DELETE_USER':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = 'Eliminar Usuario';
        break;
      case 'EDIT_TARIFF':
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1D4ED8);
        label = 'Editar Tarifas';
        break;
      case 'DELETE_PORTICO':
        bgColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFFEA580C);
        label = 'Eliminar Pórtico';
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        label = action;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageScaffold(
      title: 'Bitácora de Auditoría',
      subtitle:
          'Historial irreversible de cambios y acciones realizadas por administradores.',
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.service.streamAuditLogs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error al leer datos: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final docs = snapshot.data!;
          final filteredDocs = docs
              .where((doc) => _matchesFilters(doc))
              .toList();

          if (filteredDocs.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFiltersCard(),
                const Expanded(
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay registros de auditoría que coincidan con los filtros.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final int totalPages = (filteredDocs.length / _rowsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }

          final int startIndex = _currentPage * _rowsPerPage;
          final int endIndex = (startIndex + _rowsPerPage) > filteredDocs.length
              ? filteredDocs.length
              : (startIndex + _rowsPerPage);
          final pageDocs = filteredDocs.sublist(startIndex, endIndex);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFiltersCard(),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Fecha')),
                                  DataColumn(label: Text('Administrador')),
                                  DataColumn(label: Text('Acción')),
                                  DataColumn(label: Text('Objetivo')),
                                  DataColumn(label: Text('Detalles')),
                                ],
                                rows: pageDocs.map((data) {
                                  final String fechaStr = _formatFecha(
                                    data['fecha'],
                                  );
                                  final String adminEmail =
                                      (data['admin_email'] ?? 'Sistema')
                                          .toString();
                                  final String action = (data['action'] ?? '')
                                      .toString();
                                  final String target = (data['target'] ?? '')
                                      .toString();
                                  final String details = (data['details'] ?? '')
                                      .toString();

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          fechaStr,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(adminEmail)),
                                      DataCell(_getActionBadge(action)),
                                      DataCell(
                                        Text(
                                          target,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 350,
                                          ),
                                          child: Text(
                                            details,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                        _TablePaginationControls(
                          currentPage: _currentPage,
                          rowsPerPage: _rowsPerPage,
                          totalItems: filteredDocs.length,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          onPageChanged: (page) =>
                              setState(() => _currentPage = page),
                          onRowsPerPageChanged: (rows) => setState(() {
                            _rowsPerPage = rows;
                            _currentPage = 0;
                          }),
                          itemLabel: 'registros',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Buscar en bitácora...',
                  hintText: 'Buscar por admin, objetivo o detalle',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedActionFilter,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Tipo de Acción',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Todos',
                    child: Text('Todas las acciones'),
                  ),
                  DropdownMenuItem(
                    value: 'EDIT_USER',
                    child: Text('Editar Usuario'),
                  ),
                  DropdownMenuItem(
                    value: 'RESET_PASSWORD',
                    child: Text('Restablecer Clave'),
                  ),
                  DropdownMenuItem(
                    value: 'DELETE_USER',
                    child: Text('Eliminar Usuario'),
                  ),
                  DropdownMenuItem(
                    value: 'EDIT_TARIFF',
                    child: Text('Editar Tarifas'),
                  ),
                  DropdownMenuItem(
                    value: 'DELETE_PORTICO',
                    child: Text('Eliminar Pórtico'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedActionFilter = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _TablePaginationControls extends StatelessWidget {
  const _TablePaginationControls({
    required this.currentPage,
    required this.rowsPerPage,
    required this.totalItems,
    required this.totalPages,
    required this.startIndex,
    required this.endIndex,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    required this.itemLabel,
  });

  final int currentPage;
  final int rowsPerPage;
  final int totalItems;
  final int totalPages;
  final int startIndex;
  final int endIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${totalItems == 0 ? 0 : startIndex + 1} - $endIndex de $totalItems $itemLabel',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              const Text(
                'Filas por página: ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: rowsPerPage,
                items: [5, 10, 20, 50].map((int val) {
                  return DropdownMenuItem<int>(
                    value: val,
                    child: Text('$val', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    onRowsPerPageChanged(newValue);
                  }
                },
                underline: const SizedBox(),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.first_page_rounded),
                onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
                tooltip: 'Primera página',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'Página anterior',
              ),
              const SizedBox(width: 8),
              Text(
                'Pág. ${currentPage + 1} de ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Siguiente página',
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(totalPages - 1)
                    : null,
                tooltip: 'Última página',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirestoreListTable extends StatefulWidget {
  const _FirestoreListTable({
    required this.stream,
    required this.emptyMessage,
    required this.columns,
    required this.rowBuilder,
    required this.itemLabel,
  });

  final Stream<List<Map<String, dynamic>>> stream;
  final String emptyMessage;
  final List<String> columns;
  final List<DataCell> Function(Map<String, dynamic>) rowBuilder;
  final String itemLabel;

  @override
  State<_FirestoreListTable> createState() => _FirestoreListTableState();
}

class _FirestoreListTableState extends State<_FirestoreListTable> {
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error al leer datos: ${snapshot.error}');
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final List<Map<String, dynamic>> docs = snapshot.data!;
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(widget.emptyMessage),
                ),
              );
            }

            final int totalPages = (docs.length / _rowsPerPage).ceil();
            if (_currentPage >= totalPages && totalPages > 0) {
              _currentPage = totalPages - 1;
            }

            final int startIndex = _currentPage * _rowsPerPage;
            final int endIndex = (startIndex + _rowsPerPage) > docs.length
                ? docs.length
                : (startIndex + _rowsPerPage);
            final pageDocs = docs.sublist(startIndex, endIndex);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: widget.columns
                            .map(
                              (String column) =>
                                  DataColumn(label: Text(column)),
                            )
                            .toList(),
                        rows: pageDocs.map((doc) {
                          return DataRow(cells: widget.rowBuilder(doc));
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                _TablePaginationControls(
                  currentPage: _currentPage,
                  rowsPerPage: _rowsPerPage,
                  totalItems: docs.length,
                  totalPages: totalPages,
                  startIndex: startIndex,
                  endIndex: endIndex,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  onRowsPerPageChanged: (rows) => setState(() {
                    _rowsPerPage = rows;
                    _currentPage = 0;
                  }),
                  itemLabel: widget.itemLabel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatNumber(int val) {
  final String str = val.toString();
  final StringBuffer buffer = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    buffer.write(str[i]);
    count++;
    if (count % 3 == 0 && i != 0) {
      buffer.write('.');
    }
  }
  return buffer.toString().split('').reversed.join('');
}

Color _getColorFromName(String name) {
  final int hash = name.hashCode;
  final List<Color> colors = [
    const Color(0xFF0EA5E9),
    const Color(0xFF10B981),
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFFF59E0B),
  ];
  return colors[hash.abs() % colors.length];
}

Widget _getHighwayBadge(String highway) {
  Color bgColor;
  Color textColor;
  switch (highway) {
    case 'Autopista Central':
      bgColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF1D4ED8);
      break;
    case 'Costanera Norte':
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
      break;
    case 'Vespucio Norte':
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
      break;
    case 'Vespucio Sur':
      bgColor = const Color(0xFFFDF2F8);
      textColor = const Color(0xFFBE185D);
      break;
    case 'Vespucio Oriente (AVO)':
      bgColor = const Color(0xFFF5F3FF);
      textColor = const Color(0xFF6D28D9);
      break;
    default:
      bgColor = const Color(0xFFF8FAFC);
      textColor = const Color(0xFF475569);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: textColor.withValues(alpha: 0.15)),
    ),
    child: Text(
      highway,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: textColor,
        fontSize: 11,
      ),
    ),
  );
}

Widget _buildTariffBadge(
  String label,
  String value,
  Color bgColor,
  Color textColor,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: textColor.withValues(alpha: 0.15)),
    ),
    child: Text(
      '$label: \$$value',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: textColor,
        fontSize: 11,
      ),
    ),
  );
}
