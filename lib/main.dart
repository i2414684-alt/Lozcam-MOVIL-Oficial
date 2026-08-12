import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'theme/colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'core/local_store.dart';
import 'core/push_service.dart';
import 'core/supabase_client.dart';
import 'core/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/shell_router.dart';
import 'widgets/error_boundary.dart';

/// Arranque robusto: cualquier error de aquí en adelante (al construir una
/// pantalla, o uno que se escape de un `Future` sin capturar) queda contenido
/// y visible en vez de dejar la app congelada en blanco. Aplica a TODA la app:
///  - `ErrorWidget.builder` reemplaza el cuadro gris/rojo por defecto por
///    [AppErrorScreen] con opción de "Volver".
///  - `runZonedGuarded` atrapa errores async no capturados para que no
///    tumben la app ni la dejen en un estado inconsistente.
void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) debugPrint('Error de UI: ${details.exceptionAsString()}');
  };
  ErrorWidget.builder = (details) => AppErrorScreen(details: details);

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await LocalStore.init(); // memoria interna del dispositivo
    } catch (e) {
      debugPrint('LocalStore.init falló: $e');
    }
    ThemeController.instance.cargar(); // preferencia de tema guardada

    // Firebase ANTES de runApp: `Firebase.initializeApp()` debe completarse
    // antes de tocar cualquier API de Firebase, y el manejador de segundo plano
    // hay que registrarlo aquí (no dentro de un widget) porque Android lo
    // invoca sin que la UI exista.
    //
    // Va en try/catch a propósito: sin Google Play Services o sin red, la
    // inicialización falla, y una obra sin notificaciones sigue necesitando
    // marcar asistencia. Las push son un extra, no un requisito de arranque.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(manejadorSegundoPlano);
      await PushService.instance.iniciar();
    } catch (e) {
      debugPrint('Firebase no disponible, la app sigue sin push: $e');
    }

    await initSupabase(); // nube (solo si hay credenciales en config.dart)
    runApp(const LozcamApp());
  }, (error, stack) {
    debugPrint('Error no capturado: $error\n$stack');
  });
}

class LozcamApp extends StatelessWidget {
  const LozcamApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Escucha el modo de tema: al alternar claro/oscuro, MaterialApp se
    // reconstruye y toda la app cambia automáticamente.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.modo,
      builder: (context, modo, _) {
        return MaterialApp(
          title: 'Lozcam',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light, // Modo Claro (Inter + Lexend)
          darkTheme: AppTheme.dark, // Modo Oscuro
          themeMode: modo, // claro / oscuro / sistema
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Compuerta de sesión: intenta restaurar la sesión guardada (auto-login).
/// Si hay sesión -> entra directo al panel del rol. Si no -> login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<SessionUser?> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.instance.restaurarSesion();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionUser?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();
        return shellForSession(user);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo del tema activo, no blanco fijo: al arrancar en modo oscuro la
      // app daba un fogonazo blanco antes de pintar la primera pantalla.
      backgroundColor: context.tokens.appBg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('L',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: AppColors.brand),
          ),
        ]),
      ),
    );
  }
}
