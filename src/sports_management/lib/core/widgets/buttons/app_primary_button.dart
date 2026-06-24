import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

enum AppButtonVariant { primary, accent, inverse }

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool expand;

  Color get _background => switch (variant) {
        AppButtonVariant.primary => AppColors.ink,
        AppButtonVariant.accent => AppColors.finOrange,
        AppButtonVariant.inverse => AppColors.inverseInk,
      };

  Color get _foreground => switch (variant) {
        AppButtonVariant.primary => AppColors.inverseInk,
        AppButtonVariant.accent => AppColors.inverseInk,
        AppButtonVariant.inverse => AppColors.ink,
      };

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(label),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          );

    return SizedBox(
      width: expand ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _background,
          foregroundColor: _foreground,
          disabledBackgroundColor: AppColors.hairline,
          disabledForegroundColor: AppColors.inkTertiary,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.buttonVertical,
            horizontal: AppSpacing.buttonHorizontal,
          ),
          minimumSize: const Size(0, 40),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}