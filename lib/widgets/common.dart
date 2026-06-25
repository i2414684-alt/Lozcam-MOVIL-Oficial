import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Tarjeta blanca con borde redondeado.
class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color ?? context.tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? context.tokens.border, width: 0.5),
      ),
      child: child,
    );
  }
}

/// Título pequeño en mayúsculas dentro de una tarjeta.
class CardTitle extends StatelessWidget {
  final String text;
  const CardTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.tokens.textSecondary,
            letterSpacing: 0.4),
      ),
    );
  }
}

/// Barra de progreso con color según el porcentaje.
class ProgressBar extends StatelessWidget {
  final int pct;
  const ProgressBar(this.pct, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = pct >= 60
        ? AppColors.success
        : pct >= 30
            ? AppColors.warning
            : AppColors.danger;
    return Container(
      height: 6,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
          color: context.tokens.border, borderRadius: BorderRadius.circular(3)),
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

/// Etiqueta de estado (badge).
class AppBadge extends StatelessWidget {
  final String label;
  final String tone; // green | amber | red | blue | gray | purple
  const AppBadge(this.label, {super.key, this.tone = 'gray'});
  @override
  Widget build(BuildContext context) {
    final p = tonePair(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: p.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: p.fg)),
    );
  }
}

/// Tarjeta de estadística (número grande + etiqueta).
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const StatCard(this.value, this.label, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: context.tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.tokens.border, width: 0.5)),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color ?? context.tokens.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: context.tokens.textSecondary)),
        ]),
      ),
    );
  }
}

/// Avatar circular con iniciales.
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

/// Encabezado de color de cada panel (respeta el notch con SafeArea).
class PanelHeader extends StatelessWidget {
  final String title, subtitle;
  final Color color;
  final IconData icon;

  /// Si se provee, muestra un botón de cerrar sesión a la derecha.
  final VoidCallback? onLogout;

  const PanelHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.icon,
      this.onLogout});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha:0.78))),
                  ]),
            ),
            const ThemeToggleButton(color: Colors.white),
            if (onLogout != null)
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Placeholder visual del mapa. Para el mapa real instala google_maps_flutter.
class MapPlaceholder extends StatelessWidget {
  final String label;
  final double height;
  const MapPlaceholder({super.key, required this.label, this.height = 180});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFC8E6C9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA5D6A7), width: 0.5)),
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha:0.25), width: 2))),
        Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha:0.4), width: 2))),
        const Icon(Icons.location_on, size: 34, color: AppColors.danger),
        Positioned(
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.textPrimary)),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Text('Google Maps',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.textPrimary)),
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
  const IconRow(
      {super.key,
      required this.icon,
      required this.iconColor,
      required this.title,
      required this.subtitle,
      this.titleColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: titleColor ?? context.tokens.textPrimary)),
            const SizedBox(height: 1),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: context.tokens.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
