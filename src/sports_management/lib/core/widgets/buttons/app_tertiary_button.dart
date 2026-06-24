import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class AppTertiaryButton extends StatelessWidget {
  const AppTertiaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.buttonVertical,
          horizontal: AppSpacing.buttonHorizontal,
        ),
        minimumSize: const Size(0, 40),
      ),
      child: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            )
          : Text(label),
    );
  }
}