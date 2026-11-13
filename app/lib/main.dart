import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'core/providers.dart' as p;
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  p.prefs = await SharedPreferences.getInstance();
  ApiConfig.init(p.prefs);
  await initializeDateFormatting('ru');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ProviderScope(child: WayPointApp()));
}

class WayPointApp extends ConsumerWidget {
  const WayPointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(p.themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'WayPoint AI',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
