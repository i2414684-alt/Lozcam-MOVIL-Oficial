// Fachada multiplataforma para guardar/descargar un archivo de bytes.
// - Móvil/escritorio (dart:io): guarda en temporal y abre "compartir"; si no,
//   guarda en la carpeta Descargas del usuario.
// - Web (dart:html): dispara la descarga del navegador.
// Ambas implementaciones exponen `guardarODescargar(bytes, nombre)` y devuelven
// un mensaje de resultado para mostrar al usuario (lanzan excepción en error).
export 'descarga_io.dart' if (dart.library.html) 'descarga_web.dart';
