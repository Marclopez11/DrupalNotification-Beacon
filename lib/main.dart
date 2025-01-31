import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'device_info_service.dart';
import 'services/token_management_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beacon/beacon_service.dart';
import 'beacon/notifi_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

Future<void> initializeNotifications() async {
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    print('Estado actual de notificaciones: ${settings.authorizationStatus}');

    // Siempre solicitar permisos si no están autorizados
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('Solicitando permisos de notificaciones...');
      NotificationSettings newSettings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print(
          'Nuevo estado de notificaciones: ${newSettings.authorizationStatus}');

      if (newSettings.authorizationStatus == AuthorizationStatus.authorized) {
        //await _setupNotifications();
      }
    } else {
      print('Notificaciones ya autorizadas, configurando...');
    }
  } catch (e) {
    print('Error initializing notifications: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  var status = await Permission.bluetooth.request();
  print("status 1 $status");

  status = await Permission.bluetoothConnect.request();
  print("status 2 $status");

  status = await Permission.bluetoothScan.request();
  print("status 3 $status");

  // Inicializar servicios de notificación una sola vez
  await NotifiService.init();

  // Configurar el listener de notificaciones aquí
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    LocalNotificationsService().showFlutterNotification(message);
  });

  await LocalNotificationsService().pushNotificationListener();

  // INITIALIZE LOCAL NOTIFICATION
  LocalNotificationsService().initializeNotifications();

  // SAVING USER INFORMATION
  await SaveDeviceInfoService.saveDeviceInfo();

  // Inicializar servicios
  final beaconService = BeaconService();
  final apiService = ApiService();

  // Inicializar el servicio de API
  apiService.startService();

  // Inicializar el servicio de beacons
  await beaconService.initialize();

  // Suscribirse a cambios de idioma para actualizar los beacons
  apiService.languageStream.listen((String language) async {
    await beaconService.updateBeaconsFromApi();
  });

  _createOrUpdateToken('es');
  runApp(const MyApp());
}

Future<void> _createOrUpdateToken(String language) async {
  final tokenService = TokenManagementService();
  await tokenService.createToken(language);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Base Project Template',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E88E5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildSignature(context),
                const SizedBox(height: 32),
                Text(
                  'Proyecto Base',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildFeatureCard(
                  context,
                  title: 'Notificaciones Firebase',
                  description:
                      'Configuración completa de Firebase Cloud Messaging para recibir notificaciones push.',
                  icon: Icons.notifications_active,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  context,
                  title: 'Sistema de Beacons',
                  description:
                      'Integración de beacons con emisión de notificaciones cada 20 segundos.',
                  icon: Icons.bluetooth_searching,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  context,
                  title: 'Gestión de Permisos',
                  description:
                      'Manejo automático de permisos necesarios para bluetooth y notificaciones.',
                  icon: Icons.security,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Cómo empezar?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Configura tus credenciales de Firebase\n'
                        '2. Personaliza la lógica de beacons según tus necesidades\n'
                        '3. Integra tus propias pantallas y navegación\n'
                        '4. Modifica los servicios según tu caso de uso',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignature(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              'https://media.licdn.com/dms/image/v2/D5603AQErH8yzI2rZZg/profile-displayphoto-shrink_400_400/profile-displayphoto-shrink_400_400/0/1697578217225?e=1743638400&v=beta&t=6R7zOsNDQTK3ZF7_wdjv69Yank6twAnQREYNoH8xWsE',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desarrollado por',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Marc López',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.link,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () async {
              const url = 'https://www.linkedin.com/in/marc-lopez-marco/';
              if (await canLaunch(url)) {
                await launch(url);
              }
            },
          ),
        ],
      ),
    );
  }
}
