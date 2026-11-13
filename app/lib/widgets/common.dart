import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Логотип-марка с градиентом.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: wpGradient,
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [
          BoxShadow(
            color: WpColors.primaryBright.withValues(alpha: .35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.explore_rounded, color: Colors.white, size: size * .55),
    );
  }
}

/// Текст с градиентом Blue → Teal.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const GradientText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => wpGradient.createShader(bounds),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

/// Сетевое фото с плавным появлением и заглушкой.
class NetPhoto extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BorderRadius? radius;
  final BoxFit fit;
  const NetPhoto(this.url, {super.key, this.width, this.height, this.radius, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainer, scheme.surfaceContainerHigh],
        ),
      ),
      child: Icon(Icons.landscape_rounded, color: scheme.onSurfaceVariant.withValues(alpha: .4), size: 32),
    );

    final child = url == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url!,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 350),
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          );

    return ClipRRect(borderRadius: radius ?? BorderRadius.circular(20), child: child);
  }
}

/// Иконка погоды по коду сервера.
IconData weatherIcon(String icon) => switch (icon) {
      'sunny' => Icons.wb_sunny_rounded,
      'partly_cloudy' => Icons.wb_cloudy_rounded,
      'cloudy' => Icons.cloud_rounded,
      'fog' => Icons.foggy,
      'drizzle' || 'rain' => Icons.water_drop_rounded,
      'snow' => Icons.ac_unit_rounded,
      'storm' => Icons.thunderstorm_rounded,
      _ => Icons.cloud_rounded,
    };

/// Карточка-обёртка в стиле дизайн-системы.
class WpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  const WpCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
          ),
          child: child,
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
    ));
}
