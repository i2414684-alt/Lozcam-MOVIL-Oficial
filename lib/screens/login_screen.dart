import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/theme_controller.dart';
import '../core/auth_service.dart';
import '../core/local_store.dart';
import '../core/supabase_client.dart';
import 'shell_router.dart';

/// Oscurece un color (para los degradados corporativos).
Color _darken(Color c, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Pantalla de inicio de sesión (rediseño moderno).
/// Conserva toda la lógica: selector de panel + validación, mostrar/ocultar
/// contraseña, probar conexión y cuentas locales.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  AppArea _panel = AppArea.operativo;
  bool _cargando = false;
  bool _verPass = false;
  bool _verCuentas = false;
  String? _error;

  static const _opciones = <(AppArea, String, IconData, Color)>[
    (AppArea.gerencia, 'Gerencia', Icons.admin_panel_settings_outlined,
        AppColors.admin),
    (AppArea.operativo, 'Trabajador', Icons.engineering_outlined,
        AppColors.empleado),
    (AppArea.cliente, 'Cliente', Icons.business_outlined, AppColors.cliente),
  ];

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
      _error = null;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '✓ Conectado a la base de datos'
          : '✗ Sin conexión a la base de datos'),
      backgroundColor: ok ? AppColors.greenText : AppColors.redText,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final nube = AuthService.instance.modoNube;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4EC), Color(0xFFF5F5F7)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 8, top: 4),
                  child: ThemeToggleButton(color: AppColors.textMuted),
                ),
              ),
              Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _logo(),
                    const SizedBox(height: 18),
                    Text('Lozcam',
                        style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('Sistema de Gestión de Obras',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 26),
                    _tarjeta(),
                    const SizedBox(height: 18),
                    _pie(nube),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, _darken(AppColors.primary, 0.18)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Text('L',
          style: GoogleFonts.poppins(
              fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _tarjeta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ingresar como',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSoft)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final o in _opciones)
              Expanded(child: _opcionPanel(o.$1, o.$2, o.$3, o.$4)),
          ],
        ),
        const SizedBox(height: 18),
        _Field(
          controller: _email,
          label: 'Correo electrónico',
          hint: 'usuario@lozcam.pe',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          enabled: !_cargando,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _pass,
          label: 'Contraseña',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: !_verPass,
          enabled: !_cargando,
          onSubmitted: (_) => _ingresar(),
          suffix: IconButton(
            icon: Icon(
                _verPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textMuted),
            onPressed: () => setState(() => _verPass = !_verPass),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: 20),
        _GradientButton(
          cargando: _cargando,
          onTap: _cargando ? null : _ingresar,
        ),
      ]),
    );
  }

  Widget _opcionPanel(AppArea area, String label, IconData icon, Color color) {
    final sel = _panel == area;
    return GestureDetector(
      onTap: _cargando ? null : () => setState(() => _panel = area),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, _darken(color, 0.18)])
              : null,
          color: sel ? null : const Color(0xFFFAFAFB),
          borderRadius: BorderRadius.circular(12),
          border:
              sel ? null : Border.all(color: AppColors.border, width: 1),
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
          Icon(icon, size: 21, color: sel ? Colors.white : AppColors.textMuted),
          const SizedBox(height: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textSoft)),
        ]),
      ),
    );
  }

  Widget _pie(bool nube) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(nube ? Icons.cloud_done_outlined : Icons.smartphone,
            size: 13, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(
            nube
                ? 'Acceso protegido · Supabase'
                : 'Modo sin conexión · Memoria interna',
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textMuted)),
      ]),
      if (nube)
        TextButton(
          onPressed: _probarConexion,
          child: Text('Probar conexión',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ),
      if (!nube) _ayudaCuentasLocales(),
    ]);
  }

  /// En modo memoria interna, ayuda a ingresar mostrando las cuentas locales.
  Widget _ayudaCuentasLocales() {
    return Column(children: [
      TextButton(
        onPressed: () => setState(() => _verCuentas = !_verCuentas),
        child: Text(_verCuentas ? 'Ocultar cuentas' : 'Ver cuentas disponibles',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ),
      if (_verCuentas)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final u in LocalStore.usuarios())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _email.text = u['email'] as String;
                      _pass.text = (u['password'] ?? '') as String;
                      _panel = areaDeRol('${u['rol']}');
                    }),
                    child: Text('${u['email']}  ·  ${u['password']}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSoft)),
                  ),
                ),
              const SizedBox(height: 4),
              const Text('Toca una cuenta para autocompletar.',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
    ]);
  }
}

/// Botón premium con degradado corporativo y sombra.
class _GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool cargando;
  const _GradientButton({required this.onTap, required this.cargando});

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null && !cargando;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _darken(AppColors.primary, 0.2)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: activo
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6))
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: cargando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Text('Ingresar',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscure, enabled;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
        textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE8E8EC), width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE8E8EC), width: 1)),
        ),
      ),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  final String mensaje;
  const _ErrorBanner(this.mensaje);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.redBg,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFFF4C0C0), width: 0.5))),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 18, color: AppColors.redText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(mensaje,
              style: const TextStyle(fontSize: 12, color: AppColors.redText)),
        ),
      ]),
    );
  }
}
