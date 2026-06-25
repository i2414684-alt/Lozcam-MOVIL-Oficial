import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import 'area_editor.dart';
import 'asignar_trabajadores.dart';

/// Panel del gerente: definir las áreas de trabajo por geolocalización.
/// Cada área es una coordenada estática + radio permitido (sin rutas).
class AdminAreas extends StatefulWidget {
  const AdminAreas({super.key});
  @override
  State<AdminAreas> createState() => _AdminAreasState();
}

class _AdminAreasState extends State<AdminAreas> {
  List<Obra> _areas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() => setState(() => _areas = areasLocales());

  Future<void> _editor({Obra? area}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AreaEditor(area: area)),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _asignar(Obra area) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AsignarTrabajadores(area: area)),
    );
    _cargar();
  }

  Future<void> _eliminar(Obra a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar área'),
        content: Text('¿Eliminar "${a.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await eliminarArea(a.id);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const PanelHeader(
          title: 'Áreas de trabajo',
          subtitle: 'Define ubicaciones por GPS',
          color: AppColors.admin,
          icon: Icons.add_location_alt_outlined),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _editor(),
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text('Nueva área',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.admin,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 10),
          if (_areas.isEmpty)
            AppCard(
              child: IconRow(
                  icon: Icons.map_outlined,
                  iconColor: context.tokens.textSecondary,
                  title: 'Aún no hay áreas',
                  subtitle:
                      'Crea la primera para que los trabajadores marquen ahí.'),
            )
          else
            for (final a in _areas) _tarjetaArea(a),
        ]),
      ),
    ]);
  }

  Widget _tarjetaArea(Obra a) {
    return AppCard(
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.orangeBg, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.location_on, color: AppColors.admin, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.nombre,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.textPrimary)),
            if (a.direccion.isNotEmpty)
              Text(a.direccion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11, color: context.tokens.textSecondary)),
            Text(
                'Radio ${a.radioMetros} m · ${contarTrabajadoresArea(a.id)} trabajador(es)',
                style: TextStyle(fontSize: 10, color: context.tokens.textSecondary)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.group_add_outlined,
              size: 20, color: AppColors.admin),
          tooltip: 'Asignar trabajadores',
          onPressed: () => _asignar(a),
        ),
        IconButton(
          icon: Icon(Icons.edit_outlined,
              size: 20, color: context.tokens.textSecondary),
          tooltip: 'Editar',
          onPressed: () => _editor(area: a),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 20, color: AppColors.danger),
          tooltip: 'Eliminar',
          onPressed: () => _eliminar(a),
        ),
      ]),
    );
  }
}
