import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/models/carga_combustible_model.dart';
import '../data/models/vehiculo_model.dart';
import '../data/services/combustible_service.dart';

class CombustibleScreen extends StatefulWidget {
  final String vehiculoId;
  final String patente;

  const CombustibleScreen({
    super.key,
    required this.vehiculoId,
    required this.patente,
  });

  @override
  State<CombustibleScreen> createState() => _CombustibleScreenState();
}

class _CombustibleScreenState extends State<CombustibleScreen> {
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color navBgColor = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color accentColor = const Color(0xFF10B981);

  final CombustibleService _service = CombustibleService();
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Combustible · ${widget.patente}', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fabAgregarCarga',
        onPressed: _mostrarFormularioCarga,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<CargaCombustibleModel>>(
        stream: _service.streamPorVehiculo(widget.vehiculoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textMain)));
          }

          final cargas = snapshot.data ?? [];
          final now = DateTime.now();
          final cargasDelMes = cargas.where((c) => c.fecha.year == now.year && c.fecha.month == now.month);
          final gastoMes = cargasDelMes.fold<double>(0.0, (sum, c) => sum + c.total);
          final litrosMes = cargasDelMes.fold<double>(0.0, (sum, c) => sum + c.litros);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Gasto este mes', '\$${gastoMes.toStringAsFixed(0)}', Icons.local_gas_station, accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Litros este mes', litrosMes.toStringAsFixed(1), Icons.water_drop_outlined, primaryColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cargas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_gas_station_outlined, size: 72, color: Colors.white.withValues(alpha: 0.1)),
                            const SizedBox(height: 16),
                            Text('Aún no hay cargas registradas', style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Presiona el botón + para registrar una', style: TextStyle(color: textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cargas.length,
                        itemBuilder: (context, index) {
                          final carga = cargas[index];
                          return Card(
                            color: navBgColor,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                                child: Icon(Icons.local_gas_station, color: accentColor),
                              ),
                              title: Text(carga.estacion, style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${dateFmt.format(carga.fecha)} · ${carga.litros.toStringAsFixed(1)} L${carga.tipoCombustible != null ? ' · ${carga.tipoCombustible}' : ''}',
                                style: TextStyle(color: textMuted, fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('\$${carga.total.toStringAsFixed(0)}', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                                  GestureDetector(
                                    onTap: () => _confirmarEliminar(carga),
                                    child: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7), size: 18),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(color: textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmarEliminar(CargaCombustibleModel carga) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: navBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar carga', style: TextStyle(color: textMain)),
        content: Text('¿Eliminar el registro de ${carga.estacion} del ${dateFmt.format(carga.fecha)}?', style: TextStyle(color: textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: textMuted))),
          TextButton(
            onPressed: () async {
              await _service.eliminarCarga(carga.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioCarga() {
    final estacionCtrl = TextEditingController();
    final kilometrajeCtrl = TextEditingController();
    final litrosCtrl = TextEditingController();
    final precioLitroCtrl = TextEditingController();
    String? tipoCombustibleSel;
    DateTime fecha = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calcularTotal() {
              final litros = double.tryParse(litrosCtrl.text.trim()) ?? 0.0;
              final precio = double.tryParse(precioLitroCtrl.text.trim()) ?? 0.0;
              return litros * precio;
            }

            return AlertDialog(
              backgroundColor: navBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Registrar Carga', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fecha,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setModalState(() => fecha = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: textMuted, size: 18),
                            const SizedBox(width: 10),
                            Text(dateFmt.format(fecha), style: TextStyle(color: textMain, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Icon(Icons.edit, color: primaryColor, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: estacionCtrl,
                      style: TextStyle(color: textMain),
                      decoration: InputDecoration(
                        labelText: 'Estación de servicio',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tipoCombustibleSel,
                      dropdownColor: navBgColor,
                      style: TextStyle(color: textMain),
                      hint: Text('Selecciona', style: TextStyle(color: textMuted)),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Combustible',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                      items: kTiposCombustible.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setModalState(() => tipoCombustibleSel = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: kilometrajeCtrl,
                      style: TextStyle(color: textMain),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Kilometraje actual',
                        labelStyle: TextStyle(color: textMuted),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: litrosCtrl,
                            style: TextStyle(color: textMain),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Litros',
                              labelStyle: TextStyle(color: textMuted),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: precioLitroCtrl,
                            style: TextStyle(color: textMain),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Precio / L',
                              labelStyle: TextStyle(color: textMuted),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textMuted.withValues(alpha: 0.5))),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: TextStyle(color: textMuted)),
                          Text('\$${calcularTotal().toStringAsFixed(0)}', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: textMuted))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final estacion = estacionCtrl.text.trim();
                    final litros = double.tryParse(litrosCtrl.text.trim());
                    final precioLitro = double.tryParse(precioLitroCtrl.text.trim());
                    if (estacion.isEmpty || litros == null || precioLitro == null || litros <= 0 || precioLitro <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Completa estación, litros y precio por litro.'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    await _service.agregarCarga(CargaCombustibleModel(
                      id: '',
                      vehiculoId: widget.vehiculoId,
                      vehiculoPatente: widget.patente,
                      fecha: fecha,
                      kilometraje: double.tryParse(kilometrajeCtrl.text.trim()),
                      estacion: estacion,
                      tipoCombustible: tipoCombustibleSel,
                      litros: litros,
                      precioLitro: precioLitro,
                      total: litros * precioLitro,
                    ));
                    if (context.mounted) Navigator.pop(context);
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
}
