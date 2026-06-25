import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'core/local_store.dart';
import 'core/supabase_client.dart';
import 'core/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/shell_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init(); // memoria interna del dispositivo
  ThemeController.instance.cargar(); // preferencia de tema guardada
  await initSupabase(); // nube (solo si hay credenciales en config.dart)
  runApp(const LozcamApp());
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
          theme: AppTheme.light, // Modo Claro (Poppins incluida)
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
      backgroundColor: Colors.white,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.primary,
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
                strokeWidth: 2.2, color: AppColors.primary),
          ),
        ]),
      ),
    );
  }
}
