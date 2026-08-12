import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pantalla de error amigable que reemplaza el "cuadro gris/rojo" por defecto
/// de Flutter cuando algo falla al construir un widget. Se instala una sola
/// vez en `main.dart` vía `ErrorWidget.builder`, así que aplica a TODA la app:
/// cualquier pantalla que falle muestra esto en vez de quedar en blanco.
///
/// Si hay un Navigator disponible y se puede volver atrás, se ofrece un botón
/// "Volver" para que el usuario nunca quede atrapado sin salida.
class AppErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const AppErrorScreen({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.maybeOf(context)?.canPop() ?? false;
    // Esta pantalla se instala vía `ErrorWidget.builder` y puede dibujarse
    // fuera de un `Theme`, así que no puede leer los tokens de la app. Se guía
    // por el brillo de la plataforma para no dar un fogonazo blanco a quien
    // usa el modo oscuro.
    final oscuro =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final fondo = oscuro ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F7);
    final titulo = oscuro ? const Color(0xFFF2F2F7) : const Color(0xFF1A1A2E);
    final cuerpo = oscuro ? const Color(0xFF9E9EA7) : const Color(0xFF636366);

    return Material(
      color: fondo,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF6D00)),
                const SizedBox(height: 14),
                Text('Algo salió mal en esta pantalla',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titulo)),
                const SizedBox(height: 6),
                Text(
                    'No se pudo mostrar este contenido, pero el resto de la app sigue funcionando.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cuerpo)),
                if (puedeVolver) ...[
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Volver'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6D00),
                        foregroundColor: Colors.white),
                  ),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: 14),
                  ExpansionTile(
                    title: const Text('Detalles técnicos',
                        style: TextStyle(fontSize: 12)),
                    childrenPadding: const EdgeInsets.all(12),
                    children: [
                      Text(details.exceptionAsString(),
                          style: TextStyle(fontSize: 11, color: cuerpo)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
