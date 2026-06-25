import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/live_map.dart';
import '../../models/models.dart';
import '../../data/roles.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../core/asistencia_service.dart';
import '../../core/auth_service.dart';

/// Pantalla de marcado de asistencia por GPS.
/// Lee el GPS real con `geolocator` y llama al servicio de asistencia, que a su
/// vez usa el RPC `marcar_asistencia` (nube) o valida localmente (memoria interna).
class EmpleadoMarcar extends StatefulWidget {
  const EmpleadoMarcar({super.key});
  @override
  State<EmpleadoMarcar> createState() => _EmpleadoMarcarState();
}

class _EmpleadoMarcarState extends State<EmpleadoMarcar> {
  List<Obra> _obras = [];
  Obra? _obra;
  bool _cargando = true;
  bool _marcando = false;
  AsistenciaResult? _resultado;
  Position? _ultimaPos; // última posición reportada por el mapa en vivo
  List<Map<String, dynamic>> _recientesDias = []; // resumen por día (nube/local)

  @override
  void initState() {
    super.initState();
    _cargarObras();
    _cargarRecientes();
  }

  Future<void> _cargarObras() async {
    final todas = await cargarObras();
    final id = AuthService.instance.session?.id ?? '';
    final asignadas = await obrasAsignadasA(id);
    // Si el gerente le asignó áreas, solo esas; si no, todas (respaldo).
    final lista = asignadas.isEmpty
        ? todas
        : todas.where((o) => asignadas.contains(o.id)).toList();
    await _cargarRecientes();
    if (!mounted) return;
    setState(() {
      _obras = lista;
      _obra = lista.isNotEmpty ? lista.first : null;
      _cargando = false;
    });
  }

  /// Carga el resumen de asistencia por día. En producción lee la tabla
  /// `asistencias` (solo lectura); sin nube, agrupa la memoria interna.
  Future<void> _cargarRecientes() async {
    final dias = await AsistenciaService.instance.resumen();
    if (!mounted) return;
    setState(() => _recientesDias = dias);
  }

  Future<Position> _posicionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Activa la ubicación (GPS) del dispositivo.';
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw 'Permiso de ubicación denegado.';
    }
    if (permiso == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación bloqueado. Actívalo en Ajustes.';
    }
    return Geolocator.getCurrentPosition();
  }

  Future<void> _marcar(String tipo) async {
    if (_obra == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una obra primero.')));
      return;
    }
    setState(() {
      _marcando = true;
      _resultado = null;
    });
    try {
      // Reutiliza la posición del mapa en vivo; si no hay, la pide al GPS.
      final pos = _ultimaPos ?? await _posicionActual();
      final res = await AsistenciaService.instance.marcar(
        obra: _obra!,
        tipo: tipo,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (mounted) setState(() => _resultado = res);
      if (res.ok) await _cargarRecientes(); // refresca el resumen tras marcar
    } catch (e) {
      if (mounted) {
        setState(() => _resultado = AsistenciaResult(false, e.toString()));
      }
    } finally {
      if (mounted) setState(() => _marcando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = AuthService.instance.session?.rol ?? '';
    final puedeMarcar = puedeMarcarAsistencia(rol);

    return Column(children: [
      const PanelHeader(
          title: 'Marcar asistencia',
          subtitle: 'Validación por geolocalización',
          color: AppColors.empleado,
          icon: Icons.fingerprint),
      Expanded(
        child: !puedeMarcar
            ? _avisoSinPermiso()
            : RefreshIndicator(
                onRefresh: _cargarObras, // recarga coords frescas de la BD
                child: ListView(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _selectorObra(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LiveMap(
                          obraLat: _obra?.lat,
                          obraLng: _obra?.lng,
                          radioMetros: _obra?.radioMetros ?? 200,
                          obraNombre: _obra?.nombre,
                          height: 240,
                          onPosicion: (p) => _ultimaPos = p,
                        ),
                      ),
                      if (_resultado != null) _bannerResultado(_resultado!),
                      _botonesMarcar(),
                      _recientes(),
                    ]),
              ),
      ),
    ]);
  }

  Widget _avisoSinPermiso() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.info_outline, size: 40, color: context.tokens.textSecondary),
          const SizedBox(height: 12),
          Text('Tu rol no registra asistencia de campo',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.textPrimary)),
          const SizedBox(height: 6),
          Text('Solo el personal de obra y el maestro de obra marcan asistencia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.tokens.textSecondary)),
        ]),
      ),
    );
  }

  Widget _selectorObra() {
    if (_cargando) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text('Cargando obras…',
                style: TextStyle(fontSize: 13, color: context.tokens.textSecondary)),
          ]),
        ),
      );
    }
    if (_obras.isEmpty) {
      return const AppCard(
        child: IconRow(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            title: 'No hay obras disponibles',
            subtitle: 'Pide al administrador que te asigne una obra.'),
      );
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Obra'),
        DropdownButton<Obra>(
          value: _obra,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final o in _obras)
              DropdownMenuItem(value: o, child: Text(o.nombre)),
          ],
          onChanged: _marcando
              ? null
              : (o) => setState(() {
                    _obra = o;
                    _resultado = null;
                  }),
        ),
        if (_obra != null) ...[
          if (_obra!.direccion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_obra!.direccion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: context.tokens.textSecondary)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
                'Radio ${_obra!.radioMetros} m · ${_obra!.lat.toStringAsFixed(5)}, ${_obra!.lng.toStringAsFixed(5)}',
                style: TextStyle(
                    fontSize: 11, color: context.tokens.textSecondary)),
          ),
        ],
      ]),
    );
  }

  Widget _bannerResultado(AsistenciaResult r) {
    final dist =
        r.distanciaMetros != null ? ' · ${r.distanciaMetros!.round()} m' : '';
    return AppCard(
      color: r.ok ? AppColors.greenBg : AppColors.redBg,
      borderColor: r.ok ? const Color(0xFF9FE1CB) : const Color(0xFFF4C0C0),
      child: Row(children: [
        Icon(r.ok ? Icons.check_circle : Icons.cancel,
            size: 28, color: r.ok ? AppColors.greenText : AppColors.redText),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${r.mensaje}$dist',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: r.ok ? AppColors.greenText : AppColors.redText)),
        ),
      ]),
    );
  }

  Widget _botonesMarcar() {
    final deshab = _marcando || _obra == null;
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: deshab ? null : () => _marcar('entrada'),
          icon: _marcando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.login, color: Colors.white),
          label: const Text('Marcar Entrada',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              disabledBackgroundColor: AppColors.success.withValues(alpha:0.4),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: deshab ? null : () => _marcar('salida'),
          icon: Icon(Icons.logout, color: context.tokens.textPrimary, size: 18),
          label: Text('Marcar Salida',
              style: TextStyle(
                  color: context.tokens.textPrimary, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.grayBg,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]);
  }

  Widget _recientes() {
    if (_recientesDias.isEmpty) return const SizedBox.shrink();
    final ultimos = _recientesDias.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardTitle('Tus últimos registros'),
          for (final d in ultimos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(
                    d['hora_salida'] != null
                        ? Icons.check_circle
                        : Icons.login,
                    size: 18,
                    color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _fechaCorta(d['fecha']) +
                                ((d['obra_nombre'] ?? '').toString().isEmpty
                                    ? ''
                                    : ' · ${d['obra_nombre']}'),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.tokens.textPrimary)),
                        Text(
                            'Entrada ${_hora(d['hora_entrada'])}  ·  Salida ${_hora(d['hora_salida'])}',
                            style: TextStyle(
                                fontSize: 11, color: context.tokens.textSecondary)),
                      ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  String _hora(dynamic iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  String _fechaCorta(dynamic f) {
    final p = f.toString().split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : f.toString();
  }
}
