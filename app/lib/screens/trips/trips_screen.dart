import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(tripsProvider),
          child: trips.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [Center(child: Text('$e'))],
            ),
            data: (list) => list.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.luggage_rounded, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: .4)),
                      const SizedBox(height: 16),
                      Center(child: Text('Пока нет поездок', style: text.titleLarge)),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Попросите ИИ спланировать первую —\nэто занимает меньше минуты',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/chat'),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Спланировать поездку'),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    children: [
                      Text('My Trips', style: text.headlineMedium),
                      const SizedBox(height: 6),
                      Text('${list.length} ${_plural(list.length)}',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      ...list.indexed.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _TripCard(
                            trip: e.$2,
                            onDelete: () async {
                              await ref.read(apiProvider).delete('/trips/${e.$2.id}');
                              ref.invalidate(tripsProvider);
                            },
                          ).animate().fadeIn(delay: (70 * e.$1).ms, duration: 400.ms).slideY(begin: .06),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'поездка';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'поездки';
    return 'поездок';
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final Future<void> Function() onDelete;
  const _TripCard({required this.trip, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WpCard(
      padding: EdgeInsets.zero,
      radius: 28,
      onTap: () => context.push('/trip/${trip.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              NetPhoto(trip.coverPhoto,
                  height: 150,
                  width: double.infinity,
                  radius: const BorderRadius.vertical(top: Radius.circular(28))),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: const Text('Удалить поездку?'),
                          content: Text('«${trip.title}» будет перемещена в архив.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                          ],
                        ),
                      );
                      if (ok == true) await onDelete();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${trip.startDate} — ${trip.endDate}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -.2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, size: 15, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(trip.destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${trip.days.length} дн.',
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
