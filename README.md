# Test Notificaciones y Beacons

## 🎯 Descripción
Este es un proyecto base de Flutter que implementa un sistema completo de notificaciones push (Firebase) y beacons. Está diseñado para ser usado como punto de partida en proyectos que requieran estas funcionalidades, permitiendo una fácil integración y personalización.

## ⭐ Características Principales
- **Sistema de Beacons**
  - Escaneo automático de beacons cercanos
  - Notificaciones cada 20 segundos al detectar beacons
  - Gestión inteligente para evitar notificaciones duplicadas
  - Soporte para múltiples beacons simultáneos

- **Notificaciones Push**
  - Integración completa con Firebase Cloud Messaging
  - Soporte para notificaciones en primer y segundo plano
  - Gestión de tokens FCM
  - Notificaciones locales para beacons

- **Gestión de Permisos**
  - Bluetooth (escaneo y conexión)
  - Ubicación (necesaria para beacons)
  - Notificaciones push
  - Manejo automático de solicitudes de permisos

## 🚀 Inicio Rápido

### Prerrequisitos
- Flutter SDK ≥ 3.0.0
- Xcode (para iOS)
- Android Studio (para Android)
- Cuenta de Firebase

### Instalación
1. Clona el repositorio:

```bash
git clone https://github.com/tu-usuario/tu-proyecto.git
cd tu-proyecto
```

2. Instala las dependencias:

```bash
flutter pub get
```

3. Configura Firebase:

- Crea un proyecto en Firebase
- Agrega el archivo `google-services.json` a la raíz del proyecto
- Agrega el archivo `GoogleService-Info.plist` a la raíz del proyecto

4. Ejecuta el proyecto:

```bash
flutter run
```

## 📦 Estructura del Proyecto

lib/
├── beacon/
│ ├── beacon_service.dart # Servicio principal de beacons
│ ├── beacons.dart # Modelos y lógica de beacons
│ └── notifi_service.dart # Servicio de notificaciones locales
├── services/
│ ├── api_service.dart # Servicios de API
│ └── notification_service.dart # Servicio de notificaciones push
├── models/
│ └── beacon_data.dart # Modelos de datos
└── main.dart # Punto de entrada de la aplicación



## 🛠 Configuración

### Firebase
1. Crea un proyecto en Firebase Console
2. Añade las aplicaciones iOS y Android
3. Descarga y añade los archivos de configuración
4. Actualiza los IDs de proyecto en la configuración

### Beacons

1. Crea un proyecto 
2. Configura los beacons en el proyecto
3. Obtén los UUIDs y IDs de los beacons


## 📱 Uso
El proyecto está diseñado para ser usado como base. Principales puntos de personalización:

1. **Beacons**
   - Modifica `beacon_service.dart` para personalizar la lógica de detección
   - Ajusta los intervalos de escaneo en `beacons.dart`
   - Personaliza el formato de las notificaciones

2. **Notificaciones**
   - Configura los canales de notificación
   - Personaliza el manejo de notificaciones push
   - Ajusta el comportamiento en segundo plano

## 📦 Dependencias Principales

```yaml
dependencies:
firebase_messaging: ^14.7.4
firebase_core: ^2.22.0
flutter_beacon: ^0.5.1
flutter_local_notifications: ^17.2.1
permission_handler: ^11.0.1
```

## 🤝 Contribución
1. Fork el proyecto
2. Crea tu rama de feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 👨‍💻 Autor
**Marc López**
- LinkedIn: [Marc López](https://www.linkedin.com/in/marc-lopez-marco/)
- GitHub: [@marclopez-cinnia](https://github.com/marclopez-cinnia)

## 📄 Licencia
Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE.md](LICENSE.md) para más detalles.

## 🆘 Soporte
Para soporte y consultas:
- Crear un issue en el repositorio
- Contactar directamente con el autor vía LinkedIn

---
Desarrollado con ❤️ por [Marc López](https://www.linkedin.com/in/marc-lopez-marco/)

