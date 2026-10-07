import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/beneficios_logica.dart';
import '../models/beneficio_model.dart';

/// Catálogo de beneficios que ve el conductor. Las políticas de la base de datos
/// ya entregan solo los activos y vigentes; aquí se revisa de nuevo la vigencia
/// por si alguno venció desde la última consulta.
class BeneficiosService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<BeneficioModel>> obtenerVigentes() async {
    final filas = await _client.from('beneficios').select().order('fecha_actualizacion', ascending: false);
    return filas.map(BeneficioModel.fromJson).where((b) => estaVigente(b)).toList();
  }
}
