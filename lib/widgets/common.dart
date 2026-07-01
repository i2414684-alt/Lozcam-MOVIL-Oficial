import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../theme/theme_controller.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Helpers internos
// ══════════════════════════════════════════════════════════════════════════════

Color _darkenColor(Color c, [double amount = 0.12]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

// ══════════════════════════════════════════════════════════════════════════════
//  AppCard
// ══════════════════════════════════════════════════════════════════════════════

enum _CardVariant { standard, tonal, outlined, elevated }

/// Tarjeta con superficies desde tokens. Variantes:
/// - `AppCard(child: ...)` — estándar con borde sutil y sombra sm
/// - `AppCard.tonal(seed: color, child: ...)` — fondo tintado con el color del rol
/// - `AppCard.outlined(child: ...)` — borde más visible, sin sombra
/// - `AppCard.elevated(child: ...)` — sombra md, sin borde
class AppCard extends StatelessWidget {
  final Widget child;

  // API pública legada — se mantiene para compatibilidad.
  final Color? color;
  final Color? borderColor;

  final _CardVariant _variant;
  final Color? _seed;

  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
  })  : _variant = _CardVariant.standard,
        _seed = null;

  const AppCard.tonal({
    Key? key,
    required Color seed,
    required Widget child,
    Color? borderColor,
  })  : this._(
          key: key,
          child: child,
          variant: _CardVariant.tonal,
          seed: seed,
          color: null,
          borderColor: borderColor,
        );

  const AppCard.outlined({
    Key? key,
    required Widget child,
    Color? color,
    Color? borderColor,
  })  : this._(
          key: key,
          child: child,
          variant: _CardVariant.outlined,
          seed: null,
          color: color,
          borderColor: borderColor,
        );

  const AppCard.elevated({
    Key? key,
    required Widget child,
    Color? color,
  })  : this._(
          key: key,
          child: child,
          variant: _CardVariant.elevated,
          seed: null,
          color: color,
          borderColor: null,
        );

  const AppCard._({
    super.key,
    required this.child,
    required _CardVariant variant,
    required Color? seed,
    this.color,
    this.borderColor,
  })  : _variant = variant,
        _seed = seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final brightness = Theme.of(context).brightness;

    Color bg;
    BorderSide side;
    List<BoxShadow> shadows;

    switch (_variant) {
      case _CardVariant.tonal:
        final seed = _seed ?? t.brand;
        bg = color ?? seed.withValues(alpha: brightness == Brightness.light ? .08 : .14);
        side = BorderSide(
            color: borderColor ?? seed.withValues(alpha: .22), width: 0.5);
        shadows = const [];
        break;
      case _CardVariant.outlined:
        bg = color ?? t.surface;
        side = BorderSide(
            color: borderColor ?? t.border, width: 1.0);
        shadows = const [];
        break;
      case _CardVariant.elevated:
        bg = color ?? t.surface;
        side = BorderSide.none;
        shadows = AppShadows.md(brightness);
        break;
      case _CardVariant.standard:
        bg = color ?? t.surface;
        side = BorderSide(
            color: borderColor ?? t.border, width: 0.5);
        shadows = AppShadows.sm(brightness);
    }

    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.emphasized,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.fromBorderSide(side),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GlassPanel — "vidrio esmerilado" (glassmorphism) nativo, sin paquetes.
//  Desenfoca lo que hay detrás (BackdropFilter) y aplica un tinte translúcido.
//  Úsalo para modales, hojas inferiores o tarjetas premium sobre gradientes.
// ══════════════════════════════════════════════════════════════════════════════

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 18,
    this.radius = AppRadius.xxl,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final tint = light
        ? Colors.white.withValues(alpha: .55)
        : Colors.white.withValues(alpha: .06);
    final borderCol = light
        ? Colors.white.withValues(alpha: .60)
        : Colors.white.withValues(alpha: .12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderCol, width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CardTitle
// ══════════════════════════════════════════════════════════════════════════════

/// Título pequeño en mayúsculas dentro de una tarjeta.
class CardTitle extends StatelessWidget {
  final String text;
  const CardTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: context.text.overline,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AppBadge
// ══════════════════════════════════════════════════════════════════════════════

/// Tonos semánticos del badge.
enum BadgeTone { neutral, success, warning, danger, info }

/// Etiqueta de estado (badge). Acepta `tone` como String (legado) o `badgeTone`.
class AppBadge extends StatelessWidget {
  final String label;
  final String tone;
  final BadgeTone? badgeTone;

  const AppBadge(this.label, {super.key, this.tone = 'gray', this.badgeTone});

  ({Color bg, Color fg}) _resolveColors(BuildContext context) {
    final t = context.tokens;
    if (badgeTone != null) {
      return switch (badgeTone!) {
        BadgeTone.success => (bg: t.successSoft, fg: t.success),
        BadgeTone.warning => (bg: t.warningSoft, fg: t.warning),
        BadgeTone.danger  => (bg: t.dangerSoft,  fg: t.danger),
        BadgeTone.info    => (bg: t.brandSoft,   fg: t.brand),
        BadgeTone.neutral => (bg: t.surfaceAlt,  fg: t.textSecondary),
      };
    }
    return tonePair(tone);
  }

  @override
  Widget build(BuildContext context) {
    final p = _resolveColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 1, vertical: AppSpacing.xs - 1),
      decoration: BoxDecoration(
          color: p.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: p.fg)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RoleAvatar
// ══════════════════════════════════════════════════════════════════════════════

/// Avatar circular con iniciales del usuario, con el color del rol.
class RoleAvatar extends StatelessWidget {
  final String initials;
  final Color roleColor;
  final double size;

  const RoleAvatar({
    super.key,
    required this.initials,
    required this.roleColor,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avatar: $initials',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .22),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: .4), width: 1.5),
        ),
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PanelHeader
// ══════════════════════════════════════════════════════════════════════════════

/// Encabezado con gradiente del rol, avatar y datos del usuario.
class PanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback? onLogout;

  const PanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _darkenColor(color, 0.14);
    final initials = _initials(title);

    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, dark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(children: [
            RoleAvatar(initials: initials, roleColor: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ]),
            ),
            const ThemeToggleButton(color: Colors.white),
            if (onLogout != null)
              Tooltip(
                message: 'Cerrar sesión',
                child: IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_outlined,
                      color: Colors.white, size: 20),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  String _initials(String s) {
    final parts = s.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0];
    return '${parts.first[0]}${parts.last[0]}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PrimaryButton
// ══════════════════════════════════════════════════════════════════════════════

/// Botón principal. Soporta estado de carga y escala animada al presionar.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final IconData? icon;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.color,
    this.icon,
    this.height = 48,
  });

  const PrimaryButton.large({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool loading = false,
    Color? color,
    IconData? icon,
  }) : this(
            key: key,
            label: label,
            onPressed: onPressed,
            loading: loading,
            color: color,
            icon: icon,
            height: 54);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: AppMotion.fast, lowerBound: 0, upperBound: 1);
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.color ?? context.tokens.brand;
    final enabled = widget.onPressed != null && !widget.loading;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: enabled ? (_) => _ctrl.forward() : null,
        onTapUp: enabled
            ? (_) async {
                await _ctrl.reverse();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bg, _darkenColor(bg, 0.12)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: bg.withValues(alpha: .35),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: enabled ? () {} : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  child: widget.loading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon,
                                  size: 20, color: Colors.white),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Text(widget.label,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EmptyState
// ══════════════════════════════════════════════════════════════════════════════

/// Pantalla vacía con icono, título, descripción y CTA opcional.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: title,
              child: Icon(icon, size: 64, color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center,
                style: context.text.h2),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(description!,
                  textAlign: TextAlign.center,
                  style: context.text.body),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: PrimaryButton(
                    label: ctaLabel!, onPressed: onCta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  StatTile — tarjeta KPI
// ══════════════════════════════════════════════════════════════════════════════

/// Tarjeta de KPI con label overline, valor display, delta opcional.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool? deltaPositive;
  final Color? accentColor;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final brightness = Theme.of(context).brightness;
    final accent = accentColor ?? t.brand;

    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: t.border, width: 0.5),
          boxShadow: AppShadows.sm(brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                  child:
                      Text(label.toUpperCase(), style: context.text.overline)),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 14, color: accent),
                ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: accent,
                height: 1.1,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  deltaPositive == true
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: deltaPositive == true ? t.success : t.danger,
                ),
                const SizedBox(width: 2),
                Text(
                  delta!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: deltaPositive == true ? t.success : t.danger),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SkeletonBox — shimmer de carga
// ══════════════════════════════════════════════════════════════════════════════

/// Placeholder animado shimmer para usar durante cargas de listas/tarjetas.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base = brightness == Brightness.light
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF2E2E3C);
    final highlight = brightness == Brightness.light
        ? const Color(0xFFF5F5F5)
        : const Color(0xFF3A3A50);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Lista de skeletons para imitar una lista de tarjetas.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.tokens.border, width: 0.5),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 12),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(height: 20),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 180, height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AppBottomNav
// ══════════════════════════════════════════════════════════════════════════════

/// Wrapper de NavigationBar con identidad de rol.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppBottomNavItem> items;
  final Color roleColor;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: t.surface,
      indicatorColor: roleColor.withValues(alpha: .14),
      surfaceTintColor: roleColor.withValues(alpha: .04),
      elevation: 0,
      destinations: items
          .asMap()
          .entries
          .map((e) => NavigationDestination(
                icon: Icon(e.value.icon,
                    color: e.key == currentIndex
                        ? roleColor
                        : t.textSecondary),
                selectedIcon:
                    Icon(e.value.activeIcon ?? e.value.icon,
                        color: roleColor),
                label: e.value.label,
              ))
          .toList(),
    );
  }
}

class AppBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const AppBottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  Widgets legacy (mantenidos para compatibilidad)
// ══════════════════════════════════════════════════════════════════════════════

/// Barra de progreso con color según el porcentaje.
class ProgressBar extends StatelessWidget {
  final int pct;
  const ProgressBar(this.pct, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = pct >= 60
        ? t.success
        : pct >= 30
            ? t.warning
            : t.danger;
    return Container(
      height: 6,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
          color: t.border, borderRadius: BorderRadius.circular(3)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct / 100,
        child: Container(
          decoration: BoxDecoration(
              color: pct == 0 ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(3)),
        ),
      ),
    );
  }
}

/// Tarjeta de estadística legacy (número grande + etiqueta).
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const StatCard(this.value, this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final brightness = Theme.of(context).brightness;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.border, width: 0.5),
            boxShadow: AppShadows.sm(brightness)),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color ?? t.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: t.textSecondary)),
        ]),
      ),
    );
  }
}

/// Avatar circular con iniciales (legacy — usar RoleAvatar donde sea posible).
class Avatar extends StatelessWidget {
  final String text;
  final String colorKey;
  const Avatar(this.text, {super.key, this.colorKey = 'blue'});

  @override
  Widget build(BuildContext context) {
    final p = tonePair(colorKey);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
      child: Text(text,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: p.fg)),
    );
  }
}

/// Placeholder visual del mapa.
class MapPlaceholder extends StatelessWidget {
  final String label;
  final double height;
  const MapPlaceholder({super.key, required this.label, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
          color: t.successSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: t.success.withValues(alpha: .25), width: 0.5)),
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: t.brand.withValues(alpha: .25), width: 2))),
        Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: t.brand.withValues(alpha: .4), width: 2))),
        Icon(Icons.location_on, size: 34, color: t.danger),
        Positioned(
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(6)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary)),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text('Google Maps',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary)),
          ),
        ),
      ]),
    );
  }
}

/// Fila simple de lista con icono + textos.
class IconRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;

  const IconRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
      child: Row(children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? t.textPrimary)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: t.textSecondary)),
              ]),
        ),
      ]),
    );
  }
}
