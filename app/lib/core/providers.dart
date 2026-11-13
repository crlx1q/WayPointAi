import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api.dart';

/// Инициализируется в main() до runApp.
late final SharedPreferences prefs;

final apiProvider = Provider<ApiClient>((ref) => ApiClient(prefs));

/// ── Тема (светлая / тёмная) ──
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = prefs.getString('theme_mode');
    return switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  void toggle(Brightness current) {
    final next = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    prefs.setString('theme_mode', next == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// ── Аутентификация ──
class AuthState {
  final WpUser? user;
  final bool loading;
  const AuthState({this.user, this.loading = false});
  bool get isAuthed => user != null;
}

class AuthNotifier extends Notifier<AuthState> {
  ApiClient get _api => ref.read(apiProvider);

  @override
  AuthState build() => const AuthState();

  /// Тихий вход по сохранённому токену при запуске.
  Future<void> restore() async {
    if (_api.token == null) return;
    state = const AuthState(loading: true);
    try {
      final data = await _api.get('/auth/me');
      state = AuthState(user: WpUser.fromJson(data['user'] as Map<String, dynamic>));
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<void> _applyAuth(Map<String, dynamic> data) async {
    await _api.setToken(data['token'] as String);
    state = AuthState(user: WpUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post('/auth/login', body: {'email': email, 'password': password});
    await _applyAuth(data);
  }

  Future<void> register(String email, String password, String name) async {
    final data = await _api.post('/auth/register', body: {'email': email, 'password': password, 'name': name});
    await _applyAuth(data);
  }

  Future<void> guest() async {
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = 'dev-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
      await prefs.setString('device_id', deviceId);
    }
    final data = await _api.post('/auth/guest', body: {'deviceId': deviceId});
    await _applyAuth(data);
  }

  Future<void> updateName(String name) async {
    final data = await _api.patch('/auth/me', body: {'name': name});
    state = AuthState(user: WpUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    await _api.setToken(null);
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// ── Поездки ──
final tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  ref.watch(authProvider);
  final data = await ref.read(apiProvider).get('/trips');
  return (data['trips'] as List).map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
});

final tripProvider = FutureProvider.autoDispose.family<Trip, String>((ref, id) async {
  final data = await ref.read(apiProvider).get('/trips/$id');
  return Trip.fromJson(data['trip'] as Map<String, dynamic>);
});

/// ── Уведомления ──
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  ref.watch(authProvider);
  final data = await ref.read(apiProvider).get('/notifications');
  return (data['notifications'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
});

final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.read).length,
        orElse: () => 0,
      );
});

/// ── Погода для главного экрана (по последней поездке) ──
final homeWeatherProvider = FutureProvider.autoDispose.family<DayWeather?, (double, double)>((ref, coords) async {
  final data = await ref.read(apiProvider).get('/data/weather', query: {'lat': coords.$1, 'lon': coords.$2, 'days': 1});
  final current = data['current'] as Map<String, dynamic>?;
  if (current == null) return null;
  return DayWeather(
    tempMax: (current['temp'] as num?)?.toInt(),
    tempMin: null,
    description: (current['description'] ?? '') as String,
    icon: (current['icon'] ?? 'cloudy') as String,
  );
});
