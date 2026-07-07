import 'package:flutter_test/flutter_test.dart';
import 'package:lozcam_movil/data/diseno_obra.dart';
import 'package:lozcam_movil/models/models.dart';

Obra _obra(String nombre, String tipoServicio) =>
    Obra(1, nombre, tipoServicio, '', 'en_ejecucion', 0, '', '', 0, 0, 'blue');

void main() {
  group('Detección automática del diseño desde la BD', () {
    test('nombre con "puente" -> construcción tipo puente', () {
      final d = detectarDiseno(_obra('Puente Comas', ''));
      expect(d.construccion, isTrue);
      expect(d.tipoConstruccion, FaseDiseno.puente);
      expect(d.requiereEdicion, isFalse);
    });

    test('tipo_servicio "solo planos" -> plano, sin construcción forzada', () {
      final d = detectarDiseno(_obra('Oficina Lima', 'solo planos'));
      expect(d.plano, isTrue);
      expect(d.fases, contains(FaseDiseno.plano));
    });

    test('estudio topográfico + planos + construcción de edificio = 3 fases',
        () {
      final d = detectarDiseno(_obra('Torre Multifamiliar San Borja',
          'estudio topográfico, planos y construcción'));
      expect(d.fases, [
        FaseDiseno.topografico,
        FaseDiseno.plano,
        FaseDiseno.edificio,
      ]);
    });

    test('construcción sin tipo deducible -> requiere edición (REGLA)', () {
      final d = detectarDiseno(_obra('Proyecto Central', 'construcción'));
      expect(d.construccion, isTrue);
      expect(d.tipoConstruccion, isNull);
      expect(d.requiereEdicion, isTrue);
      expect(d.fases, isEmpty); // sin tipo no hay panel de construcción
    });

    test('sin pistas -> asume construcción y manda a edición', () {
      final d = detectarDiseno(_obra('Proyecto X', ''));
      expect(d.requiereEdicion, isTrue);
    });

    test('vivienda -> casa; carretera -> pista; vereda -> vereda', () {
      expect(detectarDiseno(_obra('Vivienda Chilca', '')).tipoConstruccion,
          FaseDiseno.casa);
      expect(detectarDiseno(_obra('Carretera Jauja', '')).tipoConstruccion,
          FaseDiseno.pista);
      expect(detectarDiseno(_obra('Vereda Av. Real', '')).tipoConstruccion,
          FaseDiseno.vereda);
    });
  });

  group('Reparto del avance global entre fases', () {
    test('con 3 fases, 50% global = fase1 llena, fase2 a medias, fase3 en 0',
        () {
      expect(progresoFase(0, 3, 50), 1.0);
      expect(progresoFase(1, 3, 50), 0.5);
      expect(progresoFase(2, 3, 50), 0.0);
    });

    test('100% global completa todas las fases', () {
      for (var i = 0; i < 3; i++) {
        expect(progresoFase(i, 3, 100), 1.0);
      }
    });
  });

  test('DisenoObra sobrevive ida y vuelta a JSON (guardado del gerente)', () {
    const d = DisenoObra(
        topografico: true,
        plano: true,
        construccion: true,
        tipoConstruccion: FaseDiseno.edificio);
    final d2 = DisenoObra.fromJson(d.toJson());
    expect(d2.fases, d.fases);
    expect(d2.requiereEdicion, isFalse);
  });
}
