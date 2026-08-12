import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const _pdfMime = 'application/pdf';

/// Mismo `guardarODescargar` sirve para exportar Excel y PDF: el mime debe
/// seguir la extensión real del archivo, no asumir siempre xlsx.
String _mimeDe(String nombre) =>
    nombre.toLowerCase().endsWith('.pdf') ? _pdfMime : _xlsxMime;

/// Móvil/escritorio: guarda el archivo en la carpeta temporal y abre el diálogo
/// de compartir. Si compartir no está disponible (típico en escritorio), guarda
/// una copia en la carpeta Descargas del usuario. Devuelve un mensaje.
Future<String> guardarODescargar(List<int> bytes, String nombre) async {
  try {
    final dir = await getTemporaryDirectory();
    final ruta = '${dir.path}/$nombre';
    await File(ruta).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(ruta, mimeType: _mimeDe(nombre))],
      subject: 'Reporte LOZCAM',
    );
    return 'Reporte generado. Elige dónde compartirlo o guardarlo.';
  } catch (_) {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    final sep = Platform.pathSeparator;
    final dir = home == null ? null : Directory('$home${sep}Downloads');
    if (dir == null || !await dir.exists()) {
      throw Exception('No se pudo compartir ni encontrar la carpeta Descargas.');
    }
    final destino = '${dir.path}$sep$nombre';
    await File(destino).writeAsBytes(bytes, flush: true);
    // El mensaje sigue la extensión real: este mismo método exporta Excel y
    // PDF, y antes decía siempre "Reporte Excel" incluso al guardar un PDF.
    final tipo = nombre.toLowerCase().endsWith('.pdf') ? 'PDF' : 'Excel';
    return 'Reporte $tipo guardado en:\n$destino';
  }
}
