import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/informes_repository.dart';

/// Lista de obras con su avance real: trabajadores asignados y el último
/// porcentaje reportado por el equipo (memoria interna, sin red).
class AdminObras extends StatefulWidget {
  const AdminObras({super.key});
  @override
  State<AdminObras> createState() => _AdminObrasState();
}

class _AdminObrasState extends State<AdminObras> {
  Future<void> _refrescar() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    final areas = areasLocales();

    return Column(children: [
      const PanelHeader(
          title: 'Obras',
          subtitle: 'Avance por obra',
          color: AppColors.admin,
          icon: Icons.business_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (areas.isEmpty)
              AppCard(
                child: IconRow(
                    icon: Icons.business_outlined,
                    iconColor: context.tokens.textSecondary,
                    title: 'No hay obras registradas',
                    subtitle: 'Créalas en la pestaña "Áreas".'),
              )
            else
              for (final a in areas) _tarjeta(a),
          ]),
        ),
      ),
    ]);
  }

  Widget _tarjeta(Obra o) {
    final trabajadores = contarTrabajadoresArea(o.id);
    final avances = informesDeObra(o.id);
    final pct = avances.isNotEmpty ? avances.first.pct : 0;
    return AppCard(
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.orangeBg,
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.location_on, color: AppColors.admin, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.nombre,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.tokens.textPrimary)),
            Text(
                '$trabajadores trabajador(es) · ${avances.length} reporte(s)',
                style: TextStyle(fontSize: 11, color: context.tokens.textSecondary)),
            ProgressBar(pct),
          ]),
        ),
        const SizedBox(width: 8),
        AppBadge(avances.isEmpty ? 'Sin avance' : '$pct%',
            tone: avances.isEmpty
                ? 'gray'
                : pct >= 60
                    ? 'green'
                    : pct >= 30
                        ? 'amber'
                        : 'red'),
      ]),
    );
  }
}
