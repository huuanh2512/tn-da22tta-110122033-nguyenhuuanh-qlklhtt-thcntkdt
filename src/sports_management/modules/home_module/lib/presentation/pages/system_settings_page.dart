// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:notification_module/notification_module.dart';
import '../cubit/theme_cubit.dart';
import 'account/widgets/customer_support_sheet.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  void _showLanguageDialog() {
    final languageCubit = context.read<LanguageCubit>();
    final currentLang = languageCubit.state;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            context.readTr(vi: 'Chọn ngôn ngữ', en: 'Select Language'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Tiếng Việt'),
                leading: Radio<String>(
                  value: 'vi',
                  groupValue: currentLang,
                  activeColor: const Color(0xFFFF5600),
                  onChanged: (val) {
                    if (val != null) {
                      languageCubit.setLanguage(val);
                      Navigator.pop(dialogContext);
                    }
                  },
                ),
                onTap: () {
                  languageCubit.setLanguage('vi');
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('English'),
                leading: Radio<String>(
                  value: 'en',
                  groupValue: currentLang,
                  activeColor: const Color(0xFFFF5600),
                  onChanged: (val) {
                    if (val != null) {
                      languageCubit.setLanguage(val);
                      Navigator.pop(dialogContext);
                    }
                  },
                ),
                onTap: () {
                  languageCubit.setLanguage('en');
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearCache() async {
    final loadingMsg = context.readTr(vi: 'Đang dọn dẹp bộ nhớ đệm...', en: 'Clearing cache memory...');
    final successMsg = context.readTr(vi: 'Đã dọn dẹp bộ nhớ đệm thành công!', en: 'Cache cleared successfully!');

    // Show a premium loading modal dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF5600)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                loadingMsg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    // Simulate clearing cache
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeCubit = context.read<ThemeCubit>();
    final currentTheme = themeCubit.state;
    final currentLang = context.watch<LanguageCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'Cài đặt hệ thống', en: 'System Settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          _buildSectionHeader(context.tr(vi: 'GIAO DIỆN HỆ THỐNG', en: 'SYSTEM APPEARANCE')),
          _buildThemeCard(themeCubit, currentTheme, theme),
          const SizedBox(height: 20),

          _buildSectionHeader(context.tr(vi: 'CẤU HÌNH CHUNG', en: 'GENERAL CONFIGURATION')),
          _buildCard([
            _buildSettingTile(
              icon: Icons.language,
              iconColor: Colors.teal,
              title: context.tr(vi: 'Ngôn ngữ', en: 'Language'),
              subtitle: currentLang == 'vi' ? 'Tiếng Việt' : 'English',
              onTap: _showLanguageDialog,
            ),
            const Divider(height: 1),
            _buildSettingTile(
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFFFF5600),
              title: context.tr(vi: 'Tùy chỉnh thông báo', en: 'Notification settings'),
              subtitle: context.tr(
                vi: 'Cấu hình âm thanh, đẩy và lọc thông báo',
                en: 'Configure sound, push and filter alerts',
              ),
              onTap: () => NotificationSettingsPanel.show(context),
            ),
          ]),
          const SizedBox(height: 20),

          _buildSectionHeader(context.tr(vi: 'BẢO TRÌ VÀ HỖ TRỢ', en: 'MAINTENANCE & SUPPORT')),
          _buildCard([
            _buildSettingTile(
              icon: Icons.cleaning_services_outlined,
              iconColor: Colors.blue,
              title: context.tr(vi: 'Xóa bộ nhớ đệm', en: 'Clear cache'),
              subtitle: context.tr(vi: 'Giải phóng dung lượng bộ nhớ tạm thời', en: 'Free up temporary memory storage'),
              onTap: _clearCache,
            ),
            const Divider(height: 1),
            _buildSettingTile(
              icon: Icons.help_outline_outlined,
              iconColor: Colors.purple,
              title: context.tr(vi: 'Hỗ trợ khách hàng', en: 'Customer Support'),
              subtitle: context.tr(vi: 'Gửi yêu cầu hỗ trợ hoặc báo cáo sự cố', en: 'Submit requests or report issues'),
              onTap: () => CustomerSupportSheet.show(context),
            ),
          ]),
          const SizedBox(height: 20),

          _buildSectionHeader(context.tr(vi: 'THÔNG TIN', en: 'INFORMATION')),
          _buildCard([
            _buildSettingTile(
              icon: Icons.info_outline,
              iconColor: Colors.grey.shade600,
              title: context.tr(vi: 'Phiên bản ứng dụng', en: 'Application version'),
              subtitle: 'v1.1.0',
              showArrow: false,
            ),
            const Divider(height: 1),
            _buildSettingTile(
              icon: Icons.business_outlined,
              iconColor: Colors.grey.shade600,
              title: context.tr(vi: 'Đơn vị phát triển', en: 'Developer'),
              subtitle: 'Sport Energy Development Team',
              showArrow: false,
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildThemeCard(ThemeCubit cubit, ThemeMode currentTheme, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(vi: 'Chế độ hiển thị', en: 'Theme Mode'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 16) / 3;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildThemeOption(
                      cubit: cubit,
                      mode: ThemeMode.light,
                      currentMode: currentTheme,
                      icon: Icons.light_mode_outlined,
                      label: context.tr(vi: 'Sáng', en: 'Light'),
                      width: itemWidth,
                      theme: theme,
                    ),
                    _buildThemeOption(
                      cubit: cubit,
                      mode: ThemeMode.dark,
                      currentMode: currentTheme,
                      icon: Icons.dark_mode_outlined,
                      label: context.tr(vi: 'Tối', en: 'Dark'),
                      width: itemWidth,
                      theme: theme,
                    ),
                    _buildThemeOption(
                      cubit: cubit,
                      mode: ThemeMode.system,
                      currentMode: currentTheme,
                      icon: Icons.settings_brightness_outlined,
                      label: context.tr(vi: 'Tự động', en: 'Auto'),
                      width: itemWidth,
                      theme: theme,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required ThemeCubit cubit,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required String label,
    required double width,
    required ThemeData theme,
  }) {
    final isSelected = mode == currentMode;
    final primaryColor = const Color(0xFFFF5600);

    return InkWell(
      onTap: () => cubit.setTheme(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? primaryColor
                : theme.colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : theme.iconTheme.color?.withValues(alpha: 0.7),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
        ),
      ),
      trailing: showArrow
          ? Icon(
              Icons.chevron_right,
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
            )
          : null,
      onTap: onTap,
    );
  }
}
