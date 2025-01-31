class BeaconData {
  final String deviceId;
  final String action;
  final String? titleMessage;
  final String? textMessage;
  final String? multimediaUrl;
  final String? resourceUrl;
  final String? imageMessageUrl;
  final double? latitude;
  final double? longitude;
  final int? major;
  final int? minor;
  final String? uuid;

  BeaconData({
    required this.deviceId,
    required this.action,
    this.titleMessage,
    this.textMessage,
    this.multimediaUrl,
    this.resourceUrl,
    this.imageMessageUrl,
    this.latitude,
    this.longitude,
    this.major,
    this.minor,
    this.uuid,
  });

  factory BeaconData.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para extraer valor
    T? extractValue<T>(String fieldName) {
      final field = json[fieldName];
      if (field == null || !(field is List) || field.isEmpty) {
        return null;
      }
      final value = field[0]['value'];
      if (value == null) return null;

      // Manejar diferentes tipos
      if (T == String) {
        return value.toString() as T;
      } else if (T == int) {
        return (int.tryParse(value.toString()) ?? 0) as T;
      } else if (T == double) {
        return (double.tryParse(value.toString()) ?? 0.0) as T;
      }
      return value as T?;
    }

    // Obtener el ID del dispositivo y acción
    final deviceId = extractValue<String>('field_beacon_id_dispositiu') ?? '';
    final action = extractValue<String>('field_beacon_action') ?? '';

    // Obtener mensajes
    final titleMessage = extractValue<String>('field_beacon_title_message');
    final textMessage = extractValue<String>('field_beacon_text_message');

    // Obtener URLs
    String? multimediaUrl;
    if (json['field_beacon_multimedia']?.isNotEmpty == true) {
      multimediaUrl = json['field_beacon_multimedia'][0]['url'];
    }

    String? imageMessageUrl;
    if (json['field_beacon_image_message']?.isNotEmpty == true) {
      imageMessageUrl = json['field_beacon_image_message'][0]['url'];
    }

    String? resourceUrl = extractValue<String>('field_beacon_url');

    // Obtener ubicación
    double? latitude;
    double? longitude;
    if (json['field_beacon_location']?.isNotEmpty == true) {
      latitude =
          double.tryParse(json['field_beacon_location'][0]['lat'].toString());
      longitude =
          double.tryParse(json['field_beacon_location'][0]['lng'].toString());
    }

    // Obtener major y minor con valores naturales
    final major = extractValue<int>('field_beacon_major');
    final minor = extractValue<int>('field_beacon_minor');

    // Obtener UUID
    final uuid = extractValue<String>('field_beacon_uuid');

    return BeaconData(
      deviceId: deviceId,
      action: action,
      titleMessage: titleMessage,
      textMessage: textMessage,
      multimediaUrl: multimediaUrl,
      resourceUrl: resourceUrl,
      imageMessageUrl: imageMessageUrl,
      latitude: latitude,
      longitude: longitude,
      major: major,
      minor: minor,
      uuid: uuid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'action': action,
      'titleMessage': titleMessage,
      'textMessage': textMessage,
      'multimediaUrl': multimediaUrl,
      'resourceUrl': resourceUrl,
      'imageMessageUrl': imageMessageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'major': major,
      'minor': minor,
      'uuid': uuid,
    };
  }
}
