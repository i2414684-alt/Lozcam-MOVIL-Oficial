import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../core/auth_service.dart';
import '../core/local_store.dart';
import '../core/supabase_client.dart';
import 'shell_router.dart';

/// Pantalla de inicio de sesión REAL (no demo).
/// Solo el apartado de credenciales: correo + contraseña + Ingresar.
/// Autentica contra Supabase si está configurado, o contra la memoria interna.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  AppArea _panel = AppArea.operativo; // panel elegido para ingresar
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  const SizedBox(height: 16),
                  const Text('Lozcam',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('Sistema de Gestión de Obras',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 22),
                  _selectorPanel(),
                  const SizedBox(height: 18),
                  _Field(
                    controller: _email,
                    label: 'Correo electrónico',
                    hint: 'usuario@lozcam.pe',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_cargando,
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _pass,
                    label: 'Contraseña',
                    hint: '••••••••',
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
                    const SizedBox(height: 12),
                    _ErrorBanner(_error!),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _ingresar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha:0.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white))
                          : const Text('Ingresar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(nube ? Icons.cloud_done_outlined : Icons.smartphone,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                        nube
                            ? 'Acceso protegido · Supabase'
                            : 'Modo sin conexión · Memoria interna',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ]),
                  if (nube)
                    TextButton(
                      onPressed: _probarConexion,
                      child: const Text('Probar conexión',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.primary)),
                    ),
                  if (!nube) _ayudaCuentasLocales(),
                ]),
          ),
        ),
      ),
    );
  }

  /// Selector del panel al que se quiere ingresar. El rol del usuario debe
  /// corresponder; si no, el ingreso se rechaza como "usuario inválido".
  Widget _selectorPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 6),
        child: Text('Ingresar como',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSoft)),
      ),
      Row(
        children: [
          for (final o in _opciones)
            Expanded(child: _opcionPanel(o.$1, o.$2, o.$3, o.$4)),
        ],
      ),
    ]);
  }

  Widget _opcionPanel(AppArea area, String label, IconData icon, Color color) {
    final sel = _panel == area;
    return GestureDetector(
      onTap: _cargando ? null : () => setState(() => _panel = area),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color : AppColors.screen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? color : AppColors.border, width: sel ? 0 : 0.5),
        ),
        child: Column(children: [
          Icon(icon,
              size: 22, color: sel ? Colors.white : AppColors.textMuted),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textSoft)),
        ]),
      ),
    );
  }

  /// En modo memoria interna, ayuda a ingresar mostrando las cuentas locales.
  Widget _ayudaCuentasLocales() {
    return Column(children: [
      TextButton(
        onPressed: () => setState(() => _verCuentas = !_verCuentas),
        child: Text(_verCuentas ? 'Ocultar cuentas' : 'Ver cuentas disponibles',
            style: const TextStyle(fontSize: 12, color: AppColors.primary)),
      ),
      if (_verCuentas)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.screen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5)),
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
                      _panel = areaDeRol('${u['rol']}'); // panel correcto
                    }),
                    child: Text(
                        '${u['email']}  ·  ${u['password']}',
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final bool obscure, enabled;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
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
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSoft)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction:
            obscure ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppColors.screen,
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 0.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 0.5)),
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
          borderRadius: BorderRadius.circular(10),
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
