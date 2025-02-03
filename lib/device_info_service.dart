import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeviceInfo {
  final String deviceId;
  final String? deviceName;
  final String? language;

  DeviceInfo({
    required this.deviceId,
    this.deviceName,
    this.language,
  });
}

class SaveDeviceInfoService {
  //SAVE USER DEVICE INFO IN FIREBASE
  static Future<void> saveDeviceInfo() async {
    try {
      print('Iniciando saveDeviceInfo...');

      String? deviceID = await getUserDeviceID();
      log('device id: ${deviceID}');
      print('device id obtenido correctamente: ${deviceID}');

      String? deviceName = await getUserDeviceName();
      log('device name: ${deviceName}');
      print('device name obtenido correctamente: ${deviceName}');

      log('fcm token:');

      String? fcmToken = await getFCMTokenApp();
      log('fcm token: ${fcmToken}');
      print('fcm token obtenido correctamente: ${fcmToken}');

      if (fcmToken != null) {
        print('Verificando existencia del documento en Firestore...');
        final document = await FirebaseFirestore.instance
            .collection('UserDevices')
            .doc(fcmToken)
            .get();

        if (!document.exists) {
          print('Documento no existe, creando nuevo registro...');
          await FirebaseFirestore.instance
              .collection('UserDevices')
              .doc(fcmToken)
              .set({
            'DeviceName': deviceName,
            'DeviceID': deviceID,
            'FCMtoken': fcmToken,
            'LastUpdated': FieldValue.serverTimestamp(),
          });
          print(
              'Información del dispositivo guardada exitosamente en Firestore');
          log('Device info saved successfully');
        } else {
          print('El dispositivo ya existe en la base de datos DE FIREBASE');
          log('Device already exists in database');
        }
      } else {
        print('Error: FCM token es null');
        log('FCM token is null');
      }
    } catch (e) {
      print('Error en saveDeviceInfo: $e');
      log('Error saving device info: $e');
    }
  }

  //GET USER DEVICE ID
  static Future<String?> getUserDeviceID() async {
    //print('Obteniendo Device ID...');
    String? deviceID;
    var deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        //print('Dispositivo iOS detectado');
        var iosDeviceInfo = await deviceInfo.iosInfo;
        deviceID = iosDeviceInfo.identifierForVendor;
      } else if (Platform.isAndroid) {
        //print('Dispositivo Android detectado');
        var androidDeviceInfo = await deviceInfo.androidInfo;
        deviceID = androidDeviceInfo.id;
      }
      //print('Device ID obtenido exitosamente: $deviceID');
      return deviceID;
    } catch (e) {
      print('Error obteniendo Device ID: $e');
      return null;
    }
  }

  //GET USER DEVICE NAME
  static Future<String?> getUserDeviceName() async {
    print('Obteniendo Device Name...');
    String? deviceName;
    var deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        //print('Obteniendo nombre de dispositivo iOS');
        var iosDeviceInfo = await deviceInfo.iosInfo;
        deviceName = iosDeviceInfo.name;
      } else if (Platform.isAndroid) {
        //print('Obteniendo nombre de dispositivo Android');
        var androidDeviceInfo = await deviceInfo.androidInfo;
        deviceName = androidDeviceInfo.model;
      }
      //print('Device Name obtenido exitosamente: $deviceName');
      return deviceName;
    } catch (e) {
      print('Error obteniendo Device Name: $e');
      return null;
    }
  }

  //GET USER DEVICE FCM TOKEN
  static Future<String?> getFCMTokenApp() async {
    //print('Obteniendo FCM Token...');
    FirebaseMessaging fcm = FirebaseMessaging.instance;

    try {
      //log('fcm ${fcm}');
      //print('Instancia FCM inicializada');

      final apnsToken = await fcm.getAPNSToken();
      //log('apnsToken ${apnsToken}');
      //print('APNS Token obtenido: $apnsToken');

      String? token = await fcm.getToken();
      //log('token ${token}');
      //print('FCM Token obtenido exitosamente: $token');

      return token;
    } catch (e) {
      print('Error obteniendo FCM Token: $e');
      return null;
    }
  }

  static Future<DeviceInfo?> getDeviceInfo() async {
    print('Iniciando getDeviceInfo...');
    try {
      // Verificar estado de permisos de notificaciones
      final notificationSettings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final bool notificationsEnabled =
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.authorized;
      print('Notificaciones activadas: $notificationsEnabled');

      final fcmToken = await getFCMTokenApp();
      //print('FCM Token obtenido: $fcmToken');

      String? deviceId = await getUserDeviceID();
      //print('Device ID obtenido: $deviceId');

      String? deviceName = await getUserDeviceName();
      //print('Device Name obtenido: $deviceName');

      if (deviceId != null) {
        //print('Obteniendo preferencias compartidas...');
        final prefs = await SharedPreferences.getInstance();
        final language = prefs.getString('language') ?? 'es';
        //print('Idioma obtenido: $language');

        return DeviceInfo(
          deviceId: deviceId,
          deviceName: deviceName,
          language: language, // Agregar el estado de las notificaciones
        );
      }
      //print('Device ID es null, retornando null');
      return null;
    } catch (e) {
      print('Error en getDeviceInfo: $e');
      return null;
    }
  }
}
