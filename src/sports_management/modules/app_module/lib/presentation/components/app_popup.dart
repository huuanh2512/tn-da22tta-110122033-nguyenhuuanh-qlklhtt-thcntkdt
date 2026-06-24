import 'package:flutter/material.dart';
import 'package:server_module/server_module.dart';

enum AppPopupTone { success, danger, warning, info }

class AppPopupOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final String? imageUrl;

  const AppPopupOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.imageUrl,
  });
}

class AppPopup {
  AppPopup._();

  static const Color _primaryColor = Color(0xFFFF5600);

  static Future<T?> showForm<T>(
    BuildContext context, {
    required String title,
    required String submitLabel,
    required Widget Function(BuildContext context, StateSetter setSheetState)
    builder,
    required VoidCallback onSubmit,
    IconData icon = Icons.edit_note_rounded,
    String? subtitle,
    bool barrierDismissible = true,
    bool showActions = true,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Theme(
                  data: theme.copyWith(
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.34),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.22),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: _primaryColor,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.32,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _primaryColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: _primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.15,
                                                ),
                                          ),
                                          if (subtitle != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              subtitle,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Đóng',
                                      onPressed: () =>
                                          Navigator.of(sheetContext).pop(),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                builder(context, setSheetState),
                              ],
                            ),
                          ),
                        ),
                        if (showActions)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Hủy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: onSubmit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      submitLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<T?> showSelection<T>(
    BuildContext context, {
    required String title,
    required List<AppPopupOption<T>> options,
    T? selectedValue,
    String? subtitle,
    IconData icon = Icons.list_alt_rounded,
    String confirmLabel = 'Xác nhận',
    String? searchHint,
    String emptySearchMessage = 'Không tìm thấy kết quả',
  }) {
    T? pendingValue = selectedValue;
    String searchQuery = '';
    return showForm<T>(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      submitLabel: confirmLabel,
      builder: (sheetContext, setSheetState) {
        final normalizedQuery = searchQuery.trim().toLowerCase();
        final filteredOptions = normalizedQuery.isEmpty
            ? options
            : options.where((option) {
                final searchableText =
                    '${option.label} ${option.subtitle ?? ''}'.toLowerCase();
                return searchableText.contains(normalizedQuery);
              }).toList();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (searchHint != null) ...[
                TextField(
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) =>
                      setSheetState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: filteredOptions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            emptySearchMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                sheetContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredOptions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final option = filteredOptions[index];
                          final selected = option.value == pendingValue;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setSheetState(() => pendingValue = option.value);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _primaryColor.withValues(alpha: 0.1)
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? _primaryColor
                                      : Theme.of(
                                          context,
                                        ).dividerColor.withValues(alpha: 0.2),
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (option.imageUrl?.trim().isNotEmpty ==
                                      true) ...[
                                    SportIconImage(
                                      imageUrl: option.imageUrl,
                                      fallbackIcon:
                                          option.icon ?? Icons.sports_rounded,
                                      size: 34,
                                      fallbackColor: selected
                                          ? _primaryColor
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.all(6),
                                    ),
                                    const SizedBox(width: 12),
                                  ] else if (option.icon != null) ...[
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _primaryColor
                                            : Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        option.icon,
                                        color: selected
                                            ? Colors.white
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? _primaryColor
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          ),
                                        ),
                                        if (option.subtitle != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            option.subtitle!,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: selected
                                        ? _primaryColor
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      onSubmit: () {
        if (pendingValue != null) {
          Navigator.of(context).pop<T>(pendingValue);
        }
      },
    );
  }

  static Future<bool> confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = 'Hủy',
    String confirmLabel = 'Xóa',
  }) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 26,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              cancelLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              confirmLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  static void show(
    BuildContext context, {
    required String message,
    AppPopupTone tone = AppPopupTone.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Clear current snackbars
    scaffoldMessenger.removeCurrentSnackBar();

    Color bgColor;
    IconData icon;

    switch (tone) {
      case AppPopupTone.success:
        bgColor = const Color(0xFF168A45);
        icon = Icons.check_rounded;
        break;
      case AppPopupTone.danger:
        bgColor = const Color(0xFFD92D20);
        icon = Icons.error_outline;
        break;
      case AppPopupTone.warning:
        bgColor = const Color(0xFFB54708);
        icon = Icons.warning_amber_rounded;
        break;
      case AppPopupTone.info:
        bgColor = const Color(0xFF2563EB);
        icon = Icons.info_outline;
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}
