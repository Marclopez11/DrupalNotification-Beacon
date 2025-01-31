import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:valdeiglesias/device_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManagementService {
  static const String baseUrl = 'https://drupal.elcorazonverdedemadrid.com';
  static const String username = 'apiuser';
  static const String password = '5@9aT8soN1Nfpx&aMGAJy!CY';

  // Obtener token de sesión del servidor
  Future<String> getSessionToken() async {
    print('Iniciando getSessionToken...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/session/token'),
        headers: {
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'grant_type': 'password',
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        print('Token de sesión obtenido con éxito');
        return response.body;
      }
      throw Exception('Error al obtener token de sesión');
    } catch (e) {
      print('Error obteniendo token de sesión: $e');
      rethrow;
    }
  }

  // Nuevo método para obtener el estado actual de las notificaciones
  Future<bool> getNotificationsEnabled() async {
    print('Iniciando getNotificationsEnabled...');
    final prefs = await SharedPreferences.getInstance();
    print(prefs.getBool('notifications_enabled'));
    return prefs.getBool('notifications_enabled') ?? false;
  }

  // Nuevo método para establecer el estado de las notificaciones
  Future<void> setNotificationsEnabled(bool enabled) async {
    print('Iniciando setNotificationsEnabled...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  // Verificar si existe el token del dispositivo
  Future<Map<String, dynamic>?> checkDeviceToken(String deviceId) async {
    print('Iniciando checkDeviceToken...');
    final String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/jsonapi/node/tokens?filter[field_deviceid]=$deviceId'),
        headers: {
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json',
          'Authorization': basicAuth,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          await setNotificationsEnabled(true);
          print('Token del dispositivo encontrado');
          return data['data'][0];
        }
        await setNotificationsEnabled(false);
        print('Token del dispositivo no encontrado');
        return null;
      }
      return null;
    } catch (e) {
      print('Error verificando token del dispositivo: $e');
      return null;
    }
  }

  // Crear nuevo token
  Future<bool> createToken(String language) async {
    print('Iniciando createToken...');
    try {
      final notificationsEnabled = await getNotificationsEnabled();
      if (!notificationsEnabled) {
        print('Notificaciones desactivadas en configuración');
        return false;
      }

      // Get device info
      String? deviceId = await SaveDeviceInfoService.getUserDeviceID();
      String? deviceName = await SaveDeviceInfoService.getUserDeviceName();
      String? fcmToken = await SaveDeviceInfoService.getFCMTokenApp();

      if (deviceId == null || fcmToken == null) {
        print('Error: Could not get device info or FCM token');
        await setNotificationsEnabled(false);
        return false;
      }

      // Get session token
      final sessionToken = await getSessionToken();

      print('Verificando si existe token del dispositivo...');
      final existingDevice = await checkDeviceToken(deviceId);
      print(
          'Resultado de verificación de dispositivo existente: $existingDevice');

      if (existingDevice != null) {
        print('Token de dispositivo encontrado, eliminando...');
        await deleteToken(sessionToken, existingDevice['id']);
        print('Token existente eliminado con éxito');
      }

      final String basicAuth =
          'Basic ' + base64Encode(utf8.encode('$username:$password'));

      final response = await http.post(
        Uri.parse('$baseUrl/jsonapi/node/tokens'),
        headers: {
          'Accept': 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json',
          'X-CSRF-Token': sessionToken,
          'Authorization': basicAuth,
        },
        body: json.encode({
          "data": {
            "type": "node--tokens",
            "attributes": {
              "title": deviceName ?? "Token Dispositivo",
              "field_deviceid": {"value": deviceId},
              "field_token": {"value": fcmToken},
              "field_langcode": {"value": language}
            }
          }
        }),
      );

      final success = response.statusCode == 201;
      await setNotificationsEnabled(success);
      if (success) {
        print('Token creado con éxito');
      } else {
        print('Error creando token: ${response.statusCode}');
        // Log the error response for debugging purposes
      }
      return success;
    } catch (e) {
      print('Error creando token: $e');
      // Log the error for debugging purposes
      await setNotificationsEnabled(false);
      return false;
    }
  }

  // Eliminar token
  Future<bool> deleteToken(
    String sessionToken, // Mantenemos el parámetro pero no lo usamos
    String tokenId,
  ) async {
    print('Iniciando deleteToken...');
    try {
      final result = await _deleteTokenFromServer(sessionToken, tokenId);
      if (result) {
        await setNotificationsEnabled(false);
        print('Token eliminado con éxito');
      }
      return result;
    } catch (e) {
      print('Error eliminando token: $e');
      return false;
    }
  }

  // Método privado para la eliminación real del token
  Future<bool> _deleteTokenFromServer(
      String sessionToken, String tokenId) async {
    print('Iniciando _deleteTokenFromServer...');
    final String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$username:$password'));

    final response = await http.delete(
      Uri.parse('$baseUrl/jsonapi/node/tokens/$tokenId'),
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
        'X-CSRF-Token': sessionToken,
        'Authorization': basicAuth,
      },
    );

    return response.statusCode == 204;
  }
}
