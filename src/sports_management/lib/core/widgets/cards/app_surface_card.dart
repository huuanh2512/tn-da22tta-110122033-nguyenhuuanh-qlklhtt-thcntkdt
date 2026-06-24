import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

enum AppCardVariant { surface, inverse, tinted }

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.surface,
    this.padding,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  Color get _background => switch (variant) {
        AppCardVariant.surface => AppColors.surface1,
        AppCardVariant.inverse => AppColors.ink,
        AppCardVariant.tinted => AppColors.surface2,
      };

  BorderSide get _border => switch (variant) {
        AppCardVariant.surface ||
        AppCardVariant.tinted =>
          const BorderSide(color: AppColors.hairline),
        AppCardVariant.inverse => BorderSide.none,
      };

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.lgAll;

    return Material(
      color: _background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: padding ??
              const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.fromBorderSide(_border),
          ),
          child: child,
        ),
      ),
    );
  }
}