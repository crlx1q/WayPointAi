import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// Экран уведомлений. Сейчас — REST-база; позже сюда встанет Firebase push
/// (fcmToken уже сохраняется на сервере через PATCH /auth/me).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(apiProvider).post('/notifications/read-all');
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Прочитать все'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(24), children: [Center(child: Text('$e'))]),
          data: (items) => items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 140),
                    Icon(Icons.notifications_off_rounded,
                        size: 60, color: scheme.onSurfaceVariant.withValues(alpha: .35)),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('Пока тихо',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('Здесь появятся новости и советы по поездкам',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    return _NotificationTile(
                      notification: n,
                      onTap: () async {
                        await ref.read(apiProvider).post('/notifications/${n.id}/read');
                        ref.invalidate(notificationsProvider);
                        final tripId = n.data['tripId'];
                        if (tripId != null && context.mounted) context.push('/trip/$tripId');
                      },
                    ).animate().fadeIn(delay: (50 * i).ms, duration: 350.ms).slideY(begin: .05);
                  },
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  (IconData, Color) get _style => switch (notification.kind) {
        'promo' => (Icons.local_offer_rounded, const Color(0xFFC64F00)),
        'trip' => (Icons.luggage_rounded, WpColors.primary),
        'ai' => (Icons.auto_awesome_rounded, WpColors.teal),
        _ => (Icons.campaign_rounded, const Color(0xFF64748B)),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _style;
    final unread = !notification.read;

    return Material(
      color: unread ? scheme.primary.withValues(alpha: .06) : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unread
                  ? scheme.primary.withValues(alpha: .25)
                  : scheme.outlineVariant.withValues(alpha: .4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(notification.title,
                              style: TextStyle(
                                  fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 14.5)),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notification.body,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('d MMM, HH:mm', 'ru').format(notification.createdAt.toLocal()),
                      style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .7), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
