import 'package:flutter_test/flutter_test.dart';
import 'package:lozcam_movil/data/reporte_excel.dart';
import 'package:lozcam_movil/data/reporte_pdf.dart';

/// Humo de los generadores de reporte: sin nube (supabaseListo=false) los
/// repos caen a datos locales/semilla; ambos formatos deben producir bytes
/// válidos con TODAS las plantillas, sin lanzar excepciones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Excel: genera bytes con las 5 plantillas', () async {
    for (final p in PlantillaReporte.values) {
      final bytes = await generarReporteExcel(plantilla: p);
      expect(bytes.length, greaterThan(500),
          reason: 'xlsx vacío con plantilla $p');
      // Firma ZIP de un .xlsx válido: PK
      expect(bytes[0], 0x50, reason: 'no es un zip/xlsx ($p)');
      expect(bytes[1], 0x4B, reason: 'no es un zip/xlsx ($p)');
    }
  });

  test('PDF: genera bytes con las 5 plantillas', () async {
    for (final p in PlantillaReporte.values) {
      final bytes = await generarReportePdf(plantilla: p);
      expect(bytes.length, greaterThan(500),
          reason: 'pdf vacío con plantilla $p');
      // Firma de un PDF válido: %PDF
      expect(String.fromCharCodes(bytes.take(4)), '%PDF',
          reason: 'no es un PDF ($p)');
    }
  });

  test('El nombre de archivo respeta el formato elegido', () {
    expect(nombreArchivoReporte(), endsWith('.xlsx'));
    expect(nombreArchivoReporte(ext: extensionDe(FormatoReporte.pdf)),
        endsWith('.pdf'));
  });
}
