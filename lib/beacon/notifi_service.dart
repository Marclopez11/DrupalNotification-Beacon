import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class NotifiService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'beacon_notifications',
    'Beacon Notifications',
    description: 'Notifications for nearby beacons',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    showBadge: true,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
  );

  static Future<void> init() async {
    print('NotifiService: Iniciando configuración de notificaciones');

    // Inicialización para Android
    var androidInitialize =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    // Inicialización para iOS con configuración específica
    var iosInitialize = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'beacon_category',
          actions: [
            DarwinNotificationAction.plain('id_1', 'Abrir'),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            DarwinNotificationCategoryOption.allowAnnouncement,
          },
        )
      ],
    );

    var initializeSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iosInitialize,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializeSettings,
      onDidReceiveNotificationResponse: openNotification,
      onDidReceiveBackgroundNotificationResponse: openNotification,
    );

    // Solicitar permisos específicamente para iOS
    if (Platform.isIOS) {
      print('NotifiService: Solicitando permisos específicos para iOS');
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
            provisional: true,
          );
    }

    await verifyNotificationChannel();
  }

  @pragma('vm:entry-point')
  static Future<void> openNotification(
      NotificationResponse notificationResponse) async {
    print(
        'NotifiService: Notificación tocada - Payload: ${notificationResponse.payload}');
    if (notificationResponse.payload != null) {
      // Aquí puedes manejar la notificación de manera diferente si la app está en primer plano
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Notificación'),
              content: Text('Payload: ${notificationResponse.payload}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cerrar'),
                ),
              ],
            ),
          );
        } else {
          // Si no hay contexto disponible, abrir URL
          final Uri url = Uri.parse(notificationResponse.payload!);
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else {
        // Abrir URL si la app está en segundo plano
        final Uri url = Uri.parse(notificationResponse.payload!);
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  static Future<void> showBeaconNotification(
      String? icon, String title, String text, String link) async {
    try {
      print('NotifiService: Mostrando notificación con imagen: $icon');

      bool isImgNotification = false;
      String largeIconPath = '';
      String bigPicturePath = '';
      BigPictureStyleInformation? bigPictureStyleInformation;

      // Procesar imagen si existe
      if (icon != null && icon.isNotEmpty) {
        isImgNotification = true;
        final img = await loadImageAndConvertToBase64(icon);

        bigPictureStyleInformation = BigPictureStyleInformation(
          ByteArrayAndroidBitmap.fromBase64String(base64Encode(img)),
          hideExpandedLargeIcon: true,
          largeIcon: ByteArrayAndroidBitmap.fromBase64String(base64Encode(img)),
        );

        largeIconPath = await _downloadAndSaveFile(
          icon,
          'beacon_large_icon',
          Platform.isIOS,
        );
        bigPicturePath = await _downloadAndSaveFile(
          icon,
          'beacon_big_picture',
          Platform.isIOS,
        );
      }

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'notification_icon',
          largeIcon:
              isImgNotification ? FilePathAndroidBitmap(largeIconPath) : null,
          styleInformation:
              isImgNotification ? bigPictureStyleInformation : null,
        ),
        iOS: isImgNotification
            ? DarwinNotificationDetails(
                attachments: [DarwinNotificationAttachment(bigPicturePath)])
            : const DarwinNotificationDetails(),
      );

      int notificationId = generateRandomNotificationId();
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title.isNotEmpty ? title : ' ',
        text.isNotEmpty ? text : ' ',
        notificationDetails,
        payload: link,
      );
    } catch (e) {
      print('Error mostrando notificación: $e');
    }
  }

  static Future<String> _downloadAndSaveFile(
      String url, String fileName, bool isIOS) async {
    final Directory? directory = isIOS
        ? await getApplicationDocumentsDirectory()
        : await getExternalStorageDirectory();
    final String filePath = '${directory!.path}/$fileName.png';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  // Métodos auxiliares para manejo de imágenes
  static Future<List<int>> loadImageAndConvertToBase64(String imageUrl) async {
    http.Response response = await http.get(Uri.parse(imageUrl));
    return response.bodyBytes;
  }

  static int generateRandomNotificationId() {
    return Random().nextInt(999999);
  }

  static Future<void> verifyNotificationChannel() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final channels = await androidPlugin.getNotificationChannels();
        final hasChannel =
            channels?.any((c) => c.id == 'beacon_notifications') ?? false;

        if (!hasChannel) {
          await androidPlugin.createNotificationChannel(channel);
        }
      }
    }
  }
}
