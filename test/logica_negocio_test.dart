import 'package:flutter_test/flutter_test.dart';
import 'package:lozcam_movil/core/auth_service.dart';
import 'package:lozcam_movil/data/fuente_datos.dart';
import 'package:lozcam_movil/data/roles.dart';

/// Pruebas de la LÓGICA DE NEGOCIO crítica, que hasta ahora no tenía ninguna:
/// jerarquía de delegación, enrutado de paneles por rol y cálculo de faltas.
/// Son reglas que, si se rompen, dejan a alguien viendo un panel que no le
/// corresponde o sumando avance a una obra ajena.
void main() {
  group('Jerarquía de delegación (puedeDelegarA)', () {
    test('gerencia delega a toda la empresa, hacia abajo', () {
      expect(puedeDelegarA('gerente_general', 'personal_obra'), isTrue);
      expect(puedeDelegarA('gerente_general', 'contador'), isTrue);
      expect(puedeDelegarA('subgerente', 'maestro_obra'), isTrue);
      expect(puedeDelegarA('administrador', 'tecnico_autocad'), isTrue);
    });

    test('nunca se delega al cliente (es externo a la empresa)', () {
      for (final r in jerarquiaLozcam) {
        expect(puedeDelegarA(r.rol, 'cliente'), isFalse,
            reason: '${r.rol} no debe poder delegar al cliente');
      }
    });

    test('no se delega hacia arriba ni al mismo nivel', () {
      expect(puedeDelegarA('personal_obra', 'gerente_general'), isFalse);
      expect(puedeDelegarA('maestro_obra', 'ingeniero_residente'), isFalse);
      // Mismo nivel 2: subgerente y administrador no se delegan entre sí.
      expect(puedeDelegarA('subgerente', 'administrador'), isFalse);
      expect(puedeDelegarA('administrador', 'subgerente'), isFalse);
    });

    test('las jefaturas solo delegan dentro de SU área', () {
      // Construcción -> construcción: sí.
      expect(puedeDelegarA('ingeniero_residente', 'maestro_obra'), isTrue);
      expect(puedeDelegarA('ingeniero_residente', 'personal_obra'), isTrue);
      // Construcción -> arquitectura: no.
      expect(puedeDelegarA('ingeniero_residente', 'tecnico_autocad'), isFalse);
      // Arquitectura -> arquitectura: sí.
      expect(puedeDelegarA('arquitecto', 'tecnico_autocad'), isTrue);
      // Arquitectura -> construcción: no.
      expect(puedeDelegarA('arquitecto', 'personal_obra'), isFalse);
    });

    test('quien no puede delegar, no delega a nadie', () {
      expect(rolesDelegablesPor('personal_obra'), isEmpty);
      expect(rolesDelegablesPor('tecnico_autocad'), isEmpty);
      expect(rolesDelegablesPor('cliente'), isEmpty);
    });

    test('un rol desconocido no delega ni recibe', () {
      expect(puedeDelegarA('rol_inventado', 'personal_obra'), isFalse);
      expect(puedeDelegarA('gerente_general', 'rol_inventado'), isFalse);
    });
  });

  group('Enrutado de panel por rol (areaDeRol)', () {
    test('niveles 1-2 van al panel de gerencia', () {
      expect(areaDeRol('gerente_general'), AppArea.gerencia);
      expect(areaDeRol('subgerente'), AppArea.gerencia);
      expect(areaDeRol('administrador'), AppArea.gerencia);
    });

    test('niveles 3-5 van al panel operativo', () {
      for (final r in const [
        'ingeniero_residente',
        'arquitecto',
        'topografo',
        'contador',
        'vendedor',
        'maestro_obra',
        'tecnico_autocad',
        'personal_obra',
      ]) {
        expect(areaDeRol(r), AppArea.operativo, reason: r);
      }
    });

    test('el cliente va a su propio panel y nunca a gerencia', () {
      expect(areaDeRol('cliente'), AppArea.cliente);
    });

    test('un rol desconocido cae en operativo, el de menos privilegios', () {
      expect(areaDeRol('rol_inventado'), AppArea.operativo);
    });
  });

  group('Asistencia de campo', () {
    test('solo personal de obra y maestro de obra marcan', () {
      expect(puedeMarcarAsistencia('personal_obra'), isTrue);
      expect(puedeMarcarAsistencia('maestro_obra'), isTrue);
      expect(puedeMarcarAsistencia('gerente_general'), isFalse);
      expect(puedeMarcarAsistencia('cliente'), isFalse);
      expect(puedeMarcarAsistencia('contador'), isFalse);
    });
  });

  group('Totales de asistencia', () {
    test('cuenta días, entradas y salidas por separado', () {
      final dias = [
        {'fecha': '2026-08-10', 'hora_entrada': 'x', 'hora_salida': 'y'},
        {'fecha': '2026-08-11', 'hora_entrada': 'x', 'hora_salida': null},
        {'fecha': '2026-08-12', 'hora_entrada': 'x', 'hora_salida': 'y'},
      ];
      final t = totalesDe(dias);
      expect(t.dias, 3);
      expect(t.entradas, 3);
      expect(t.salidas, 2);
      // Una jornada abierta: entró pero no marcó salida.
      expect(t.sinCerrar, 1);
    });

    test('nunca reporta jornadas sin cerrar negativas', () {
      final t = totalesDe([
        {'fecha': '2026-08-10', 'hora_entrada': null, 'hora_salida': 'y'},
      ]);
      expect(t.sinCerrar, 0);
    });

    test('sin registros, todo en cero', () {
      final t = totalesDe(const []);
      expect(t.dias, 0);
      expect(t.entradas, 0);
      expect(t.salidas, 0);
    });
  });

  group('Días hábiles para el cálculo de faltas', () {
    test('el domingo no cuenta como falta', () {
      // 2026-08-09 fue domingo.
      expect(esDiaHabil(DateTime(2026, 8, 9)), isFalse);
    });

    test('de lunes a sábado sí son días hábiles de obra', () {
      for (var d = 10; d <= 15; d++) {
        expect(esDiaHabil(DateTime(2026, 8, d)), isTrue,
            reason: '2026-08-$d debe ser hábil');
      }
    });
  });

  group('Roles de campo asignables a un área', () {
    test('no incluye perfiles de oficina ni al cliente', () {
      expect(rolesDeCampo.contains('contador'), isFalse);
      expect(rolesDeCampo.contains('vendedor'), isFalse);
      expect(rolesDeCampo.contains('cliente'), isFalse);
      expect(rolesDeCampo.contains('personal_obra'), isTrue);
      expect(rolesDeCampo.contains('maestro_obra'), isTrue);
    });

    test('todos los roles de campo existen en la jerarquía', () {
      for (final r in rolesDeCampo) {
        expect(rolPorClave(r), isNotNull, reason: r);
      }
    });
  });
}
