// Prueba de humo: la app arranca y muestra la pantalla de inicio de sesión.
import 'package:flutter_test/flutter_test.dart';

import 'package:lozcam_movil/main.dart';

void main() {
  testWidgets('Arranca en el login con el apartado de credenciales',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LozcamApp());
    // Deja que la compuerta de sesión resuelva (sin sesión -> login).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Lozcam'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });
}
