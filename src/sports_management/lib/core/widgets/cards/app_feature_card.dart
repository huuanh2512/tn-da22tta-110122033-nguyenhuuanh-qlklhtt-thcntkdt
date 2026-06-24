import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import 'app_surface_card.dart';

class AppFeatureCard extends StatelessWidget {
  const AppFeatureCard({
    super.key,
    required this.title,
    this.description,
    this.eyebrow,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? description;
  final String? eyebrow;
  final Widget? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(height: AppSpacing.md),
          ],
          if (eyebrow != null) ...[
            Text(eyebrow!, style: AppTypography.eyebrow),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppTypography.cardTitle),
              ),
              ?trailing,
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              description!,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}