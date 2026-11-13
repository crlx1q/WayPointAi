import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Color _hexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = auth.user;
    final brightness = Theme.of(context).brightness;
    final isDark = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && brightness == Brightness.dark);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text('Profile', style: text.headlineMedium),
            const SizedBox(height: 20),

            // ── Карточка пользователя ──
            WpCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _hexColor(user.avatarColor),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          user.isGuest ? 'Гостевой аккаунт' : (user.email ?? ''),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editName(context, ref, user.name),
                    icon: const Icon(Icons.edit_rounded, size: 20),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: .05),
            const SizedBox(height: 16),

            if (user.isGuest)
              WpCard(
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Создайте аккаунт, чтобы не потерять поездки при смене устройства',
                        style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
            if (user.isGuest) const SizedBox(height: 16),

            // ── Настройки ──
            Text('Настройки', style: text.titleLarge),
            const SizedBox(height: 12),
            WpCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: isDark,
                    onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(brightness),
                    secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: scheme.primary),
                    title: const Text('Тёмная тема', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(isDark ? 'Включена' : 'Выключена',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  Divider(height: 1, indent: 20, endIndent: 20,
                      color: scheme.outlineVariant.withValues(alpha: .4)),
                  ListTile(
                    leading: Icon(Icons.notifications_none_rounded, color: scheme.primary),
                    title: const Text('Уведомления', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    onTap: () => context.push('/notifications'),
                  ),
                  Divider(height: 1, indent: 20, endIndent: 20,
                      color: scheme.outlineVariant.withValues(alpha: .4)),
                  ListTile(
                    leading: Icon(Icons.dns_rounded, color: scheme.primary),
                    title: const Text('Сервер', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(ApiConfig.base,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                    trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    onTap: () => _editServer(context, ref),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: .05),
            const SizedBox(height: 24),

            // ── О приложении ──
            WpCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const ListTile(
                    leading: LogoMark(size: 36),
                    title: Text('WayPoint AI', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Версия 1.0.0'),
                  ),
                  Divider(height: 1, indent: 20, endIndent: 20,
                      color: scheme.outlineVariant.withValues(alpha: .4)),
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: scheme.error),
                    title: Text('Выйти',
                        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error)),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: const Text('Выйти из аккаунта?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
                          ],
                        ),
                      );
                      if (ok == true) await ref.read(authProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: .05),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ваше имя'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(authProvider.notifier).updateName(name);
    }
  }

  Future<void> _editServer(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: ApiConfig.base);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Адрес сервера'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'http://192.168.0.10:8080'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Сохранить')),
        ],
      ),
    );
    if (url != null) {
      await ApiConfig.setBase(url);
      if (context.mounted) showSnack(context, 'Сервер: ${ApiConfig.base}. Перезайдите в аккаунт.');
    }
  }
}
