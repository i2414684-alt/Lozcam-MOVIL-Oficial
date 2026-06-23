import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../widgets/live_map.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../core/geocoding_service.dart';

/// Vista del cliente: SOLO ve la ubicación de su obra y la dirección
/// (resuelta por geolocalización). Sin marcar, sin rutas.
class ClienteMapa extends StatefulWidget {
  const ClienteMapa({super.key});
  @override
  State<ClienteMapa> createState() => _ClienteMapaState();
}

class _ClienteMapaState extends State<ClienteMapa> {
  Obra? _obra;
  String? _direccion;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await cargarObras();
    final o = lista.isNotEmpty ? lista.first : null;
    if (!mounted) return;
    setState(() {
      _obra = o;
      _cargando = false;
      _direccion = (o != null && o.direccion.isNotEmpty) ? o.direccion : null;
    });
    // Si no hay dirección guardada, la resolvemos por geolocalización inversa.
    if (o != null && _direccion == null) {
      final dir = await GeocodingService.instance.direccionDe(o.lat, o.lng);
      if (mounted && dir != null) setState(() => _direccion = dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obra = _obra;
    return Column(children: [
      PanelHeader(
          title: 'Ubicación de obra',
          subtitle: obra?.nombre ?? 'Cargando…',
          color: AppColors.cliente,
          icon: Icons.location_on_outlined),
      Expanded(
        child: obra == null && _cargando
            ? const Center(child: CircularProgressIndicator())
            : obra == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aún no hay una obra asignada.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                : ListView(padding: const EdgeInsets.all(12), children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LiveMap(
                        obraLat: obra.lat,
                        obraLng: obra.lng,
                        radioMetros: obra.radioMetros,
                        obraNombre: obra.nombre,
                        height: 220,
                        mostrarUsuario: false,
                      ),
                    ),
                    AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardTitle('Dirección'),
                            Row(children: [
                              const Icon(Icons.place,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    _direccion ?? 'Resolviendo dirección…',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textDark)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                'Coordenadas: ${obra.lat.toStringAsFixed(5)}, ${obra.lng.toStringAsFixed(5)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                          ]),
                    ),
                  ]),
      ),
    ]);
  }
}
