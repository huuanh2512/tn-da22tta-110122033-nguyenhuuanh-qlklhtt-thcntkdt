import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Data class for a single navigation item.
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  /// Optional badge counts per item (0 = no badge, null = not shown).
  final List<int?>? badgeCounts;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.badgeCounts,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return FloatingPillBottomNavigation(
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: widget.items,
      badgeCounts: widget.badgeCounts,
    );
  }
}

/// Floating pill bottom navigation that renders whatever tab list is passed in.
class FloatingPillBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;
  final List<int?>? badgeCounts;

  const FloatingPillBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.badgeCounts,
  });

  static const Duration _animationDuration = Duration(milliseconds: 240);

  void _handleTap(int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedIndex = currentIndex.clamp(0, items.length - 1);
    final barColor = isDark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surface;
    final accentColor = colorScheme.secondary;
    final inactiveColor =
        theme.bottomNavigationBarTheme.unselectedItemColor ??
        colorScheme.onSurface.withValues(alpha: isDark ? 0.72 : 0.56);
    final borderColor = colorScheme.outline.withValues(
      alpha: isDark ? 0.22 : 0.16,
    );
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.26 : 0.12);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemCount = items.length;
            final preferredActiveWidth = constraints.maxWidth >= 340
                ? 150.0
                : 128.0;
            final inactiveWidth = itemCount <= 1
                ? 0.0
                : ((constraints.maxWidth - preferredActiveWidth) /
                          (itemCount - 1))
                      .clamp(36.0, 52.0);
            final remainingActiveWidth =
                constraints.maxWidth - (inactiveWidth * (itemCount - 1));
            final resolvedActiveWidth = remainingActiveWidth.clamp(0.0, 156.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(itemCount, (index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                final badgeCount =
                    badgeCounts != null && index < badgeCounts!.length
                    ? badgeCounts![index]
                    : null;

                return _FloatingPillNavItem(
                  width: isSelected ? resolvedActiveWidth : inactiveWidth,
                  item: item,
                  isSelected: isSelected,
                  badgeCount: badgeCount,
                  accentColor: accentColor,
                  inactiveColor: inactiveColor,
                  animationDuration: _animationDuration,
                  onTap: () => _handleTap(index),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _FloatingPillNavItem extends StatelessWidget {
  final double width;
  final AppNavItem item;
  final bool isSelected;
  final int? badgeCount;
  final Color accentColor;
  final Color inactiveColor;
  final Duration animationDuration;
  final VoidCallback onTap;

  const _FloatingPillNavItem({
    required this.width,
    required this.item,
    required this.isSelected,
    required this.badgeCount,
    required this.accentColor,
    required this.inactiveColor,
    required this.animationDuration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activePillColor = accentColor.withValues(alpha: isDark ? 0.22 : 0.12);
    final labelStyle =
        theme.textTheme.labelMedium?.copyWith(
          color: accentColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ) ??
        TextStyle(
          color: accentColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        );
    final badgeValue = badgeCount ?? 0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            width: width,
            height: 48,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 14 : 0,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? activePillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: animationDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        child: child,
                      ),
                    );
                  },
                  child: isSelected
                      ? Row(
                          key: const ValueKey('selected'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Icon(item.activeIcon, color: accentColor, size: 22),
                            const SizedBox(width: 7),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: labelStyle,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          item.icon,
                          key: const ValueKey('unselected'),
                          color: inactiveColor,
                          size: 24,
                        ),
                ),
                if (badgeValue > 0)
                  Positioned(
                    top: -4,
                    right: isSelected ? -6 : 8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeValue > 99 ? '99+' : '$badgeValue',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
