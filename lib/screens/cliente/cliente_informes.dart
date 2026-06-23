import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/informes_repository.dart';

/// Informes de avance que ve el cliente: los partes que reportan los
/// trabajadores para SU obra (memoria interna, sin red). Cierra el ciclo
/// trabajador → cliente.
class ClienteInformes extends StatefulWidget {
  const ClienteInformes({super.key});
  @override
  State<ClienteInformes> createState() => _ClienteInformesState();
}

class _ClienteInformesState extends State<ClienteInformes> {
  Future<void> _refrescar() async => setState(() {});

  String _fecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final areas = areasLocales();
    final Obra? obra = areas.isNotEmpty ? areas.first : null;
    final avances = obra == null ? <InformeAvance>[] : informesDeObra(obra.id);
    final ultimoPct = avances.isNotEmpty ? avances.first.pct : null;

    return Column(children: [
      const PanelHeader(
          title: 'Informes de avance',
          subtitle: 'Reportes de tu obra',
          color: AppColors.cliente,
          icon: Icons.description_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (obra != null)
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
                          Text('${avances.length} reporte(s)',
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
            if (avances.isEmpty)
              const AppCard(
                child: IconRow(
                    icon: Icons.description_outlined,
                    iconColor: AppColors.textMuted,
                    title: 'Aún no hay avances reportados',
                    subtitle: 'Cuando el equipo reporte, aparecerá aquí.'),
              )
            else
              for (final inf in avances) _tarjeta(inf),
          ]),
        ),
      ),
    ]);
  }

  Widget _tarjeta(InformeAvance inf) {
    final tieneFoto =
        inf.fotoPath != null && File(inf.fotoPath!).existsSync();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inf.perfilNombre.isEmpty ? 'Equipo' : inf.perfilNombre,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              Text(_fecha(inf.fecha),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          AppBadge('${inf.pct}%',
              tone: inf.pct >= 60
                  ? 'green'
                  : inf.pct >= 30
                      ? 'amber'
                      : 'red'),
        ]),
        const SizedBox(height: 6),
        Text(inf.texto,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSoft, height: 1.4)),
        ProgressBar(inf.pct),
        if (tieneFoto) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(inf.fotoPath!),
                width: double.infinity, height: 160, fit: BoxFit.cover),
          ),
        ],
      ]),
    );
  }
}
