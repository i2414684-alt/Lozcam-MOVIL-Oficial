import '../core/auth_service.dart';
import '../core/local_store.dart';

/// Informe/parte de avance que el trabajador guarda en memoria interna (offline).
class InformeAvance {
  final int id;
  final String perfilId;
  final String perfilNombre;
  final int? obraId;
  final String obraNombre;
  final String texto;
  final int pct;
  final String fecha; // ISO
  final String? fotoPath; // ruta local de la foto (subirá a Storage al integrar)

  InformeAvance({
    required this.id,
    required this.perfilId,
    required this.perfilNombre,
    this.obraId,
    required this.obraNombre,
    required this.texto,
    required this.pct,
    required this.fecha,
    this.fotoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'perfil_id': perfilId,
        'perfil_nombre': perfilNombre,
        'obra_id': obraId,
        'obra_nombre': obraNombre,
        'texto': texto,
        'pct': pct,
        'fecha': fecha,
        'foto_path': fotoPath,
      };

  factory InformeAvance.fromJson(Map<String, dynamic> j) => InformeAvance(
        id: (j['id'] as num).toInt(),
        perfilId: (j['perfil_id'] ?? '') as String,
        perfilNombre: (j['perfil_nombre'] ?? '') as String,
        obraId: (j['obra_id'] as num?)?.toInt(),
        obraNombre: (j['obra_nombre'] ?? '') as String,
        texto: (j['texto'] ?? '') as String,
        pct: (j['pct'] as num?)?.toInt() ?? 0,
        fecha: (j['fecha'] ?? '') as String,
        fotoPath: j['foto_path'] as String?,
      );
}

/// Informes del trabajador actual (más recientes primero).
List<InformeAvance> misInformes() {
  final id = AuthService.instance.session?.id ?? '';
  return LocalStore.informes()
      .map(InformeAvance.fromJson)
      .where((i) => i.perfilId == id)
      .toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
}

/// Avances reportados para una obra (lo que ve el cliente), recientes primero.
List<InformeAvance> informesDeObra(int obraId) => LocalStore.informes()
    .map(InformeAvance.fromJson)
    .where((i) => i.obraId == obraId)
    .toList()
  ..sort((a, b) => b.fecha.compareTo(a.fecha));

Future<void> guardarInforme({
  int? obraId,
  required String obraNombre,
  required String texto,
  required int pct,
  String? fotoPath,
}) async {
  final yo = AuthService.instance.session;
  final inf = InformeAvance(
    id: DateTime.now().millisecondsSinceEpoch,
    perfilId: yo?.id ?? 'local',
    perfilNombre: yo?.nombre ?? 'Trabajador',
    obraId: obraId,
    obraNombre: obraNombre,
    texto: texto,
    pct: pct,
    fecha: DateTime.now().toIso8601String(),
    fotoPath: fotoPath,
  );
  await LocalStore.guardarInforme(inf.toJson());
}

Future<void> eliminarInforme(int id) => LocalStore.eliminarInforme(id);
