import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../widgets/common.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final restore = ref.read(authProvider.notifier).restore();
    // Минимальная задержка, чтобы логотип успел красиво появиться
    await Future.wait([restore, Future.delayed(const Duration(milliseconds: 1400))]);
    if (!mounted) return;
    context.go(ref.read(authProvider).isAuthed ? '/home' : '/auth');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LogoMark(size: 96)
                .animate()
                .scale(duration: 700.ms, curve: Curves.easeOutBack, begin: const Offset(.6, .6))
                .then()
                .shimmer(duration: 1200.ms, color: Colors.white54),
            const SizedBox(height: 28),
            Text('WayPoint AI', style: Theme.of(context).textTheme.headlineMedium)
                .animate()
                .fadeIn(delay: 250.ms, duration: 600.ms)
                .slideY(begin: .3, curve: Curves.easeOutCubic),
            const SizedBox(height: 8),
            Text(
              'Путешествия, спланированные ИИ',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ).animate().fadeIn(delay: 450.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
