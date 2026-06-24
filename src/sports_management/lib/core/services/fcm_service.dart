import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:app_module/router/app_router.dart';
import 'package:get_it/get_it.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../router/app_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Nhận thông báo ngầm: ${message.messageId}');
}

class FcmService {
  FcmService._();

  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Request permissions
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM] Nhận thông báo foreground: ${message.data}');
      await _handleMessagePayload(message, isForeground: true);
    });

    // Listen to background click messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('[FCM] Message Opened App: ${message.notification?.title}');
      await _handleMessagePayload(message, isForeground: false);
    });

    // Check initial message (Terminated State)
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[FCM] Initial Message: ${initialMessage.notification?.title}',
      );
      await _handleMessagePayload(initialMessage, isForeground: false);
    }
  }

  static Future<void> registerDeviceToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Request permission again just to be sure
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          debugPrint('[FCM] Device Token: $fcmToken');
          final userService = GetIt.I<UserService>();
          final response = await userService.registerFCMToken(fcmToken);
          if (response.success) {
            debugPrint('[FCM] Đã gửi device token lên backend thành công.');
          } else {
            debugPrint(
              '[FCM] Gửi device token lên backend thất bại: ${response.message}',
            );
          }
        } else {
          debugPrint('[FCM] Không lấy được device token (null).');
        }
      } else {
        debugPrint('[FCM] Quyền thông báo bị từ chối.');
      }
    } catch (e) {
      debugPrint('[FCM] Lỗi khi đăng ký device token: $e');
    }
  }

  static Future<void> removeDeviceToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        final userService = GetIt.I<UserService>();
        final response = await userService.removeFCMToken(fcmToken);
        if (response.success) {
          debugPrint('[FCM] Đã xóa device token khỏi backend thành công.');
        } else {
          debugPrint(
            '[FCM] Xóa device token khỏi backend thất bại: ${response.message}',
          );
        }
      }
    } catch (e) {
      debugPrint('[FCM] Lỗi khi hủy đăng ký device token: $e');
    }
  }

  static String _getTitleForType(String type) {
    switch (type) {
      case 'MATCHING':
        return 'Ghép trận ⚽';
      case 'BOOKING':
        return 'Đặt sân ✅';
      case 'PAYMENT':
        return 'Thanh toán 💳';
      case 'PROMOTION':
        return 'Khuyến mãi 🔥';
      default:
        return 'Thông báo';
    }
  }

  static Future<void> _handleMessagePayload(
    RemoteMessage message, {
    required bool isForeground,
  }) async {
    final data = message.data;
    final type = data['type'] as String?;

    try {
      GetIt.I<AppNotificationEventBus>().emit(
        AppNotificationEvent(
          type: AppNotificationEventType.fcmReceived,
          data: Map<String, dynamic>.from(data),
        ),
      );
    } catch (e) {
      debugPrint('[FCM] Lỗi khi phát event reload thông báo: $e');
    }

    if (type == null) return;

    // Load local notification settings preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final pushEnabled = prefs.getBool('notification_push_enabled') ?? true;
      if (!pushEnabled) {
        debugPrint('[FCM] Bỏ qua thông báo: Người dùng tắt Thông báo đẩy.');
        return;
      }

      final bookingEnabled =
          prefs.getBool('notification_booking_enabled') ?? true;
      final paymentEnabled =
          prefs.getBool('notification_payment_enabled') ?? true;
      final systemEnabled =
          prefs.getBool('notification_system_enabled') ?? true;

      if ((type == 'BOOKING' || type == 'MATCHING') && !bookingEnabled) {
        debugPrint(
          '[FCM] Bỏ qua thông báo $type: Người dùng tắt nhận thông báo Đặt sân & Kèo đấu.',
        );
        return;
      }

      if (type == 'PAYMENT' && !paymentEnabled) {
        debugPrint(
          '[FCM] Bỏ qua thông báo $type: Người dùng tắt nhận thông báo Giao dịch & Thanh toán.',
        );
        return;
      }

      if (type == 'SYSTEM' && !systemEnabled) {
        debugPrint(
          '[FCM] Bỏ qua thông báo $type: Người dùng tắt nhận thông báo Hệ thống & Bảo trì.',
        );
        return;
      }
    } catch (e) {
      debugPrint('[FCM] Lỗi khi đọc cấu hình thông báo: $e');
    }

    String? route;
    if (type == 'MATCHING' && data['matchingSessionId'] != null) {
      route = '/matching/detail/${data['matchingSessionId']}';
    } else if (type == 'BOOKING' && data['bookingId'] != null) {
      route = '/booking/${data['bookingId']}';
    } else if (type == 'PAYMENT' && data['paymentId'] != null) {
      route = '/payments/invoices/${data['paymentId']}';
    }

    final link = data['link'] as String?;

    if (isForeground) {
      final navContext = AppModuleRouter.navigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        showDialog(
          context: navContext,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(message.notification?.title ?? _getTitleForType(type)),
            content: Text(
              message.notification?.body ?? 'Có cập nhật mới từ hệ thống.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Bỏ qua'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5600),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  if (route != null) {
                    AppRouter.router.push(route);
                  } else if (type == 'PROMOTION' && link != null) {
                    final uri = Uri.tryParse(link);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
                child: const Text('Xem chi tiết'),
              ),
            ],
          ),
        );
      }
    } else {
      if (route != null) {
        AppRouter.router.push(route);
      } else if (type == 'PROMOTION' && link != null) {
        final uri = Uri.tryParse(link);
        if (uri != null) {
          canLaunchUrl(uri).then((can) {
            if (can) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          });
        }
      }
    }
  }
}
