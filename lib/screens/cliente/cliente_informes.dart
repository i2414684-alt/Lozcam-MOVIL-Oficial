import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/avance_repository.dart';

/// Informes de avance que ve el cliente: los avances de SU obra.
/// Producción: tabla `avance_obra`; sin nube: partes locales.
class ClienteInformes extends StatefulWidget {
  const ClienteInformes({super.key});
  @override
  State<ClienteInformes> createState() => _ClienteInformesState();
}

class _ClienteInformesState extends State<ClienteInformes> {
  Obra? _obra;
  List<AvanceItem> _avances = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final o = await obraDelCliente();
    final av = o == null ? <AvanceItem>[] : await avancesDeObra(o.id);
    if (!mounted) return;
    setState(() {
      _obra = o;
      _avances = av;
      _cargando = false;
    });
  }

  String _fecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final obra = _obra;
    final ultimoPct = _avances.isNotEmpty ? _avances.first.pct : null;

    return Column(children: [
      const PanelHeader(
          title: 'Informes de avance',
          subtitle: 'Reportes de tu obra',
          color: AppColors.cliente,
          icon: Icons.description_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (obra == null)
                const AppCard(
                  child: IconRow(
                      icon: Icons.business_outlined,
                      iconColor: AppColors.textMuted,
                      title: 'Aún no hay un proyecto asignado',
                      subtitle: 'Aparecerá cuando el sistema lo registre.'),
                )
              else ...[
                AppCard(
                  color: AppColors.greenBg,
                  borderColor: const Color(0xFF9FE1CB),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(obra.nombre,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                            Text('${_avances.length} reporte(s)',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSoft)),
                          ]),
                    ),
                    if (ultimoPct != null)
                      Column(children: [
                        Text('$ultimoPct%',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cliente)),
                        const Text('último',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textSoft)),
                      ]),
                  ]),
                ),
                if (_avances.isEmpty)
                  const AppCard(
                    child: IconRow(
                        icon: Icons.description_outlined,
                        iconColor: AppColors.textMuted,
                        title: 'Aún no hay avances reportados',
                        subtitle: 'Cuando el equipo reporte, aparecerá aquí.'),
                  )
                else
                  for (final a in _avances) _tarjeta(a),
              ],
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _tarjeta(AvanceItem a) {
    final tieneLocal =
        a.fotoPath != null && File(a.fotoPath!).existsSync();
    final tieneUrl = a.fotoUrl != null && a.fotoUrl!.isNotEmpty;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.autor,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              Text(_fecha(a.fecha),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          AppBadge('${a.pct}%',
              tone: a.pct >= 60
                  ? 'green'
                  : a.pct >= 30
                      ? 'amber'
                      : 'red'),
        ]),
        if (a.texto.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(a.texto,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSoft, height: 1.4)),
        ],
        ProgressBar(a.pct),
        if (tieneUrl || tieneLocal) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: tieneUrl
                ? Image.network(a.fotoUrl!,
                    width: double.infinity, height: 160, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink())
                : Image.file(File(a.fotoPath!),
                    width: double.infinity, height: 160, fit: BoxFit.cover),
          ),
        ],
      ]),
    );
  }
}
