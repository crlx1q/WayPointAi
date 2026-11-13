import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Каркас с нижней стеклянной навигацией: Home / Explore / My Trips / Profile.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  static const _tabs = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
    (Icons.map_rounded, Icons.map_outlined, 'My Trips'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: isDark ? .78 : .82),
              border: Border(
                top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .35)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final selected = shell.currentIndex == i;
                    final (active, inactive, label) = _tabs[i];
                    return Expanded(
                      child: InkWell(
                        onTap: () => shell.goBranch(i, initialLocation: selected),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.primary.withValues(alpha: .14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                selected ? active : inactive,
                                size: 24,
                                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
