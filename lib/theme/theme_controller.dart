import 'package:flutter/material.dart';
import '../core/local_store.dart';

/// ============================================================================
///  CONTROLADOR DE TEMA  (Modo Claro / Oscuro / Sistema)
///
///  Un único `ValueNotifier<ThemeMode>` global. `MaterialApp` lo escucha en
///  `main.dart` (vía ValueListenableBuilder) y reconstruye toda la app al
///  cambiar el modo. La preferencia se guarda en memoria interna
///  (`shared_preferences`) — NO toca Supabase ni el esquema de la BD.
///
///  Uso:
///    ThemeController.instance.alternar();          // claro <-> oscuro
///    ThemeController.instance.set(ThemeMode.dark); // fijar un modo
/// ============================================================================
class ThemeController {
  ThemeController._();
  static final instance = ThemeController._();

  /// Estado observable del modo de tema. Por defecto sigue al sistema.
  final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  /// Carga la preferencia guardada. Llamar una vez en `main()` tras
  /// `LocalStore.init()`.
  void cargar() {
    modo.value = _desdeEtiqueta(LocalStore.temaModo());
  }

  /// Fija un modo concreto y lo persiste.
  Future<void> set(ThemeMode m) async {
    modo.value = m;
    await LocalStore.guardarTemaModo(_aEtiqueta(m));
  }

  /// Alterna entre claro y oscuro (si está en "sistema", resuelve según el
  /// brillo actual de la plataforma para que el cambio sea intuitivo).
  Future<void> alternar(BuildContext context) async {
    final esOscuroAhora = switch (modo.value) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    await set(esOscuroAhora ? ThemeMode.light : ThemeMode.dark);
  }

  static ThemeMode _desdeEtiqueta(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _aEtiqueta(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

/// Botón reutilizable para alternar claro/oscuro. Colócalo en cualquier
/// `AppBar` (`actions: [const ThemeToggleButton()]`) o en una pantalla.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.color});

  /// Color opcional del icono (por defecto usa el del tema actual).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.modo,
      builder: (context, modo, _) {
        final esOscuro = modo == ThemeMode.dark ||
            (modo == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        return IconButton(
          tooltip: esOscuro ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
          icon: Icon(esOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          color: color,
          onPressed: () => ThemeController.instance.alternar(context),
        );
      },
    );
  }
}
