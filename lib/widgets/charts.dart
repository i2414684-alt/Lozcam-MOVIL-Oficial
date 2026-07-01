import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gráfica de línea compacta (tendencia). [valores] en orden cronológico
/// (más antiguo → más reciente). Estilo 2026: curva suave + área tenue.
class LineaTendencia extends StatelessWidget {
  final List<double> valores;
  final Color color;
  final double height;

  const LineaTendencia({
    super.key,
    required this.valores,
    required this.color,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (valores.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Datos insuficientes para la gráfica',
              style: TextStyle(fontSize: 11, color: t.textSecondary)),
        ),
      );
    }
    final spots = [
      for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i]),
    ];
    final maxV = valores.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxV <= 0 ? 1 : maxV) * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: t.border, strokeWidth: 0.5),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: .14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gauge radial premium 2026: arco con degradado del acento + glow suave y el
/// valor al centro. [value] en 0..1. Estilo "obsidian + naranja".
class GaugeCircular extends StatelessWidget {
  final double value;
  final String? centerLabel;
  final String? subLabel;
  final double size;
  final Color color;
  final double stroke;

  const GaugeCircular({
    super.key,
    required this.value,
    this.centerLabel,
    this.subLabel,
    this.size = 120,
    required this.color,
    this.stroke = 10,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: Size(size, size),
          painter: _GaugePainter(
            value: value.clamp(0.0, 1.0),
            color: color,
            track: t.surfaceAlt,
            stroke: stroke,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          if (centerLabel != null)
            Text(centerLabel!,
                style: TextStyle(
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: t.textPrimary)),
          if (subLabel != null)
            Text(subLabel!,
                style: TextStyle(
                    fontSize: size * 0.11, color: t.textSecondary)),
        ]),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * value;

    // Pista de fondo.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track
        ..strokeCap = StrokeCap.round,
    );

    if (value <= 0) return;

    final shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [color.withValues(alpha: .55), color],
      transform: const GradientRotation(start),
    ).createShader(rect);

    // Glow (arco desenfocado detrás).
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Arco principal.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Gráfica de barras compacta. [datos] = lista de (label, valor).
class BarrasComparativa extends StatelessWidget {
  final List<({String label, double valor})> datos;
  final Color color;
  final double height;

  const BarrasComparativa({
    super.key,
    required this.datos,
    required this.color,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (datos.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Sin datos para graficar',
              style: TextStyle(fontSize: 11, color: t.textSecondary)),
        ),
      );
    }
    final maxV = datos.map((d) => d.valor).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxV <= 0 ? 1 : maxV) * 1.25,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: t.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= datos.length) return const SizedBox.shrink();
                  final label = datos[i].label;
                  final corto =
                      label.length > 6 ? '${label.substring(0, 6)}…' : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(corto,
                        style: TextStyle(fontSize: 9, color: t.textSecondary)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < datos.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: datos[i].valor,
                    color: color,
                    width: 16,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
