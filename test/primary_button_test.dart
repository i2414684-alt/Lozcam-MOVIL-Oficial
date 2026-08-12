import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lozcam_movil/theme/app_theme.dart';
import 'package:lozcam_movil/widgets/common.dart';

/// Regresión del bug "el botón Ingresar no hace nada al tocarlo".
///
/// Causa original: PrimaryButton tenía un GestureDetector externo con el
/// `onTapUp` que llamaba a `onPressed`, y DENTRO un InkWell con `onTap: () {}`.
/// En la arena de gestos de Flutter gana el detector más profundo, así que el
/// InkWell (vacío) se quedaba el toque y `onPressed` no se ejecutaba jamás.
/// Con el teclado sí funcionaba porque el login usa `onSubmitted` del TextField,
/// que no pasa por la arena de gestos.
void main() {
  Widget envolver(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('PrimaryButton ejecuta onPressed al tocarlo', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      PrimaryButton(label: 'Ingresar', onPressed: () => toques++),
    ));

    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(toques, 1, reason: 'Un toque debe disparar onPressed exactamente 1 vez');
  });

  testWidgets('PrimaryButton.large también responde al toque', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      PrimaryButton.large(label: 'Marcar asistencia', onPressed: () => toques++),
    ));

    await tester.tap(find.text('Marcar asistencia'));
    await tester.pumpAndSettle();

    expect(toques, 1);
  });

  testWidgets('No dispara onPressed mientras está en loading', (tester) async {
    var toques = 0;
    await tester.pumpWidget(envolver(
      PrimaryButton(
          label: 'Ingresar', loading: true, onPressed: () => toques++),
    ));

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump(const Duration(milliseconds: 400));

    expect(toques, 0, reason: 'En loading el botón debe ignorar los toques');
  });

  testWidgets('No dispara nada cuando onPressed es null', (tester) async {
    await tester.pumpWidget(envolver(
      const PrimaryButton(label: 'Ingresar'),
    ));

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Se anuncia como botón para accesibilidad', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(envolver(
      PrimaryButton(label: 'Ingresar', onPressed: () {}),
    ));

    expect(
      tester.getSemantics(find.byType(PrimaryButton)),
      matchesSemantics(
        label: 'Ingresar',
        isButton: true,
        isEnabled: true,
        isFocusable: true,
        hasEnabledState: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
