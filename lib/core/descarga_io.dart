import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Móvil/escritorio: guarda el archivo en la carpeta temporal y abre el diálogo
/// de compartir. Si compartir no está disponible (típico en escritorio), guarda
/// una copia en la carpeta Descargas del usuario. Devuelve un mensaje.
Future<String> guardarODescargar(List<int> bytes, String nombre) async {
  try {
    final dir = await getTemporaryDirectory();
    final ruta = '${dir.path}/$nombre';
    await File(ruta).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(ruta, mimeType: _xlsxMime)],
      subject: 'Reporte LOZCAM',
    );
    return 'Reporte Excel generado. Elige dónde compartirlo o guardarlo.';
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
    return 'Reporte Excel guardado en:\n$destino';
  }
}
