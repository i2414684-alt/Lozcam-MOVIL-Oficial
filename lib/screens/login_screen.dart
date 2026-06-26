import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../theme/theme_controller.dart';
import '../core/auth_service.dart';
import '../core/local_store.dart';
import '../core/supabase_client.dart';
import '../widgets/common.dart';
import 'shell_router.dart';

Color _darken(Color c, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Pantalla de inicio de sesión — rediseño con tokens, sin colores hardcodeados.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  AppArea _panel   = AppArea.operativo;
  bool _cargando   = false;
  bool _verPass    = false;
  bool _verCuentas = false;
  String? _error;

  static const _opciones = <(AppArea, String, IconData, Color)>[
    (AppArea.gerencia,  'Gerencia',    Icons.admin_panel_settings_outlined, AppColors.roleAdmin),
    (AppArea.operativo, 'Trabajador',  Icons.engineering_outlined,          AppColors.roleEmpleado),
    (AppArea.cliente,   'Cliente',     Icons.business_outlined,             AppColors.roleCliente),
  ];

  Color get _rolColor => switch (_panel) {
        AppArea.gerencia  => AppColors.roleAdmin,
        AppArea.operativo => AppColors.roleEmpleado,
        AppArea.cliente   => AppColors.roleCliente,
      };

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error    = null;
    });
    try {
      final user = await AuthService.instance
          .ingresar(_email.text, _pass.text, panel: _panel);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => shellForSession(user)),
      );
    } on LoginError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ocurrió un error. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _probarConexion() async {
    final ok = await probarConexion();
    if (!mounted) return;
    final t = context.tokens;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '✓ Conectado a la base de datos'
          : '✗ Sin conexión a la base de datos'),
      backgroundColor: ok ? t.success : t.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t    = context.tokens;
    final nube = AuthService.instance.modoNube;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: t.appBg,
      body: Stack(
        children: [
          // Gradiente sutil en el 35% superior
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.brandSoft,
                    t.appBg,
                  ],
                ),
              ),
            ),
          ),
          // Botón tema
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: const ThemeToggleButton(),
          ),
          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _logo(t),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Lozcam',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: t.textPrimary,
                              letterSpacing: -0.5,
                              fontFamily: 'Poppins')),
                      const SizedBox(height: 2),
                      Text('Sistema de Gestión de Obras',
                          style: context.text.caption),
                      const SizedBox(height: AppSpacing.xl),
                      _tarjeta(t, brightness),
                      const SizedBox(height: AppSpacing.lg),
                      _pie(nube, t),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(AppTokens t) {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, _darken(AppColors.brand, 0.18)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Text('L',
          style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: t.onBrand,
              fontFamily: 'Poppins')),
    );
  }

  Widget _tarjeta(AppTokens t, Brightness brightness) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: t.border, width: 0.5),
        boxShadow: AppShadows.md(brightness),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ingresar como', style: context.text.overline),
        const SizedBox(height: AppSpacing.sm),
        // Selector de panel
        Row(
          children: [
            for (final o in _opciones)
              Expanded(child: _opcionPanel(o.$1, o.$2, o.$3, o.$4, t)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _LoginField(
          controller: _email,
          label: 'Correo electrónico',
          hint: 'usuario@lozcam.pe',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          enabled: !_cargando,
        ),
        const SizedBox(height: AppSpacing.md),
        _LoginField(
          controller: _pass,
          label: 'Contraseña',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: !_verPass,
          enabled: !_cargando,
          onSubmitted: (_) => _ingresar(),
          suffix: IconButton(
            tooltip: _verPass ? 'Ocultar contraseña' : 'Mostrar contraseña',
            icon: Icon(
                _verPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: t.textSecondary),
            onPressed: () => setState(() => _verPass = !_verPass),
          ),
        ),
        // Banner de error animado
        AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: AppMotion.emphasized,
          child: _error != null
              ? Padding(
                  key: const ValueKey('error'),
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _ErrorBanner(_error!),
                )
              : const SizedBox.shrink(key: ValueKey('no-error')),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Ingresar',
            onPressed: _cargando ? null : _ingresar,
            loading: _cargando,
            color: _rolColor,
          ),
        ),
      ]),
    );
  }

  Widget _opcionPanel(
      AppArea area, String label, IconData icon, Color color, AppTokens t) {
    final sel = _panel == area;
    return GestureDetector(
      onTap: _cargando ? null : () => setState(() => _panel = area),
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, _darken(color, 0.18)])
              : null,
          color: sel ? null : t.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: sel
              ? null
              : Border.all(color: t.border, width: 1),
          boxShadow: sel
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Column(children: [
          Icon(icon,
              size: 21,
              color: sel ? t.onBrand : t.textSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? t.onBrand : t.textSecondary)),
        ]),
      ),
    );
  }

  Widget _pie(bool nube, AppTokens t) {
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(nube ? Icons.cloud_done_outlined : Icons.smartphone,
            size: 13, color: t.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
              nube
                  ? 'Acceso protegido · Supabase'
                  : 'Modo sin conexión · Memoria interna',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption),
        ),
      ]),
      if (nube)
        OutlinedButton.icon(
          onPressed: _probarConexion,
          icon: const Icon(Icons.wifi_tethering_outlined, size: 16),
          label: const Text('Probar conexión'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xs)),
        ),
      if (!nube) _ayudaCuentasLocales(t),
    ]);
  }

  Widget _ayudaCuentasLocales(AppTokens t) {
    return Column(children: [
      TextButton(
        onPressed: () => setState(() => _verCuentas = !_verCuentas),
        child: Text(_verCuentas ? 'Ocultar cuentas' : 'Ver cuentas disponibles'),
      ),
      AnimatedSwitcher(
        duration: AppMotion.base,
        child: _verCuentas
            ? Container(
                key: const ValueKey('cuentas'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: t.border, width: 1)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final u in LocalStore.usuarios())
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs - 1),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _email.text = u['email'] as String;
                            _pass.text  = (u['password'] ?? '') as String;
                            _panel      = areaDeRol('${u['rol']}');
                          }),
                          child: Text(
                            '${u['email']}  ·  ${u['password']}',
                            style: context.text.caption,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Toca una cuenta para autocompletar.',
                        style: TextStyle(
                            fontSize: 10, color: t.textSecondary)),
                  ],
                ),
              )
            : const SizedBox.shrink(key: ValueKey('no-cuentas')),
      ),
    ]);
  }
}

// ── Campos de texto del login ─────────────────────────────────────────────────

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscure, enabled;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _LoginField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure    = false,
    this.enabled    = true,
    this.keyboardType,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: context.text.caption),
      const SizedBox(height: AppSpacing.sm - 2),
      TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: t.textPrimary),
        textInputAction:
            obscure ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: t.textSecondary),
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}

// ── Banner de error ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String mensaje;
  const _ErrorBanner(this.mensaje);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
          color: t.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: t.danger.withValues(alpha: .25), width: 0.5)),
      child: Row(children: [
        Icon(Icons.error_outline, size: 18, color: t.danger),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(mensaje,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: t.danger)),
        ),
      ]),
    );
  }
}
