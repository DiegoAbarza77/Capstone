import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/beneficios_logica.dart';
import '../models/beneficio_model.dart';
import 'consulta_periodica.dart';

/// Catálogo de beneficios que ve el conductor. Las políticas de la base de datos
/// ya entregan solo los activos y vigentes; aquí se revisa de nuevo la vigencia
/// por si alguno venció desde la última consulta.
class BeneficiosService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<BeneficioModel>> obtenerVigentes() async {
    final filas = await _client.from('beneficios').select().order('fecha_actualizacion', ascending: false);
    return filas.map(BeneficioModel.fromJson).where((b) => estaVigente(b)).toList();
  }

  /// El catálogo se actualiza solo: los beneficios los crea o desactiva un
  /// administrador desde el panel, así que la app los vuelve a consultar cada 30 s.
  Stream<List<BeneficioModel>> streamVigentes() {
    return consultaPeriodica<List<BeneficioModel>>(obtenerVigentes, cada: const Duration(seconds: 30));
  }
}
