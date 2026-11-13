import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Рекомендации ИИ на главной: направление + % совпадения + фото с сервера.
final _recsProvider = FutureProvider.autoDispose<List<(String, String, int, String?)>>((ref) async {
  const candidates = [
    ('Париж, Франция', 'Идеально подходит для вашего интереса к искусству', 98),
    ('Бали, Индонезия', 'Отличный выбор для расслабления у океана', 94),
    ('Алматы, Казахстан', 'Горы и город — баланс активности и уюта', 91),
    ('Стамбул, Турция', 'История, еда и восточный колорит', 88),
  ];
  final api = ref.read(apiProvider);
  return Future.wait(candidates.map((c) async {
    String? photo;
    try {
      final data = await api.get('/data/photos', query: {'q': c.$1, 'limit': 1});
      final photos = data['photos'] as List;
      if (photos.isNotEmpty) photo = photos.first['url'] as String;
    } catch (_) {}
    return (c.$1, c.$2, c.$3, photo);
  }));
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final trips = ref.watch(tripsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tripsProvider);
            ref.invalidate(notificationsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              // ── Шапка ──
              Row(
                children: [
                  const LogoMark(size: 40),
                  const SizedBox(width: 12),
                  Text('WayPoint AI', style: text.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(Icons.notifications_none_rounded, size: 26),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),

              // ── Hero: Куда отправимся? ──
              _HeroCard(onSearch: (q) => context.push('/chat?q=${Uri.encodeComponent(q)}'))
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: .06, curve: Curves.easeOutCubic),
              const SizedBox(height: 28),

              // ── Недавние планы ──
              trips.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Недавние планы', style: text.headlineSmall),
                          const SizedBox(height: 14),
                          ...list.take(3).map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _RecentTripCard(trip: t),
                              )),
                          const SizedBox(height: 16),
                        ],
                      ).animate().fadeIn(duration: 500.ms, delay: 120.ms),
              ),

              // ── Рекомендации ИИ ──
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => wpGradient.createShader(b),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Text('Рекомендации ИИ', style: text.headlineSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Все'),
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: ref.watch(_recsProvider).when(
                      loading: () => ListView(
                        scrollDirection: Axis.horizontal,
                        children: List.generate(
                          2,
                          (_) => Container(
                            width: 220,
                            margin: const EdgeInsets.only(right: 14),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (recs) => ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final (title, subtitle, match, photo) = recs[i];
                          return _RecCard(
                            title: title,
                            subtitle: subtitle,
                            match: match,
                            photo: photo,
                            onTap: () => context.push(
                              '/chat?q=${Uri.encodeComponent('Хочу поехать: $title')}',
                            ),
                          ).animate().fadeIn(delay: (100 * i).ms, duration: 450.ms).slideX(begin: .08);
                        },
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Спросить ИИ'),
      ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

class _HeroCard extends StatefulWidget {
  final void Function(String query) onSearch;
  const _HeroCard({required this.onSearch});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _go() {
    if (ctrl.text.trim().isEmpty) return;
    widget.onSearch(ctrl.text.trim());
    ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: WpColors.primary.withValues(alpha: .25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Фоновое фото гор (Wikimedia, свободная лицензия)
            const NetPhoto(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Moraine_Lake_17092005.jpg/1200px-Moraine_Lake_17092005.jpg',
              radius: BorderRadius.zero,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  stops: [.35, .75, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Куда отправимся?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 16),
                      ],
                    ),
                    padding: const EdgeInsets.only(left: 18, right: 6, top: 6, bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.black45),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            onSubmitted: (_) => _go(),
                            style: const TextStyle(color: Colors.black87, fontSize: 15.5),
                            decoration: const InputDecoration(
                              hintText: 'Поиск направлений…',
                              hintStyle: TextStyle(color: Colors.black38),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _go,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              gradient: wpGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTripCard extends ConsumerWidget {
  final Trip trip;
  const _RecentTripCard({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    String range = '';
    if (trip.startDate.isNotEmpty) {
      final s = trip.startDate.split('-');
      final e = trip.endDate.split('-');
      const months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
      range = '${int.parse(s[2])} - ${int.parse(e[2])} ${months[int.parse(e[1]) - 1]}';
    }

    return WpCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/trip/${trip.id}'),
      child: Row(
        children: [
          NetPhoto(trip.coverPhoto, width: 64, height: 64, radius: BorderRadius.circular(16)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(range, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int match;
  final String? photo;
  final VoidCallback onTap;

  const _RecCard({
    required this.title,
    required this.subtitle,
    required this.match,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: WpCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                NetPhoto(photo, height: 130, width: 220,
                    radius: const BorderRadius.vertical(top: Radius.circular(24))),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text('$match% совпадение',
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 5),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
