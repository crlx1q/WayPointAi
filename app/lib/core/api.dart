import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class SseEvent {
  final String event;
  final Map<String, dynamic> data;
  SseEvent(this.event, this.data);
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// HTTP-клиент WayPoint API: JSON-запросы + SSE-стримы для чата с агентом.
class ApiClient {
  ApiClient(this._prefs);

  final SharedPreferences _prefs;
  String? get token => _prefs.getString('auth_token');

  Future<void> setToken(String? value) async {
    if (value == null) {
      await _prefs.remove('auth_token');
    } else {
      await _prefs.setString('auth_token', value);
    }
  }

  Dio get _dio => Dio(BaseOptions(
        baseUrl: '${ApiConfig.base}/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        validateStatus: (_) => true,
      ));

  Future<Map<String, dynamic>> _handle(Future<Response> future) async {
    try {
      final res = await future;
      final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
      if ((res.statusCode ?? 500) >= 400) {
        throw ApiException(data['error']?.toString() ?? 'Ошибка ${res.statusCode}');
      }
      return data;
    } on DioException catch (e) {
      throw ApiException(e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
          ? 'Нет соединения с сервером'
          : (e.message ?? 'Ошибка сети'));
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _handle(_dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) => _handle(_dio.post(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) => _handle(_dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(String path) => _handle(_dio.delete(path));

  /// POST с ответом в виде SSE-потока (чат с агентом, генерация поездки).
  Stream<SseEvent> postSse(String path, {Object? body}) async* {
    final res = await _dio.post<ResponseBody>(
      path,
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    if ((res.statusCode ?? 500) >= 400) {
      throw ApiException('Ошибка ${res.statusCode}');
    }

    var buffer = '';
    await for (final chunk in res.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
      buffer += chunk;
      int idx;
      while ((idx = buffer.indexOf('\n\n')) != -1) {
        final raw = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);
        final eventMatch = RegExp(r'^event: (.+)$', multiLine: true).firstMatch(raw);
        final dataMatch = RegExp(r'^data: (.+)$', multiLine: true).firstMatch(raw);
        if (eventMatch != null) {
          Map<String, dynamic> data = {};
          if (dataMatch != null) {
            try {
              data = jsonDecode(dataMatch.group(1)!) as Map<String, dynamic>;
            } catch (_) {}
          }
          yield SseEvent(eventMatch.group(1)!, data);
        }
      }
    }
  }
}
