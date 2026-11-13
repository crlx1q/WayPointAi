import 'package:shared_preferences/shared_preferences.dart';

/// Конфигурация API.
/// По умолчанию — продовый домен; для локальной разработки можно:
///  1) собрать с --dart-define=API_BASE=http://192.168.x.x:8080
///  2) поменять адрес сервера в Профиль → Сервер (сохраняется на устройстве)
class ApiConfig {
  static const String defaultBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://waypoint.crlx1q.com',
  );

  static String base = defaultBase;
  static SharedPreferences? _prefs;

  static void init(SharedPreferences prefs) {
    _prefs = prefs;
    base = prefs.getString('api_base') ?? defaultBase;
  }

  static Future<void> setBase(String url) async {
    base = url.trim().isEmpty ? defaultBase : url.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs?.setString('api_base', base);
  }
}
