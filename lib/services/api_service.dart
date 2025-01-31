import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valdeiglesias/models/beacon_data.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const _updateInterval = Duration(seconds: 5);

  Timer? _timer;
  String _currentLanguage = 'es';

  final _languageController = StreamController<String>.broadcast();
  Stream<String> get languageStream => _languageController.stream;

  final Map<String, Map<String, String>> _apiUrls = {
    'beacon': {
      'es': 'https://drupal.elcorazonverdedemadrid.com/beacon_es',
      'en': 'https://drupal.elcorazonverdedemadrid.com/beacon_en',
    },
  };

  void startService() {
    _timer = Timer.periodic(_updateInterval, (_) => _fetchData());
  }

  void stopService() {
    _timer?.cancel();
  }

  Future<void> _fetchData() async {
    for (var apiName in _apiUrls.keys) {
      for (var language in _apiUrls[apiName]!.keys) {
        final url = _apiUrls[apiName]![language];
        try {
          final response = await http.get(Uri.parse(url!));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            await _saveData(apiName, language, data);
            //print('Data fetched and saved successfully for $apiName in $language');
          } else {
            print(
                'Failed to fetch data for $apiName in $language. Status code: ${response.statusCode}');
          }
        } catch (e) {
          print('Error fetching data for $apiName in $language: $e');
        }
      }
    }
  }

  Future<void> _saveData(
      String apiName, String language, List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${apiName}_$language', json.encode(data));
  }

  Future<List<dynamic>> loadCachedData(String apiName, String language) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${apiName}_$language';

    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      return json.decode(cachedData);
    }
    return [];
  }

  Future<List<dynamic>> loadFreshData(String apiName, String language) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${apiName}_$language';

    try {
      final url = _apiUrls[apiName]?[language];
      if (url == null) {
        return [];
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: 10)); // Añadimos timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Guardar en caché
        await prefs.setString(cacheKey, json.encode(data));
        return data;
      } else {
        // Si hay error en la respuesta, intentamos devolver datos en caché
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          return json.decode(cachedData);
        }
        return [];
      }
    } catch (e) {
      print('Error in loadFreshData: $e');
      // Si hay error de conexión, intentamos devolver datos en caché
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        return json.decode(cachedData);
      }
      return [];
    }
  }

  Future<List<dynamic>> loadData(String apiName, String language) async {
    try {
      // Primero intentamos obtener los datos de la caché
      final cachedData = await loadCachedData(apiName, language);
      if (cachedData.isNotEmpty) {
        return cachedData;
      }

      // Solo si no hay datos en caché, intentamos cargar datos frescos
      try {
        final freshData = await loadFreshData(apiName, language);
        return freshData;
      } catch (e) {
        print('Error loading fresh data: $e');
        // Si falla la carga de datos frescos, devolvemos los datos en caché
        // aunque estén vacíos
        return cachedData;
      }
    } catch (e) {
      print('Error in loadData: $e');
      return [];
    }
  }

  Future<List<BeaconData>> loadBeacons(String language) async {
    try {
      print('🔄 Cargando beacons para idioma: $language');
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'beacons_$language';

      // Intentar obtener datos de la caché primero
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        print('📦 Usando beacons en caché');
        final List<dynamic> decodedData = json.decode(cachedData);
        return decodedData.map((json) => BeaconData.fromJson(json)).toList();
      }

      // Si no hay caché, cargar desde la API
      print('🌐 Cargando beacons desde API');
      final url = _apiUrls['beacon']?[language];
      if (url == null) {
        print('❌ URL no encontrada para beacons');
        return [];
      }

      final response =
          await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Guardar en caché
        await prefs.setString(cacheKey, response.body);
        print('✅ Beacons guardados en caché: ${data.length}');
        return data.map((json) => BeaconData.fromJson(json)).toList();
      } else {
        print('❌ Error al cargar beacons: ${response.statusCode}');
        // Si hay error, intentar usar caché antigua
        final oldCachedData = prefs.getString(cacheKey);
        if (oldCachedData != null) {
          print('📦 Usando caché antigua de beacons');
          final List<dynamic> decodedData = json.decode(oldCachedData);
          return decodedData.map((json) => BeaconData.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('❌ Error cargando beacons: $e');
      // En caso de error, intentar usar caché
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('beacons_$language');
      if (cachedData != null) {
        print('📦 Usando caché de emergencia para beacons');
        final List<dynamic> decodedData = json.decode(cachedData);
        return decodedData.map((json) => BeaconData.fromJson(json)).toList();
      }
    }
    return [];
  }
}
