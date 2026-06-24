import 'package:flutter/material.dart';

class SportIconImage extends StatelessWidget {
  final String? imageUrl;
  final IconData fallbackIcon;
  final double size;
  final Color? fallbackColor;
  final BoxFit fit;
  final bool tintImage;
  final Color? tintColor;
  final bool showBackground;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const SportIconImage({
    super.key,
    required this.imageUrl,
    this.fallbackIcon = Icons.sports_rounded,
    this.size = 32,
    this.fallbackColor,
    this.fit = BoxFit.cover,
    this.tintImage = false,
    this.tintColor,
    this.showBackground = true,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final url = imageUrl?.trim() ?? '';
    final effectivePadding = padding ?? _defaultPadding(size);
    final effectiveFallbackColor =
        fallbackColor ??
        (isDarkMode ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final effectiveTintColor = tintColor ?? effectiveFallbackColor;
    final effectiveBackgroundColor =
        backgroundColor ??
        (isDarkMode
            ? colorScheme.onSurface.withValues(alpha: 0.14)
            : colorScheme.primary.withValues(alpha: 0.1));

    Widget iconChild;
    if (url.isEmpty) {
      iconChild = Icon(fallbackIcon, size: size, color: effectiveFallbackColor);
    } else {
      iconChild = ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: fit,
          color: tintImage ? effectiveTintColor : null,
          colorBlendMode: tintImage ? BlendMode.srcIn : null,
          errorBuilder: (context, error, stackTrace) =>
              Icon(fallbackIcon, size: size, color: effectiveFallbackColor),
        ),
      );
    }

    if (!showBackground) {
      return iconChild;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: Padding(padding: effectivePadding, child: iconChild),
    );
  }

  EdgeInsetsGeometry _defaultPadding(double iconSize) {
    if (iconSize >= 36) {
      return const EdgeInsets.all(6);
    }
    if (iconSize >= 28) {
      return const EdgeInsets.all(6);
    }
    return const EdgeInsets.all(4);
  }
}
