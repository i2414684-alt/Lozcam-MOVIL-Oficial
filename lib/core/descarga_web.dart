// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Web: crea un Blob con los bytes y dispara la descarga del navegador.
Future<String> guardarODescargar(List<int> bytes, String nombre) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], _xlsxMime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = nombre;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return 'Descarga iniciada: revisa las descargas de tu navegador.';
}
