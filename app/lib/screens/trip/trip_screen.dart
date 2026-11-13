import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Экран поездки: карта с метками и маршрутом + шторка с почасовым таймлайном.
class TripScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  int dayIndex = 0;
  final Set<String> activeCategories = {}; // пусто = все
  final mapController = MapController();

  static const _filterChips = [
    ('food', Icons.restaurant_rounded, 'Еда'),
    ('sleep', Icons.hotel_rounded, 'Сон'),
    ('activity', Icons.attractions_rounded, 'Развлечения'),
    ('sight', Icons.landscape_rounded, 'Места'),
  ];

  bool _visible(String category) =>
      activeCategories.isEmpty || activeCategories.contains(category);

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(tripProvider(widget.tripId)),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        data: (trip) {
          final day = trip.days.isEmpty ? null : trip.days[dayIndex.clamp(0, trip.days.length - 1)];
          final markers = <Marker>[];
          if (day != null) {
            for (final item in day.items) {
              final place = item.place;
              if (place == null || !_visible(item.category)) continue;
              markers.add(Marker(
                point: LatLng(place.lat, place.lon),
                width: 120,
                height: 78,
                child: _PlaceMarker(item: item, onTap: () => _showItemSheet(context, item)),
              ));
            }
          }

          return Stack(
            children: [
              // ── Карта ──
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: LatLng(trip.centerLat, trip.centerLon),
                  initialZoom: 12.5,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.crlx.waypoint.waypoint_ai',
                    tileBuilder: Theme.of(context).brightness == Brightness.dark
                        ? (context, widget, tile) => ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                -0.9, 0, 0, 0, 235,
                                0, -0.9, 0, 0, 235,
                                0, 0, -0.9, 0, 235,
                                0, 0, 0, 1, 0,
                              ]),
                              child: widget,
                            )
                        : null,
                  ),
                  if (day != null && day.route.polyline.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: day.route.polyline.map((p) => LatLng(p[0], p[1])).toList(),
                        strokeWidth: 5,
                        color: WpColors.primaryBright.withValues(alpha: .85),
                        borderStrokeWidth: 2,
                        borderColor: Colors.white.withValues(alpha: .8),
                      ),
                    ]),
                  MarkerLayer(markers: markers),
                ],
              ),

              // ── Верхняя панель: назад + фильтры ──
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _filterChips.map((c) {
                              final (cat, icon, label) = c;
                              final selected = activeCategories.contains(cat);
                              final style = CategoryStyle.of(cat);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  avatar: Icon(icon,
                                      size: 17, color: selected ? Colors.white : style.color),
                                  label: Text(label),
                                  selected: selected,
                                  showCheckmark: false,
                                  selectedColor: style.color,
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  backgroundColor: scheme.surfaceContainerLowest.withValues(alpha: .95),
                                  onSelected: (_) => setState(() {
                                    selected ? activeCategories.remove(cat) : activeCategories.add(cat);
                                  }),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -.3, curve: Curves.easeOutCubic),

              // ── Нижняя шторка: план дня ──
              DraggableScrollableSheet(
                initialChildSize: .42,
                minChildSize: .18,
                maxChildSize: .88,
                snap: true,
                snapSizes: const [.18, .42, .88],
                builder: (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: day == null
                      ? const Center(child: Text('Дни не найдены'))
                      : CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: scheme.outlineVariant,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('День ${day.index + 1}',
                                                  style: Theme.of(context).textTheme.headlineSmall),
                                              const SizedBox(height: 3),
                                              Text(day.title,
                                                  style: TextStyle(
                                                      color: scheme.onSurfaceVariant, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        if (day.route.googleMapsUrl != null)
                                          _RoundButton(
                                            icon: Icons.directions_rounded,
                                            filled: true,
                                            tooltip: 'Открыть маршрут в Google Maps',
                                            onTap: () => launchUrl(
                                              Uri.parse(day.route.googleMapsUrl!),
                                              mode: LaunchMode.externalApplication,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Селектор дней
                                  SizedBox(
                                    height: 46,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      itemCount: trip.days.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (_, i) {
                                        final selected = i == dayIndex;
                                        return ChoiceChip(
                                          label: Text('День ${i + 1}'),
                                          selected: selected,
                                          showCheckmark: false,
                                          selectedColor: scheme.primary,
                                          labelStyle: TextStyle(
                                            color: selected ? scheme.onPrimary : scheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          onSelected: (_) {
                                            setState(() => dayIndex = i);
                                            final d = trip.days[i];
                                            final pts = d.items
                                                .where((it) => it.place != null)
                                                .map((it) => LatLng(it.place!.lat, it.place!.lon))
                                                .toList();
                                            if (pts.isNotEmpty) {
                                              mapController.fitCamera(CameraFit.coordinates(
                                                coordinates: pts,
                                                padding: const EdgeInsets.fromLTRB(50, 120, 50, 320),
                                              ));
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  // Погода и дистанция дня
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                                    child: Row(
                                      children: [
                                        if (day.weather != null) ...[
                                          Icon(weatherIcon(day.weather!.icon),
                                              size: 18, color: scheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${day.weather!.description}, ${day.weather!.tempMin}…${day.weather!.tempMax}°C',
                                            style: TextStyle(
                                                color: scheme.onSurfaceVariant, fontSize: 13),
                                          ),
                                        ],
                                        const Spacer(),
                                        if (day.route.distanceKm != null)
                                          Text(
                                            '${day.route.distanceKm} км · ~${day.route.durationMin} мин',
                                            style: TextStyle(
                                                color: scheme.onSurfaceVariant, fontSize: 13),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .4)),
                                ],
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                              sliver: SliverList.builder(
                                itemCount: day.items.length,
                                itemBuilder: (_, i) {
                                  final item = day.items[i];
                                  if (!_visible(item.category)) return const SizedBox.shrink();
                                  return _TimelineTile(
                                    item: item,
                                    isLast: i == day.items.length - 1,
                                    onTap: () => _showItemSheet(context, item),
                                  ).animate().fadeIn(delay: (40 * i).ms, duration: 350.ms).slideX(begin: .04);
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showItemSheet(BuildContext context, TripItem item) {
    final scheme = Theme.of(context).colorScheme;
    final style = CategoryStyle.of(item.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (item.place?.photo != null) ...[
              NetPhoto(item.place!.photo, height: 170, width: double.infinity),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${item.time}${item.durationMin != null ? ' · ~${item.durationMin} мин' : ''}',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
                if (item.place?.stars != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(item.place!.stars!.toStringAsFixed(item.place!.stars! % 1 == 0 ? 0 : 1),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(item.description, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            if (item.place != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.place!.name + (item.place!.address != null ? ' · ${item.place!.address}' : ''),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            if (item.googleMapsUrl != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse(item.googleMapsUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.map_rounded, size: 20),
                  label: const Text('Открыть в Google Maps'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  final TripItem item;
  final VoidCallback onTap;
  const _PlaceMarker({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(item.category);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: style.color.withValues(alpha: .45), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(style.icon, color: Colors.white, size: 20),
          ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 6)],
            ),
            child: Text(
              item.place?.name ?? item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final TripItem item;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineTile({required this.item, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = CategoryStyle.of(item.category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(item.time,
                      style: TextStyle(color: style.color, fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 5),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: style.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surfaceContainerLowest, width: 2.5),
                      boxShadow: [BoxShadow(color: style.color.withValues(alpha: .4), blurRadius: 6)],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(style.icon, color: style.color, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          const SizedBox(height: 3),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.4),
                          ),
                          if (item.place != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.place_rounded, size: 13, color: style.color),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.place!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: style.color, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (item.place!.stars != null) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                                  Text(
                                    ' ${item.place!.stars!.toStringAsFixed(item.place!.stars! % 1 == 0 ? 0 : 1)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (item.place?.photo != null) ...[
                      const SizedBox(width: 10),
                      NetPhoto(item.place!.photo, width: 52, height: 52, radius: BorderRadius.circular(12)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final String? tooltip;

  const _RoundButton({required this.icon, required this.onTap, this.filled = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = Material(
      color: filled ? scheme.primary : scheme.surfaceContainerLowest.withValues(alpha: .95),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: .2),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: filled ? scheme.onPrimary : scheme.onSurface),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
