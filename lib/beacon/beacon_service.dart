import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:beacon_scanner/beacon_scanner.dart' as beacon_scanner;
import '../beacon/notifi_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../beacon/beacons.dart';
import '../services/api_service.dart';
import '../models/beacon_data.dart';
import 'package:url_launcher/url_launcher.dart';

class BeaconService {
  static final BeaconService _instance = BeaconService._internal();
  factory BeaconService() => _instance;
  BeaconService._internal();

  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();
  final beacon_scanner.BeaconScanner _beaconScanner =
      beacon_scanner.BeaconScanner.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? timerInitBt;
  Timer? timerInitScan;
  StreamSubscription<beacon_scanner.ScanResult>? _streamRanging;
  VibracomBeacons vBeacons = VibracomBeacons();
  VibracomBeaconsInfo vBeaconsInfo = VibracomBeaconsInfo();
  final ApiService _apiService = ApiService();
  Timer? _updateBeaconsTimer;

  Future<void> initialize() async {
    print('🚀 Inicializando servicio de beacons...');
    await _initializeNotifications();
    await _initializeBackgroundService();

    // Cargar beacons inicialmente
    await updateBeaconsFromApi();

    // Configurar actualización periódica de beacons (cada 5 minutos)
    _updateBeaconsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => updateBeaconsFromApi(),
    );

    if (Platform.isIOS) {
      await _initializeBeaconScanner();
    } else {
      await _requestInitialPermissions();
    }

    timerInitBt =
        Timer.periodic(const Duration(seconds: 30), (Timer t) => _initBT());
    timerInitScan = Timer.periodic(
        const Duration(seconds: 10), (Timer t) => _startRanging());
  }

  Future<void> _initializeBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundStart,
        autoStart: true,
        isForegroundMode: false,
      ),
      iosConfiguration: IosConfiguration(),
    );

    if (!await _backgroundService.isRunning()) {
      await _backgroundService.startService();
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  Future<void> _initBT() async {
    timerInitBt?.cancel();
    try {
      if (Platform.isIOS) {
        final status = await _beaconScanner.authorizationStatus;
        if (status == beacon_scanner.AuthorizationStatus.notDetermined) {
          await _beaconScanner.requestAuthorization();
        } else if (status == beacon_scanner.AuthorizationStatus.denied ||
            status == beacon_scanner.AuthorizationStatus.restricted) {
          print('Permisos de ubicación denegados o restringidos');
          return;
        }
      }
      await _beaconScanner.initialize(true);
    } catch (e) {
      print('Error initializing beacon scanner: $e');
    }
  }

  Future<void> _startRanging() async {
    timerInitScan?.cancel();
    final regions = <beacon_scanner.Region>[];

    if (Platform.isIOS) {
      // Usar UUIDs de la API
      for (String uuid in vBeaconsInfo.uuids) {
        regions.add(beacon_scanner.Region(
          identifier: 'iBeacon_$uuid',
          beaconId: beacon_scanner.IBeaconId(
            proximityUUID: uuid,
          ),
        ));
      }
    } else {
      regions.add(beacon_scanner.Region(identifier: 'com.beacon'));
    }

    _streamRanging = _beaconScanner.ranging(regions).listen(_handleScanResult);
  }

  void _handleScanResult(beacon_scanner.ScanResult result) async {
    print('\n📡 Escaneando beacons...');
    print('Beacons detectados: ${result.beacons.length}');

    for (final beacon in result.beacons) {
      final vBeacon = VibracomBeacon(
        beacon.id.majorId,
        beacon.id.minorId,
        DateTime.now(),
      );

      print('''
🔎 Analizando beacon:
   Major: ${beacon.id.majorId}
   Minor: ${beacon.id.minorId}
   RSSI: ${beacon.rssi}''');

      final mustNotify = vBeacons.addBeacon(vBeacon);
      print('✉️ Debe notificarse: $mustNotify');

      if (mustNotify) {
        final vBeaconInfo = vBeaconsInfo.findBeacon(vBeacon);
        print('''
🔍 Valores de vBeaconInfo:
   ${vBeaconInfo?.toString()}
        ''');
        print('🔍 Información del beacon encontrada: ${vBeaconInfo != null}');

        if (vBeaconInfo != null) {
          print('''
📢 Enviando notificación:
   Título: ${vBeaconInfo.title}
   Texto: ${vBeaconInfo.text}
   Link: ${vBeaconInfo.link}''');

          try {
            await NotifiService.showBeaconNotification(
              vBeaconInfo.iconUrl,
              vBeaconInfo.title,
              vBeaconInfo.text,
              vBeaconInfo.link,
            );
            print('✅ Notificación enviada correctamente');
          } catch (e) {
            print('❌ Error al enviar la notificación: $e');
            // Intentar actualizar los beacons y reintentar
            await updateBeaconsFromApi();
            final updatedBeaconInfo = vBeaconsInfo.findBeacon(vBeacon);
            if (updatedBeaconInfo != null) {
              try {
                await NotifiService.showBeaconNotification(
                  updatedBeaconInfo.iconUrl,
                  updatedBeaconInfo.title,
                  updatedBeaconInfo.text,
                  updatedBeaconInfo.link,
                );
                print(
                    '✅ Notificación enviada correctamente después de actualizar');
              } catch (e) {
                print(
                    '❌ Error al enviar la notificación después de actualizar: $e');
              }
            }
          }
        } else {
          print('❌ No se encontró información para este beacon');
          // Intentar actualizar los beacons
          await updateBeaconsFromApi();
        }
      }
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(
      NotificationResponse notificationResponse) {
    print('notification(${notificationResponse.id}) action tapped: '
        '${notificationResponse.actionId} with'
        ' payload: ${notificationResponse.payload}');

    if (notificationResponse.payload != null) {
      _launchURL(notificationResponse.payload!);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      _launchURL(response.payload!);
    }
  }

  // Método auxiliar para lanzar URLs actualizado para url_launcher 6.3.0
  static Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      )) {
        print('No se pudo abrir la URL: $urlString');
      }
    } catch (e) {
      print('Error al abrir la URL: $e');
    }
  }

  Future<void> _initializeBeaconScanner() async {
    try {
      final status = await _beaconScanner.authorizationStatus;
      if (status == beacon_scanner.AuthorizationStatus.notDetermined) {
        await _beaconScanner.requestAuthorization();
      } else if (status == beacon_scanner.AuthorizationStatus.denied ||
          status == beacon_scanner.AuthorizationStatus.restricted) {
        print('Permisos de ubicación denegados o restringidos en iOS');
        return;
      }
      await _beaconScanner.initialize(true);
    } catch (e) {
      print('Error initializing iOS beacon scanner: $e');
    }
  }

  Future<void> _requestInitialPermissions() async {
    try {
      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        print('Permiso de ubicación denegado');
        return;
      }

      final bluetoothStatus = await Permission.bluetooth.request();
      if (!bluetoothStatus.isGranted) {
        print('Permiso de Bluetooth denegado');
        return;
      }

      if (Platform.isAndroid) {
        final bluetoothScanStatus = await Permission.bluetoothScan.request();
        if (!bluetoothScanStatus.isGranted) {
          print('Permiso de Bluetooth scan denegado');
          return;
        }
      }

      await _beaconScanner.initialize(true);
    } catch (e) {
      print('Error requesting initial permissions: $e');
    }
  }

  Future<void> startScanning() async {
    await _initBT();
    await _startRanging();
  }

  Future<void> stopScanning() async {
    timerInitBt?.cancel();
    timerInitScan?.cancel();
    _streamRanging?.cancel();
  }

  void dispose() {
    stopScanning();
    _streamRanging?.cancel();
    timerInitBt?.cancel();
    timerInitScan?.cancel();
    _updateBeaconsTimer?.cancel();
  }

  Future<bool> checkPermissions() async {
    try {
      if (Platform.isIOS) {
        final status = await _beaconScanner.authorizationStatus;
        return status == beacon_scanner.AuthorizationStatus.allowed;
      } else {
        final locationStatus = await Permission.locationWhenInUse.status;
        final locationAlwaysStatus = await Permission.locationAlways.status;
        final bluetoothStatus = await Permission.bluetooth.status;
        final bluetoothScanStatus = await Permission.bluetoothScan.status;

        return locationStatus.isGranted &&
            locationAlwaysStatus.isGranted &&
            bluetoothStatus.isGranted &&
            bluetoothScanStatus.isGranted;
      }
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _beaconScanner.requestAuthorization();
    } else {
      // Primero solicitar permisos básicos
      await Permission.locationWhenInUse.request();

      // Si se concedió el permiso básico, solicitar permiso en segundo plano
      if (await Permission.locationWhenInUse.isGranted) {
        // En Android 10 (API 29) y superior, necesitamos solicitar el permiso de ubicación en segundo plano por separado
        if (await Permission.locationAlways.request().isGranted) {
          print('Permiso de ubicación en segundo plano concedido');
        } else {
          print('Permiso de ubicación en segundo plano denegado');
        }
      }

      // Solicitar permisos de Bluetooth
      if (await Permission.bluetooth.request().isGranted) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
      }

      // Verificar todos los permisos
      final hasLocationWhenInUse = await Permission.locationWhenInUse.isGranted;
      final hasLocationAlways = await Permission.locationAlways.isGranted;
      final hasBluetoothScan = await Permission.bluetoothScan.isGranted;
      final hasBluetoothConnect = await Permission.bluetoothConnect.isGranted;

      if (!hasLocationWhenInUse || !hasBluetoothScan || !hasBluetoothConnect) {
        throw Exception(
          'Se requieren permisos de ubicación y Bluetooth para escanear beacons',
        );
      }

      // Informar al usuario sobre el estado de la ubicación en segundo plano
      if (!hasLocationAlways) {
        print('Advertencia: La ubicación en segundo plano no está habilitada. ' +
            'Algunas funciones pueden no estar disponibles cuando la app esté en segundo plano.');
      }
    }
  }

  Future<void> updateBeaconsFromApi() async {
    try {
      print('📥 Actualizando beacons desde API...');
      final currentLanguage = 'es';
      final beacons = await _apiService.loadData('beacon', currentLanguage);

      // Limpiar lista actual y UUIDs
      vBeaconsInfo.beaconList.clear();
      vBeaconsInfo.clearUuids();
      DateTime nullDateTime = DateTime.parse('1970-01-01 00:00:00Z');

      if (beacons is List && beacons.isNotEmpty) {
        for (var beaconJson in beacons) {
          final beacon = BeaconData.fromJson(beaconJson);

          // Guardar UUID si existe
          vBeaconsInfo.addUuid(beacon.uuid);

          if (beacon.major != null && beacon.minor != null) {
            print('''
📍 Registrando beacon desde API:
   Major: ${beacon.major}
   Minor: ${beacon.minor}
   UUID: ${beacon.uuid}
   Título: ${beacon.titleMessage ?? 'Sin título'}''');

            vBeaconsInfo.beaconList.add(
              VibracomBeaconInfo(
                VibracomBeacon(beacon.major!, beacon.minor!, nullDateTime),
                beacon.titleMessage ?? '',
                beacon.textMessage ?? '',
                beacon.imageMessageUrl ?? '',
                beacon.resourceUrl ?? beacon.multimediaUrl ?? '',
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error actualizando beacons: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
