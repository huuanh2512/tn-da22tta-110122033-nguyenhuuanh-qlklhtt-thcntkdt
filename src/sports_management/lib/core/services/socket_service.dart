import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:server_module/server_module.dart';
import 'package:get_it/get_it.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:notification_module/notification_module.dart';

class NotificationSocketService {
  NotificationSocketService._();

  static io.Socket? _socket;
  static Timer? _notificationReloadDebounce;

  static void connect() async {
    if (_socket != null && _socket!.connected) {
      debugPrint('[Socket.IO] Đã kết nối trước đó.');
      return;
    }

    try {
      // 1. Lấy token JWT hiện tại từ Registry
      final token = await AuthTokenProviderRegistry.currentToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          '[Socket.IO] Token rỗng hoặc không tồn tại, không thể kết nối.',
        );
        return;
      }

      // 2. Parse base URL của API để trích xuất host và port
      // Ví dụ: "http://10.0.2.2:3000/api/v1" -> "http://10.0.2.2:3000"
      final uri = Uri.parse(ApiConfig.baseUrl);
      final socketUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      debugPrint(
        '[Socket.IO] Đang kết nối tới Socket Server tại: $socketUrl...',
      );

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .setQuery({'token': token})
            .build(),
      );

      _socket!.onConnect((_) async {
        debugPrint('[Socket.IO] Kết nối thành công.');

        // 3. Lấy userId hiện tại từ Local Session và emit join_room
        final localUserUseCase = GetIt.I<GetLocalUserUseCase>();
        final userResult = await localUserUseCase();
        userResult.fold(
          (failure) => debugPrint(
            '[Socket.IO] Lỗi khi lấy thông tin người chơi: ${failure.message}',
          ),
          (user) {
            final userId = user.userId;
            if (userId != null && userId.isNotEmpty) {
              final roomId = 'user_$userId';
              _socket!.emit('join', roomId);
              debugPrint('[Socket.IO] Đã tham gia phòng (emit join): $roomId');
            }
          },
        );
      });

      // Lắng nghe sự kiện nhận thông báo thời gian thực từ Room
      _socket!.on('notification_received', (data) {
        debugPrint('[Socket.IO] Nhận sự kiện notification_received: $data');
        _handleSocketNotification(_unwrapSocketPayload(data));
      });

      // Lắng nghe sự kiện trực tiếp từ backend (nếu có)
      _socket!.on('new_notification', (data) {
        debugPrint('[Socket.IO] Nhận sự kiện new_notification: $data');
        _handleSocketNotification(_unwrapSocketPayload(data));
      });

      _socket!.onDisconnect((_) => debugPrint('[Socket.IO] Đã ngắt kết nối.'));
      _socket!.onConnectError(
        (err) => debugPrint('[Socket.IO] Connect Error: $err'),
      );
      _socket!.onError((err) => debugPrint('[Socket.IO] Error: $err'));

      _socket!.connect();
    } catch (e) {
      debugPrint('[Socket.IO] Lỗi khi khởi tạo kết nối: $e');
    }
  }

  static void disconnect() {
    _notificationReloadDebounce?.cancel();
    _notificationReloadDebounce = null;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      debugPrint('[Socket.IO] Đã ngắt kết nối và giải phóng Socket.');
    }
  }

  static void _handleSocketNotification(dynamic payload) {
    try {
      _notificationReloadDebounce?.cancel();
      _notificationReloadDebounce = Timer(
        const Duration(milliseconds: 250),
        () {
          // Socket server may emit both legacy and current notification events.
          // Debounce them into one reload for the notification list.
          GetIt.I<AppNotificationEventBus>().emit(
            AppNotificationEvent(
              type: AppNotificationEventType.fcmReceived,
              data: payload is Map<String, dynamic> ? payload : const {},
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('[Socket.IO] Lỗi khi xử lý payload sự kiện: $e');
    }
  }

  static dynamic _unwrapSocketPayload(dynamic payload) {
    if (payload is Map && payload['data'] is Map) {
      return Map<String, dynamic>.from(payload['data'] as Map);
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return payload;
  }
}
