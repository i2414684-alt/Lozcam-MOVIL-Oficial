import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lozcam_movil/screens/admin/admin_areas.dart';
import 'package:lozcam_movil/screens/admin/area_editor.dart';
import 'package:lozcam_movil/theme/app_theme.dart';

void main() {
  // ═══ Flujo real en web (correr con: flutter test --platform chrome) ═══
  // Reproducen el reporte "Nueva área se queda en blanco" del panel gerente.

  testWidgets('AreaEditor (nueva área) construye el body completo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const AreaEditor(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'El body del editor no debe lanzar errores de layout');
    expect(find.text('Nueva área'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    // Body: buscador + nombre = 2 TextField
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.textContaining('Radio permitido'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  }, skip: !kIsWeb);

  testWidgets('Flujo real: AdminAreas -> tocar "Nueva área" -> editor visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: AdminAreas()),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Nueva área'), findsOneWidget);
    await tester.tap(find.text('Nueva área'));
    // Transición de la ruta
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(Slider), findsOneWidget);
  }, skip: !kIsWeb);

  // ═══ Regresión (corre en VM y web) ═══
  // Causa raíz del bug: el tema definía minimumSize con Size.fromHeight(...),
  // cuyo ancho es double.infinity. Un botón así dentro de un Row (ancho
  // no-acotado) lanza "BoxConstraints forces an infinite width" en LAYOUT y
  // deja el body de la pantalla en blanco (el error boundary de build no lo
  // atrapa). Este test fija el contrato: ningún botón del tema puede exigir
  // ancho mínimo infinito.

  testWidgets('El tema no impone ancho mínimo infinito a los botones',
      (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      for (final min in [
        theme.elevatedButtonTheme.style?.minimumSize?.resolve({}),
        theme.filledButtonTheme.style?.minimumSize?.resolve({}),
        theme.outlinedButtonTheme.style?.minimumSize?.resolve({}),
      ]) {
        expect(min, isNotNull);
        expect(min!.width.isFinite, isTrue,
            reason: 'minimumSize con ancho infinito rompe botones en Rows');
      }
    }
  });

  testWidgets(
      'REPRO del bug: el tema viejo (Size.fromHeight) SÍ rompía el layout',
      (tester) async {
    // Con el minimumSize que tenía el tema antes del fix, la misma estructura
    // del buscador lanza "BoxConstraints forces an infinite width".
    final temaViejo = AppTheme.light.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48)),
      ),
    );
    await tester.pumpWidget(MaterialApp(
      theme: temaViejo,
      home: Scaffold(
        body: Row(children: [
          const Expanded(child: TextField()),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {},
              child: const Icon(Icons.search),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump();
    // El layout truena en cascada (~8 excepciones por frame: "BoxConstraints
    // forces an infinite width" + los "RenderBox was not laid out" derivados).
    final e = tester.takeException();
    expect(e, isNotNull,
        reason: 'El tema viejo debía reproducir el crash de layout');
  });

  testWidgets('Botón del tema dentro de un Row (ancho no-acotado) no crashea',
      (tester) async {
    // Réplica de la estructura del buscador de area_editor: TextField
    // expandido + botón en un SizedBox solo con alto.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Row(children: [
          const Expanded(child: TextField()),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {},
              child: const Icon(Icons.search),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'Con el tema corregido, un botón en un Row debe medir finito');
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
