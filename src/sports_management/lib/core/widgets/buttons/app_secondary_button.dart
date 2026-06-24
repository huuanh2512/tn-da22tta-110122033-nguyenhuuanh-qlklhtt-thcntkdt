import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface1,
          foregroundColor: AppColors.ink,
          textStyle: AppTypography.button,
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.buttonVertical,
            horizontal: AppSpacing.buttonHorizontal,
          ),
          minimumSize: const Size(0, 40),
          elevation: 0,
        ),
        child: leading != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading!,
                  const SizedBox(width: AppSpacing.xs),
                  Text(label),
                ],
              )
            : Text(label),
      ),
    );
  }
}