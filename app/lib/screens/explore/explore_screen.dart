import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../widgets/common.dart';

/// Каталог направлений: подборки с реальными фото с сервера.
final _exploreProvider = FutureProvider.autoDispose<List<_Destination>>((ref) async {
  const seeds = [
    ('Боровое, Казахстан', 'Горы, озёра и сосны — «Казахстанская Швейцария»', 'природа'),
    ('Алматы, Казахстан', 'Горы Заилийского Алатау и лучший кофе страны', 'город'),
    ('Стамбул, Турция', 'Босфор, базары и восточные сладости', 'история'),
    ('Париж, Франция', 'Лувр, круассаны и вечерняя Сена', 'искусство'),
    ('Бали, Индонезия', 'Океан, рисовые террасы и закаты', 'пляж'),
    ('Токио, Япония', 'Неон, суши и тишина храмов', 'город'),
    ('Дубай, ОАЭ', 'Небоскрёбы, пустыня и шопинг', 'люкс'),
    ('Рим, Италия', 'Колизей, паста и фонтаны', 'история'),
  ];
  final api = ref.read(apiProvider);
  return Future.wait(seeds.map((s) async {
    String? photo;
    try {
      final data = await api.get('/data/photos', query: {'q': s.$1, 'limit': 1});
      final photos = data['photos'] as List;
      if (photos.isNotEmpty) photo = photos.first['url'] as String;
    } catch (_) {}
    return _Destination(s.$1, s.$2, s.$3, photo);
  }));
});

class _Destination {
  final String name;
  final String description;
  final String tag;
  final String? photo;
  _Destination(this.name, this.description, this.tag, this.photo);
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String filter = 'все';
  static const tags = ['все', 'природа', 'город', 'история', 'пляж', 'искусство', 'люкс'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = ref.watch(_exploreProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('Explore', style: text.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Куда отправиться дальше?', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = filter == tags[i];
                  return ChoiceChip(
                    label: Text(tags[i]),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: scheme.primary,
                    labelStyle: TextStyle(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => filter = tags[i]),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  final filtered =
                      filter == 'все' ? list : list.where((d) => d.tag == filter).toList();
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .78,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final d = filtered[i];
                      return _DestCard(dest: d)
                          .animate()
                          .fadeIn(delay: (60 * i).ms, duration: 400.ms)
                          .scale(begin: const Offset(.95, .95), curve: Curves.easeOutCubic);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestCard extends StatelessWidget {
  final _Destination dest;
  const _DestCard({required this.dest});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/chat?q=${Uri.encodeComponent('Хочу поехать: ${dest.name}')}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetPhoto(dest.photo, radius: BorderRadius.zero),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45, Colors.black87],
                  stops: [.4, .72, 1],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dest.name.split(',').first,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -.2)),
                  const SizedBox(height: 4),
                  Text(dest.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)),
                ],
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(dest.tag,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
