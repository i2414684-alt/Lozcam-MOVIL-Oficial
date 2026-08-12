import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// ============================================================================
///  NOTIFICACIONES PUSH (Firebase Cloud Messaging)
///
///  Los TRES estados en los que puede llegar un mensaje, que NO son los mismos
///  que los tres callbacks:
///
///   1. PRIMER PLANO (app abierta y visible)
///      -> `FirebaseMessaging.onMessage`
///      OJO: en Android el sistema NO dibuja nada en primer plano. Solo se
///      ejecuta este callback. Para que aparezca la bandeja hay que pintarla a
///      mano con `flutter_local_notifications` (ver nota al final del archivo).
///
///   2. SEGUNDO PLANO (app minimizada) y 3. APP CERRADA (terminated)
///      Estos dos comparten el mismo manejador de datos:
///      -> `FirebaseMessaging.onBackgroundMessage`, que corre en un ISOLATE
///         NUEVO, separado del de la app.
///      La diferencia está en QUÉ PASA AL TOCAR la notificación:
///        · app en segundo plano -> `onMessageOpenedApp`
///        · app cerrada          -> `getInitialMessage()` (una sola vez, al
///          arrancar; si se usa `onMessageOpenedApp` para este caso, el toque
///          se pierde porque el stream aún no existía cuando llegó).
///
///  No toca la base de datos ni la sesión: solo recibe, registra y avisa.
/// ============================================================================

/// Manejador de SEGUNDO PLANO / APP CERRADA.
///
/// Tres requisitos que no son negociables, o Android no lo encuentra:
///  - función de NIVEL SUPERIOR (no un método de clase, no una función anónima),
///  - anotada con `@pragma('vm:entry-point')` para que el compilador de release
///    no la elimine por "código no usado" (en debug funciona y en release no:
///    es el fallo clásico de esta integración),
///  - `Firebase.initializeApp()` dentro, porque este isolate arranca vacío.
///
/// IMPORTANTE: aquí NO existe nada del estado de la app. `AuthService.session`
/// es null, `LocalStore` no está inicializado y el cliente de Supabase no
/// existe. Todo lo que se necesite hay que inicializarlo dentro.
@pragma('vm:entry-point')
Future<void> manejadorSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[FCM][segundo plano] id=${mensaje.messageId}');
  debugPrint('[FCM][segundo plano] título=${mensaje.notification?.title}');
  debugPrint('[FCM][segundo plano] cuerpo=${mensaje.notification?.body}');
  debugPrint('[FCM][segundo plano] datos=${mensaje.data}');
}

/// Servicio de notificaciones push de Lozcam.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Token del dispositivo. Es la "dirección" a la que el servidor envía las
  /// notificaciones a ESTE teléfono.
  String? token;

  /// Último mensaje que abrió la app (por toque en la notificación).
  /// Lo puede leer la UI para navegar a la pantalla correspondiente.
  final ValueNotifier<RemoteMessage?> mensajeDeApertura =
      ValueNotifier<RemoteMessage?>(null);

  bool _iniciado = false;

  /// Arranca el servicio. Se llama UNA vez desde `main()`, después de
  /// `Firebase.initializeApp()`.
  ///
  /// Nunca lanza: si Firebase falla (sin red, sin Google Play Services en el
  /// dispositivo, configuración incompleta), la app debe seguir funcionando.
  /// Las notificaciones son un extra, no un requisito para marcar asistencia.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    try {
      await _pedirPermiso();
      await _registrarToken();
      _escucharPrimerPlano();
      _escucharAperturaDesdeSegundoPlano();
      await _revisarAperturaDesdeAppCerrada();
    } catch (e, s) {
      debugPrint('[FCM] no se pudo iniciar: $e\n$s');
    }
  }

  // ── Permisos ───────────────────────────────────────────────────────────────

  /// Android 13+ (API 33) exige permiso de notificaciones en tiempo de
  /// ejecución, igual que la cámara. En versiones anteriores se concede solo.
  /// En iOS abre el diálogo del sistema.
  Future<void> _pedirPermiso() async {
    final ajustes = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] permiso: ${ajustes.authorizationStatus.name}');
  }

  // ── Token del dispositivo ──────────────────────────────────────────────────

  Future<void> _registrarToken() async {
    token = await _fcm.getToken();
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('[FCM] TOKEN DEL DISPOSITIVO:');
    debugPrint(token ?? '(null — sin red o sin Google Play Services)');
    debugPrint('══════════════════════════════════════════════════════');
    await _guardarToken(token);

    // El token se renueva solo (reinstalación, borrado de datos, restauración
    // en otro teléfono). Si no se escucha este stream, el servidor se queda
    // apuntando a una dirección muerta y las notificaciones dejan de llegar
    // sin que nadie se entere.
    _fcm.onTokenRefresh.listen((nuevo) {
      token = nuevo;
      debugPrint('[FCM] token renovado: $nuevo');
      _guardarToken(nuevo);
    });
  }

  /// Punto de enganche para asociar el token al usuario en el servidor.
  ///
  /// DELIBERADAMENTE VACÍO: enviar el token requiere una columna o tabla donde
  /// guardarlo (p. ej. `profiles.fcm_token` o una tabla `dispositivos`), y hoy
  /// el esquema no la tiene. Cuando exista, este es el único sitio a tocar.
  Future<void> _guardarToken(String? t) async {
    if (t == null) return;
    // Pendiente de tabla en el backend. Ejemplo de implementación futura:
    //
    // final uid = AuthService.instance.session?.id;
    // if (uid == null || !supabaseListo) return;
    // await supabase.from('profiles').update({'fcm_token': t}).eq('id', uid);
  }

  // ── Estado 1: PRIMER PLANO ─────────────────────────────────────────────────

  /// App abierta y visible. En Android el sistema no muestra nada: este
  /// callback es la única señal de que llegó un mensaje.
  void _escucharPrimerPlano() {
    FirebaseMessaging.onMessage.listen((mensaje) {
      debugPrint('[FCM][primer plano] id=${mensaje.messageId}');
      debugPrint('[FCM][primer plano] título=${mensaje.notification?.title}');
      debugPrint('[FCM][primer plano] cuerpo=${mensaje.notification?.body}');
      debugPrint('[FCM][primer plano] datos=${mensaje.data}');
      // Aquí es donde iría `flutter_local_notifications` para dibujar la
      // bandeja, o un SnackBar/banner dentro de la app.
    });
  }

  // ── Estado 2: SEGUNDO PLANO (toque en la notificación) ─────────────────────

  /// La app estaba minimizada y el usuario tocó la notificación.
  void _escucharAperturaDesdeSegundoPlano() {
    FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
      debugPrint('[FCM][abierta desde segundo plano] datos=${mensaje.data}');
      mensajeDeApertura.value = mensaje;
    });
  }

  // ── Estado 3: APP CERRADA (toque en la notificación) ───────────────────────

  /// La app estaba completamente cerrada y arrancó por el toque en la
  /// notificación. `getInitialMessage()` devuelve ese mensaje UNA sola vez;
  /// en cualquier otro arranque devuelve null.
  Future<void> _revisarAperturaDesdeAppCerrada() async {
    final inicial = await _fcm.getInitialMessage();
    if (inicial == null) return;
    debugPrint('[FCM][abierta desde app cerrada] datos=${inicial.data}');
    mensajeDeApertura.value = inicial;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NOTA SOBRE MOSTRAR LA NOTIFICACIÓN EN PRIMER PLANO
//
//  FCM por sí solo NO dibuja nada mientras la app está abierta en Android.
//  Para conseguirlo hace falta `flutter_local_notifications`:
//
//    flutter pub add flutter_local_notifications
//
//  y crear el canal con el MISMO id que el declarado en AndroidManifest.xml
//  (`lozcam_avisos`), porque a partir de Android 8 toda notificación necesita
//  un canal existente; si no coincide, el sistema la descarta en silencio.
// ─────────────────────────────────────────────────────────────────────────────
