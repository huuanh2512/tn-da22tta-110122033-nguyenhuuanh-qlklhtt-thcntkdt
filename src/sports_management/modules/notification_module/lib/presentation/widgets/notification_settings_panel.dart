import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import '../../core/services/app_notification_event_bus.dart';
import '../../core/app_localizations.dart';

class NotificationSettingsPanel extends StatefulWidget {
  const NotificationSettingsPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSettingsPanel(),
    );
  }

  @override
  State<NotificationSettingsPanel> createState() => _NotificationSettingsPanelState();
}

class _NotificationSettingsPanelState extends State<NotificationSettingsPanel> {
  bool _isLoading = true;

  bool _pushEnabled = true;
  bool _bookingEnabled = true;
  bool _paymentEnabled = true;
  bool _systemEnabled = true;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushEnabled = prefs.getBool('notification_push_enabled') ?? true;
        _bookingEnabled = prefs.getBool('notification_booking_enabled') ?? true;
        _paymentEnabled = prefs.getBool('notification_payment_enabled') ?? true;
        _systemEnabled = prefs.getBool('notification_system_enabled') ?? true;
        _soundEnabled = prefs.getBool('notification_sound_enabled') ?? true;
        _vibrateEnabled = prefs.getBool('notification_vibrate_enabled') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      // Trigger side-effects for specific keys
      if (key == 'notification_push_enabled') {
        final eventBus = GetIt.I<AppNotificationEventBus>();
        if (value) {
          eventBus.emit(const AppNotificationEvent(
            type: AppNotificationEventType.fcmTokenRegisterRequested,
          ));
        } else {
          eventBus.emit(const AppNotificationEvent(
            type: AppNotificationEventType.fcmTokenRemoveRequested,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error saving notification setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(vi: 'Cấu hình thông báo', en: 'Notification Settings'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(vi: 'Tùy chỉnh các cài đặt thông báo của bạn', en: 'Customize your notification options'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      _buildSectionHeader(context.tr(vi: 'Phương thức nhận', en: 'Delivery Method')),
                      _buildSettingCard([
                        _buildSwitchTile(
                          icon: Icons.notifications_active_outlined,
                          iconColor: const Color(0xFFFF5600),
                          title: context.tr(vi: 'Thông báo đẩy (Push)', en: 'Push Notifications'),
                          subtitle: context.tr(vi: 'Nhận thông báo tức thời trên màn hình khóa', en: 'Get instant alerts on your lock screen'),
                          value: _pushEnabled,
                          onChanged: (val) {
                            setState(() => _pushEnabled = val);
                            _updateSetting('notification_push_enabled', val);
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context.tr(vi: 'Loại thông báo nhận', en: 'Notification Categories')),
                      _buildSettingCard([
                        _buildSwitchTile(
                          icon: Icons.sports_soccer,
                          iconColor: Colors.green,
                          title: context.tr(vi: 'Đặt sân & Kèo đấu', en: 'Bookings & Matching'),
                          subtitle: context.tr(vi: 'Cập trạng thái đặt sân và khớp kèo đấu', en: 'Update booking status and matching results'),
                          value: _bookingEnabled,
                          enabled: _pushEnabled,
                          onChanged: (val) {
                            setState(() => _bookingEnabled = val);
                            _updateSetting('notification_booking_enabled', val);
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.payment_outlined,
                          iconColor: Colors.blue,
                          title: context.tr(vi: 'Giao dịch & Thanh toán', en: 'Transactions & Payments'),
                          subtitle: context.tr(vi: 'Hóa đơn đặt sân và xác nhận thanh toán', en: 'Booking invoices and payment confirmations'),
                          value: _paymentEnabled,
                          enabled: _pushEnabled,
                          onChanged: (val) {
                            setState(() => _paymentEnabled = val);
                            _updateSetting('notification_payment_enabled', val);
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.info_outline,
                          iconColor: Colors.orange,
                          title: context.tr(vi: 'Hệ thống & Bảo trì', en: 'System & Maintenance'),
                          subtitle: context.tr(vi: 'Tin tức, ưu đãi và lịch bảo trì hệ thống', en: 'News, promotions and scheduled maintenance'),
                          value: _systemEnabled,
                          enabled: _pushEnabled,
                          onChanged: (val) {
                            setState(() => _systemEnabled = val);
                            _updateSetting('notification_system_enabled', val);
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      _buildSectionHeader(context.tr(vi: 'Âm thanh & Phản hồi', en: 'Sound & Feedback')),
                      _buildSettingCard([
                        _buildSwitchTile(
                          icon: Icons.volume_up_outlined,
                          iconColor: Colors.purple,
                          title: context.tr(vi: 'Âm thanh thông báo', en: 'Notification Sound'),
                          subtitle: context.tr(vi: 'Phát âm thanh khi có thông báo mới', en: 'Play a sound for incoming notifications'),
                          value: _soundEnabled,
                          onChanged: (val) {
                            setState(() => _soundEnabled = val);
                            _updateSetting('notification_sound_enabled', val);
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.vibration_outlined,
                          iconColor: Colors.teal,
                          title: context.tr(vi: 'Rung', en: 'Vibration'),
                          subtitle: context.tr(vi: 'Rung thiết bị khi nhận thông báo', en: 'Vibrate device for alerts'),
                          value: _vibrateEnabled,
                          onChanged: (val) {
                            setState(() => _vibrateEnabled = val);
                            _updateSetting('notification_vibrate_enabled', val);
                          },
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
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

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? iconColor.withValues(alpha: 0.1)
              : theme.disabledColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? iconColor : theme.disabledColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enabled ? theme.textTheme.bodyLarge?.color : theme.disabledColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled
              ? theme.textTheme.bodySmall?.color
              : theme.disabledColor.withValues(alpha: 0.7),
        ),
      ),
      value: enabled ? value : false,
      onChanged: enabled ? onChanged : null,
      activeTrackColor: const Color(0xFFFF5600).withValues(alpha: 0.5),
      activeThumbColor: const Color(0xFFFF5600),
    );
  }
}
